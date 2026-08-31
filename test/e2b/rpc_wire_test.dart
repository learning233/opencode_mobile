import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/e2b/e2b.dart';
import '../helpers/fake_http_adapter.dart';

void main() {
  group('ConnectTransport wire protocol (mock envd)', () {
    test('serverStreamCall sends enveloped frame body with connect+json',
        () async {
      final adapter = FakeHttpAdapter((options, body) async {
        return ResponseBody(
          Stream.fromIterable([
            framedEvents([
              {
                'event': {'start': {'pid': 123}},
              },
            ]),
          ]),
          200,
          headers: {
            'content-type': ['application/connect+json'],
          },
        );
      });
      final dio = Dio()..httpClientAdapter = adapter;
      const config = ConnectionConfig(apiKey: 'k', envdAccessToken: 'tok');
      final transport = ConnectTransport(config: config, dio: dio);

      await transport.serverStreamCall(
        sandboxId: 'sbx-1',
        path: '/process.Process/Start',
        request: {'process': {'cmd': 'echo'}},
      ).drain<void>();

      final req = adapter.requests.single;
      expect(req.header('Content-Type'), 'application/connect+json');
      expect(req.header('X-Access-Token'), 'tok');
      expect(req.header('E2b-Sandbox-Id'), 'sbx-1');

      // 请求体必须是信封帧而非裸 JSON
      expect(req.body.length, greaterThan(5));
      expect(req.body[0], 0x00);
      final len = (req.body[1] << 24) |
          (req.body[2] << 16) |
          (req.body[3] << 8) |
          req.body[4];
      expect(len, req.body.length - 5);
      final decoded = jsonDecode(utf8.decode(req.body.sublist(5)));
      expect(decoded['process']['cmd'], 'echo');
    });

    test('serverStreamCall decodes frames split across chunks', () async {
      final full = framedEvents([
        {
          'event': {'start': {'pid': 7}},
        },
        {
          'event': {'end': {'exit_code': 0}},
        },
      ]);
      final adapter = FakeHttpAdapter((options, body) async {
        // 从帧中间切开,模拟 TCP 分片
        final splitAt = 7;
        return ResponseBody(
          Stream.fromIterable([
            Uint8List.fromList(full.sublist(0, splitAt)),
            Uint8List.fromList(full.sublist(splitAt)),
          ]),
          200,
        );
      });
      final dio = Dio()..httpClientAdapter = adapter;
      const config = ConnectionConfig(apiKey: 'k');
      final transport = ConnectTransport(config: config, dio: dio);

      final frames = await transport.serverStreamCall(
        sandboxId: 'sbx-1',
        path: '/process.Process/Start',
        request: {'x': 1},
      ).toList();

      final events = frames
          .map((f) => f.jsonMap)
          .whereType<Map<String, dynamic>>()
          .where((m) => m.containsKey('event'))
          .toList();
      expect(events.length, 2);
      expect((events[0]['event'] as Map)['start']['pid'], 7);
      expect((events[1]['event'] as Map)['end']['exit_code'], 0);
    });

    test('unaryCall sends plain JSON and parses response', () async {
      final adapter = FakeHttpAdapter((options, body) async {
        return ResponseBody.fromString('{"pid": 42}', 200);
      });
      final dio = Dio()..httpClientAdapter = adapter;
      const config = ConnectionConfig(apiKey: 'k', envdAccessToken: 'tok');
      final transport = ConnectTransport(config: config, dio: dio);

      final res = await transport.unaryCall(
        sandboxId: 'sbx-1',
        path: '/process.Process/List',
        request: {},
      );

      expect(res['pid'], 42);
      final req = adapter.requests.single;
      expect(req.header('Content-Type'), 'application/json');
      // Unary 请求体是裸 JSON,无信封帧
      expect(utf8.decode(req.body), '{}');
    });

    test('unaryCall maps 401 to authentication exception', () async {
      final adapter = FakeHttpAdapter((options, body) async {
        return ResponseBody.fromString('unauthorized', 401);
      });
      final dio = Dio()..httpClientAdapter = adapter;
      const config = ConnectionConfig(apiKey: 'k');
      final transport = ConnectTransport(config: config, dio: dio);

      await expectLater(
        transport.unaryCall(
          sandboxId: 'sbx-1',
          path: '/process.Process/List',
          request: {},
        ),
        throwsA(isA<SandboxAuthenticationException>()),
      );
    });
  });

  group('Commands.start over mock envd', () {
    Commands buildCommands(FakeHttpAdapter adapter) {
      final dio = Dio()..httpClientAdapter = adapter;
      const config = ConnectionConfig(apiKey: 'k', envdAccessToken: 'tok');
      final transport = ConnectTransport(config: config, dio: dio);
      return Commands(sandboxId: 'sbx-1', transport: transport);
    }

    test('parses start/data/end events and decodes utf8 stdout', () async {
      final adapter = FakeHttpAdapter((options, body) async {
        return ResponseBody(
          Stream.fromIterable([
            framedEvents([
              {
                'event': {'start': {'pid': 123}},
              },
              {
                'event': {
                  'data': {
                    'stdout':
                        base64Encode(utf8.encode('hello 世界')),
                  },
                },
              },
              {
                'event': {'end': {'exit_code': 0, 'exited': true}},
              },
            ]),
          ]),
          200,
        );
      });
      final commands = buildCommands(adapter);

      String? captured;
      final result = await commands.run(
        'echo hi',
        opts: CommandOpts(
          timeoutMs: 30000,
          onStdout: (s) => captured = s,
        ),
      );

      expect(result.exitCode, 0);
      expect(result.isSuccess, isTrue);
      expect(result.stdout, 'hello 世界');
      expect(captured, 'hello 世界');

      final req = adapter.requests
          .firstWhere((r) => r.options.uri.path.contains('Process/Start'));
      final payload = jsonDecode(utf8.decode(req.body.sublist(5)));
      expect(payload['process']['args'][0], '-l');
      expect(payload['process']['args'][1], '-c');
      expect(payload['process']['args'][2], 'echo hi');
      expect(payload['stdin'], false);
    });

    test('accepts camelCase exitCode in end event', () async {
      final adapter = FakeHttpAdapter((options, body) async {
        return ResponseBody(
          Stream.fromIterable([
            framedEvents([
              {
                'event': {'start': {'pid': 9}},
              },
              {
                'event': {'end': {'exitCode': 3}},
              },
            ]),
          ]),
          200,
        );
      });
      final commands = buildCommands(adapter);

      final handle = await commands.start('exit 3');
      final result = await handle.wait();

      expect(result.exitCode, 3);
      expect(result.isSuccess, isFalse);
    });

    test('background detaches right after start event', () async {
      final controller = StreamController<Uint8List>();
      addTearDown(() => controller.close());

      final adapter = FakeHttpAdapter((options, body) async {
        // 流保持打开,模拟长驻进程
        return ResponseBody(controller.stream, 200);
      });
      final commands = buildCommands(adapter);

      controller.add(ConnectTransportFrameHelper.encode({
        'event': {'start': {'pid': 77}},
      }));

      final sw = DateTime.now();
      final handle = await commands.start(
        'sleep infinity',
        opts: const CommandOpts(background: true),
      );
      expect(handle.pid, 77);

      final result = await handle.wait();
      expect(result.exitCode, 0);
      expect(DateTime.now().difference(sw).inSeconds, lessThan(10));
    });

    test('foreground run enforces timeoutMs', () async {
      final controller = StreamController<Uint8List>();
      addTearDown(() => controller.close());

      final adapter = FakeHttpAdapter((options, body) async {
        // 不发送任何事件也永不结束,模拟挂起的长命令
        return ResponseBody(controller.stream, 200);
      });
      final commands = buildCommands(adapter);

      final handle = await commands.start(
        'sleep infinity',
        opts: const CommandOpts(timeoutMs: 100),
      );
      final result = await handle.wait();

      expect(result.exitCode, -1);
      expect(result.error, contains('超时'));
    });
  });

  group('Sandbox.connect over mock control plane', () {
    test('calls POST /sandboxes/{id}/connect and returns fresh token',
        () async {
      final adapter = FakeHttpAdapter((options, body) async {
        expect(options.method, 'POST');
        expect(options.uri.path, contains('/sandboxes/sbx-9/connect'));
        final req = jsonDecode(utf8.decode(body));
        expect(req['timeout'], 600);
        return ResponseBody.fromString(
          jsonEncode({
            'sandboxID': 'sbx-9',
            'templateID': 'opencode',
            'envdAccessToken': 'fresh-tok',
            'domain': 'e2b.app',
          }),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        );
      });
      final dio = Dio()..httpClientAdapter = adapter;

      final sandbox = await Sandbox.connect(
        SandboxConnectOpts(
          sandboxId: 'sbx-9',
          apiKey: 'k',
          timeout: 600,
          envdAccessToken: 'stale-tok',
        ),
        dio: dio,
      );

      expect(sandbox.sandboxId, 'sbx-9');
      expect(sandbox.envdAccessToken, 'fresh-tok');
      expect(sandbox.connectionConfig.envdAccessToken, 'fresh-tok');
      expect(
        sandbox.connectionConfig.getSandboxEnvdUrl('sbx-9'),
        'https://49983-sbx-9.e2b.app',
      );
    });

    test('404 maps to SandboxNotFoundException', () async {
      final adapter = FakeHttpAdapter((options, body) async {
        return ResponseBody.fromString('not found', 404);
      });
      final dio = Dio()..httpClientAdapter = adapter;

      await expectLater(
        Sandbox.connect(
          const SandboxConnectOpts(sandboxId: 'sbx-gone', apiKey: 'k'),
          dio: dio,
        ),
        throwsA(isA<SandboxNotFoundException>()),
      );
    });

    test('empty apiKey fails fast', () async {
      await expectLater(
        Sandbox.connect(
          const SandboxConnectOpts(sandboxId: 'sbx-1'),
          dio: Dio(),
        ),
        throwsA(isA<SandboxAuthenticationException>()),
      );
    });
  });
}
