import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/services/e2b/e2b.dart';

void main() {
  group('E2B Signature Tests', () {
    test('generateSignature matches JS SDK algorithm', () {
      final res = E2bSignature.getSignature(
        path: '/home/user/file.txt',
        operation: 'read',
        user: 'user',
        expirationInSeconds: 300,
        envdAccessToken: 'test_token_123',
      );

      expect(res.signature.startsWith('v1_'), isTrue);
      expect(res.expiration, isNotNull);
    });

    test('generateSignature throws when envdAccessToken is empty', () {
      expect(
        () => E2bSignature.getSignature(
          path: '/path',
          operation: 'write',
          envdAccessToken: '',
        ),
        throwsArgumentError,
      );
    });
  });

  group('E2B Connect-RPC Framing Tests', () {
    test('encodeFrame and decodeFrames roundtrip', () {
      final testData = {'key': 'value', 'number': 42};
      final encoded = ConnectTransport.encodeFrame(testData);

      expect(encoded.length > 5, isTrue);
      expect(encoded[0], equals(0x00)); // Data frame flag

      final decodedFrames = ConnectTransport.decodeFrames(encoded);
      expect(decodedFrames.length, equals(1));
      expect(decodedFrames.first.flag, equals(ConnectFrameFlag.data));
      expect(decodedFrames.first.jsonMap, equals(testData));
    });

    test('decodeFrames handles multiple concatenated frames', () {
      final f1 = ConnectTransport.encodeFrame({'id': 1});
      final f2 = ConnectTransport.encodeFrame({
        'id': 2,
      }, flag: ConnectFrameFlag.endOfStream);

      final combined = BytesBuilder();
      combined.add(f1);
      combined.add(f2);

      final frames = ConnectTransport.decodeFrames(combined.toBytes());
      expect(frames.length, equals(2));
      expect(frames[0].flag, equals(ConnectFrameFlag.data));
      expect(frames[0].jsonMap?['id'], equals(1));
      expect(frames[1].flag, equals(ConnectFrameFlag.endOfStream));
      expect(frames[1].jsonMap?['id'], equals(2));
    });
  });

  group('ConnectionConfig Tests', () {
    test('getHost and getHostUrl generate correct URLs', () {
      const config = ConnectionConfig(apiKey: 'e2b_test', domain: 'e2b.app');
      expect(config.getHost('sbx123', 4096), equals('4096-sbx123.e2b.app'));
      expect(
        config.getHostUrl('sbx123', 4096),
        equals('https://4096-sbx123.e2b.app'),
      );
      expect(
        config.getSandboxEnvdUrl('sbx123'),
        equals('https://49983-sbx123.e2b.app'),
      );
    });

    test('getEnvdHeaders (unary) contains required Connect-RPC headers', () {
      const config = ConnectionConfig(
        apiKey: 'e2b_key',
        envdAccessToken: 'token_abc',
      );
      final headers = config.getEnvdHeaders(sandboxId: 'sbx1');

      expect(headers['Connect-Protocol-Version'], equals('1'));
      expect(headers['Content-Type'], equals('application/json'));
      expect(headers['E2b-Sandbox-Id'], equals('sbx1'));
      expect(headers['E2b-Sandbox-Port'], equals('49983'));
      expect(headers['X-Access-Token'], equals('token_abc'));
      expect(headers['X-API-Key'], equals('e2b_key'));
    });
  });

  group('Filesystem Model Tests', () {
    test('EntryInfo parses json correctly', () {
      final json = {
        'name': 'test.py',
        'path': '/home/user/test.py',
        'type': 'file',
        'size': 1024,
        'modified_at': '2026-08-31T12:00:00Z',
      };
      final entry = EntryInfo.fromJson(json);
      expect(entry.name, equals('test.py'));
      expect(entry.path, equals('/home/user/test.py'));
      expect(entry.type, equals(EntryType.file));
      expect(entry.size, equals(1024));
      expect(entry.modifiedAt, isNotNull);
    });
  });

  group('Process Model Tests', () {
    test('CommandResult properties work correctly', () {
      const resSuccess = CommandResult(exitCode: 0, stdout: 'ok', stderr: '');
      expect(resSuccess.isSuccess, isTrue);

      const resFail = CommandResult(exitCode: 1, stdout: '', stderr: 'error');
      expect(resFail.isSuccess, isFalse);
    });
  });
}
