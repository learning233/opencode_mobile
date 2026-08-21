import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';
import 'package:kterm/src/core/cell.dart';

void main() {
  test(
      'Full-screen underline scenario: underline on, fill screen, reset, erase, new text should have no underline',
      () {
    final terminal = Terminal();

    // Ensure default 80x24
    expect(terminal.viewWidth, 80);
    expect(terminal.viewHeight, 24);

    // 1. Set underline
    terminal.write('\x1b[4m');
    expect(
        terminal.cursor.underlineStyle, equals(CellAttr.underlineStyleSingle));
    expect(terminal.cursor.attrs & CellAttr.underline, isNot(equals(0)));

    // 2. Fill entire screen with text (simulate opencode drawing underlined title)
    for (int row = 0; row < 24; row++) {
      terminal.setCursor(0, row);
      terminal.write('X' * 80);
    }

    // Verify all cells have underline
    for (int row = 0; row < 24; row++) {
      final line = terminal.buffer.lines[row];
      for (int col = 0; col < 80; col++) {
        final cell = line.createCellData(col);
        expect(cell.underlineStyle, equals(CellAttr.underlineStyleSingle),
            reason: 'Cell at ($row,$col) should have underlineStyle=1');
        expect(cell.flags & CellAttr.underline, isNot(equals(0)),
            reason: 'Cell at ($row,$col) should have underline flag');
      }
    }

    // 3. Reset attributes (SGR 0)
    terminal.write('\x1b[0m');
    expect(terminal.cursor.underlineStyle, equals(0));
    expect(terminal.cursor.attrs & CellAttr.underline, equals(0));

    // 4. Erase display (CSI 2J) — typical clear screen
    terminal.eraseDisplay();
    // After erase, all cells should have no underline
    for (int row = 0; row < 24; row++) {
      final line = terminal.buffer.lines[row];
      for (int col = 0; col < 80; col++) {
        final cell = line.createCellData(col);
        expect(cell.underlineStyle, equals(0),
            reason:
                'After eraseDisplay, cell ($row,$col) should have no underlineStyle');
        expect(cell.flags & CellAttr.underline, equals(0),
            reason:
                'After eraseDisplay, cell ($row,$col) should have no underline flag');
      }
    }

    // 5. Write new text after reset/erase
    terminal.setCursor(0, 0);
    terminal.write('New Text');
    // Check that new cells have no underline
    final line0 = terminal.buffer.lines[0];
    for (int col = 0; col < 8; col++) {
      final cell = line0.createCellData(col);
      expect(cell.underlineStyle, equals(0),
          reason: 'New text cell at col $col should have no underlineStyle');
      expect(cell.flags & CellAttr.underline, equals(0),
          reason: 'New text cell at col $col should have no underline flag');
    }
  });
}
