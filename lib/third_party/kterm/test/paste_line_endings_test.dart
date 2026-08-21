import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('Paste Line Ending Normalization', () {
    late Terminal terminal;
    late List<String> output;

    setUp(() {
      output = [];
      terminal = Terminal(
        maxLines: 100,
        onOutput: (data) => output.add(data),
      );
    });

    test('normalizes CRLF line endings to CR by default', () {
      const text = 'line1\r\nline2\r\nline3';
      terminal.paste(text);
      expect(output, ['line1\rline2\rline3']);
    });

    test('normalizes LF line endings to CR by default', () {
      const text = 'line1\nline2\nline3';
      terminal.paste(text);
      expect(output, ['line1\rline2\rline3']);
    });

    test('normalizes CR line endings to CR by default', () {
      const text = 'line1\rline2\rline3';
      terminal.paste(text);
      expect(output, ['line1\rline2\rline3']);
    });

    test('preserves tabs in pasted text', () {
      const text = 'line1\twith\ttabs\nline2';
      terminal.paste(text);
      expect(output, ['line1\twith\ttabs\rline2']);
    });

    test('filters out other control characters', () {
      const text = 'line1\x00\x07\x08with\x0b\x0ccontrol\x1e\x1fchars\nline2';
      terminal.paste(text);
      expect(output, ['line1withcontrolchars\rline2']);
    });

    test('normalizes to CRLF when lineFeedMode is enabled', () {
      // Enable line feed mode (Enter sends CRLF)
      terminal.write('\x1b[20h'); // SM lineFeedMode

      const text = 'line1\nline2\nline3';
      terminal.paste(text);
      // Output should have CRLF line endings
      expect(output, ['line1\r\nline2\r\nline3']);
    });

    test('works correctly with bracketed paste mode enabled', () {
      // Enable bracketed paste mode
      terminal.write('\x1b[?2004h');

      const text = 'line1\nline2\nline3';
      terminal.paste(text);
      // Should be wrapped in bracketed paste sequences with normalized line endings
      expect(output, ['\x1b[200~line1\rline2\rline3\x1b[201~']);
    });

    test('handles mixed line endings correctly', () {
      const text = 'line1\rline2\nline3\r\nline4';
      terminal.paste(text);
      expect(output, ['line1\rline2\rline3\rline4']);
    });
  });
}
