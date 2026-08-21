import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('Terminal resize edge cases', () {
    test('adjusts cursor Y when height shrinks below cursor', () {
      final terminal = Terminal();
      terminal.resize(10, 10);
      // Place cursor at bottom row (y=9)
      terminal.setCursor(0, 9);
      terminal.resize(10, 5);
      // Cursor should be clamped to max row (4)
      expect(terminal.buffer.cursorY, equals(4));
    });

    test('shrink height with cursor at top removes bottom lines', () {
      final terminal = Terminal();
      terminal.resize(10, 10);
      // Write a marker on each row
      for (int y = 0; y < 10; y++) {
        terminal.setCursor(0, y);
        terminal.write('L$y');
      }
      expect(terminal.buffer.lines.length, equals(10));
      // Move cursor to top
      terminal.setCursor(0, 0);
      // Shrink to 5 rows
      terminal.resize(10, 5);
      // Buffer should now have only 5 lines (bottom lines popped)
      expect(terminal.buffer.lines.length, equals(5));
      // Cursor remains at top
      expect(terminal.buffer.cursorY, equals(0));
    });

    test('shrink width with reflow disabled truncates line content', () {
      final terminal = Terminal(reflowEnabled: false);
      terminal.resize(20, 10);
      terminal.write('This is a long line that will be truncated');
      // First 20 characters of the string
      expect(
          terminal.buffer.lines[0].toString(), equals('This is a long line '));
      // Shrink width to 10
      terminal.resize(10, 10);
      // Line should be truncated to first 10 characters
      expect(terminal.buffer.lines[0].toString(), equals('This is a '));
    });

    test('shrink width with reflow enabled triggers reflow', () {
      final terminal = Terminal(reflowEnabled: true);
      terminal.resize(20, 10);
      terminal.write('This is a long line that should wrap');
      // Shrink width to 10
      terminal.resize(10, 10);
      // After reflow, first line should have first 10 characters
      expect(terminal.buffer.lines[0].toString(), equals('This is a '));
      // Subsequent lines should have the rest
      expect(terminal.buffer.lines[1].toString(), isNotEmpty);
    });

    test('grow height beyond current line count adds new empty lines', () {
      final terminal = Terminal();
      terminal.resize(10, 5);
      // Initially 5 lines
      expect(terminal.buffer.lines.length, equals(5));
      // Grow to 10 rows
      terminal.resize(10, 10);
      // Buffer should now have 10 lines
      expect(terminal.buffer.lines.length, equals(10));
      // New lines should be empty
      for (int y = 5; y < 10; y++) {
        expect(terminal.buffer.lines[y].toString(), isEmpty);
      }
    });

    test('alt buffer resize does not reflow even when reflowEnabled', () {
      final terminal = Terminal(reflowEnabled: true);
      terminal.useAltBuffer();
      terminal.resize(20, 10);
      terminal.write('This is a long line that should not reflow on resize');
      // Initial line length 20
      expect(terminal.buffer.lines[0].toString().length, equals(20));
      // Shrink width
      terminal.resize(10, 10);
      // Since alt buffer does not reflow, line should be truncated
      expect(terminal.buffer.lines[0].toString(), equals('This is a '));
    });
  });
}
