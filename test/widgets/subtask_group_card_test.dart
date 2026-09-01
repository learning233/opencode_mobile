import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/api/models/message.dart';
import 'package:opencode_app/pages/home/widgets/message/tool_cards/subtask_group_card.dart';

Part _part({required String id, required PartType type, String tool = ''}) {
  return Part(
    id: id,
    sessionID: 's1',
    messageID: 'm1',
    type: type,
    raw: {
      'id': id,
      'sessionID': 's1',
      'messageID': 'm1',
      'type': type.name,
      if (tool.isNotEmpty) 'tool': tool,
      if (type == PartType.tool)
        'state': {'status': 'completed', 'input': <String, dynamic>{}},
    },
  );
}

void main() {
  group('SubtaskGroupCard.findChildren', () {
    test('collects parts until next task/subtask boundary', () {
      final header = _part(id: 't1', type: PartType.tool, tool: 'task');
      final read = _part(id: 'r1', type: PartType.tool, tool: 'read');
      final text = _part(id: 'x1', type: PartType.text);
      final next = _part(id: 't2', type: PartType.tool, tool: 'task');
      final after = _part(id: 'r2', type: PartType.tool, tool: 'bash');

      final children = SubtaskGroupCard.findChildren(header, [
        header,
        read,
        text,
        next,
        after,
      ]);

      expect(children.map((p) => p.id), ['r1', 'x1']);
    });

    test('stops at PartType.subtask', () {
      final header = _part(id: 't1', type: PartType.tool, tool: 'task');
      final read = _part(id: 'r1', type: PartType.tool, tool: 'read');
      final sub = _part(id: 's1', type: PartType.subtask);

      final children = SubtaskGroupCard.findChildren(header, [
        header,
        read,
        sub,
      ]);

      expect(children.map((p) => p.id), ['r1']);
    });

    test('returns empty when header is last', () {
      final header = _part(id: 't1', type: PartType.tool, tool: 'task');
      expect(SubtaskGroupCard.findChildren(header, [header]), isEmpty);
    });
  });
}
