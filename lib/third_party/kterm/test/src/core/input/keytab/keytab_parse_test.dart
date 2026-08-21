import 'package:test/test.dart';
import 'package:kterm/src/core/input/keytab/keytab_parse.dart';
import 'package:kterm/src/core/input/keytab/keytab_token.dart';
import 'package:kterm/src/core/input/keytab/keytab.dart';
import 'package:kterm/src/core/input/keytab/keytab_record.dart';
import 'package:kterm/src/core/input/keys.dart';

void main() {
  group('ParseError', () {
    test('is a simple class', () {
      final error = ParseError();
      expect(error, isA<ParseError>());
    });
  });

  group('TokensReader', () {
    group('constructor', () {
      test('Given empty token list, When created, Then done returns true', () {
        final reader = TokensReader([]);
        expect(reader.done, isTrue);
      });

      test('Given tokens, When created, Then done returns false', () {
        final tokens = [KeytabToken(KeytabTokenType.input, 'test')];
        final reader = TokensReader(tokens);
        expect(reader.done, isFalse);
      });
    });

    group('peek', () {
      test(
          'Given tokens, When peek called, Then returns first token without advancing',
          () {
        final tokens = [
          KeytabToken(KeytabTokenType.input, 'first'),
          KeytabToken(KeytabTokenType.input, 'second'),
        ];
        final reader = TokensReader(tokens);

        final peeked = reader.peek();
        expect(peeked!.value, equals('first'));

        // Should still be able to peek the same token
        expect(reader.peek()!.value, equals('first'));
      });
    });

    group('take', () {
      test(
          'Given tokens, When take called, Then returns token and advances position',
          () {
        final tokens = [
          KeytabToken(KeytabTokenType.input, 'first'),
          KeytabToken(KeytabTokenType.input, 'second'),
        ];
        final reader = TokensReader(tokens);

        final taken = reader.take();
        expect(taken!.value, equals('first'));

        // Next take should return second
        final taken2 = reader.take();
        expect(taken2!.value, equals('second'));
      });

      test('Given no more tokens, When take called, Then returns null', () {
        final reader = TokensReader([]);
        expect(reader.take(), isNull);
      });
    });
  });

  group('KeytabParser', () {
    group('addTokens', () {
      test(
          'Given valid keytab tokens, When parsed, Then returns Keytab with records',
          () {
        final parser = KeytabParser();
        parser.addTokens([
          KeytabToken(KeytabTokenType.keyboard, ''),
          KeytabToken(KeytabTokenType.input, 'test-keyboard'),
          KeytabToken(KeytabTokenType.keyDefine, ''),
          KeytabToken(KeytabTokenType.keyName, 'Home'),
          KeytabToken(KeytabTokenType.modeStatus, '+'),
          KeytabToken(KeytabTokenType.mode, 'KeyPad'),
          KeytabToken(KeytabTokenType.colon, ':'),
          KeytabToken(KeytabTokenType.input, 'test-action'),
        ]);

        final result = parser.result;
        expect(result.name, equals('test-keyboard'));
        expect(result.records.length, equals(1));
        expect(result.records[0].qtKeyName, equals('Home'));
        expect(result.records[0].keyPad, isTrue);
      });

      test('Given multiple modifiers, When parsed, Then captures all modifiers',
          () {
        final parser = KeytabParser();
        parser.addTokens([
          KeytabToken(KeytabTokenType.keyboard, ''),
          KeytabToken(KeytabTokenType.input, 'test-keyboard'),
          KeytabToken(KeytabTokenType.keyDefine, ''),
          KeytabToken(KeytabTokenType.keyName, 'A'),
          KeytabToken(KeytabTokenType.modeStatus, '+'),
          KeytabToken(KeytabTokenType.mode, 'Control'),
          KeytabToken(KeytabTokenType.modeStatus, '+'),
          KeytabToken(KeytabTokenType.mode, 'Shift'),
          KeytabToken(KeytabTokenType.colon, ':'),
          KeytabToken(KeytabTokenType.input, 'test-action'),
        ]);

        final result = parser.result;
        expect(result.records[0].ctrl, isTrue);
        expect(result.records[0].shift, isTrue);
      });

      test('Given invalid token sequence, When parsed, Then throws ParseError',
          () {
        final parser = KeytabParser();
        expect(
          () => parser.addTokens([
            KeytabToken(KeytabTokenType.input, 'invalid'),
          ]),
          throwsA(isA<ParseError>()),
        );
      });

      test('Given unknown key name, When parsed, Then throws ParseError', () {
        final parser = KeytabParser();
        expect(
          () => parser.addTokens([
            KeytabToken(KeytabTokenType.keyboard, ''),
            KeytabToken(KeytabTokenType.input, 'test'),
            KeytabToken(KeytabTokenType.keyDefine, ''),
            KeytabToken(KeytabTokenType.keyName, 'UnknownKey'),
            KeytabToken(KeytabTokenType.colon, ':'),
            KeytabToken(KeytabTokenType.input, 'action'),
          ]),
          throwsA(isA<ParseError>()),
        );
      });

      test('Given shortcut action, When parsed, Then parses as shortcut type',
          () {
        final parser = KeytabParser();
        parser.addTokens([
          KeytabToken(KeytabTokenType.keyboard, ''),
          KeytabToken(KeytabTokenType.input, 'test-keyboard'),
          KeytabToken(KeytabTokenType.keyDefine, ''),
          KeytabToken(KeytabTokenType.keyName, 'Home'),
          KeytabToken(KeytabTokenType.colon, ':'),
          KeytabToken(KeytabTokenType.shortcut, 'copy'),
        ]);

        final result = parser.result;
        expect(
            result.records[0].action.type, equals(KeytabActionType.shortcut));
        expect(result.records[0].action.unescapedValue(), equals('copy'));
      });
    });

    group('result', () {
      test(
          'Given empty tokens, When result accessed, Then returns Keytab with null name',
          () {
        final parser = KeytabParser();
        parser.addTokens([
          KeytabToken(KeytabTokenType.keyboard, ''),
          KeytabToken(KeytabTokenType.input, 'test-keyboard'),
        ]);

        final result = parser.result;
        expect(result.name, equals('test-keyboard'));
        expect(result.records, isEmpty);
      });
    });
  });
}
