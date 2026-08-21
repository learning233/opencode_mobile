import 'package:test/test.dart';
import 'package:kterm/src/core/input/keytab/keytab_record.dart';
import 'package:kterm/src/core/input/keys.dart';

void main() {
  group('KeytabAction', () {
    group('Type handling', () {
      test(
          'Given input type, When unescapedValue called, Then returns unescaped value',
          () {
        // Using \E for escape (ESC), and hex notation for Ctrl+A = \x01
        final action = KeytabAction(KeytabActionType.input, r'\E\x01');
        final result = action.unescapedValue();
        expect(result.length, greaterThan(0));
        // Should contain ESC (0x1b) and Ctrl+A (0x01)
        expect(result.runes.contains(0x1b), isTrue);
        expect(result.runes.contains(0x01), isTrue);
      });

      test(
          'Given shortcut type, When unescapedValue called, Then returns raw value',
          () {
        final action = KeytabAction(KeytabActionType.shortcut, 'Ctrl+Alt+F');
        expect(action.unescapedValue(), equals('Ctrl+Alt+F'));
      });

      test(
          'Given input type with no escapes, When unescapedValue, Then returns raw',
          () {
        final action = KeytabAction(KeytabActionType.input, 'hello');
        expect(action.unescapedValue(), equals('hello'));
      });
    });

    group('toString', () {
      test('Given input type, When toString, Then returns quoted value', () {
        final action = KeytabAction(KeytabActionType.input, 'test');
        expect(action.toString(), equals('"test"'));
      });

      test('Given shortcut type, When toString, Then returns raw value', () {
        final action = KeytabAction(KeytabActionType.shortcut, 'Ctrl+C');
        expect(action.toString(), equals('Ctrl+C'));
      });

      test('Given input with special chars, When toString, Then shows quoted',
          () {
        final action = KeytabAction(KeytabActionType.input, r'\e');
        expect(action.toString(), contains('\\e'));
      });
    });
  });

  group('KeytabRecord', () {
    test('Given complete record, When created, Then all fields are set', () {
      final record = KeytabRecord(
        qtKeyName: 'Key_A',
        key: TerminalKey.keyA,
        action: KeytabAction(KeytabActionType.input, 'a'),
        alt: true,
        ctrl: false,
        shift: null,
        anyModifier: false,
        ansi: true,
        appScreen: null,
        keyPad: false,
        appCursorKeys: null,
        appKeyPad: null,
        newLine: false,
        macos: null,
      );

      expect(record.qtKeyName, 'Key_A');
      expect(record.key, TerminalKey.keyA);
      expect(record.alt, isTrue);
      expect(record.ctrl, isFalse);
      expect(record.shift, isNull);
    });

    test(
        'Given record with null modifiers, When toString, Then omits null modifiers',
        () {
      final record = KeytabRecord(
        qtKeyName: 'Key_Return',
        key: TerminalKey.enter,
        action: KeytabAction(KeytabActionType.input, '\r'),
        alt: null,
        ctrl: null,
        shift: null,
        anyModifier: null,
        ansi: null,
        appScreen: null,
        keyPad: null,
        appCursorKeys: null,
        appKeyPad: null,
        newLine: null,
        macos: null,
      );

      final output = record.toString();
      expect(output, contains('Key_Return'));
      // Action with input type shows quoted value, carriage return is actual char
      expect(output, contains('"\r"'));
      // Should not have any + or - modes
      expect(output, isNot(contains('+')));
      expect(output, isNot(contains('-')));
    });

    test(
        'Given record with mixed modifiers, When toString, Then formats correctly',
        () {
      final record = KeytabRecord(
        qtKeyName: 'Key_C',
        key: TerminalKey.keyC,
        action: KeytabAction(KeytabActionType.shortcut, 'Copy'),
        alt: true,
        ctrl: true,
        shift: false,
        anyModifier: null,
        ansi: null,
        appScreen: null,
        keyPad: null,
        appCursorKeys: null,
        appKeyPad: null,
        newLine: null,
        macos: null,
      );

      final output = record.toString();
      expect(output, contains('Key_C'));
      expect(output, contains('+Alt'));
      expect(output, contains('+Control'));
      expect(output, contains('-Shift'));
      expect(output, contains('Copy'));
    });

    test(
        'Given record with all true modifiers, When toString, Then shows all +modes',
        () {
      final record = KeytabRecord(
        qtKeyName: 'Key_X',
        key: TerminalKey.keyX,
        action: KeytabAction(KeytabActionType.shortcut, 'Cut'),
        alt: true,
        ctrl: true,
        shift: true,
        anyModifier: true,
        ansi: true,
        appScreen: true,
        keyPad: true,
        appCursorKeys: true,
        appKeyPad: true,
        newLine: true,
        macos: true,
      );

      final output = record.toString();
      expect(output, contains('+Alt'));
      expect(output, contains('+Control'));
      expect(output, contains('+Shift'));
      expect(output, contains('+AnyMod'));
      expect(output, contains('+Ansi'));
      expect(output, contains('+AppScreen'));
      expect(output, contains('+KeyPad'));
      expect(output, contains('+AppCuKeys'));
      expect(output, contains('+AppKeyPad'));
      expect(output, contains('+NewLine'));
      expect(output, contains('+Mac'));
    });

    test(
        'Given record with all false modifiers, When toString, Then shows all -modes',
        () {
      final record = KeytabRecord(
        qtKeyName: 'Key_V',
        key: TerminalKey.keyV,
        action: KeytabAction(KeytabActionType.shortcut, 'Paste'),
        alt: false,
        ctrl: false,
        shift: false,
        anyModifier: false,
        ansi: false,
        appScreen: false,
        keyPad: false,
        appCursorKeys: false,
        appKeyPad: false,
        newLine: false,
        macos: false,
      );

      final output = record.toString();
      expect(output, contains('-Alt'));
      expect(output, contains('-Control'));
      expect(output, contains('-Shift'));
      expect(output, contains('-AnyMod'));
      expect(output, contains('-Ansi'));
    });

    test(
        'Given record with TerminalKey, When toString, Then qtKeyName appears first',
        () {
      final record = KeytabRecord(
        qtKeyName: 'Key_1',
        key: TerminalKey.digit1,
        action: KeytabAction(KeytabActionType.input, '1'),
        alt: null,
        ctrl: null,
        shift: null,
        anyModifier: null,
        ansi: null,
        appScreen: null,
        keyPad: null,
        appCursorKeys: null,
        appKeyPad: null,
        newLine: null,
        macos: null,
      );

      final output = record.toString();
      expect(output.startsWith('Key_1'), isTrue);
    });

    test(
        'Given record with action, When toString, Then action appears after modifiers',
        () {
      final record = KeytabRecord(
        qtKeyName: 'Key_Up',
        key: TerminalKey.arrowUp,
        action: KeytabAction(KeytabActionType.shortcut, 'ScrollUp'),
        alt: null,
        ctrl: null,
        shift: null,
        anyModifier: null,
        ansi: null,
        appScreen: null,
        keyPad: null,
        appCursorKeys: null,
        appKeyPad: null,
        newLine: null,
        macos: null,
      );

      final output = record.toString();
      expect(output, contains(' : ScrollUp'));
    });

    test(
        'Given record with newLine modifier, When toString, Then includes NewLine',
        () {
      final record = KeytabRecord(
        qtKeyName: 'Key_Return',
        key: TerminalKey.enter,
        action: KeytabAction(KeytabActionType.input, '\r'),
        alt: null,
        ctrl: null,
        shift: null,
        anyModifier: null,
        ansi: null,
        appScreen: null,
        keyPad: null,
        appCursorKeys: null,
        appKeyPad: null,
        newLine: true,
        macos: null,
      );

      final output = record.toString();
      expect(output, contains('+NewLine'));
      // action value should be quoted (input type)
      expect(output, contains('"\r"'));
    });
  });

  group('KeytabRecord - field variability', () {
    test('Given record with all fields nullable, When toString, Then no crash',
        () {
      final record = KeytabRecord(
        qtKeyName: 'Key_F1',
        key: TerminalKey.f1,
        action: KeytabAction(KeytabActionType.input, '\x1bOP'),
        alt: null,
        ctrl: null,
        shift: null,
        anyModifier: null,
        ansi: null,
        appScreen: null,
        keyPad: null,
        appCursorKeys: null,
        appKeyPad: null,
        newLine: null,
        macos: null,
      );

      // Should not throw
      expect(() => record.toString(), returnsNormally);
      expect(record.qtKeyName, 'Key_F1');
    });

    test('Given record with various key types, When created, Then all accepted',
        () {
      final keys = [
        TerminalKey.keyA,
        TerminalKey.enter,
        TerminalKey.arrowUp,
        TerminalKey.f1,
        TerminalKey.escape,
      ];

      for (final key in keys) {
        final record = KeytabRecord(
          qtKeyName: 'Key_Test',
          key: key,
          action: KeytabAction(KeytabActionType.input, 'test'),
          alt: null,
          ctrl: null,
          shift: null,
          anyModifier: null,
          ansi: null,
          appScreen: null,
          keyPad: null,
          appCursorKeys: null,
          appKeyPad: null,
          newLine: null,
          macos: null,
        );
        expect(record.key, equals(key));
      }
    });
  });

  group('KeytabActionType enum', () {
    test('Given enum values, When accessed, Then has two values', () {
      expect(KeytabActionType.values.length, equals(2));
      expect(KeytabActionType.values, contains(KeytabActionType.input));
      expect(KeytabActionType.values, contains(KeytabActionType.shortcut));
    });

    test('Given input type, When indexed, Then name is "input"', () {
      expect(KeytabActionType.input.name, equals('input'));
    });

    test('Given shortcut type, When indexed, Then name is "shortcut"', () {
      expect(KeytabActionType.shortcut.name, equals('shortcut'));
    });
  });
}
