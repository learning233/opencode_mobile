import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/utils/unicode_v11.dart';

void main() {
  group('UnicodeV11', () {
    group('constructor', () {
      test('Given UnicodeV11, When created, Then has version 11', () {
        final unicode = UnicodeV11();
        expect(unicode.version, equals('11'));
      });
    });

    group('wcwidth', () {
      group('control characters', () {
        test('Given code point 0, When wcwidth called, Then returns 0', () {
          expect(unicodeV11.wcwidth(0), equals(0));
        });

        test('Given code point 31, When wcwidth called, Then returns 0', () {
          expect(unicodeV11.wcwidth(31), equals(0));
        });
      });

      group('ASCII printable', () {
        test('Given code point 32 (space), When wcwidth called, Then returns 1',
            () {
          expect(unicodeV11.wcwidth(32), equals(1));
        });

        test('Given code point 126 (~), When wcwidth called, Then returns 1',
            () {
          expect(unicodeV11.wcwidth(126), equals(1));
        });
      });

      group('C0 controls', () {
        test('Given code point 127 (DEL), When wcwidth called, Then returns 0',
            () {
          expect(unicodeV11.wcwidth(127), equals(0));
        });
      });

      group('combining characters', () {
        test(
            'Given combining grave accent (0x0300), When wcwidth called, Then returns 0',
            () {
          expect(unicodeV11.wcwidth(0x0300), equals(0));
        });

        test(
            'Given combining acute (0x0301), When wcwidth called, Then returns 0',
            () {
          expect(unicodeV11.wcwidth(0x0301), equals(0));
        });
      });

      group('wide characters (CJK)', () {
        test(
            'Given Han character (0x4E00, 一), When wcwidth called, Then returns 2',
            () {
          expect(unicodeV11.wcwidth(0x4E00), equals(2));
        });

        test('Given Hiragana (0x3042, あ), When wcwidth called, Then returns 2',
            () {
          expect(unicodeV11.wcwidth(0x3042), equals(2));
        });

        test('Given Katakana (0x30A2, ア), When wcwidth called, Then returns 2',
            () {
          expect(unicodeV11.wcwidth(0x30A2), equals(2));
        });

        test('Given Hangul (0xAC00), When wcwidth called, Then returns 2', () {
          expect(unicodeV11.wcwidth(0xAC00), equals(2));
        });
      });

      group('emoji', () {
        test('Given emoji (0x1F600, 😀), When wcwidth called, Then returns 2',
            () {
          expect(unicodeV11.wcwidth(0x1F600), equals(2));
        });

        test('Given arrow (0x1F4A9, 💩), When wcwidth called, Then returns 2',
            () {
          expect(unicodeV11.wcwidth(0x1F4A9), equals(2));
        });
      });

      group('non-wide BMP', () {
        test(
            'Given Latin-1 character (0x00A9, ©), When wcwidth called, Then returns 1',
            () {
          expect(unicodeV11.wcwidth(0x00A9), equals(1));
        });
      });

      group('high surrogates', () {
        test(
            'Given code point > 65535 combining, When wcwidth called, Then returns 0',
            () {
          // First high combining character
          expect(unicodeV11.wcwidth(0x1DC0), equals(0));
        });

        test(
            'Given code point > 65535 wide, When wcwidth called, Then returns 2',
            () {
          // First high wide character (CJK Extension B starts at 0x20000)
          expect(unicodeV11.wcwidth(0x20000), equals(2));
        });
      });
    });
  });

  group('unicodeV11 singleton', () {
    test('Given unicodeV11, When accessed, Then returns instance', () {
      expect(unicodeV11, isA<UnicodeV11>());
      expect(unicodeV11.version, equals('11'));
    });
  });

  group('bisearch', () {
    test('Given value in range, When bisearch called, Then returns true', () {
      expect(bisearch(0x0300, BMP_COMBINING), isTrue);
    });

    test('Given value not in range, When bisearch called, Then returns false',
        () {
      expect(bisearch(0xFFFF, BMP_COMBINING), isFalse);
    });

    test('Given value below range, When bisearch called, Then returns false',
        () {
      expect(bisearch(0x0001, BMP_COMBINING), isFalse);
    });
  });

  group('buildTable', () {
    test('Given buildTable called, Then returns Uint8List of 65536', () {
      final table = buildTable();
      expect(table.length, equals(65536));
    });

    test('Given buildTable, Then index 0 is 0', () {
      final table = buildTable();
      expect(table[0], equals(0));
    });

    test('Given buildTable, Then control characters are 0', () {
      final table = buildTable();
      expect(table[1], equals(0));
      expect(table[31], equals(0));
    });

    test('Given buildTable, Then printable ASCII are 1', () {
      final table = buildTable();
      expect(table[32], equals(1));
      expect(table[126], equals(1));
    });

    test('Given buildTable, Then wide characters are 2', () {
      final table = buildTable();
      // First wide character range starts at 0x1100
      expect(table[0x1100], equals(2));
    });
  });
}
