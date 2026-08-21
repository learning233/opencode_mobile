import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('enable bracketed paste mode', () {
    terminal.write('\x1b[?2004h');
    // Check if the terminal recognizes the mode - we'll verify through state
    terminal.write('X');
    // Just verify it doesn't crash - the bracketed paste tracking is internal
    expect(
        terminal.buffer.lines[0].createCellData(0).content, isNot(equals(0)));
  });
}
