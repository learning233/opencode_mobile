import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_logger.dart';

/// SWR 本地会话历史缓存：按会话持久化服务端原始消息 JSON，供
/// `SessionController.loadMessages` 先出本地缓存秒开、再由网络静默对齐。
///
/// 文件格式：`session_cache/<sessionId>.json`，内容
/// `{"v":<版本>,"messages":[...]}`。messages 为**时间正序、已过滤
/// isChatMessage** 的服务端原始 JSON（即 `MessageModel.raw`），归一化在
/// 写入侧完成，读取侧无需再排序/过滤。空 messages 不落盘——空会话宁可走
/// 正常网络加载态（配合 loadMessages 的加载中/失败重试三态 UI）。
class SessionCacheStore {
  SessionCacheStore({Directory? baseDir}) : _baseDir = baseDir;

  /// 全局共享实例。测试通过注入 [baseDir] 指向临时目录。
  static final SessionCacheStore instance = SessionCacheStore();

  final Directory? _baseDir;

  static const _dirName = 'session_cache';
  static const _version = 1;

  /// 淘汰上限：超出后按 mtime 从旧到新删除，防止磁盘无限增长。
  static const _maxFiles = 200;
  static const _maxTotalBytes = 64 * 1024 * 1024;

  /// 写入串行队列：save/delete/clearAll 共用，防止同一文件的 tmp+rename
  /// 并发交错，也防止 delete 之后被先入队的 save 重新写出已删会话的文件。
  Future<void> _writeQueue = Future.value();

  bool _pruneDone = false;

  Future<Directory> _dir() async {
    final root = _baseDir ?? await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, _dirName));
    await dir.create(recursive: true);
    if (!_pruneDone) {
      _pruneDone = true;
      await prune();
    }
    return dir;
  }

  /// 会话 ID 直接参与文件名，拒绝空值与路径分隔符，防畸形 ID 逃逸目录。
  bool _isValidId(String sessionId) =>
      sessionId.isNotEmpty &&
      !sessionId.contains('/') &&
      !sessionId.contains('\\');

  File _fileFor(Directory dir, String sessionId) =>
      File(p.join(dir.path, '$sessionId.json'));

  /// 读取会话缓存。文件缺失、版本不符、损坏或解析异常一律返回 `null`，
  /// 调用方静默降级为正常网络加载。
  Future<List<Map<String, dynamic>>?> load(String sessionId) async {
    if (!_isValidId(sessionId)) return null;
    try {
      final dir = await _dir();
      final file = _fileFor(dir, sessionId);
      if (!await file.exists()) return null;
      final decoded = await compute(jsonDecode, await file.readAsString());
      if (decoded is! Map || decoded['v'] != _version) return null;
      final rawMessages = decoded['messages'];
      if (rawMessages is! List) return null;
      final messages = rawMessages
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (messages.isEmpty) return null;
      return messages;
    } catch (e) {
      AppLogger.e('SessionCacheStore.load failed: $e');
      return null;
    }
  }

  /// 原子写入：jsonEncode 放 compute（大会话数 MB，避免主线程卡顿），
  /// 先写 `.tmp` 再 rename 覆盖，断电/闪退不会留下半截文件。
  Future<void> save(String sessionId, List<Map<String, dynamic>> messages) {
    if (!_isValidId(sessionId) || messages.isEmpty) return Future.value();
    return _enqueue(() async {
      try {
        final dir = await _dir();
        final json = await compute(
          jsonEncode,
          {'v': _version, 'messages': messages},
        );
        final file = _fileFor(dir, sessionId);
        final tmp = File('${file.path}.tmp');
        try {
          await tmp.writeAsString(json, flush: true);
          await tmp.rename(file.path);
        } catch (_) {
          if (await tmp.exists()) await tmp.delete();
          rethrow;
        }
      } catch (e) {
        AppLogger.e('SessionCacheStore.save failed: $e');
      }
    });
  }

  Future<void> delete(String sessionId) {
    if (!_isValidId(sessionId)) return Future.value();
    return _enqueue(() async {
      try {
        final dir = await _dir();
        final file = _fileFor(dir, sessionId);
        if (await file.exists()) await file.delete();
        final tmp = File('${file.path}.tmp');
        if (await tmp.exists()) await tmp.delete();
      } catch (e) {
        AppLogger.e('SessionCacheStore.delete failed: $e');
      }
    });
  }

  Future<void> clearAll() {
    return _enqueue(() async {
      try {
        final dir = await _dir();
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          try {
            await entity.delete();
          } catch (_) {}
        }
      } catch (e) {
        AppLogger.e('SessionCacheStore.clearAll failed: $e');
      }
    });
  }

  /// 淘汰最旧的缓存文件。生产路径仅在首次访问目录时自动执行一次；
  /// 测试可直接调用并传入更小的上限。
  Future<void> prune({
    int maxFiles = _maxFiles,
    int maxTotalBytes = _maxTotalBytes,
  }) async {
    try {
      final dir = await _dir();
      final entries = <File, ({DateTime modified, int size})>{};
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final stat = await entity.stat();
          entries[entity] = (modified: stat.modified, size: stat.size);
          total += stat.size;
        } catch (_) {}
      }
      if (entries.length <= maxFiles && total <= maxTotalBytes) return;
      final byOldest = entries.keys.toList()
        ..sort(
          (a, b) => entries[a]!.modified.compareTo(entries[b]!.modified),
        );
      for (final file in byOldest) {
        if (entries.length <= maxFiles && total <= maxTotalBytes) return;
        final info = entries.remove(file);
        total -= info?.size ?? 0;
        try {
          await file.delete();
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.e('SessionCacheStore.prune failed: $e');
    }
  }

  Future<void> _enqueue(Future<void> Function() task) {
    final next = _writeQueue.then((_) => task());
    // 单个任务失败不能让队列中断后续任务。
    _writeQueue = next.catchError((_) {});
    return next;
  }
}
