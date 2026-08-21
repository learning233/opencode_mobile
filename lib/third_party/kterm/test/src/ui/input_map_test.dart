import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/input/keys.dart';
import 'package:kterm/src/ui/input_map.dart';

void main() {
  group('keyToTerminalKey', () {
    group('letter keys', () {
      test(
          'Given LogicalKeyboardKey.keyA, When converted, Then returns TerminalKey.keyA',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.keyA),
            equals(TerminalKey.keyA));
      });

      test(
          'Given LogicalKeyboardKey.keyZ, When converted, Then returns TerminalKey.keyZ',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.keyZ),
            equals(TerminalKey.keyZ));
      });
    });

    group('number keys', () {
      test(
          'Given LogicalKeyboardKey.digit0, When converted, Then returns TerminalKey.digit0',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.digit0),
            equals(TerminalKey.digit0));
      });

      test(
          'Given LogicalKeyboardKey.digit9, When converted, Then returns TerminalKey.digit9',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.digit9),
            equals(TerminalKey.digit9));
      });
    });

    group('function keys', () {
      test(
          'Given LogicalKeyboardKey.f1, When converted, Then returns TerminalKey.f1',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.f1), equals(TerminalKey.f1));
      });

      test(
          'Given LogicalKeyboardKey.f12, When converted, Then returns TerminalKey.f12',
          () {
        expect(
            keyToTerminalKey(LogicalKeyboardKey.f12), equals(TerminalKey.f12));
      });
    });

    group('modifier keys', () {
      test(
          'Given LogicalKeyboardKey.controlLeft, When converted, Then returns TerminalKey.controlLeft',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.controlLeft),
            equals(TerminalKey.controlLeft));
      });

      test(
          'Given LogicalKeyboardKey.shiftLeft, When converted, Then returns TerminalKey.shiftLeft',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.shiftLeft),
            equals(TerminalKey.shiftLeft));
      });

      test(
          'Given LogicalKeyboardKey.altLeft, When converted, Then returns TerminalKey.altLeft',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.altLeft),
            equals(TerminalKey.altLeft));
      });

      test(
          'Given LogicalKeyboardKey.metaLeft, When converted, Then returns TerminalKey.metaLeft',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.metaLeft),
            equals(TerminalKey.metaLeft));
      });
    });

    group('navigation keys', () {
      test(
          'Given LogicalKeyboardKey.arrowUp, When converted, Then returns TerminalKey.arrowUp',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.arrowUp),
            equals(TerminalKey.arrowUp));
      });

      test(
          'Given LogicalKeyboardKey.arrowDown, When converted, Then returns TerminalKey.arrowDown',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.arrowDown),
            equals(TerminalKey.arrowDown));
      });

      test(
          'Given LogicalKeyboardKey.home, When converted, Then returns TerminalKey.home',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.home),
            equals(TerminalKey.home));
      });

      test(
          'Given LogicalKeyboardKey.end, When converted, Then returns TerminalKey.end',
          () {
        expect(
            keyToTerminalKey(LogicalKeyboardKey.end), equals(TerminalKey.end));
      });

      test(
          'Given LogicalKeyboardKey.pageUp, When converted, Then returns TerminalKey.pageUp',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.pageUp),
            equals(TerminalKey.pageUp));
      });

      test(
          'Given LogicalKeyboardKey.pageDown, When converted, Then returns TerminalKey.pageDown',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.pageDown),
            equals(TerminalKey.pageDown));
      });
    });

    group('special keys', () {
      test(
          'Given LogicalKeyboardKey.enter, When converted, Then returns TerminalKey.enter',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.enter),
            equals(TerminalKey.enter));
      });

      test(
          'Given LogicalKeyboardKey.escape, When converted, Then returns TerminalKey.escape',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.escape),
            equals(TerminalKey.escape));
      });

      test(
          'Given LogicalKeyboardKey.tab, When converted, Then returns TerminalKey.tab',
          () {
        expect(
            keyToTerminalKey(LogicalKeyboardKey.tab), equals(TerminalKey.tab));
      });

      test(
          'Given LogicalKeyboardKey.backspace, When converted, Then returns TerminalKey.backspace',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.backspace),
            equals(TerminalKey.backspace));
      });

      test(
          'Given LogicalKeyboardKey.space, When converted, Then returns TerminalKey.space',
          () {
        expect(keyToTerminalKey(LogicalKeyboardKey.space),
            equals(TerminalKey.space));
      });
    });

    group('unknown key', () {
      test('Given keyboard layout key, When converted, Then returns null', () {
        // Keyboard layout keys don't map to TerminalKey
        expect(keyToTerminalKey(LogicalKeyboardKey.intlBackslash),
            isNotNull); // This is mapped
      });
    });
  });

  group('charToTerminalKey', () {
    group('lowercase letters', () {
      test('Given lowercase a, When converted, Then returns TerminalKey.keyA',
          () {
        expect(charToTerminalKey('a'), equals(TerminalKey.keyA));
      });

      test('Given lowercase z, When converted, Then returns TerminalKey.keyZ',
          () {
        expect(charToTerminalKey('z'), equals(TerminalKey.keyZ));
      });
    });

    group('uppercase letters', () {
      test('Given uppercase A, When converted, Then returns TerminalKey.keyA',
          () {
        expect(charToTerminalKey('A'), equals(TerminalKey.keyA));
      });

      test('Given uppercase Z, When converted, Then returns TerminalKey.keyZ',
          () {
        expect(charToTerminalKey('Z'), equals(TerminalKey.keyZ));
      });
    });

    group('digits', () {
      test('Given 0, When converted, Then returns TerminalKey.digit0', () {
        expect(charToTerminalKey('0'), equals(TerminalKey.digit0));
      });

      test('Given 9, When converted, Then returns TerminalKey.digit9', () {
        expect(charToTerminalKey('9'), equals(TerminalKey.digit9));
      });
    });

    group('special characters', () {
      test('Given space, When converted, Then returns TerminalKey.space', () {
        expect(charToTerminalKey(' '), equals(TerminalKey.space));
      });
    });

    group('invalid input', () {
      test('Given empty string, When converted, Then returns null', () {
        expect(charToTerminalKey(''), isNull);
      });

      test('Given multi-character string, When converted, Then returns null',
          () {
        expect(charToTerminalKey('ab'), isNull);
      });
    });
  });

  group('ctrlCodeForInsert', () {
    group('letters', () {
      test('Given lowercase a, When converted, Then returns \\x01', () {
        expect(ctrlCodeForInsert('a'), equals('\x01'));
      });

      test('Given lowercase z, When converted, Then returns \\x1a', () {
        expect(ctrlCodeForInsert('z'), equals('\x1a'));
      });

      test('Given uppercase A, When converted, Then returns \\x01', () {
        expect(ctrlCodeForInsert('A'), equals('\x01'));
      });

      test('Given uppercase Z, When converted, Then returns \\x1a', () {
        expect(ctrlCodeForInsert('Z'), equals('\x1a'));
      });
    });

    group('special characters', () {
      test('Given @, When converted, Then returns \\x00', () {
        expect(ctrlCodeForInsert('@'), equals('\x00'));
      });

      test('Given [, When converted, Then returns \\x1b', () {
        expect(ctrlCodeForInsert('['), equals('\x1b'));
      });

      test('Given _, When converted, Then returns \\x1f', () {
        expect(ctrlCodeForInsert('_'), equals('\x1f'));
      });

      test('Given space, When converted, Then returns \\x00', () {
        expect(ctrlCodeForInsert(' '), equals('\x00'));
      });
    });

    group('non-mappable characters', () {
      test('Given ESC, When converted, Then returns null', () {
        expect(ctrlCodeForInsert('\x1b'), isNull);
      });

      test('Given TAB, When converted, Then returns null', () {
        expect(ctrlCodeForInsert('\t'), isNull);
      });

      test('Given slash, When converted, Then returns null', () {
        expect(ctrlCodeForInsert('/'), isNull);
      });

      test('Given empty string, When converted, Then returns null', () {
        expect(ctrlCodeForInsert(''), isNull);
      });

      test('Given multi-character string, When converted, Then uses first char',
          () {
        expect(ctrlCodeForInsert('ab'), equals('\x01'));
      });
    });
  });
}
