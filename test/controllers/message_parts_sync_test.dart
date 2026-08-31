import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/api/models/message.dart';
import 'package:opencode_app/controllers/session_controller.dart';

void main() {
  test('messageWithSyncedParts round-trips current parts into legacy raw', () {
    final original = MessageModel.fromJson({
      'id': 'msg1',
      'sessionID': 's1',
      'role': 'assistant',
      'parts': [
        {'id': 'p1', 'type': 'text', 'text': 'first-delta'},
      ],
    });
    // 流式 finalize 后的解析态：文本已完整，但 original.raw 仍停留旧内容。
    final streamed = Part(
      id: 'p1',
      sessionID: 's1',
      messageID: 'msg1',
      type: PartType.text,
      raw: {
        'id': 'p1',
        'type': 'text',
        'text': 'full streamed text',
      },
    );

    final synced = SessionController.messageWithSyncedParts(original, [streamed]);

    // raw 副本持有当前 parts，原 raw 不被污染。
    expect(identical(synced.raw, original.raw), isFalse);
    expect((original.raw['parts'] as List).single['text'], 'first-delta');
    expect((synced.raw['parts'] as List).single, same(streamed.raw));

    // 缓存读取侧按 raw 重建，与内存解析态一致。
    final reparsed = MessageModel.fromJson(synced.raw);
    expect(reparsed.id, 'msg1');
    expect(reparsed.role, MessageRole.assistant);
    expect(reparsed.parts.single.text, 'full streamed text');
  });

  test('messageWithSyncedParts writes the v2 info.content shape', () {
    final original = MessageModel.fromJson({
      'id': 'msg2',
      'info': {
        'id': 'msg2',
        'type': 'assistant',
        'content': [
          {'id': 'p1', 'type': 'text', 'text': 'old'},
        ],
      },
    });
    final streamed = Part(
      id: 'p1',
      sessionID: 's1',
      messageID: 'msg2',
      type: PartType.text,
      raw: {
        'id': 'p1',
        'type': 'text',
        'text': 'v2 full text',
      },
    );

    final synced = SessionController.messageWithSyncedParts(original, [streamed]);
    final info = synced.raw['info'] as Map;
    expect((info['content'] as List).single, same(streamed.raw));

    final reparsed = MessageModel.fromJson(synced.raw);
    expect(reparsed.parts.single.text, 'v2 full text');
  });

  test('messageWithSyncedParts fills identity keys for shell messages', () {
    // _upsertPartInState 的合成消息：raw 只有 role，id 只在模型字段上。
    final shell = MessageModel(
      id: 'msg3',
      sessionID: 's3',
      role: MessageRole.assistant,
      parts: [],
      raw: {'role': 'assistant'},
    );
    final part = Part(
      id: 'p1',
      sessionID: 's3',
      messageID: 'msg3',
      type: PartType.tool,
      raw: {
        'id': 'p1',
        'type': 'tool',
        'state': {'status': 'running'},
      },
    );

    final synced = SessionController.messageWithSyncedParts(shell, [part]);
    expect(synced.raw['id'], 'msg3');
    expect(synced.raw['sessionID'], 's3');
    expect((synced.raw['parts'] as List).single, same(part.raw));

    final reparsed = MessageModel.fromJson(synced.raw);
    expect(reparsed.id, 'msg3');
    expect(reparsed.parts.single.id, 'p1');
    expect(reparsed.parts.single.toolStatus, ToolStateStatus.running);
  });
}
