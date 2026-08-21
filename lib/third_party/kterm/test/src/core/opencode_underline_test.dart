import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';
import 'package:kterm/src/core/cell.dart';

void main() {
  test('Reproduce opencode-like sequence: verify underline is off after reset',
      () {
    final terminal = Terminal();

    // Simulate: some initial text with underline ON
    terminal.write('\x1b[4mHello');

    // Then the reset sequence from the log
    terminal.write('\x1b[0m\x1b[49m\x1b[39m\x1b[27m\x1b[24m');

    // Write new text after reset
    terminal.write('World');

    // Check that new cells have no underline
    for (var i = 5; i < 10; i++) {
      final cell = terminal.buffer.lines[0].createCellData(i);
      expect(cell.underlineStyle, equals(0),
          reason: 'Cell $i should have no underline style after reset');
      expect(cell.flags & CellAttr.underline, equals(0),
          reason: 'Cell $i should have no underline flag after reset');
    }
  });
}
