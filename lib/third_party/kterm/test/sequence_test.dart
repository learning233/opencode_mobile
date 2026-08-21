import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitty_protocol/kitty_protocol.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('Kitty sequence verification', () {
    test('Shift+Enter keycode is 13 in Kitty protocol', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      // Simulate Shift+Enter
      final seq = terminal.kittyEncoder.encode(SimpleKeyEvent(
        logicalKey: LogicalKeyboardKey.enter,
        modifiers: {SimpleModifier.shift},
        isKeyUp: false,
        isKeyRepeat: false,
      ));

      print('Sequence: "$seq"');
      print('Bytes: ${seq.codeUnits}');
      print(
          'First char (ESC): ${seq.codeUnitAt(0)} == 27: ${seq.codeUnitAt(0) == 27}');

      // Kitty protocol uses keycode 13 for Enter
      expect(seq.codeUnitAt(0), equals(27)); // ESC
      expect(seq, contains('13')); // Enter keycode is 13
      expect(seq, contains('2')); // Shift modifier
    });

    test('Enter without modifiers produces sequence', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      final seq = terminal.kittyEncoder.encode(SimpleKeyEvent(
        logicalKey: LogicalKeyboardKey.enter,
        modifiers: {},
        isKeyUp: false,
        isKeyRepeat: false,
      ));

      print('Enter sequence: "$seq"');
      print('Bytes: ${seq.codeUnits}');

      // Kitty protocol uses keycode 13 for Enter
      expect(seq.codeUnitAt(0), equals(27)); // ESC
      expect(seq, contains('13')); // Enter keycode is 13
    });
  });
}
