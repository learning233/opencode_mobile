import 'package:test/test.dart';
import 'package:kterm/core.dart';

void main() {
  group('SGR underline handling', () {
    test('SGR 4 (no subparam) sets underlineStyle to single (1)', () {
      final terminal = Terminal();

      terminal.write('\x1b[4mX');

      final line0 = terminal.buffer.lines[0];
      final cell = line0.createCellData(0);
      expect(cell.underlineStyle, equals(1),
          reason: 'Plain SGR 4 should set underlineStyle=1 (single)');
      expect(cell.flags & CellAttr.underline, isNot(equals(0)),
          reason: 'Plain SGR 4 should set the underline attrs bit');
    });

    test(
        'SGR 4;0 clears underline completely (both attrs bit and underlineStyle)',
        () {
      final terminal = Terminal();

      // Set underline first
      terminal.write('\x1b[4mX');
      var line0 = terminal.buffer.lines[0];
      expect(line0.getUnderlineStyle(0), equals(1));
      expect(line0.getAttributes(0) & CellAttr.underline, isNot(equals(0)));

      // Now use 4;0 to turn off
      terminal.write('\x1b[4;0mY');
      line0 = terminal.buffer.lines[0];

      // Cell at position 1 (Y) should have no underline style
      expect(line0.getUnderlineStyle(1), equals(0),
          reason: 'SGR 4;0 should clear underlineStyle');
      // The attrs underline bit should also be cleared
      expect(line0.getAttributes(1) & CellAttr.underline, equals(0),
          reason: 'SGR 4;0 should clear the underline attrs bit too');
    });

    test('SGR 4;n sets underlineStyle to n for n=2,3,4,5', () {
      for (var style = 2; style <= 5; style++) {
        final terminal = Terminal();
        terminal.write('\x1b[4;${style}mZ');
        final line0 = terminal.buffer.lines[0];
        final cell = line0.createCellData(0);
        expect(cell.underlineStyle, equals(style),
            reason: 'SGR 4;$style should set underlineStyle=$style');
        // Extended styles (2-5) are custom-drawn and should NOT set the basic
        // underline attrs bit. Only style 1 sets that bit.
        expect(cell.flags & CellAttr.underline, equals(0),
            reason:
                'SGR 4;$style should NOT set underline attrs bit (custom render)');
      }
    });

    test('SGR 24 clears both underlineStyle and attrs bit', () {
      final terminal = Terminal();

      // Set underline first
      terminal.write('\x1b[4mX');
      var line0 = terminal.buffer.lines[0];
      expect(line0.getUnderlineStyle(0), equals(1));
      expect(line0.getAttributes(0) & CellAttr.underline, isNot(equals(0)));

      // Turn off with SGR 24
      terminal.write('\x1b[24mY');
      line0 = terminal.buffer.lines[0];

      expect(line0.getUnderlineStyle(1), equals(0),
          reason: 'SGR 24 should clear underlineStyle');
      expect(line0.getAttributes(1) & CellAttr.underline, equals(0),
          reason: 'SGR 24 should clear underline attrs bit');
    });

    test('SGR 0 resets underlineStyle and underlineColor', () {
      final terminal = Terminal();

      // Set underline with custom color
      terminal.write('\x1b[4;3m\x1b[58;2;255;0;0mA');
      final line0 = terminal.buffer.lines[0];
      expect(line0.getUnderlineStyle(0), equals(3)); // curly
      expect(line0.getUnderlineColor(0), isNot(equals(0))); // custom color set

      // Reset with SGR 0
      terminal.write('\x1b[0mB');
      final line0After = terminal.buffer.lines[0];
      expect(line0After.getUnderlineStyle(1), equals(0),
          reason: 'SGR 0 should reset underlineStyle to 0');
      expect(line0After.getUnderlineColor(1), equals(0),
          reason: 'SGR 0 should reset underlineColor to 0');
      expect(line0After.getAttributes(1) & CellAttr.underline, equals(0),
          reason: 'SGR 0 should clear underline attrs bit');
    });

    test('SGR 4:n with colon separator (modern extended syntax)', () {
      final terminal = Terminal();

      // Set curly underline with colon syntax (modern terminal convention)
      terminal.write('\x1b[4:3mX');
      var line0 = terminal.buffer.lines[0];
      expect(line0.getUnderlineStyle(0), equals(3));
      expect(line0.getAttributes(0) & CellAttr.underline, equals(0));

      // Clear underline with colon syntax 4:0
      terminal.write('\x1b[4:0mY');
      line0 = terminal.buffer.lines[0];
      expect(line0.getUnderlineStyle(1), equals(0));
      expect(line0.getAttributes(1) & CellAttr.underline, equals(0));
    });

    test('SGR 4:1 with colon sets single underline', () {
      final terminal = Terminal();
      terminal.write('\x1b[4:1mX');
      final line0 = terminal.buffer.lines[0];
      final cell = line0.createCellData(0);
      expect(cell.underlineStyle, equals(1));
      expect(cell.flags & CellAttr.underline, isNot(equals(0)));
    });
  });

  group('DECSC/DECRC cursor save/restore', () {
    test('DECSC/DECRC preserves underlineStyle and underlineColor', () {
      final terminal = Terminal();

      // Set underline style to curly (3)
      terminal.write('\x1b[4;3m');
      expect(terminal.cursor.underlineStyle, equals(3));

      // Save cursor
      terminal.write('\x1b7');

      // Change underline style to something else
      terminal.write('\x1b[4;1m');
      expect(terminal.cursor.underlineStyle, equals(1));

      // Restore cursor should bring back curly underline
      terminal.write('\x1b8');
      expect(terminal.cursor.underlineStyle, equals(3),
          reason: 'Restored cursor should have underlineStyle=3');

      // Write a character and verify cell has curly underline
      terminal.write('A');
      final line = terminal.buffer.lines[0];
      final cell = line.createCellData(0);
      expect(cell.underlineStyle, equals(3),
          reason:
              'Cell written after restore should have curly underlineStyle');
    });

    test(
        'DECSC/DECRC preserves underlineStyle even when saved state has no underline',
        () {
      final terminal = Terminal();

      // Initial state: no underline
      expect(terminal.cursor.underlineStyle, equals(0));

      // Save cursor with no underline
      terminal.write('\x1b7');

      // Turn on underline
      terminal.write('\x1b[4m');
      expect(terminal.cursor.underlineStyle, equals(1));

      // Restore should bring back no underline
      terminal.write('\x1b8');
      expect(terminal.cursor.underlineStyle, equals(0),
          reason: 'Restored cursor should have underlineStyle=0 (none)');

      // Write a character and verify
      terminal.write('X');
      final line = terminal.buffer.lines[0];
      final cell = line.createCellData(0);
      expect(cell.underlineStyle, equals(0),
          reason: 'Cell written after restore should have no underline');
      expect(cell.flags & CellAttr.underline, equals(0),
          reason: 'Cell should have no underline attrs bit');
    });

    test('DECSC/DECRC preserves underlineColor', () {
      final terminal = Terminal();

      // Set underline style and custom RGB color
      terminal.write('\x1b[4;2m\x1b[58;2;255;128;64m');
      expect(terminal.cursor.underlineStyle, equals(2));
      final savedColor = terminal.cursor.underlineColor;

      // Save cursor
      terminal.write('\x1b7');

      // Change underline color
      terminal.write('\x1b[58;2;0;255;0m');
      expect(terminal.cursor.underlineColor, isNot(equals(savedColor)));

      // Restore should bring back original color
      terminal.write('\x1b8');
      expect(terminal.cursor.underlineColor, equals(savedColor),
          reason: 'Restored cursor should have original underlineColor');
    });
  });

  group('Cursor style reset', () {
    test(
        'CursorStyle.reset() clears all fields including underlineStyle and underlineColor',
        () {
      final cursor = CursorStyle()
        ..foreground = 123
        ..background = 456
        ..attrs = CellAttr.bold | CellAttr.underline
        ..underlineStyle = 3
        ..underlineColor = 0x12345678
        ..hyperlinkId = 42;

      cursor.reset();

      expect(cursor.foreground, equals(0));
      expect(cursor.background, equals(0));
      expect(cursor.attrs, equals(0));
      expect(cursor.underlineStyle, equals(0));
      expect(cursor.underlineColor, equals(0));
      expect(cursor.hyperlinkId, equals(0));
    });

    test(
        'CursorStyle.copy() captures all fields including underlineStyle and underlineColor',
        () {
      final original = CursorStyle()
        ..foreground = 100
        ..background = 200
        ..attrs = CellAttr.italic | CellAttr.underline
        ..underlineStyle = 4
        ..underlineColor = 0xDEADBEEF
        ..hyperlinkId = 999;

      final copy = original.copy();

      expect(copy.foreground, equals(original.foreground));
      expect(copy.background, equals(original.background));
      expect(copy.attrs, equals(original.attrs));
      expect(copy.underlineStyle, equals(original.underlineStyle));
      expect(copy.underlineColor, equals(original.underlineColor));
      expect(copy.hyperlinkId, equals(original.hyperlinkId));

      // Verify independence
      original.underlineStyle = 0;
      expect(copy.underlineStyle, equals(4));
    });
  });
}
