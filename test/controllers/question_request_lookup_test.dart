import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/controllers/session_controller.dart';

void main() {
  group('SessionController.questionRequestIDForCallID', () {
    const requests = {
      'que_1': QuestionRequestRef(
        sessionId: 's1',
        messageId: 'm1',
        callId: 'call_1',
      ),
      'que_2': QuestionRequestRef(
        sessionId: 's2',
        messageId: 'm2',
        callId: 'call_2',
      ),
    };

    test('returns null for an empty index', () {
      expect(
        SessionController.questionRequestIDForCallID(const {}, 'call_1'),
        isNull,
      );
    });

    test('returns null for an empty callId', () {
      expect(
        SessionController.questionRequestIDForCallID(requests, ''),
        isNull,
      );
    });

    test('returns null for an unknown callId', () {
      expect(
        SessionController.questionRequestIDForCallID(requests, 'call_x'),
        isNull,
      );
    });

    test('matches a callId without needing a sessionId', () {
      expect(
        SessionController.questionRequestIDForCallID(requests, 'call_1'),
        'que_1',
      );
    });

    test('prefers the same-session entry when callIDs collide', () {
      const mixed = {
        'que_1': QuestionRequestRef(
          sessionId: 's1',
          messageId: 'm1',
          callId: 'shared',
        ),
        'que_2': QuestionRequestRef(
          sessionId: 's2',
          messageId: 'm2',
          callId: 'shared',
        ),
      };
      expect(
        SessionController.questionRequestIDForCallID(
          mixed,
          'shared',
          sessionId: 's2',
        ),
        'que_2',
      );
    });

    test('falls back to a callId match when the session is not in the index',
        () {
      expect(
        SessionController.questionRequestIDForCallID(
          requests,
          'call_1',
          sessionId: 's9',
        ),
        'que_1',
      );
    });

    test('ignores refs with an empty callId', () {
      const withEmpty = {
        'que_x': QuestionRequestRef(
          sessionId: 's1',
          messageId: 'm1',
          callId: '',
        ),
      };
      expect(
        SessionController.questionRequestIDForCallID(withEmpty, 'call_1'),
        isNull,
      );
    });
  });
}
