import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/utils/diff_paths.dart';

void main() {
  group('normalizeDiffPath', () {
    test('keeps repo-relative paths intact', () {
      expect(normalizeDiffPath('lib/foo.dart'), 'lib/foo.dart');
      expect(normalizeDiffPath('src/deep/bar.dart'), 'src/deep/bar.dart');
    });

    test('normalizes backslashes to forward slashes', () {
      expect(normalizeDiffPath(r'lib\foo.dart'), 'lib/foo.dart');
      expect(normalizeDiffPath(r'lib\deep\bar.dart'), 'lib/deep/bar.dart');
    });

    test('strips leading ./ and /', () {
      expect(normalizeDiffPath('./lib/foo.dart'), 'lib/foo.dart');
      expect(normalizeDiffPath('/lib/foo.dart'), 'lib/foo.dart');
    });

    test('resolves . and .. segments', () {
      expect(normalizeDiffPath('a/./b/foo.dart'), 'a/b/foo.dart');
      expect(normalizeDiffPath('a/b/../foo.dart'), 'a/foo.dart');
    });

    test('strips an absolute worktree prefix', () {
      expect(
        normalizeDiffPath(
          'D:/project/opencode_app/lib/foo.dart',
          ['D:/project/opencode_app'],
        ),
        'lib/foo.dart',
      );
    });

    test('returns empty for empty input', () {
      expect(normalizeDiffPath(''), '');
    });
  });

  group('diffPathsEqual', () {
    test('matches identical paths', () {
      expect(diffPathsEqual('lib/foo.dart', 'lib/foo.dart'), isTrue);
    });

    test('matches backslash vs forward slash', () {
      expect(diffPathsEqual(r'lib\foo.dart', 'lib/foo.dart'), isTrue);
    });

    test('matches absolute vs repo-relative with known worktree', () {
      expect(
        diffPathsEqual(
          'D:/project/opencode_app/lib/foo.dart',
          'lib/foo.dart',
          ['D:/project/opencode_app'],
        ),
        isTrue,
      );
    });

    test('absolute vs relative without known worktree stays unmatched', () {
      expect(
        diffPathsEqual('D:/project/opencode_app/lib/foo.dart', 'lib/foo.dart'),
        isFalse,
      );
    });

    test('matches with . segments and case differences', () {
      expect(diffPathsEqual('./lib/foo.dart', 'Lib/FOO.dart'), isTrue);
    });

    test('rejects different files', () {
      expect(diffPathsEqual('lib/foo.dart', 'lib/bar.dart'), isFalse);
      expect(diffPathsEqual('a/foo.dart', 'b/foo.dart'), isFalse);
    });
  });
}
