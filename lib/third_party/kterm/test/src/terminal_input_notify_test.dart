import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('Terminal.notifyListeners', () {
    test('write() calls notifyListeners', () {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      terminal.write('hello');

      expect(notifyCount, equals(1));
    });

    test('textInput() calls notifyListeners', () {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      terminal.textInput('hello');

      // BUG: textInput does NOT call notifyListeners currently
      // This test documents the EXPECTED behavior after the fix
      expect(notifyCount, equals(1),
          reason: 'textInput should call notifyListeners to update UI');
    });

    test('charInput() does not notify when no output', () {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      // 'A' (65) - no ctrl/alt, so returns false without output
      terminal.charInput(65);

      // charInput should NOT notify when no output generated
      expect(notifyCount, equals(0));
    });

    test('charInput() calls notifyListeners when producing output', () {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      // ctrl+a produces '\x01'
      terminal.charInput(97, ctrl: true); // 'a' with ctrl

      // charInput should call notifyListeners when output is produced
      expect(notifyCount, equals(1));
    });

    test('keyInput() does not notify when no inputHandler', () {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      // No inputHandler set, so returns false without output
      terminal.keyInput(TerminalKey.keyA);

      // keyInput should NOT notify when no output
      expect(notifyCount, equals(0));
    });

    test('paste() calls notifyListeners', () {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      terminal.paste('hello world');

      // paste goes through textInput which should call notifyListeners
      expect(notifyCount, equals(1));
    });

    test('rapid write + textInput sequence calls notifyListeners for each', () {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      terminal.write('hello');
      terminal.textInput(' world');

      // Each should trigger a notification
      expect(notifyCount, equals(2));
    });

    test('multiple rapid textInput calls each notify', () {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      terminal.textInput('a');
      terminal.textInput('b');
      terminal.textInput('c');

      expect(notifyCount, equals(3));
    });

    test('write with mixed control characters calls notifyListeners', () {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      // Mixed content: text + ANSI color codes + text
      terminal.write('\x1b[31mred\x1b[0m normal');

      expect(notifyCount, equals(1));
    });

    test('textInput with mixed control characters calls notifyListeners', () {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      // User typing text that happens to contain control characters
      terminal.textInput('hello\x1b[31mworld');

      expect(notifyCount, equals(1),
          reason: 'textInput should notify even with control chars');
    });
  });
}
