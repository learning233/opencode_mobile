import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/input/keytab/keytab_escape.dart';

void main() {
  group('keytabUnescape', () {
    group('escape sequences', () {
      test(
          'Given escaped backslash, When unescaped, Then returns single backslash',
          () {
        expect(keytabUnescape(r'\\'), equals('\\'));
      });

      test('Given escaped quote, When unescaped, Then returns single quote',
          () {
        expect(keytabUnescape(r'\"'), equals('"'));
      });

      test('Given escaped tab, When unescaped, Then returns tab character', () {
        expect(keytabUnescape(r'\t'), equals('\t'));
      });

      test(
          'Given escaped carriage return, When unescaped, Then returns carriage return',
          () {
        expect(keytabUnescape(r'\r'), equals('\r'));
      });

      test('Given escaped newline, When unescaped, Then returns newline', () {
        expect(keytabUnescape(r'\n'), equals('\n'));
      });

      test('Given escaped backspace, When unescaped, Then returns backspace',
          () {
        expect(keytabUnescape(r'\b'), equals('\b'));
      });

      test(
          'Given escaped escape character, When unescaped, Then returns escape',
          () {
        expect(keytabUnescape(r'\E'), equals('\x1b'));
      });
    });

    group('hex sequences', () {
      test(
          'Given valid hex sequence, When unescaped, Then returns corresponding character',
          () {
        expect(keytabUnescape(r'\x41'), equals('A'));
      });

      test('Given lowercase hex, When unescaped, Then returns character', () {
        expect(keytabUnescape(r'\x61'), equals('a'));
      });

      test(
          'Given multiple hex sequences, When unescaped, Then returns all characters',
          () {
        // Each hex sequence is converted to its character code
        // H=0x48, e=0x65, l=0x6c, l=0x6c, o=0x6f
        expect(keytabUnescape(r'\x48\x65\x6c\x6c\x6f'), equals('Hello'));
      });

      test('Given mixed case hex, When unescaped, Then returns character', () {
        // Mixed case hex works: J = 0x4A
        expect(keytabUnescape(r'\x4a'), equals('J'));
      });
    });

    group('complex sequences', () {
      test('Given combined escape and text, When unescaped, Then processes all',
          () {
        expect(keytabUnescape(r'\E[31m'), equals('\x1b[31m'));
      });

      test(
          'Given arrow key sequence, When unescaped, Then returns correct sequence',
          () {
        expect(keytabUnescape(r'\E[A'), equals('\x1b[A'));
      });

      test(
          'Given function key sequence, When unescaped, Then returns correct sequence',
          () {
        expect(keytabUnescape(r'\EOP'), equals('\x1bOP'));
      });
    });

    group('no escape sequences', () {
      test('Given plain text, When unescaped, Then returns unchanged', () {
        expect(keytabUnescape('hello world'), equals('hello world'));
      });

      test('Given empty string, When unescaped, Then returns empty', () {
        expect(keytabUnescape(''), equals(''));
      });
    });
  });
}
