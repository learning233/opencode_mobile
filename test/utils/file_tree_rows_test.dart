import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/api/models/file_entry.dart';
import 'package:opencode_app/utils/file_tree_rows.dart';

FileEntry _dir(String name, String path) =>
    FileEntry(name: name, path: path, type: 'directory');

FileEntry _file(String name, String path) =>
    FileEntry(name: name, path: path, type: 'file');

Map<String, List<FileEntry>> _cache(Map<String, List<FileEntry>> m) =>
    Map<String, List<FileEntry>>.from(m);

void main() {
  group('flattenFileTree', () {
    const root = '.';

    test('empty state produces no rows', () {
      final rows = flattenFileTree(
        root: root,
        dirCache: {},
        expanded: {},
        loading: {},
        errors: {},
      );
      expect(rows, isEmpty);
    });

    test('renders root children in cache order (dirs first, then files)', () {
      final rows = flattenFileTree(
        root: root,
        dirCache: _cache({
          root: [_dir('src', 'src'), _file('a.dart', 'a.dart')],
        }),
        expanded: {root: true},
        loading: {},
        errors: {},
      );

      expect(rows.length, 2);
      expect(rows[0].kind, FileTreeRowKind.folder);
      expect(rows[0].entry?.path, 'src');
      expect(rows[0].depth, 0);
      expect(rows[1].kind, FileTreeRowKind.file);
      expect(rows[1].entry?.path, 'a.dart');
    });

    test('expanded folder recurses its children at depth+1', () {
      final rows = flattenFileTree(
        root: root,
        dirCache: _cache({
          root: [_dir('src', 'src')],
          'src': [_file('b.dart', 'src/b.dart'), _dir('lib', 'src/lib')],
        }),
        expanded: {root: true, 'src': true},
        loading: {},
        errors: {},
      );

      expect(rows.length, 3);
      expect(rows[0].entry?.path, 'src');
      expect(rows[0].depth, 0);
      expect(rows[1].entry?.path, 'src/b.dart');
      expect(rows[1].depth, 1);
      expect(rows[2].entry?.path, 'src/lib');
      expect(rows[2].depth, 1);
    });

    test('collapsed folder shows only the folder row, no children', () {
      final rows = flattenFileTree(
        root: root,
        dirCache: _cache({
          root: [_dir('src', 'src')],
          'src': [_file('b.dart', 'src/b.dart')],
        }),
        expanded: {root: true, 'src': false},
        loading: {},
        errors: {},
      );

      expect(rows.length, 1);
      expect(rows[0].entry?.path, 'src');
    });

    test('loading dir without cached children yields a loading row', () {
      final rows = flattenFileTree(
        root: root,
        dirCache: _cache({
          root: [_dir('src', 'src')],
        }),
        expanded: {root: true, 'src': true},
        loading: {'src': true},
        errors: {},
      );

      expect(rows.length, 2);
      expect(rows[1].kind, FileTreeRowKind.loading);
      expect(rows[1].dir, 'src');
      expect(rows[1].depth, 1);
    });

    test('loading dir with cached children shows cached children', () {
      final rows = flattenFileTree(
        root: root,
        dirCache: _cache({
          root: [_dir('src', 'src')],
          'src': [_file('b.dart', 'src/b.dart')],
        }),
        expanded: {root: true, 'src': true},
        loading: {'src': true},
        errors: {},
      );

      expect(rows.length, 2);
      expect(rows[1].kind, FileTreeRowKind.file);
    });

    test('errored dir without cached children yields an error row', () {
      final rows = flattenFileTree(
        root: root,
        dirCache: _cache({
          root: [_dir('src', 'src')],
        }),
        expanded: {root: true, 'src': true},
        loading: {},
        errors: {'src': 'boom'},
      );

      expect(rows.length, 2);
      expect(rows[1].kind, FileTreeRowKind.error);
      expect(rows[1].error, 'boom');
      expect(rows[1].dir, 'src');
    });

    test('maxDepth caps recursion beyond the default limit', () {
      // 构造深度 10 的链：'.' -> src1 -> src2 -> ... -> src10 -> leaf.dart
      final cache = <String, List<FileEntry>>{};
      final expanded = <String, bool>{root: true};
      cache[root] = [_dir('src1', 'src1')];
      for (var i = 1; i <= 10; i++) {
        final path = i == 1 ? 'src$i' : 'src${i - 1}/src$i';
        final child = i == 10 ? 'src9/src10' : 'src$i/src${i + 1}';
        if (i < 10) {
          cache[path] = [_dir('src${i + 1}', child)];
        } else {
          cache[path] = [_file('leaf.dart', '$path/leaf.dart')];
        }
        expanded[path] = true;
      }

      final rows = flattenFileTree(
        root: root,
        dirCache: cache,
        expanded: expanded,
        loading: {},
        errors: {},
      );

      final deepestFolder = rows.where((r) => r.kind == FileTreeRowKind.folder).last;
      expect(deepestFolder.depth, lessThanOrEqualTo(kFileTreeMaxDepth));
      final hasDeepChildren = rows.any(
        (r) => r.kind == FileTreeRowKind.file && r.depth > kFileTreeMaxDepth,
      );
      expect(hasDeepChildren, isFalse);
    });
  });
}
