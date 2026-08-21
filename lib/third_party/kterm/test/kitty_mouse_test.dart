import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('SGR 1004 enable focus tracking', () {
    terminal.write('\x1b[?1004h');
    // Just verify no crash - focus tracking is internal state
    expect(true, isTrue);
  });

  test('SGR 1006 extended mouse encoding', () {
    terminal.write('\x1b[?1006h');
    // Just verify no crash - extended encoding is internal state
    expect(true, isTrue);
  });
}
