import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:opencode_app/api/endpoints.dart';
import 'package:opencode_app/api/opencode_client.dart';
import 'package:opencode_app/controllers/session_controller.dart';
import 'package:opencode_app/init.dart';
import 'package:opencode_app/models/model_info.dart';
import 'package:opencode_app/utils/app_logger.dart';
import 'package:opencode_app/utils/app_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionController ctrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Global.settings = AppSettingsStore(prefs);

    await AppLogger.init(logDir: Directory.systemTemp.createTempSync().path);

    OpenCodeClient().dio.interceptors.clear();

    ctrl = SessionController();
  });

  final modelVision1 = ModelInfo(
    id: 'gpt-4o',
    name: 'GPT-4o',
    providerId: 'openai',
    supportsImage: true,
  );

  final modelVision2 = ModelInfo(
    id: 'claude-3-5-sonnet',
    name: 'Claude 3.5 Sonnet',
    providerId: 'anthropic',
    supportsImage: true,
  );

  final modelTextOnly = ModelInfo(
    id: 'deepseek-chat',
    name: 'DeepSeek Chat',
    providerId: 'deepseek',
    supportsImage: false,
  );

  final testImage = (
    bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    mime: 'image/png',
    ext: 'png',
  );

  group('Vision Model Selection & Properties', () {
    test('returns false when no models support image', () {
      ctrl.availableModels.assignAll([modelTextOnly]);

      expect(ctrl.hasVisionModel, isFalse);
      expect(ctrl.visionModelName, isEmpty);
    });

    test('picks the first vision model when no preference is configured', () {
      ctrl.availableModels.assignAll([modelTextOnly, modelVision1, modelVision2]);

      expect(ctrl.hasVisionModel, isTrue);
      expect(ctrl.visionModelName, 'GPT-4o');
    });

    test('respects configured visionModelKey (matching key)', () async {
      ctrl.availableModels.assignAll([modelVision1, modelVision2]);

      await ctrl.setVisionModel('anthropic:claude-3-5-sonnet');

      expect(ctrl.visionModelKey, 'anthropic:claude-3-5-sonnet');
      expect(ctrl.hasVisionModel, isTrue);
      expect(ctrl.visionModelName, 'Claude 3.5 Sonnet');
    });

    test('respects configured visionModelKey (matching id)', () async {
      ctrl.availableModels.assignAll([modelVision1, modelVision2]);

      await ctrl.setVisionModel('claude-3-5-sonnet');

      expect(ctrl.hasVisionModel, isTrue);
      expect(ctrl.visionModelName, 'Claude 3.5 Sonnet');
    });

    test('falls back to default model if configured model is not found', () async {
      ctrl.availableModels.assignAll([modelVision1]);

      await ctrl.setVisionModel('non-existent:model');

      // 找不到配置的模型时，应回落到 availableModels 里第一个支持识图的模型
      expect(ctrl.hasVisionModel, isTrue);
      expect(ctrl.visionModelName, 'GPT-4o');
    });
  });

  group('describeImagesToText - Precondition Checks', () {
    test('returns null immediately when image list is empty without HTTP calls', () async {
      ctrl.availableModels.assignAll([modelVision1]);

      var requestMade = false;
      OpenCodeClient().dio.httpClientAdapter = FakeHttpAdapter((options, body) async {
        requestMade = true;
        return ResponseBody.fromString('{}', 200);
      });

      final result = await ctrl.describeImagesToText([], prompt: 'Describe');

      expect(result, isNull);
      expect(requestMade, isFalse);
    });

    test('returns null immediately when no vision model is available without HTTP calls', () async {
      ctrl.availableModels.assignAll([modelTextOnly]);

      var requestMade = false;
      OpenCodeClient().dio.httpClientAdapter = FakeHttpAdapter((options, body) async {
        requestMade = true;
        return ResponseBody.fromString('{}', 200);
      });

      final result = await ctrl.describeImagesToText([testImage], prompt: 'Describe');

      expect(result, isNull);
      expect(requestMade, isFalse);
    });
  });

  group('describeImagesToText - Polling Fallback Flow', () {
    test('happy path: creates session, sends prompt, polls completed message, deletes session', () async {
      ctrl.availableModels.assignAll([modelVision1]);

      const tempSessionId = 'ses_vision_123';
      final requests = <CapturedRequest>[];

      OpenCodeClient().dio.httpClientAdapter = FakeHttpAdapter((options, body) async {
        requests.add(CapturedRequest(options, body));
        final path = options.path;

        // 1. 创建临时会话
        if (options.method == 'POST' && path == ApiEndpoints.sessions) {
          return ResponseBody.fromString(
            jsonEncode({'id': tempSessionId, 'title': 'Temporary Vision'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        // 2. 发送异步 Prompt
        if (options.method == 'POST' && path == ApiEndpoints.sessionPromptAsync(tempSessionId)) {
          return ResponseBody.fromString(
            jsonEncode({'status': 'ok'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        // 3. 轮询消息 (带 time.completed)
        if (options.method == 'GET' && path == ApiEndpoints.sessionMessages(tempSessionId)) {
          final messages = [
            {
              'id': 'msg_user_1',
              'sessionID': tempSessionId,
              'role': 'user',
              'parts': [
                {'id': 'prt_1', 'type': 'text', 'text': 'Describe image'},
              ],
            },
            {
              'id': 'msg_assistant_1',
              'sessionID': tempSessionId,
              'role': 'assistant',
              'content': 'A fluffy white cat sitting on a keyboard.',
              'parts': [
                {
                  'id': 'prt_2',
                  'type': 'text',
                  'text': 'A fluffy white cat sitting on a keyboard.',
                },
              ],
              'info': {
                'time': {
                  'completed': 1725450000000,
                },
              },
            },
          ];
          return ResponseBody.fromString(
            jsonEncode(messages),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        // 4. 删除临时会话
        if (options.method == 'DELETE' && path == ApiEndpoints.sessionDelete(tempSessionId)) {
          return ResponseBody.fromString(
            jsonEncode({'status': 'ok'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        return ResponseBody.fromString('Not Found', 404);
      });

      final result = await ctrl.describeImagesToText(
        [testImage],
        prompt: 'Describe image',
      );

      // 验证返回结果
      expect(result, 'A fluffy white cat sitting on a keyboard.');

      // 验证临时会话未泄露到主列表
      expect(ctrl.sessions.any((s) => s.id == tempSessionId), isFalse);

      // 验证调用的接口顺序
      final methods = requests.map((r) => '${r.options.method} ${r.options.path}').toList();
      expect(methods, contains('POST ${ApiEndpoints.sessions}'));
      expect(methods, contains('POST ${ApiEndpoints.sessionPromptAsync(tempSessionId)}'));
      expect(methods, contains('GET ${ApiEndpoints.sessionMessages(tempSessionId)}'));
      expect(methods, contains('DELETE ${ApiEndpoints.sessionDelete(tempSessionId)}'));

      // 验证 Prompt 请求体格式
      final promptReq = requests.firstWhere(
        (r) => r.options.path == ApiEndpoints.sessionPromptAsync(tempSessionId),
      );
      final promptBody = jsonDecode(utf8.decode(promptReq.body)) as Map<String, dynamic>;
      expect(promptBody['agent'], 'plan');
      expect(promptBody['model'], {'providerID': 'openai', 'modelID': 'gpt-4o'});
      final parts = promptBody['parts'] as List;
      expect(parts.length, 2); // 1 text + 1 image
      expect(parts[0]['text'], 'Describe image');
      expect(parts[1]['type'], 'file');
      expect(parts[1]['mime'], 'image/png');
      expect((parts[1]['url'] as String).startsWith('data:image/png;base64,'), isTrue);
    });

    test('polling: returns text when 4 consecutive polls return identical non-completed text', () async {
      ctrl.availableModels.assignAll([modelVision1]);
      const tempSessionId = 'ses_vision_stable';
      var pollCount = 0;

      OpenCodeClient().dio.httpClientAdapter = FakeHttpAdapter((options, body) async {
        final path = options.path;

        if (options.method == 'POST' && path == ApiEndpoints.sessions) {
          return ResponseBody.fromString(
            jsonEncode({'id': tempSessionId}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        if (options.method == 'POST' && path == ApiEndpoints.sessionPromptAsync(tempSessionId)) {
          return ResponseBody.fromString(jsonEncode({'status': 'ok'}), 200);
        }

        if (options.method == 'GET' && path == ApiEndpoints.sessionMessages(tempSessionId)) {
          pollCount++;
          // 不带 time.completed，纯靠连续 4 次一致检测完成
          final messages = [
            {
              'id': 'msg_asst',
              'role': 'assistant',
              'content': 'Stable text description',
              'parts': [
                {'id': 'prt_text', 'type': 'text', 'text': 'Stable text description'},
              ],
            },
          ];
          return ResponseBody.fromString(
            jsonEncode(messages),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        if (options.method == 'DELETE' && path == ApiEndpoints.sessionDelete(tempSessionId)) {
          return ResponseBody.fromString(jsonEncode({'status': 'ok'}), 200);
        }

        return ResponseBody.fromString('Not Found', 404);
      });

      final result = await ctrl.describeImagesToText(
        [testImage],
        prompt: 'Describe image',
      );

      expect(result, 'Stable text description');
      expect(pollCount, greaterThanOrEqualTo(4));
    });
  });

  group('describeImagesToText - Error Handling & Resource Cleanup', () {
    test('returns null when session creation returns 500 error', () async {
      ctrl.availableModels.assignAll([modelVision1]);

      OpenCodeClient().dio.httpClientAdapter = FakeHttpAdapter((options, body) async {
        if (options.path == ApiEndpoints.sessions) {
          return ResponseBody.fromString('Internal Server Error', 500);
        }
        return ResponseBody.fromString('Not Found', 404);
      });

      final result = await ctrl.describeImagesToText([testImage], prompt: 'Test');
      expect(result, isNull);
    });

    test('cleans up temporary session when prompt async fails with 500', () async {
      ctrl.availableModels.assignAll([modelVision1]);
      const tempSessionId = 'ses_vision_prompt_err';
      var deleteCalled = false;

      OpenCodeClient().dio.httpClientAdapter = FakeHttpAdapter((options, body) async {
        if (options.method == 'POST' && options.path == ApiEndpoints.sessions) {
          return ResponseBody.fromString(
            jsonEncode({'id': tempSessionId}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        if (options.path == ApiEndpoints.sessionPromptAsync(tempSessionId)) {
          return ResponseBody.fromString('Prompt Failed', 500);
        }

        if (options.method == 'DELETE' && options.path == ApiEndpoints.sessionDelete(tempSessionId)) {
          deleteCalled = true;
          return ResponseBody.fromString(jsonEncode({'status': 'ok'}), 200);
        }

        return ResponseBody.fromString('Not Found', 404);
      });

      final result = await ctrl.describeImagesToText([testImage], prompt: 'Test');

      expect(result, isNull);
      // 即使 prompt 失败，finally 块也必须清理创建的临时会话
      expect(deleteCalled, isTrue);
    });

    test('does not throw unhandled exception if DELETE cleanup fails', () async {
      ctrl.availableModels.assignAll([modelVision1]);
      const tempSessionId = 'ses_vision_del_fail';

      OpenCodeClient().dio.httpClientAdapter = FakeHttpAdapter((options, body) async {
        if (options.method == 'POST' && options.path == ApiEndpoints.sessions) {
          return ResponseBody.fromString(
            jsonEncode({'id': tempSessionId}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        if (options.path == ApiEndpoints.sessionPromptAsync(tempSessionId)) {
          return ResponseBody.fromString(
            jsonEncode({'status': 'ok'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        if (options.path == ApiEndpoints.sessionMessages(tempSessionId)) {
          final messages = [
            {
              'id': 'msg_asst',
              'role': 'assistant',
              'content': 'Successful description',
              'parts': [
                {'id': 'p', 'type': 'text', 'text': 'Successful description'},
              ],
              'info': {'time': {'completed': 123}},
            },
          ];
          return ResponseBody.fromString(
            jsonEncode(messages),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        // DELETE 报错
        if (options.method == 'DELETE' && options.path == ApiEndpoints.sessionDelete(tempSessionId)) {
          return ResponseBody.fromString('Delete Failed', 500);
        }

        return ResponseBody.fromString('Not Found', 404);
      });

      // 验证 DELETE 失败时不会向外抛异常，依然正常返回结果
      final result = await ctrl.describeImagesToText([testImage], prompt: 'Test');
      expect(result, 'Successful description');
    });

    test('multiple images: sends all images as separate parts with correct filenames and mime', () async {
      ctrl.availableModels.assignAll([modelVision1]);
      const tempSessionId = 'ses_multi_img';
      CapturedRequest? capturedPromptReq;

      final testJpg = (
        bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        mime: 'image/jpeg',
        ext: 'jpg',
      );

      OpenCodeClient().dio.httpClientAdapter = FakeHttpAdapter((options, body) async {
        if (options.method == 'POST' && options.path == ApiEndpoints.sessions) {
          return ResponseBody.fromString(
            jsonEncode({'id': tempSessionId}),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        if (options.path == ApiEndpoints.sessionPromptAsync(tempSessionId)) {
          capturedPromptReq = CapturedRequest(options, body);
          return ResponseBody.fromString(jsonEncode({'status': 'ok'}), 200);
        }
        if (options.path == ApiEndpoints.sessionMessages(tempSessionId)) {
          return ResponseBody.fromString(
            jsonEncode([
              {
                'id': 'msg_asst',
                'role': 'assistant',
                'content': 'Two images described',
                'parts': [
                  {'id': 'p', 'type': 'text', 'text': 'Two images described'},
                ],
                'info': {'time': {'completed': 1}},
              },
            ]),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        if (options.method == 'DELETE') {
          return ResponseBody.fromString(jsonEncode({'status': 'ok'}), 200);
        }
        return ResponseBody.fromString('Not Found', 404);
      });

      final result = await ctrl.describeImagesToText(
        [testImage, testJpg],
        prompt: 'Compare two images',
      );

      expect(result, 'Two images described');
      expect(capturedPromptReq, isNotNull);
      final bodyMap = jsonDecode(utf8.decode(capturedPromptReq!.body)) as Map<String, dynamic>;
      final parts = bodyMap['parts'] as List;
      // 1 text + 2 images
      expect(parts.length, 3);
      expect(parts[0]['text'], 'Compare two images');
      expect(parts[1]['filename'], 'image_1.png');
      expect(parts[1]['mime'], 'image/png');
      expect(parts[2]['filename'], 'image_2.jpg');
      expect(parts[2]['mime'], 'image/jpeg');
    });

    test('ignores empty assistant messages and reasoning parts, extracting final content', () async {
      ctrl.availableModels.assignAll([modelVision1]);
      const tempSessionId = 'ses_parts_filter';

      OpenCodeClient().dio.httpClientAdapter = FakeHttpAdapter((options, body) async {
        if (options.method == 'POST' && options.path == ApiEndpoints.sessions) {
          return ResponseBody.fromString(
            jsonEncode({'id': tempSessionId}),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        if (options.path == ApiEndpoints.sessionPromptAsync(tempSessionId)) {
          return ResponseBody.fromString(jsonEncode({'status': 'ok'}), 200);
        }
        if (options.path == ApiEndpoints.sessionMessages(tempSessionId)) {
          return ResponseBody.fromString(
            jsonEncode([
              // 空助手消息 (流式刚启动)
              {'id': 'm0', 'role': 'assistant', 'parts': []},
              // 包含 reasoning + text
              {
                'id': 'm1',
                'role': 'assistant',
                'parts': [
                  {'id': 'p_r', 'type': 'reasoning', 'text': 'Thinking about the image...'},
                  {'id': 'p_t', 'type': 'text', 'text': 'The final OCR text extracted.'},
                ],
                'info': {'time': {'completed': 999}},
              },
            ]),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        if (options.method == 'DELETE') {
          return ResponseBody.fromString(jsonEncode({'status': 'ok'}), 200);
        }
        return ResponseBody.fromString('Not Found', 404);
      });

      final result = await ctrl.describeImagesToText([testImage], prompt: 'OCR');
      expect(result, 'The final OCR text extracted.');
    });
  });
}
