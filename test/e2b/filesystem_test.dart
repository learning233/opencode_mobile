import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/e2b/e2b.dart';

void main() {
  group('Filesystem Model Tests (Replicated from entryInfo.test.ts / list.test.ts)', () {
    test('EntryInfo parses directory entry correctly', () {
      final json = {
        'name': 'src',
        'path': '/home/user/src',
        'type': 'dir',
        'size': 4096,
        'modified_at': '2026-08-31T10:00:00.000Z',
      };

      final entry = EntryInfo.fromJson(json);
      expect(entry.name, equals('src'));
      expect(entry.path, equals('/home/user/src'));
      expect(entry.type, equals(EntryType.directory));
      expect(entry.size, equals(4096));
      expect(entry.modifiedAt, isNotNull);
    });

    test('EntryInfo parses symlink and file correctly', () {
      final fileJson = {
        'name': 'README.md',
        'path': '/home/user/README.md',
        'file_type': 'file',
        'size': 512,
      };
      final fileEntry = EntryInfo.fromJson(fileJson);
      expect(fileEntry.type, equals(EntryType.file));

      final symlinkJson = {
        'name': 'current',
        'path': '/home/user/current',
        'type': 'symlink',
        'size': 0,
      };
      final symlinkEntry = EntryInfo.fromJson(symlinkJson);
      expect(symlinkEntry.type, equals(EntryType.symlink));
    });

    test('FilesystemEvent model', () {
      const event = FilesystemEvent(
        path: '/tmp/test.log',
        type: FilesystemEventType.write,
      );

      expect(event.path, equals('/tmp/test.log'));
      expect(event.type, equals(FilesystemEventType.write));
    });
  });
}
