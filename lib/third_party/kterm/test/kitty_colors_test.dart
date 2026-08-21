import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('SGR 38;2 RGB true color (CSI format)', () {
    terminal.write('\x1b[38;2;255;128;0m'); // Orange RGB
    terminal.write('X');
    final cell = terminal.buffer.lines[0].createCellData(0);
    // RGB encoded as (r << 16) | (g << 8) | b | (3 << 25)
    // 255,128,0 = 0x07F80000 | 0x00008000 | 0 | 0x6000000 = 0x07F80000 + 0x00008000 + 0x06000000
    // = 0x07F80000 + 0x06000000 = 0x0DF80000 = 117407744
    expect(cell.foreground, equals(117407744));
  });

  test('SGR 48;2 RGB true color background (CSI format)', () {
    terminal.write('\x1b[48;2;0;0;255m'); // Blue background
    terminal.write('X');
    final cell = terminal.buffer.lines[0].createCellData(0);
    // 0,0,255 = (0 << 16) | (0 << 8) | 255 | (3 << 25)
    // = 255 + 100663296 = 100663551
    expect(cell.background, equals(100663551));
  });

  test('SGR 38;5 256 colors (CSI format)', () {
    terminal.write('\x1b[38;5;196m'); // Bright red
    terminal.write('X');
    final cell = terminal.buffer.lines[0].createCellData(0);
    // 196 should be in the 256-color range
    expect(cell.foreground, greaterThan(0));
  });
}
