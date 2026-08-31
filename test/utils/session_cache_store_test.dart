import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/api/models/message.dart';
import 'package:opencode_app/controllers/session_controller.dart';
import 'package:opencode_app/utils/app_logger.dart';
import 'package:opencode_app/utils/session_cache_store.dart';

Map<String, dynamic> _rawMessage(
  String id, {
  String? role,
  required int created,
  String? type,
}) => {
  'id': id,
  'role': ?role,
  'type': ?type,
  'parts': [
    {'id': 'p-$id', 'type': 'text', 'text': 'msg-$id'},
  ],
  'time': {'created': created},
};

void main() {
  late Directory temp;
  late SessionCacheStore store;

  setUpAll(() async {
    final logDir = Directory.systemTemp.createTempSync('session_cache_log');
    await AppLogger.init(logDir: logDir.path);
  });

  setUp(() {
    temp = Directory.systemTemp.createTempSync('session_cache_store_test');
    store = SessionCacheStore(baseDir: temp);
  });

  tearDown(() {
    try {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    } catch (_) {}
  });

  Directory cacheDir() =>
      Directory('${temp.path}${Platform.pathSeparator}session_cache');

  group('SessionCacheStore', () {
    test('save then load round-trips the raw messages', () async {
      final messages = [
        _rawMessage('m1', role: 'user', created: 100),
        _rawMessage('m2', role: 'assistant', created: 200),
      ];

      await store.save('s1', messages);
      final loaded = await store.load('s1');

      expect(loaded, isNotNull);
      expect(loaded, hasLength(2));
      expect(loaded![0]['id'], 'm1');
      expect(loaded[1]['id'], 'm2');
      // 时间正序保持不变（归一化在写入侧完成）。
      expect(
        (loaded[0]['time'] as Map)['created'] as int,
        lessThan((loaded[1]['time'] as Map)['created'] as int),
      );
    });

    test('save overwrites the previous snapshot', () async {
      await store.save('s1', [_rawMessage('m1', role: 'user', created: 100)]);
      await store.save('s1', [
        _rawMessage('m2', role: 'assistant', created: 200),
        _rawMessage('m3', role: 'user', created: 300),
      ]);

      final loaded = await store.load('s1');

      expect(loaded, hasLength(2));
      expect(loaded!.map((m) => m['id']), ['m2', 'm3']);
    });

    test('save leaves no tmp file behind (atomic rename)', () async {
      await store.save('s1', [_rawMessage('m1', role: 'user', created: 100)]);

      final tmpFiles = cacheDir()
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'))
          .toList();

      expect(tmpFiles, isEmpty);
    });

    test('delete removes the cache file', () async {
      await store.save('s1', [_rawMessage('m1', role: 'user', created: 100)]);
      await store.delete('s1');

      expect(await store.load('s1'), isNull);
    });

    test('clearAll removes every cache file', () async {
      await store.save('s1', [_rawMessage('m1', role: 'user', created: 100)]);
      await store.save('s2', [_rawMessage('m2', role: 'user', created: 200)]);
      await store.clearAll();

      expect(await store.load('s1'), isNull);
      expect(await store.load('s2'), isNull);
    });

    test('load returns null for a missing session', () async {
      expect(await store.load('nope'), isNull);
    });

    test('load returns null for corrupted json', () async {
      cacheDir().createSync(recursive: true);
      File(
        '${cacheDir().path}${Platform.pathSeparator}s1.json',
      ).writeAsStringSync('{"v":1,"messages":[{"id":');

      expect(await store.load('s1'), isNull);
    });

    test('load returns null for an unsupported version', () async {
      await store.save('s1', [_rawMessage('m1', role: 'user', created: 100)]);
      final file = File('${cacheDir().path}${Platform.pathSeparator}s1.json');
      final payload = jsonDecode(file.readAsStringSync()) as Map;
      payload['v'] = 999;
      file.writeAsStringSync(jsonEncode(payload));

      expect(await store.load('s1'), isNull);
    });

    test('empty messages are never written to disk', () async {
      await store.save('s1', []);

      expect(
        cacheDir().existsSync() && cacheDir().listSync().isNotEmpty,
        isFalse,
      );
      expect(await store.load('s1'), isNull);
    });

    test('session ids containing path separators are rejected', () async {
      await store.save('../evil', [
        _rawMessage('m1', role: 'user', created: 100),
      ]);

      expect(await store.load('../evil'), isNull);
      // 目录里不应出现任何文件（未逃逸出 session_cache）。
      expect(
        cacheDir().existsSync() && cacheDir().listSync().isNotEmpty,
        isFalse,
      );
    });

    test('prune removes the oldest files beyond the limits', () async {
      for (var i = 0; i < 5; i++) {
        await store.save('s$i', [_rawMessage('m$i', role: 'user', created: i)]);
      }
      final dir = cacheDir();
      final files = dir.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (var i = 0; i < files.length; i++) {
        files[i].setLastModifiedSync(
          DateTime.now().subtract(Duration(minutes: 100 - i)),
        );
      }

      await store.prune(maxFiles: 3);

      final remaining = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toList();
      expect(remaining, hasLength(3));
      // 最旧的 s0、s1 被淘汰。
      expect(remaining.contains('s0.json'), isFalse);
      expect(remaining.contains('s1.json'), isFalse);
    });
  });

  group('SessionController.normalizeServerMessages', () {
    test('reverses newest-first responses to chronological order', () {
      final raws = [
        _rawMessage('m2', role: 'assistant', created: 200),
        _rawMessage('m1', role: 'user', created: 100),
      ];

      final msgs = SessionController.normalizeServerMessages(raws);

      expect(msgs.map((m) => m.id).toList(), ['m1', 'm2']);
    });

    test('keeps chronological responses unchanged', () {
      final raws = [
        _rawMessage('m1', role: 'user', created: 100),
        _rawMessage('m2', role: 'assistant', created: 200),
      ];

      final msgs = SessionController.normalizeServerMessages(raws);

      expect(msgs.map((m) => m.id).toList(), ['m1', 'm2']);
    });

    test('filters out non-chat metadata events', () {
      final raws = [
        _rawMessage('m1', role: 'user', created: 100),
        _rawMessage('evt', created: 150, type: 'agent-switched'),
        _rawMessage('m2', role: 'assistant', created: 200),
      ];

      final msgs = SessionController.normalizeServerMessages(raws);

      expect(msgs.map((m) => m.id).toList(), ['m1', 'm2']);
    });

    test('handles empty and single-message inputs', () {
      expect(SessionController.normalizeServerMessages([]), isEmpty);
      final single = SessionController.normalizeServerMessages([
        _rawMessage('m1', role: 'user', created: 100),
      ]);
      expect(single, hasLength(1));
    });

    test('output raw json round-trips through MessageModel.fromJson', () {
      final raws = [
        _rawMessage('m2', role: 'assistant', created: 200),
        _rawMessage('m1', role: 'user', created: 100),
      ];

      final msgs = SessionController.normalizeServerMessages(raws);
      final rehydrated = msgs
          .map((m) => MessageModel.fromJson(Map<String, dynamic>.from(m.raw)))
          .toList();

      expect(rehydrated.map((m) => m.id).toList(), ['m1', 'm2']);
      expect(rehydrated.first.parts.first.raw['text'], 'msg-m1');
    });
  });
}
