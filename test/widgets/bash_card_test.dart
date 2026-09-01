import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/api/models/message.dart';
import 'package:opencode_app/pages/home/widgets/tool_cards/bash_card.dart';

Part _bashPart({
  required String status,
  String command = 'echo hi',
  String output = '',
}) {
  return Part(
    id: 'p1',
    sessionID: 's1',
    messageID: 'm1',
    type: PartType.tool,
    raw: {
      'id': 'p1',
      'sessionID': 's1',
      'messageID': 'm1',
      'type': 'tool',
      'tool': 'bash',
      'state': {
        'status': status,
        'input': <String, dynamic>{'command': command},
        if (output.isNotEmpty) 'output': output,
      },
    },
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('BashCard trailing spinner', () {
    testWidgets('shows spinner while running and streaming', (tester) async {
      await tester.pumpWidget(
        _wrap(BashCard(part: _bashPart(status: 'running'), isStreaming: true)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('hides spinner for a stale running part in history', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BashCard(part: _bashPart(status: 'running'), isStreaming: false)),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('hides spinner after completion', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BashCard(
            part: _bashPart(status: 'completed', output: 'done'),
            isStreaming: false,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('hides spinner for pending parts not streaming', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BashCard(part: _bashPart(status: 'pending'), isStreaming: false)),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
