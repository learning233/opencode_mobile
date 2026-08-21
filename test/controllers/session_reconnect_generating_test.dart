import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/api/models/message.dart';
import 'package:opencode_app/controllers/session_controller.dart';

MessageModel _assistantMsg(List<Part> parts) =>
    MessageModel(id: 'm1', role: MessageRole.assistant, parts: parts);

Part _textPart(String id) => Part(
      id: id,
      sessionID: 's',
      messageID: 'm1',
      type: PartType.text,
      raw: {'id': id, 'type': 'text', 'text': 'hi'},
    );

Part _stepFinish(String id) => Part(
      id: id,
      sessionID: 's',
      messageID: 'm1',
      type: PartType.stepFinish,
      raw: {'id': id, 'type': 'step-finish'},
    );

Part _tool(String id, String status) => Part(
      id: id,
      sessionID: 's',
      messageID: 'm1',
      type: PartType.tool,
      raw: {
        'id': id,
        'type': 'tool',
        'state': {'status': status},
      },
    );

void main() {
  group('turnAppearsFinished', () {
    test('wasAborted always counts as finished', () {
      expect(
        SessionController.turnAppearsFinished(
          messages: const [],
          wasAborted: true,
        ),
        isTrue,
      );
      expect(
        SessionController.turnAppearsFinished(
          messages: [_assistantMsg([_textPart('p1')])],
          wasAborted: true,
        ),
        isTrue,
      );
    });

    test('no assistant message means not finished', () {
      final user = MessageModel(
        id: 'm0',
        role: MessageRole.user,
        parts: [_textPart('p0')],
      );
      expect(
        SessionController.turnAppearsFinished(
          messages: [user],
          wasAborted: false,
        ),
        isFalse,
      );
      expect(
        SessionController.turnAppearsFinished(
          messages: const [],
          wasAborted: false,
        ),
        isFalse,
      );
    });

    test('last assistant message ending with stepFinish is finished', () {
      final msgs = [
        MessageModel(
          id: 'm0',
          role: MessageRole.user,
          parts: [_textPart('p0')],
        ),
        _assistantMsg([_textPart('p1'), _stepFinish('p2')]),
      ];
      expect(
        SessionController.turnAppearsFinished(
          messages: msgs,
          wasAborted: false,
        ),
        isTrue,
      );
    });

    test('completed tool followed by stepFinish is finished', () {
      final msgs = [_assistantMsg([_tool('p1', 'completed'), _stepFinish('p2')])];
      expect(
        SessionController.turnAppearsFinished(
          messages: msgs,
          wasAborted: false,
        ),
        isTrue,
      );
    });

    test('running tool means still generating', () {
      final msgs = [_assistantMsg([_tool('p1', 'running')])];
      expect(
        SessionController.turnAppearsFinished(
          messages: msgs,
          wasAborted: false,
        ),
        isFalse,
      );
    });

    test('pending tool means still generating', () {
      final msgs = [_assistantMsg([_tool('p1', 'pending')])];
      expect(
        SessionController.turnAppearsFinished(
          messages: msgs,
          wasAborted: false,
        ),
        isFalse,
      );
    });

    test('mid-stream text without stepFinish is not finished', () {
      final msgs = [_assistantMsg([_textPart('p1')])];
      expect(
        SessionController.turnAppearsFinished(
          messages: msgs,
          wasAborted: false,
        ),
        isFalse,
      );
    });

    test('finished text plus a later running tool is not finished', () {
      final msgs = [
        _assistantMsg([_textPart('p1'), _stepFinish('p2'), _tool('p3', 'running')]),
      ];
      expect(
        SessionController.turnAppearsFinished(
          messages: msgs,
          wasAborted: false,
        ),
        isFalse,
      );
    });
  });
}
