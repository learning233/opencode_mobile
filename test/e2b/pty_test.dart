import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/e2b/e2b.dart';

void main() {
  group(
    'PTY Subsystem Tests (Replicated from ptyCreate.test.ts / resize.test.ts)',
    () {
      test('PtySize toJson matches Connect-RPC schema', () {
        const size = PtySize(cols: 120, rows: 40);
        final json = size.toJson();

        expect(json['cols'], equals(120));
        expect(json['rows'], equals(40));
      });

      test('PtyOpts default values', () {
        const opts = PtyOpts();
        expect(opts.size.cols, equals(80));
        expect(opts.size.rows, equals(24));
        expect(opts.cwd, isNull);
        expect(opts.envs.isEmpty, isTrue);
        expect(opts.onData, isNull);
      });

      test('PtyHandle methods routing', () async {
        bool inputSent = false;
        bool resized = false;
        bool killed = false;

        final handle = PtyHandle(
          pid: 8888,
          inputSender: (data) async {
            inputSent = true;
          },
          resizer: (size) async {
            resized = true;
          },
          killer: () async {
            killed = true;
          },
        );

        expect(handle.pid, equals(8888));

        await handle.sendInput(Uint8List.fromList([0x03])); // Ctrl+C
        expect(inputSent, isTrue);

        await handle.resize(const PtySize(cols: 100, rows: 30));
        expect(resized, isTrue);

        await handle.kill();
        expect(killed, isTrue);
      });
    },
  );
}
