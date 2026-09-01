import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/services/e2b.dart';

void main() {
  group(
    'Sandbox Lifecycle Models Tests (Replicated from create.test.ts / kill.test.ts)',
    () {
      test('SandboxCreateOpts defaults', () {
        const opts = SandboxCreateOpts(
          apiKey: 'e2b_live_key',
          template: 'opencode',
        );

        expect(opts.template, equals('opencode'));
        expect(opts.timeout, equals(300));
        expect(opts.autoPause, isTrue);
        expect(opts.domain, equals('e2b.app'));
      });

      test('SandboxConnectOpts model fields', () {
        const opts = SandboxConnectOpts(
          sandboxId: 'sbx-active-99',
          apiKey: 'api_key_1',
          envdAccessToken: 'token_2',
        );

        expect(opts.sandboxId, equals('sbx-active-99'));
        expect(opts.apiKey, equals('api_key_1'));
        expect(opts.envdAccessToken, equals('token_2'));
      });

      test('SandboxListOpts pagination parameters', () {
        const opts = SandboxListOpts(
          states: ['running', 'paused'],
          limit: 20,
          nextToken: 'cursor_xyz',
        );

        expect(opts.states, equals(['running', 'paused']));
        expect(opts.limit, equals(20));
        expect(opts.nextToken, equals('cursor_xyz'));
      });
    },
  );
}
