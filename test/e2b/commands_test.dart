import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/services/e2b.dart';

void main() {
  group(
    'Commands Models Tests (Replicated from commandHandle.test.ts / run.test.ts)',
    () {
      test('CommandResult isSuccess is true only when exitCode is 0', () {
        const success = CommandResult(
          exitCode: 0,
          stdout: 'Process finished',
          stderr: '',
        );
        expect(success.isSuccess, isTrue);

        const fail = CommandResult(
          exitCode: 127,
          stdout: '',
          stderr: 'command not found',
        );
        expect(fail.isSuccess, isFalse);
      });

      test('CommandExitException contains exitCode and output details', () {
        const ex = CommandExitException(
          exitCode: 1,
          stdout: 'partial stdout',
          stderr: 'fatal error: disk full',
        );

        expect(ex.exitCode, equals(1));
        expect(ex.stdout, equals('partial stdout'));
        expect(ex.stderr, equals('fatal error: disk full'));
        expect(ex.toString().contains('disk full'), isTrue);
      });

      test('CommandOpts has sensible defaults', () {
        const opts = CommandOpts();
        expect(opts.background, isFalse);
        expect(opts.cwd, isNull);
        expect(opts.envs.isEmpty, isTrue);
        expect(opts.stdin, isFalse);
        expect(opts.timeoutMs, equals(60000));

        const customOpts = CommandOpts(stdin: true);
        expect(customOpts.stdin, isTrue);
      });

      test('ProcessInfo.fromJson parses envd Process.List response correctly', () {
        final json = {
          'pid': 1234,
          'tag': 'opencode-serve',
          'config': {
            'cmd': '/bin/bash',
            'args': ['-c', 'opencode serve'],
            'envs': {'PORT': '4096'},
            'cwd': '/home/user/workspace',
          },
        };

        final info = ProcessInfo.fromJson(json);
        expect(info.pid, equals(1234));
        expect(info.tag, equals('opencode-serve'));
        expect(info.cmd, equals('/bin/bash'));
        expect(info.args, equals(['-c', 'opencode serve']));
        expect(info.envs, equals({'PORT': '4096'}));
        expect(info.cwd, equals('/home/user/workspace'));
      });

      test('CommandHandle lifecycle wiring', () async {
        bool killCalled = false;
        bool stdinSent = false;
        bool stdinClosed = false;

        final handle = CommandHandle(
          pid: 4567,
          waiter: () async =>
              const CommandResult(exitCode: 0, stdout: 'done', stderr: ''),
          killer: () async {
            killCalled = true;
          },
          stdinSender: (data) async {
            stdinSent = true;
          },
          stdinCloser: () async {
            stdinClosed = true;
          },
        );

        expect(handle.pid, equals(4567));

        final res = await handle.wait();
        expect(res.exitCode, equals(0));
        expect(res.stdout, equals('done'));

        await handle.sendStdin('input_text\n');
        expect(stdinSent, isTrue);

        await handle.closeStdin();
        expect(stdinClosed, isTrue);

        await handle.kill();
        expect(killCalled, isTrue);
      });
    },
  );
}
