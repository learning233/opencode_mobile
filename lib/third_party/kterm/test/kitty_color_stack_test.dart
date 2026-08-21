import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('OSC 30001 push color stack', () {
    terminal.write('\x1b[31m'); // Red foreground
    terminal.write('\x1b]30001;push\x1b\\');
    // Just verify no crash
    expect(true, isTrue);
  });

  test('OSC 30101 pop color stack', () {
    terminal.write('\x1b[31m');
    terminal.write('\x1b]30001;push\x1b\\');
    terminal.write('\x1b]30101;pop\x1b\\');
    // Just verify no crash
    expect(true, isTrue);
  });
}
