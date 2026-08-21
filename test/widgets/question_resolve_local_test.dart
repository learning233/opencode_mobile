import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/api/models/message.dart';
import 'package:opencode_app/widgets/message/tool_cards/question_card.dart';

Part _questionPart({
  String id = 'p1',
  String callID = 'call_1',
  String sessionID = 's1',
}) => Part(
      id: id,
      sessionID: sessionID,
      messageID: 'm1',
      type: PartType.tool,
      raw: {
        'id': id,
        'sessionID': sessionID,
        'messageID': 'm1',
        'type': 'tool',
        if (callID.isNotEmpty) 'callID': callID,
      },
    );

void main() {
  group('resolveQuestionIDLocal', () {
    String? cache(String callId, {String? sessionId}) => null;

    test('prefers a que_-prefixed part id', () {
      final part = _questionPart(id: 'que_abc', callID: 'call_1');
      expect(resolveQuestionIDLocal(part, cache), 'que_abc');
    });

    test('prefers a que_-prefixed callID when id is not que_', () {
      final part = _questionPart(id: 'p1', callID: 'que_abc');
      expect(resolveQuestionIDLocal(part, cache), 'que_abc');
    });

    test('returns the cached questionID for a plain callID', () {
      final part = _questionPart(callID: 'call_1');
      final lookup = (String callId, {String? sessionId}) =>
          callId == 'call_1' ? 'que_xyz' : null;
      expect(resolveQuestionIDLocal(part, lookup), 'que_xyz');
    });

    test('returns null when neither id/callID nor cache resolves', () {
      final part = _questionPart(callID: 'call_1');
      expect(resolveQuestionIDLocal(part, cache), isNull);
    });

    test('returns null when cache returns an empty string', () {
      final part = _questionPart(callID: 'call_1');
      final lookup = (String callId, {String? sessionId}) => '';
      expect(resolveQuestionIDLocal(part, lookup), isNull);
    });

    test('passes the part sessionID to the lookup', () {
      final part = _questionPart(callID: 'call_1', sessionID: 's9');
      String? sessionSeen;
      final lookup = (String callId, {String? sessionId}) {
        sessionSeen = sessionId;
        return 'que_xyz';
      };
      expect(resolveQuestionIDLocal(part, lookup), 'que_xyz');
      expect(sessionSeen, 's9');
    });
  });
}
