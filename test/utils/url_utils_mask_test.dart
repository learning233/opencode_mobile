import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/utils/url_utils.dart';

void main() {
  group('maskIpsInText', () {
    test('masks IPv4 in plain text', () {
      expect(
        maskIpsInText('target at 192.168.1.100 unreachable'),
        'target at *92.*68.*.*00 unreachable',
      );
    });

    test('masks IPv4 embedded in a full URL', () {
      expect(
        maskIpsInText('DioException: uri http://192.168.1.100:4096/api/health'),
        'DioException: uri http://*92.*68.*.*00:4096/api/health',
      );
    });

    test('masks multiple IPs', () {
      expect(
        maskIpsInText('a=10.0.0.1 b=172.16.0.2'),
        'a=*0.*.*.* b=*72.*6.*.*',
      );
    });

    test('keeps localhost and domain names intact', () {
      expect(
        maskIpsInText('http://localhost:4096 and https://example.com/path'),
        'http://localhost:4096 and https://example.com/path',
      );
    });

    test('does not touch text without IPs', () {
      const s = 'some random text 42.17 nothing';
      expect(maskIpsInText(s), s);
    });
  });

  group('maskUrl', () {
    test('masks IPv4 host', () {
      expect(
        maskUrl('http://192.168.1.100:4096'),
        'http://*92.*68.*.*00:4096',
      );
    });

    test('keeps domain and localhost unchanged', () {
      expect(maskUrl('https://example.com:3000'), 'https://example.com:3000');
      expect(maskUrl('http://localhost:8080'), 'http://localhost:8080');
    });

    test('returns input unchanged when unparseable', () {
      const bad = 'not a url at all';
      expect(maskUrl(bad), bad);
    });
  });
}
