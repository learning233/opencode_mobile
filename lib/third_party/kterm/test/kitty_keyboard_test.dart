import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitty_protocol/kitty_protocol.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('Kitty Keyboard Protocol - Key Encoding', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal();
    });

    group('Basic Mode (CSI > 1u)', () {
      test('Enter key enables kitty mode', () {
        terminal.write('\x1b[>1u');
        expect(terminal.kittyMode, isTrue);
      });

      test('Enter key encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        // Enter should be keycode 13 in Kitty protocol
        expect(result, contains('13'));
      });

      test('Tab key encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.tab,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        // Tab keycode is 9 in Kitty protocol
        expect(result, contains('9'));
      });

      test('Backspace key encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.backspace,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        // Backspace keycode is 127
        expect(result, contains('127'));
      });
    });

    group('Modifier Keys', () {
      test('Shift modifier is encoded', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {SimpleModifier.shift},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        // Shift is encoded in the sequence
        expect(result, isNotEmpty);
      });

      test('Control modifier returns empty for printable (deferToSystem)', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.keyA,
            modifiers: {SimpleModifier.control},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        // Ctrl+letter returns empty due to deferToSystemOnComplexInput
        expect(result, isEmpty);
      });

      test('Alt modifier returns empty for printable (deferToSystem)', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.keyA,
            modifiers: {SimpleModifier.alt},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        // Alt+letter returns empty due to deferToSystemOnComplexInput
        expect(result, isEmpty);
      });

      test('Meta (Super) modifier returns empty for printable', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.keyA,
            modifiers: {SimpleModifier.meta},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        // Meta+letter returns empty due to deferToSystemOnComplexInput
        expect(result, isEmpty);
      });

      test('Special keys with modifiers encode correctly', () {
        terminal.write('\x1b[>1u');

        // Test with a special key (Enter) that should encode with modifiers
        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {SimpleModifier.shift},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        // Special keys with modifiers should encode
        expect(result, isNotEmpty);
      });
    });

    group('Arrow Keys', () {
      test('Arrow Up encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.arrowUp,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        expect(result, isNotEmpty);
        expect(result, contains('u'));
      });

      test('Arrow Down encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.arrowDown,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        expect(result, isNotEmpty);
      });

      test('Arrow Left encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.arrowLeft,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        expect(result, isNotEmpty);
      });

      test('Arrow Right encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.arrowRight,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        expect(result, isNotEmpty);
      });
    });

    group('Function Keys', () {
      test('F1 encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.f1,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        expect(result, isNotEmpty);
      });

      test('F12 encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.f12,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        expect(result, isNotEmpty);
      });
    });

    group('Home/End Keys', () {
      test('Home key encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.home,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        expect(result, isNotEmpty);
      });

      test('End key encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.end,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        expect(result, isNotEmpty);
      });
    });

    group('Page Up/Down Keys', () {
      test('PageUp encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.pageUp,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        expect(result, isNotEmpty);
      });

      test('PageDown encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.pageDown,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        expect(result, isNotEmpty);
      });
    });

    group('Insert/Delete Keys', () {
      test('Insert key encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.insert,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        expect(result, isNotEmpty);
      });

      test('Delete key encodes correctly', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.delete,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        expect(result, isNotEmpty);
      });
    });

    group('Flag Stack (Push/Pop)', () {
      test('pushKittyFlags and popKittyFlags work without throwing', () {
        terminal.write('\x1b[>1u');

        // Should not throw
        terminal.pushKittyFlags(1);
        terminal.popKittyFlags();
      });

      test('Nested push/pop works', () {
        terminal.write('\x1b[>1u');

        // Should not throw
        terminal.pushKittyFlags(1);
        terminal.pushKittyFlags(2);
        terminal.popKittyFlags();
        terminal.popKittyFlags();
      });

      test('popKittyFlags on empty stack is safe', () {
        terminal.write('\x1b[>1u');
        // Should not throw
        terminal.popKittyFlags();
        terminal.popKittyFlags();
      });
    });

    group('Escape Sequence Format', () {
      test('Sequence format is correct', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        // Should be \x1b[13;1u format
        expect(result, startsWith('\x1b['));
        expect(result, endsWith('u'));
      });
    });

    group('Key Release Events', () {
      test('Key up event is encoded', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {},
            isKeyUp: true,
            isKeyRepeat: false,
          ),
        );

        // Key up should still produce a sequence
        expect(result, isNotEmpty);
      });

      test('Key repeat event is encoded', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: true,
          ),
        );

        expect(result, isNotEmpty);
      });
    });

    group('Printable Characters with Modifiers', () {
      test('Ctrl+letter returns empty (needs fallback to TextInput)', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.keyA,
            modifiers: {SimpleModifier.control},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        // Ctrl+letter should return empty, handled by system
        expect(result, isEmpty);
      });

      test('Printable without modifiers returns empty', () {
        terminal.write('\x1b[>1u');

        final result = terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.keyA,
            modifiers: {},
            isKeyUp: false,
            isKeyRepeat: false,
          ),
        );

        // Regular printable characters return empty, handled by TextInput
        expect(result, isEmpty);
      });
    });
  });
}
