import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/api/models/file_entry.dart';
import 'package:opencode_app/api/models/snapshot_file_diff.dart';
import 'package:opencode_app/controllers/project_controller.dart';
import 'package:opencode_app/controllers/tablet_tool_controller.dart';
import 'package:opencode_app/models/session_runtime_state.dart';

void main() {
  group('ProjectController directoryCache', () {
    late ProjectController ctrl;

    setUp(() {
      ctrl = ProjectController();
    });

    test('dirKey correctly formats worktree and path', () {
      expect(
        ProjectController.dirKey('src', '/work/proj'),
        '/work/proj\u0000src',
      );
      expect(ProjectController.dirKey('src', null), 'src');
    });

    test('directoryCache can store and retrieve entries', () {
      final entry = FileEntry(
        name: 'main.dart',
        path: 'src/main.dart',
        type: 'file',
      );
      const key = '/work/proj\u0000src';
      ctrl.directoryCache[key] = [entry];

      expect(ctrl.directoryCache.containsKey(key), isTrue);
      expect(ctrl.directoryCache[key]!.first.name, 'main.dart');
    });

    test('invalidateDirectoryCache removes specific path', () {
      const key1 = '/work/proj\u0000src';
      const key2 = '/work/proj\u0000lib';
      ctrl.directoryCache[key1] = [];
      ctrl.directoryCache[key2] = [];

      ctrl.invalidateDirectoryCache(path: 'src', worktree: '/work/proj');
      expect(ctrl.directoryCache.containsKey(key1), isFalse);
      expect(ctrl.directoryCache.containsKey(key2), isTrue);
    });

    test('invalidateDirectoryCache removes all paths for a worktree', () {
      const key1 = '/work/projA\u0000src';
      const key2 = '/work/projA\u0000lib';
      const key3 = '/work/projB\u0000src';
      ctrl.directoryCache[key1] = [];
      ctrl.directoryCache[key2] = [];
      ctrl.directoryCache[key3] = [];

      ctrl.invalidateDirectoryCache(worktree: '/work/projA');
      expect(ctrl.directoryCache.containsKey(key1), isFalse);
      expect(ctrl.directoryCache.containsKey(key2), isFalse);
      expect(ctrl.directoryCache.containsKey(key3), isTrue);
    });

    test('invalidateDirectoryCache clears everything when no args given', () {
      ctrl.directoryCache['key1'] = [];
      ctrl.directoryCache['key2'] = [];

      ctrl.invalidateDirectoryCache();
      expect(ctrl.directoryCache, isEmpty);
    });
  });

  group('SessionRuntimeState fetchedMessageDiffs cache', () {
    test('fetchedMessageDiffs stores and retrieves diffs per messageId', () {
      final state = SessionRuntimeState('ses_1');
      expect(state.fetchedMessageDiffs, isEmpty);

      final diff = SnapshotFileDiff(file: 'lib/test.dart', status: 'modified');
      state.fetchedMessageDiffs['msg_123'] = [diff];

      expect(state.fetchedMessageDiffs.containsKey('msg_123'), isTrue);
      expect(state.fetchedMessageDiffs['msg_123']!.first.file, 'lib/test.dart');
    });
  });

  group('TabletToolController binary cache', () {
    test('cacheBinaryContent and cachedBinaryContent work correctly', () {
      final ctrl = TabletToolController();
      final bytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
      ]); // PNG magic header

      ctrl.cacheBinaryContent('assets/logo.png', bytes, worktree: '/proj');
      expect(
        ctrl.cachedBinaryContent('assets/logo.png', worktree: '/proj'),
        bytes,
      );
      expect(
        ctrl.cachedBinaryContent('assets/logo.png', worktree: '/other'),
        isNull,
      );

      ctrl.invalidateBinaryContent('assets/logo.png', worktree: '/proj');
      expect(
        ctrl.cachedBinaryContent('assets/logo.png', worktree: '/proj'),
        isNull,
      );
    });
  });
}
