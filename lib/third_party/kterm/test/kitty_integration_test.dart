import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitty_protocol/kitty_protocol.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('Kitty Keyboard Protocol', () {
    test('enables Kitty mode on CSI > 1u', () {
      final terminal = Terminal();

      // Send CSI > 1u to enable Kitty mode
      terminal.write('\x1b[>1u');

      expect(terminal.kittyMode, isTrue);
    });

    test('disables Kitty mode on CSI > 0u', () {
      final terminal = Terminal();

      terminal.write('\x1b[>1u');
      expect(terminal.kittyMode, isTrue);

      terminal.write('\x1b[>0u');
      expect(terminal.kittyMode, isFalse);
    });

    test('generates Kitty sequences for Shift+Enter', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      // Test the encoder directly
      // Note: Flutter's LogicalKeyboardKey.enter maps to keycode 13 in Kitty protocol
      expect(
        terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {SimpleModifier.shift},
          ),
        ),
        equals('\x1b[13;2u'),
      );
    });

    test('generates Kitty sequences with modifiers', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      // Test the encoder with Escape key and shift modifier
      // This verifies the encoder handles modifier combinations
      final result = terminal.kittyEncoder.encode(
        SimpleKeyEvent(
          logicalKey: LogicalKeyboardKey.escape,
          modifiers: {SimpleModifier.shift},
        ),
      );
      // Should produce a non-empty Kitty sequence with shift modifier (2)
      expect(result, isNotEmpty);
      expect(result, contains('2')); // shift modifier
    });

    test('push and pop flags', () {
      final terminal = Terminal();

      // Enable Kitty mode first
      terminal.write('\x1b[>1u');
      expect(terminal.kittyMode, isTrue);

      // Push flags with value 1
      terminal.write('\x1b[>+1u');

      // Verify we can still encode
      // Note: Flutter's LogicalKeyboardKey.enter maps to keycode 13 in Kitty protocol
      expect(
        terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {SimpleModifier.shift},
          ),
        ),
        equals('\x1b[13;2u'),
      );

      // Pop flags
      terminal.write('\x1b[>-1u');

      // Verify encoding still works after pop
      expect(
        terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {SimpleModifier.shift},
          ),
        ),
        equals('\x1b[13;2u'),
      );
    });

    test('kitty mode defaults to false', () {
      final terminal = Terminal();

      // Kitty mode should be false by default
      expect(terminal.kittyMode, isFalse);
    });

    test('toggle Kitty mode multiple times', () {
      final terminal = Terminal();

      // Enable
      terminal.write('\x1b[>1u');
      expect(terminal.kittyMode, isTrue);

      // Disable
      terminal.write('\x1b[>0u');
      expect(terminal.kittyMode, isFalse);

      // Enable again
      terminal.write('\x1b[>1u');
      expect(terminal.kittyMode, isTrue);

      // Disable again
      terminal.write('\x1b[>0u');
      expect(terminal.kittyMode, isFalse);
    });
  });
}
