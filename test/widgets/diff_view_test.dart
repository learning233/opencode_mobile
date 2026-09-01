import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/pages/home/tablet/diff_view.dart';

void main() {
  group('parsePatchLines', () {
    test('drops ---/+++ file headers but keeps ---x/+++x content lines', () {
      final patch = [
        '--- a/src/a.ts',
        '+++ b/src/a.ts',
        '@@ -1,4 +1,4 @@',
        ' context',
        '---removed',
        '+++added',
        '-gone',
        '+kept',
      ].join('\n');

      final lines = parsePatchLines(patch);

      final removed = lines
          .where((l) => l.type == DiffLineType.removed)
          .map((l) => l.text)
          .toList();
      final added = lines
          .where((l) => l.type == DiffLineType.added)
          .map((l) => l.text)
          .toList();

      expect(removed, contains('--removed'));
      expect(removed, contains('gone'));
      expect(added, contains('++added'));
      expect(added, contains('kept'));
      expect(lines.any((l) => l.text.contains('a/src/a.ts')), isFalse);
    });

    test('loose patch fallback keeps +++x/---x content lines', () {
      final patch = [
        '+++added',
        '---removed',
        '+kept',
        '-gone',
        ' context',
      ].join('\n');

      final lines = parsePatchLines(patch);

      final removed = lines
          .where((l) => l.type == DiffLineType.removed)
          .map((l) => l.text)
          .toList();
      final added = lines
          .where((l) => l.type == DiffLineType.added)
          .map((l) => l.text)
          .toList();

      expect(added, contains('++added'));
      expect(added, contains('kept'));
      expect(removed, contains('--removed'));
      expect(removed, contains('gone'));
    });

    test('keeps hunk content lines that look like ---/+++ headers', () {
      final patch = [
        '--- a/src/a.ts',
        '+++ b/src/a.ts',
        '@@ -1,2 +1,2 @@',
        '--- spaced',
        '+++ spaced',
      ].join('\n');

      final lines = parsePatchLines(patch);

      final removed = lines
          .where((l) => l.type == DiffLineType.removed)
          .map((l) => l.text)
          .toList();
      final added = lines
          .where((l) => l.type == DiffLineType.added)
          .map((l) => l.text)
          .toList();

      expect(removed, contains('-- spaced'));
      expect(added, contains('++ spaced'));
      expect(lines.any((l) => l.text.contains('a/src/a.ts')), isFalse);
    });
  });
}
