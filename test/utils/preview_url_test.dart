import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/utils/url_utils.dart';

void main() {
  group('buildPreviewUrl', () {
    test('joins server host and port', () {
      expect(
        buildPreviewUrl('http://192.168.1.100:4096', '5173'),
        'http://192.168.1.100:5173',
      );
    });

    test('preserves https scheme and localhost', () {
      expect(
        buildPreviewUrl('https://localhost:4096', '3000'),
        'https://localhost:3000',
      );
    });

    test('defaults to https when server url has no scheme', () {
      expect(
        buildPreviewUrl('192.168.1.100:4096', '8080'),
        'https://192.168.1.100:8080',
      );
    });

    test('returns null for blank port', () {
      expect(buildPreviewUrl('http://localhost:4096', ''), isNull);
      expect(buildPreviewUrl('http://localhost:4096', '   '), isNull);
    });

    test('returns null for non-numeric port', () {
      expect(buildPreviewUrl('http://localhost:4096', 'abc'), isNull);
    });

    test('returns null for out-of-range port', () {
      expect(buildPreviewUrl('http://localhost:4096', '0'), isNull);
      expect(buildPreviewUrl('http://localhost:4096', '65536'), isNull);
      expect(buildPreviewUrl('http://localhost:4096', '-1'), isNull);
    });

    test('returns null for unparseable server url', () {
      expect(buildPreviewUrl('', '5173'), isNull);
      expect(buildPreviewUrl('   ', '5173'), isNull);
    });
  });
}
