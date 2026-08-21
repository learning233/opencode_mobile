import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/api/models/file_content.dart';

void main() {
  group('FileContent.parse', () {
    test('parses a text response', () {
      final result = FileContent.parse({'type': 'text', 'content': 'hello'});
      expect(result.isBinary, isFalse);
      expect(result.content, 'hello');
      expect(result.encoding, isNull);
    });

    test('parses a binary response', () {
      final result = FileContent.parse({
        'type': 'binary',
        'content': 'aGVsbG8=',
        'encoding': 'base64',
        'mimeType': 'image/png',
      });
      expect(result.isBinary, isTrue);
      expect(result.encoding, 'base64');
      expect(result.mimeType, 'image/png');
    });

    test('defaults to text when type is missing', () {
      final result = FileContent.parse({'content': 'abc'});
      expect(result.isBinary, isFalse);
      expect(result.content, 'abc');
    });

    test('handles a raw string body', () {
      final result = FileContent.parse('plain text');
      expect(result.isBinary, isFalse);
      expect(result.content, 'plain text');
    });

    test('handles empty body', () {
      final result = FileContent.parse(null);
      expect(result.isBinary, isFalse);
      expect(result.content, isEmpty);
    });
  });
}
