import 'package:kterm/kterm.dart';

void main() {
  final terminal = Terminal(maxLines: 100);
  terminal.write('\x1b[2J\x1b[H'); // clear
  terminal.write('Test 1: Visible underline\x1b[4m_____\x1b[0m\r\n');
  terminal.write('Test 2: Invisible text\x1b[4;8mINVISIBLE\x1b[0m\r\n');
  terminal.write('Test 3: Normal text\r\n');

  // Print buffer content via getText()
  print('=== buffer.getText() ===');
  print(terminal.buffer.getText());
  print('=== end getText ===\n');

  // Inspect line 1 (index 1) cell by cell
  final line = terminal.buffer.lines[1];
  print('Line 1 (index 1) text: "${line.getText()}"');
  print('Line 1 length: ${line.length}');
  for (int i = 0; i < line.length; i++) {
    final cell = line.createCellData(i);
    final cp = cell.content & CellContent.codepointMask;
    final flags = cell.flags;
    final inv = (flags & CellFlags.invisible) != 0;
    final underl = cell.underlineStyle;
    if (cp != 0 || inv || underl != 0) {
      print(
          'cell[$i]: char="${String.fromCharCode(cp)}" (0x${cp.toRadixString(16)}) flags=0x${flags.toRadixString(16)} inv=$inv underl=$underl');
    }
  }
}
