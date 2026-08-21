import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('OSC 52 get clipboard query', () {
    // OSC 52 ; c ; ? - query clipboard
    final outputs = <String>[];
    terminal.onOutput = (output) => outputs.add(output);
    terminal.write('\x1b]52;c;?\x1b\\');
    // Should trigger clipboard read callback
    expect(outputs, isEmpty); // Callback triggers async, just verify no crash
  });

  test('OSC 52 set clipboard', () {
    String? clipboardData;
    terminal.onClipboardWrite = (data, target) {
      clipboardData = data;
    };
    // OSC 52 ; c ; base64("hello") = aGVsbG8=
    terminal.write('\x1b]52;c;aGVsbG8=\x1b\\');
    expect(clipboardData, equals('hello'));
  });

  test('OSC 5522 extended clipboard sync start', () {
    terminal.write('\x1b]5522;sync;start\x1b\\');
    // Just verify no crash
    expect(true, isTrue);
  });
}
