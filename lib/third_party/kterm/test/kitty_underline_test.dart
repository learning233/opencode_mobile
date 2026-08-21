import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('CSI 4:0 no underline', () {
    terminal.write('\x1b[4;0m');
    terminal.write('X');
    final cell = terminal.buffer.lines[0].createCellData(0);
    expect(cell.underlineStyle, equals(0));
  });

  test('CSI 4:1 single underline', () {
    terminal.write('\x1b[4;1m');
    terminal.write('X');
    final cell = terminal.buffer.lines[0].createCellData(0);
    expect(cell.underlineStyle, equals(1));
  });

  test('CSI 4:3 double underline', () {
    terminal.write('\x1b[4;3m');
    terminal.write('X');
    final cell = terminal.buffer.lines[0].createCellData(0);
    expect(cell.underlineStyle, equals(3));
  });

  test('CSI 4:4 curly underline', () {
    terminal.write('\x1b[4;4m');
    terminal.write('X');
    final cell = terminal.buffer.lines[0].createCellData(0);
    expect(cell.underlineStyle, equals(4));
  });

  test('CSI 4:5 dotted underline', () {
    terminal.write('\x1b[4;5m');
    terminal.write('X');
    final cell = terminal.buffer.lines[0].createCellData(0);
    expect(cell.underlineStyle, equals(5));
  });

  test(
      'CSI 4:6 with SGR 6 (not a valid underline style) yields single underline',
      () {
    terminal.write('\x1b[4;6m');
    terminal.write('X');
    final cell = terminal.buffer.lines[0].createCellData(0);
    // 6 is a standard SGR (rapid blink) not an underline style.
    // Since 6 is not consumed as subparameter, underline defaults to single (1)
    // and SGR 6 is ignored (not implemented).
    expect(cell.underlineStyle, equals(1));
  });
}
