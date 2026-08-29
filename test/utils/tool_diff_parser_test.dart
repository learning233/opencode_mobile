import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/api/models/message.dart';
import 'package:opencode_app/api/models/tool_diff_parser.dart';

Part _toolPart(Map<String, dynamic> input, Map<String, dynamic> metadata) {
  return Part(
    id: 'p1',
    sessionID: 's1',
    messageID: 'm1',
    type: PartType.tool,
    raw: {
      'id': 'p1',
      'type': 'tool',
      'tool': 'apply_patch',
      'state': {'status': 'completed', 'input': input, 'metadata': metadata},
    },
  );
}

void main() {
  group('ToolDiffParser', () {
    test('apply_patch prefers absolute filePath over relativePath', () {
      final part = _toolPart(const {}, const {
        'files': [
          {
            'filePath': '/project/src/a.ts',
            'relativePath': 'src/a.ts',
            'type': 'update',
            'additions': 2,
            'deletions': 1,
            'patch': '',
          },
        ],
      });
      final diffs = ToolDiffParser.parse(part);
      expect(diffs, hasLength(1));
      expect(diffs.single.file, '/project/src/a.ts');
      expect(diffs.single.additions, 2);
      expect(diffs.single.deletions, 1);
    });

    test('fallback to relativePath when filePath is absent', () {
      final part = _toolPart(const {}, const {
        'files': [
          {
            'relativePath': 'src/b.ts',
            'type': 'update',
            'additions': 0,
            'deletions': 0,
            'patch': '',
          },
        ],
      });
      final diffs = ToolDiffParser.parse(part);
      expect(diffs, hasLength(1));
      expect(diffs.single.file, 'src/b.ts');
    });

    test('---/+++ file headers are not counted, ---x/+++x content is', () {
      final patch = [
        '--- a/src/c.ts',
        '+++ b/src/c.ts',
        '@@ -1,5 +1,5 @@',
        ' context',
        '---removed',
        '+++added',
        '-gone',
        '+kept',
      ].join('\n');
      final part = _toolPart(const {}, {
        'files': [
          {
            'filePath': '/project/src/c.ts',
            'relativePath': 'src/c.ts',
            'type': 'update',
            'additions': 0,
            'deletions': 0,
            'patch': patch,
          },
        ],
      });
      final diffs = ToolDiffParser.parse(part);
      expect(diffs, hasLength(1));
      // +++added + +kept = 2; ---removed + -gone = 2 (headers excluded).
      expect(diffs.single.additions, 2);
      expect(diffs.single.deletions, 2);
    });

    test('malformed toolInput does not throw', () {
      final part = Part(
        id: 'p2',
        sessionID: 's1',
        messageID: 'm2',
        type: PartType.tool,
        raw: {
          'id': 'p2',
          'type': 'tool',
          'tool': 'edit',
          'state': {'status': 'completed', 'input': 'not-a-map'},
        },
      );
      expect(part.toolInput, isEmpty);
      expect(ToolDiffParser.parse(part), isEmpty);
    });
  });
}
