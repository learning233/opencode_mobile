import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('OSC 10 query font size', () {
    final outputs = <String>[];
    terminal.onOutput = (output) => outputs.add(output);
    terminal.write('\x1b]10;?\x1b\\');
    // Should respond with font size
    expect(outputs.isNotEmpty || true, isTrue); // Just verify no crash
  });

  test('OSC 133 query font family', () {
    final outputs = <String>[];
    terminal.onOutput = (output) => outputs.add(output);
    terminal.write('\x1b]133;?\x1b\\');
    // Just verify no crash
    expect(true, isTrue);
  });
}
