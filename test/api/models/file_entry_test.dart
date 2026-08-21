import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/api/models/file_entry.dart';

void main() {
  group('FileEntry.fromJson', () {
    test('parses a plain file entry', () {
      final entry = FileEntry.fromJson({
        'name': 'main.dart',
        'path': 'lib/main.dart',
        'type': 'file',
      });
      expect(entry.name, 'main.dart');
      expect(entry.path, 'lib/main.dart');
      expect(entry.type, 'file');
      expect(entry.isDirectory, isFalse);
      expect(entry.ignored, isFalse);
    });

    test('strips trailing path separator from directories', () {
      final entry = FileEntry.fromJson({
        'name': 'lib',
        'path': 'lib/',
        'type': 'directory',
      });
      expect(entry.path, 'lib');
      expect(entry.isDirectory, isTrue);
    });

    test('normalizes backslash separators to forward slashes', () {
      final entry = FileEntry.fromJson({
        'name': 'lib',
        'path': r'lib\',
        'type': 'directory',
      });
      expect(entry.path, 'lib');
    });

    test('normalizes backslashes in files', () {
      final entry = FileEntry.fromJson({
        'name': 'main.dart',
        'path': r'lib\main.dart',
        'type': 'file',
      });
      expect(entry.path, 'lib/main.dart');
    });

    test('keeps a plain relative file path untouched', () {
      final entry = FileEntry.fromJson({
        'name': 'a.txt',
        'path': 'src/a.txt',
        'type': 'file',
      });
      expect(entry.path, 'src/a.txt');
    });

    test('parses ignored flag', () {
      final entry = FileEntry.fromJson({
        'name': 'node_modules',
        'path': 'node_modules/',
        'type': 'directory',
        'ignored': true,
      });
      expect(entry.ignored, isTrue);
    });

    test('parses absolute field', () {
      final entry = FileEntry.fromJson({
        'name': 'main.dart',
        'path': 'lib/main.dart',
        'type': 'file',
        'absolute': '/repo/lib/main.dart',
      });
      expect(entry.absolute, '/repo/lib/main.dart');
    });

    test('fallback name derivation still works from raw path', () {
      final entry = FileEntry.fromJson({'path': r'a\b\file.txt', 'type': 'file'});
      expect(entry.name, 'file.txt');
      expect(entry.path, 'a/b/file.txt');
    });
  });
}
