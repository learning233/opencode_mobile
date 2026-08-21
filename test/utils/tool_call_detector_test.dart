import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/utils/tool_call_detector.dart';

void main() {
  group('ToolCallDetector.detect', () {
    test('detects a real top-level tool call', () {
      final info = ToolCallDetector.detect(
        'Here is the command:\n<bash>ls -la</bash>\nDone.',
      );
      expect(info, isNotNull);
      expect(info!.toolName, 'bash');
    });

    test('skips tool XML inside a fenced code block', () {
      final info = ToolCallDetector.detect(
        'Example:\n```xml\n<bash>ls -la</bash>\n```\nThat is it.',
      );
      expect(info, isNull);
    });

    test('skips tool XML inside a tilde-fenced code block', () {
      final info = ToolCallDetector.detect(
        '~~~\n<read_file path="a.ts" />\n<bash>ls</bash>\n~~~',
      );
      expect(info, isNull);
    });

    test('skips tool XML inside an inline code span', () {
      final info = ToolCallDetector.detect(
        'Use `<bash>ls</bash>` carefully in text.',
      );
      expect(info, isNull);
    });

    test('still detects a real call when code blocks are also present', () {
      final info = ToolCallDetector.detect(
        '```\n<bash>echo example</bash>\n```\nNow run it:\n<grep>foo</grep>',
      );
      expect(info, isNotNull);
      expect(info!.toolName, 'grep');
    });

    test('returns null for plain text', () {
      expect(ToolCallDetector.detect('Just some text, no XML here.'), isNull);
    });

    test('returns null for empty/blank text', () {
      expect(ToolCallDetector.detect(''), isNull);
      expect(ToolCallDetector.detect('   \n  '), isNull);
    });
  });
}
