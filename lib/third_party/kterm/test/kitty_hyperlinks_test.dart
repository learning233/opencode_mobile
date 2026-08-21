import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('OSC 8 hyperlink start', () {
    terminal.write('\x1b]8;id=example;https://dart.dev\x1b\\');
    terminal.write('X'); // Write a character to apply the hyperlink
    // Check that current cell has hyperlink
    final cell = terminal.buffer.lines[0].createCellData(0);
    expect(cell.hyperlinkId, isNot(equals(0)));
  });

  test('OSC 8 hyperlink end', () {
    terminal.write('\x1b]8;;\x1b\\');
    terminal.write('X');
    final cell = terminal.buffer.lines[0].createCellData(0);
    expect(cell.hyperlinkId, equals(0));
  });

  test('hyperlink with text', () {
    terminal.write('\x1b]8;;https://dart.dev\x1b\\');
    terminal.write('Dart');
    terminal.write('\x1b]8;;\x1b\\');
    expect(terminal.buffer.lines[0].createCellData(0).hyperlinkId,
        equals(terminal.buffer.lines[0].createCellData(3).hyperlinkId));
  });
}
