import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('OSC 133 A shell started', () {
    terminal.write('\x1b]133;A\x1b\\');
    // Just verify no crash
    expect(true, isTrue);
  });

  test('OSC 133 D command executed', () {
    terminal.write('\x1b]133;D\x1b\\');
    // Just verify no crash
    expect(true, isTrue);
  });
}
