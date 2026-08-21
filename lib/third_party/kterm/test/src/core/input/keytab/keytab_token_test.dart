import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/input/keytab/keytab_token.dart';

void main() {
  group('KeytabToken', () {
    group('constructor', () {
      test(
          'Given KeytabTokenType and value, When created, Then stores type and value',
          () {
        final token = KeytabToken(KeytabTokenType.keyDefine, 'test');
        expect(token.type, equals(KeytabTokenType.keyDefine));
        expect(token.value, equals('test'));
      });
    });

    group('toString', () {
      test(
          'Given KeytabToken, When toString called, Then returns formatted string',
          () {
        final token = KeytabToken(KeytabTokenType.keyName, 'Enter');
        expect(token.toString(), equals('KeytabTokenType.keyName<Enter>'));
      });
    });
  });

  group('LineReader', () {
    group('constructor', () {
      test('Given string line, When created, Then stores line', () {
        final reader = LineReader('test line');
        expect(reader.line, equals('test line'));
      });
    });

    group('done', () {
      test('Given empty line, When created, Then done is true', () {
        final reader = LineReader('');
        expect(reader.done, isTrue);
      });

      test('Given non-empty line at start, When created, Then done is false',
          () {
        final reader = LineReader('test');
        expect(reader.done, isFalse);
      });

      test('Given line after reading all, When done called, Then returns true',
          () {
        final reader = LineReader('ab');
        reader.take(2);
        expect(reader.done, isTrue);
      });
    });

    group('peek', () {
      test(
          'Given line with content, When peek called, Then returns character at current position',
          () {
        final reader = LineReader('abc');
        expect(reader.peek(), equals('a'));
      });

      test(
          'Given line after peek, When peek called multiple times, Then returns same character',
          () {
        final reader = LineReader('abc');
        reader.peek();
        reader.peek();
        expect(reader.peek(), equals('a'));
      });

      test('Given line at end, When peek called, Then returns null', () {
        final reader = LineReader('');
        expect(reader.peek(), isNull);
      });

      test('Given line, When peek with count called, Then returns substring',
          () {
        final reader = LineReader('abcd');
        expect(reader.peek(3), equals('abc'));
      });
    });

    group('take', () {
      test(
          'Given line with content, When take called, Then returns character and advances position',
          () {
        final reader = LineReader('abc');
        expect(reader.take(), equals('a'));
        expect(reader.peek(), equals('b'));
      });

      test(
          'Given line, When take with count called, Then returns substring and advances',
          () {
        final reader = LineReader('abcd');
        expect(reader.take(3), equals('abc'));
        expect(reader.peek(), equals('d'));
      });

      test('Given empty line, When take called, Then returns null', () {
        final reader = LineReader('');
        expect(reader.take(), isNull);
      });
    });

    group('skipWhitespace', () {
      test(
          'Given line starting with spaces, When skipWhitespace called, Then advances past spaces',
          () {
        final reader = LineReader('  abc');
        reader.skipWhitespace();
        expect(reader.peek(), equals('a'));
      });

      test(
          'Given line starting with tabs, When skipWhitespace called, Then advances past tabs',
          () {
        final reader = LineReader('\t\tabc');
        reader.skipWhitespace();
        expect(reader.peek(), equals('a'));
      });

      test(
          'Given line with no whitespace, When skipWhitespace called, Then position unchanged',
          () {
        final reader = LineReader('abc');
        reader.skipWhitespace();
        expect(reader.peek(), equals('a'));
      });
    });

    group('readString', () {
      test(
          'Given line with word characters, When readString called, Then returns word',
          () {
        final reader = LineReader('hello world');
        expect(reader.readString(), equals('hello'));
      });

      test(
          'Given line with underscore, When readString called, Then includes underscore',
          () {
        final reader = LineReader('hello_world');
        expect(reader.readString(), equals('hello_world'));
      });

      test(
          'Given line at end, When readString called, Then returns empty string',
          () {
        final reader = LineReader('abc');
        reader.take(3);
        expect(reader.readString(), equals(''));
      });
    });

    group('readUntil', () {
      test(
          'Given line with pattern, When readUntil called, Then returns text before pattern',
          () {
        final reader = LineReader('hello world');
        expect(reader.readUntil(' '), equals('hello'));
      });

      test(
          'Given line with inclusive, When readUntil called with inclusive true, Then includes pattern',
          () {
        final reader = LineReader('hello world');
        expect(reader.readUntil(' ', inclusive: true), equals('hello '));
      });

      test(
          'Given line without pattern, When readUntil called, Then returns rest of line',
          () {
        final reader = LineReader('hello');
        expect(reader.readUntil('x'), equals('hello'));
      });
    });
  });

  group('TokenizeError', () {
    test('Given TokenizeError, When instantiated, Then creates empty error',
        () {
      final error = TokenizeError();
      expect(error, isA<TokenizeError>());
    });
  });

  group('tokenize', () {
    group('keyboard definition', () {
      test(
          'Given valid keyboard line with quoted input, When tokenized, Then yields keyboard token',
          () {
        final tokens = tokenize('keyboard "test"').toList();
        expect(tokens.length, equals(2));
        expect(tokens[0].type, equals(KeytabTokenType.keyboard));
        expect(tokens[0].value, equals('keyboard'));
        expect(tokens[1].type, equals(KeytabTokenType.input));
        expect(tokens[1].value, equals('test'));
      });
    });

    group('key definition', () {
      test('Given simple key line, When tokenized, Then yields key tokens', () {
        final tokens = tokenize('key a: "x"').toList();
        expect(tokens[0].type, equals(KeytabTokenType.keyDefine));
        expect(tokens[1].type, equals(KeytabTokenType.keyName));
        expect(tokens[1].value, equals('a'));
        expect(tokens[2].type, equals(KeytabTokenType.colon));
        expect(tokens[3].type, equals(KeytabTokenType.input));
        expect(tokens[3].value, equals('x'));
      });

      test('Given key with modifiers, When tokenized, Then yields mode tokens',
          () {
        final tokens = tokenize('key f1+shift: "\\eOP"').toList();
        expect(tokens[2].type, equals(KeytabTokenType.modeStatus));
        expect(tokens[2].value, equals('+'));
        expect(tokens[3].type, equals(KeytabTokenType.mode));
        expect(tokens[3].value, equals('shift'));
      });

      test(
          'Given key with action (no quotes), When tokenized, Then yields shortcut token',
          () {
        final tokens = tokenize('key Home: scrollup').toList();
        expect(tokens[3].type, equals(KeytabTokenType.shortcut));
        expect(tokens[3].value, equals('scrollup'));
      });
    });

    group('comments', () {
      test('Given line with comment, When tokenized, Then ignores comment', () {
        final tokens = tokenize('key a: "x"  # this is comment').toList();
        expect(tokens.length, equals(4));
      });
    });

    group('empty lines', () {
      test('Given empty line, When tokenized, Then yields no tokens', () {
        final tokens = tokenize('').toList();
        expect(tokens, isEmpty);
      });

      test('Given whitespace only, When tokenized, Then yields no tokens', () {
        final tokens = tokenize('   ').toList();
        expect(tokens, isEmpty);
      });
    });
  });
}
