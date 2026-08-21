import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  test('SGR 24 properly turns off underline for subsequent text', () {
    final terminal = Terminal();

    // Write underlined text
    terminal.write('\x1b[4mUnderlined');
    expect(
        terminal.buffer.lines[0].createCellData(0).underlineStyle, equals(1));
    expect(terminal.buffer.lines[0].createCellData(0).flags & 0x8,
        isNot(equals(0)));

    // Turn off underline
    terminal.write('\x1b[24m');
    terminal.write('Normal');

    // Check that 'N' at position 10 has NO underline
    final normalCell = terminal.buffer.lines[0].createCellData(10);
    expect(normalCell.underlineStyle, equals(0),
        reason: 'Cell after SGR 24 should have underlineStyle=0');
    expect(normalCell.flags & 0x8, equals(0),
        reason: 'Cell after SGR 24 should have attrs.underline=0');
  });

  test('Full reset sequence (opencode pattern) clears underline completely',
      () {
    final terminal = Terminal();

    // Underline some text
    terminal.write('\x1b[4mHello');
    for (var i = 0; i < 5; i++) {
      final cell = terminal.buffer.lines[0].createCellData(i);
      expect(cell.underlineStyle, equals(1));
    }

    // The exact sequence from opencode log
    terminal.write('\x1b[0m\x1b[49m\x1b[39m\x1b[27m\x1b[24m');

    // Write new text
    terminal.write('World');

    // Cells for "World" should have NO underline
    for (var i = 5; i < 10; i++) {
      final cell = terminal.buffer.lines[0].createCellData(i);
      expect(cell.underlineStyle, equals(0),
          reason: 'Cell $i after reset should have no underlineStyle');
      expect(cell.flags & 0x8, equals(0),
          reason: 'Cell $i after reset should have no underline attrs bit');
    }
  });

  test('DECSC/DECRC does not leak underline to subsequent text', () {
    final terminal = Terminal();

    terminal.write('\x1b[4mA'); // col 0: A underlined
    terminal.write('\x1b7'); // save at col 1 (after A)
    terminal.write('\x1b[24mB'); // col 1: B not underlined
    terminal.write('\x1b[2C'); // move to col 3 (skip past B)
    terminal.write('\x1b8'); // restore to col 1 with underline
    terminal.write('C'); // col 1: C should be underlined (overwrites B)

    final line = terminal.buffer.lines[0];

    // col 0: A underlined (from before DECSC/DECRC, never overwritten)
    expect(line.createCellData(0).underlineStyle, equals(1),
        reason: 'A at col 0 should remain underlined');
    // col 1: C underlined (restored underline state after DECRC, overwrites B)
    expect(line.createCellData(1).underlineStyle, equals(1),
        reason: 'C at col 1 should have underline restored by DECRC');
    // col 2: should be empty (cursor moved past it, no character written)
    expect(line.createCellData(2).content, equals(0),
        reason: 'col 2 should be empty (cursor skipped)');
  });

  test('Diagnostic: trace underline state through SGR 0 and 24', () {
    final terminal = Terminal();

    terminal.write('\x1b[4m');
    expect(terminal.cursor.underlineStyle, equals(1));
    expect(terminal.cursor.attrs & 0x8, isNot(equals(0)));

    terminal.write('A');
    var cellA = terminal.buffer.lines[0].createCellData(0);
    expect(cellA.underlineStyle, equals(1));
    expect(cellA.flags & 0x8, isNot(equals(0)));

    terminal.write('\x1b[24m');
    expect(terminal.cursor.underlineStyle, equals(0));
    expect(terminal.cursor.attrs & 0x8, equals(0));

    terminal.write('B');
    var cellB = terminal.buffer.lines[0].createCellData(1);
    expect(cellB.underlineStyle, equals(0));
    expect(cellB.flags & 0x8, equals(0));

    terminal.write('\x1b[0m\x1b[49m\x1b[39m\x1b[27m\x1b[24m');
    expect(terminal.cursor.underlineStyle, equals(0));
    expect(terminal.cursor.attrs & 0x8, equals(0));

    terminal.write('C');
    var cellC = terminal.buffer.lines[0].createCellData(2);
    expect(cellC.underlineStyle, equals(0));
    expect(cellC.flags & 0x8, equals(0));
  });

  test('Diagnostic: DECSC/DECRC underline preservation', () {
    final terminal = Terminal();

    terminal.write('\x1b[4;3m'); // curly underline
    terminal.write('\x1b7'); // save
    terminal.write('\x1b[4;1m'); // single underline
    expect(terminal.cursor.underlineStyle, equals(1));

    terminal.write('\x1b8'); // restore
    expect(terminal.cursor.underlineStyle, equals(3));

    terminal.write('X');
    var cell = terminal.buffer.lines[0].createCellData(0);
    expect(cell.underlineStyle, equals(3));
  });
}
