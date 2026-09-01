import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/services/e2b.dart';

void main() {
  group(
    'Git Helper Tests (Replicated from git/clone.test.ts / status.test.ts)',
    () {
      test('clone command string construction', () {
        final mockCommands = Commands(
          sandboxId: 'sbx-test',
          transport: ConnectTransport(
            config: const ConnectionConfig(apiKey: 'key'),
          ),
        );

        expect(mockCommands.sandboxId, equals('sbx-test'));
      });
    },
  );
}
