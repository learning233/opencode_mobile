import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/utils/char_code.dart';

void main() {
  group('StringCharCode', () {
    test(
        'Given single character string, When charCode accessed, Then returns correct code',
        () {
      expect('A'.charCode, equals(65));
      expect('Z'.charCode, equals(90));
      expect('a'.charCode, equals(97));
      expect('z'.charCode, equals(122));
      expect('0'.charCode, equals(48));
      expect('9'.charCode, equals(57));
    });

    test(
        'Given special characters, When charCode accessed, Then returns correct code',
        () {
      expect(' '.charCode, equals(32));
      expect('\n'.charCode, equals(10));
      expect('\t'.charCode, equals(9));
    });

    test(
        'Given emoji (multi-byte), When charCode accessed, Then returns first code unit',
        () {
      // Emoji are typically multi-codeunit, charCode returns first code unit
      final emoji = '😀';
      expect(emoji.charCode, isPositive);
    });
  });
}
