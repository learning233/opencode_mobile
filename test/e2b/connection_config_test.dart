import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/services/e2b.dart';

void main() {
  group(
    'ConnectionConfig Tests (Replicated from connectionConfig.test.ts)',
    () {
      test('Default domain and URLs', () {
        const config = ConnectionConfig(apiKey: 'test-api-key');

        expect(config.domain, equals('e2b.app'));
        expect(config.apiUrl, equals('https://api.e2b.app'));
        expect(config.sandboxUrl, isNull);
      });

      test('Custom domain overrides API URL', () {
        const config = ConnectionConfig(
          apiKey: 'test-api-key',
          domain: 'custom.domain.com',
        );

        expect(config.domain, equals('custom.domain.com'));
        expect(config.apiUrl, equals('https://api.custom.domain.com'));
      });

      test('getHost constructs {port}-{sandboxId}.{domain}', () {
        const config = ConnectionConfig(apiKey: 'key', domain: 'e2b.dev');
        final host = config.getHost('sbx-9988', 3000);

        expect(host, equals('3000-sbx-9988.e2b.dev'));
      });

      test('getHostUrl constructs https://{port}-{sandboxId}.{domain}', () {
        const config = ConnectionConfig(apiKey: 'key', domain: 'e2b.app');
        final url = config.getHostUrl('sbx-1234', 4096);

        expect(url, equals('https://4096-sbx-1234.e2b.app'));
      });

      test(
        'getSandboxEnvdUrl routes by direct domain ({port}-{sandboxId})',
        () {
          const config = ConnectionConfig(apiKey: 'key');
          final envdUrl = config.getSandboxEnvdUrl('sbx-xyz');

          expect(envdUrl, equals('https://49983-sbx-xyz.e2b.app'));
        },
      );

      test('getSandboxEnvdUrl honors custom port', () {
        const config = ConnectionConfig(apiKey: 'key');
        final envdUrl = config.getSandboxEnvdUrl('sbx-xyz', port: 49982);

        expect(envdUrl, equals('https://49982-sbx-xyz.e2b.app'));
      });

      test(
        'getSandboxEnvdUrl uses explicit sandboxUrl override when provided',
        () {
          const config = ConnectionConfig(
            apiKey: 'key',
            sandboxUrl: 'https://my-proxy.example.com/',
          );
          final envdUrl = config.getSandboxEnvdUrl('sbx-xyz');

          expect(envdUrl, equals('https://my-proxy.example.com'));
        },
      );

      test('getEnvdHeaders (unary) uses application/json Content-Type', () {
        const config = ConnectionConfig(
          apiKey: 'e2b_5678',
          envdAccessToken: 'envd_token_abc',
        );

        final headers = config.getEnvdHeaders(
          sandboxId: 'sbx-test',
          port: 49983,
        );

        expect(headers['Connect-Protocol-Version'], equals('1'));
        expect(headers['Content-Type'], equals('application/json'));
        expect(headers['E2b-Sandbox-Id'], equals('sbx-test'));
        expect(headers['E2b-Sandbox-Port'], equals('49983'));
        expect(headers['X-Access-Token'], equals('envd_token_abc'));
        expect(headers['X-API-Key'], equals('e2b_5678'));
        expect(headers.containsKey('Keepalive-Ping-Interval'), isFalse);
      });

      test(
        'getEnvdHeaders (streaming) uses connect+json with ping interval',
        () {
          const config = ConnectionConfig(
            apiKey: 'e2b_5678',
            envdAccessToken: 'envd_token_abc',
          );

          final headers = config.getEnvdHeaders(
            sandboxId: 'sbx-test',
            port: 49983,
            streaming: true,
          );

          expect(headers['Content-Type'], equals('application/connect+json'));
          expect(headers['Keepalive-Ping-Interval'], equals('50'));
          expect(headers['X-Access-Token'], equals('envd_token_abc'));
        },
      );

      test('getApiHeaders includes JSON Content-Type and X-API-Key', () {
        const config = ConnectionConfig(apiKey: 'my_secret_api_key');
        final headers = config.getApiHeaders();

        expect(headers['Content-Type'], equals('application/json'));
        expect(headers['X-API-Key'], equals('my_secret_api_key'));
      });
    },
  );
}
