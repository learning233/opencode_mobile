import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitty_protocol/kitty_protocol.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('Kitty Encoder - Default behavior (reportAllKeysAsEscape=false)', () {
    test(
        'basic mode (CSI > 1u) sets kittyMode=true but reportAllKeysAsEscape=false',
        () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      // Basic mode: kittyMode enabled, but not using full Kitty encoding
      expect(terminal.kittyMode, isTrue);
      expect(terminal.kittyEncoder.flags.reportAllKeysAsEscape, isFalse);
    });

    test(
        'Tab encoder returns sequence but should be ignored due to reportAllKeysAsEscape=false',
        () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      // The encoder returns a sequence, but kterm should ignore it
      // because reportAllKeysAsEscape=false
      final result = terminal.kittyEncoder.encode(
        SimpleKeyEvent(
          logicalKey: LogicalKeyboardKey.tab,
          modifiers: {},
          isKeyUp: false,
          isKeyRepeat: false,
        ),
      );

      // Encoder still returns sequence (this is a library quirk)
      expect(result, equals('\x1B[9;1u'));
      // But we should check the flag in kterm to decide whether to use it
      expect(terminal.kittyEncoder.flags.reportAllKeysAsEscape, isFalse);
    });

    test('Digit1 returns empty string (needs fallback)', () {
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

      // Digit1 returns empty - needs fallback
      expect(result, equals(''));
    });

    test('Enter returns sequence', () {
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

      expect(result, isNotEmpty);
    });
  });
}
