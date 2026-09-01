import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/services/e2b/e2b.dart';
import 'package:opencode_app/services/e2b_workspace_service.dart';

/// 模拟 Dio HTTP 客户端 Adapter，用于拦截并检验请求参数与模拟服务器响应
class MockDioAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  ResponseBody Function(RequestOptions options)? handler;

  MockDioAdapter({this.handler});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (handler != null) {
      return handler!(options);
    }
    return ResponseBody.fromString(
      jsonEncode({'sandboxID': 'sbx_test', 'templateID': 'opencode'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('E2B Timeout Dynamic Fallback Tests', () {
    test(
      'sanitizeTimeoutSeconds allows 600s to 86400s (up to 24h for Pro)',
      () {
        // 0 hours -> min clamp 600s
        expect(E2bWorkspaceService.sanitizeTimeoutSeconds(0), equals(600));
        // 1 hour -> 3600s
        expect(E2bWorkspaceService.sanitizeTimeoutSeconds(1), equals(3600));
        // 2 hours -> 7200s (Pro tier support)
        expect(E2bWorkspaceService.sanitizeTimeoutSeconds(2), equals(7200));
        // 24 hours -> 86400s (Max Pro duration)
        expect(E2bWorkspaceService.sanitizeTimeoutSeconds(24), equals(86400));
        // >24 hours -> max clamp 86400s
        expect(E2bWorkspaceService.sanitizeTimeoutSeconds(48), equals(86400));
      },
    );

    test(
      'Sandbox.create retries with 3600s when 400 timeout error is returned',
      () async {
        int requestCount = 0;
        final mockAdapter = MockDioAdapter(
          handler: (options) {
            requestCount++;
            final body = options.data is Map ? options.data as Map : {};
            final requestedTimeout = body['timeout'];

            if (requestCount == 1) {
              expect(requestedTimeout, equals(7200));
              // First attempt with 2h (7200s) rejected by Hobby plan limit
              return ResponseBody.fromString(
                jsonEncode({
                  'message': 'HTTP 400: Timeout cannot be greater than 1 hours',
                }),
                400,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            } else {
              // Second attempt automatically degraded to 3600s
              expect(requestedTimeout, equals(3600));
              return ResponseBody.fromString(
                jsonEncode({
                  'sandboxID': 'sbx_fallback_123',
                  'templateID': 'opencode',
                }),
                201,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            }
          },
        );

        final dio = Dio()..httpClientAdapter = mockAdapter;

        final sandbox = await Sandbox.create(
          opts: const SandboxCreateOpts(
            apiKey: 'e2b_test_key',
            template: 'opencode',
            timeout: 7200, // User requested 2 hours
          ),
          dio: dio,
        );

        expect(requestCount, equals(2));
        expect(sandbox.sandboxId, equals('sbx_fallback_123'));
      },
    );

    test(
      'Sandbox.create succeeds on first try for Pro users (no fallback needed)',
      () async {
        int requestCount = 0;
        final mockAdapter = MockDioAdapter(
          handler: (options) {
            requestCount++;
            final body = options.data is Map ? options.data as Map : {};
            expect(body['timeout'], equals(14400)); // 4 hours for Pro account
            return ResponseBody.fromString(
              jsonEncode({
                'sandboxID': 'sbx_pro_456',
                'templateID': 'opencode',
              }),
              201,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          },
        );

        final dio = Dio()..httpClientAdapter = mockAdapter;

        final sandbox = await Sandbox.create(
          opts: const SandboxCreateOpts(
            apiKey: 'e2b_pro_key',
            template: 'opencode',
            timeout: 14400,
          ),
          dio: dio,
        );

        expect(requestCount, equals(1));
        expect(sandbox.sandboxId, equals('sbx_pro_456'));
      },
    );

    test(
      'Sandbox.connect retries with 3600s when 400 timeout is returned',
      () async {
        int requestCount = 0;
        final mockAdapter = MockDioAdapter(
          handler: (options) {
            requestCount++;
            final body = options.data is Map ? options.data as Map : {};
            final requestedTimeout = body['timeout'];

            if (requestCount == 1) {
              expect(requestedTimeout, equals(7200));
              return ResponseBody.fromString(
                jsonEncode({
                  'message': 'HTTP 400: Timeout cannot be greater than 1 hours',
                }),
                400,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            } else {
              expect(requestedTimeout, equals(3600));
              return ResponseBody.fromString(
                jsonEncode({
                  'sandboxID': 'sbx_connect_789',
                  'templateID': 'opencode',
                }),
                200,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            }
          },
        );

        final dio = Dio()..httpClientAdapter = mockAdapter;

        final sandbox = await Sandbox.connect(
          const SandboxConnectOpts(
            sandboxId: 'sbx_connect_789',
            apiKey: 'e2b_test_key',
            timeout: 7200,
          ),
          dio: dio,
        );

        expect(requestCount, equals(2));
        expect(sandbox.sandboxId, equals('sbx_connect_789'));
      },
    );

    test(
      'Sandbox.setTimeout retries with 3600s when 400 timeout is returned',
      () async {
        int requestCount = 0;
        final mockAdapter = MockDioAdapter(
          handler: (options) {
            requestCount++;
            final body = options.data is Map ? options.data as Map : {};
            final requestedTimeout = body['timeout'];

            if (requestCount == 1) {
              expect(requestedTimeout, equals(7200));
              return ResponseBody.fromString(
                jsonEncode({
                  'message': 'HTTP 400: Timeout cannot be greater than 1 hours',
                }),
                400,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            } else {
              expect(requestedTimeout, equals(3600));
              return ResponseBody.fromString(
                jsonEncode({'success': true}),
                200,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            }
          },
        );

        final dio = Dio()..httpClientAdapter = mockAdapter;

        await Sandbox.setTimeout(
          'sbx_keepalive_999',
          apiKey: 'e2b_test_key',
          timeoutSeconds: 7200,
          dio: dio,
        );

        expect(requestCount, equals(2));
      },
    );
  });
}
