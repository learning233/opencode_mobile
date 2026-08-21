import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/utils/ascii.dart';

void main() {
  group('Ascii', () {
    group('isNonPrintable', () {
      test(
          'Given character code 0, When isNonPrintable called, Then returns true',
          () {
        expect(Ascii.isNonPrintable(0), isTrue);
      });

      test(
          'Given character code 31, When isNonPrintable called, Then returns true',
          () {
        expect(Ascii.isNonPrintable(31), isTrue);
      });

      test(
          'Given character code 32 (space), When isNonPrintable called, Then returns false',
          () {
        expect(Ascii.isNonPrintable(32), isFalse);
      });

      test(
          'Given character code 126 (~), When isNonPrintable called, Then returns false',
          () {
        expect(Ascii.isNonPrintable(126), isFalse);
      });

      test(
          'Given character code 127 (DEL), When isNonPrintable called, Then returns true',
          () {
        expect(Ascii.isNonPrintable(127), isTrue);
      });
    });

    group('non-printable constants', () {
      test('NULL equals 0', () {
        expect(Ascii.NULL, equals(0));
      });

      test('BEL equals 7', () {
        expect(Ascii.BEL, equals(7));
      });

      test('BS equals 8', () {
        expect(Ascii.BS, equals(8));
      });

      test('HT equals 9', () {
        expect(Ascii.HT, equals(9));
      });

      test('LF equals 10', () {
        expect(Ascii.LF, equals(10));
      });

      test('CR equals 13', () {
        expect(Ascii.CR, equals(13));
      });

      test('ESC equals 27', () {
        expect(Ascii.ESC, equals(27));
      });

      test('DEL equals 127', () {
        expect(Ascii.DEL, equals(127));
      });
    });

    group('printable constants', () {
      test('space equals 32', () {
        expect(Ascii.space, equals(32));
      });

      test('A equals 65', () {
        expect(Ascii.A, equals(65));
      });

      test('Z equals 90', () {
        expect(Ascii.Z, equals(90));
      });

      test('a equals 97', () {
        expect(Ascii.a, equals(97));
      });

      test('z equals 122', () {
        expect(Ascii.z, equals(122));
      });

      test('num0 equals 48', () {
        expect(Ascii.num0, equals(48));
      });

      test('num9 equals 57', () {
        expect(Ascii.num9, equals(57));
      });
    });
  });
}
