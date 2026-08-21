import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitty_protocol/kitty_protocol.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('Kitty Encoder for regular keys', () {
    test('Tab key encodes to a valid sequence (not null or empty)', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      final result = terminal.kittyEncoder.encode(
        SimpleKeyEvent(
          logicalKey: LogicalKeyboardKey.tab,
          modifiers: {},
          isKeyUp: false,
          isKeyRepeat: false,
        ),
      );
      print('Tab result: "$result"');
      // Tab should encode to a valid Kitty sequence (keycode 9)
      expect(result, isNotNull);
      expect(result, isNotEmpty);
      expect(result, contains('9')); // Tab keycode is 9 in Kitty protocol
    });

    test('Digit1 key encodes to empty string (needs fallback)', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      final result = terminal.kittyEncoder.encode(
        SimpleKeyEvent(
          logicalKey: LogicalKeyboardKey.digit1,
          modifiers: {},
          isKeyUp: false,
          isKeyRepeat: false,
        ),
      );
      print('Digit1 result: "$result"');
      // Digit1 returns empty string - needs fallback to TextInput
      expect(result, equals(''));
    });

    test('keyA encodes to empty string (needs fallback)', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      final result = terminal.kittyEncoder.encode(
        SimpleKeyEvent(
          logicalKey: LogicalKeyboardKey.keyA,
          modifiers: {},
          isKeyUp: false,
          isKeyRepeat: false,
        ),
      );
      print('keyA result: "$result"');
      // keyA returns empty string - needs fallback to TextInput
      expect(result, equals(''));
    });

    test('Enter encodes to a valid sequence', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      final result = terminal.kittyEncoder.encode(
        SimpleKeyEvent(
          logicalKey: LogicalKeyboardKey.enter,
          modifiers: {},
          isKeyUp: false,
          isKeyRepeat: false,
        ),
      );
      print('Enter result: "$result"');
      expect(result, isNotNull);
      expect(result, isNotEmpty);
    });
  });
}
