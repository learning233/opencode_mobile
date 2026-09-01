import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/utils/diff_render.dart';
import 'package:opencode_app/pages/tablet/diff_view.dart';

DiffLine _line(DiffLineType type, String text, {int? oldNum, int? newNum}) =>
    DiffLine(type, text, oldLineNum: oldNum, newLineNum: newNum);

void main() {
  group('buildDiffRenderLines', () {
    final lines = [
      _line(DiffLineType.unchanged, 'ctx', oldNum: 1, newNum: 1),
      _line(DiffLineType.added, 'plus', newNum: 2),
      _line(DiffLineType.removed, 'minus', oldNum: 2),
    ];

    test('added lines get "+ " prefix and new-line number', () {
      final r = buildDiffRenderLines(lines, hideContextLines: false);
      final added = r[1];
      expect(added.type, DiffLineType.added);
      expect(added.displayText, '+ plus');
      expect(added.numberText, '2');
      expect(added.text, 'plus');
    });

    test('removed lines get "- " prefix and old-line number', () {
      final r = buildDiffRenderLines(lines, hideContextLines: false);
      final removed = r[2];
      expect(removed.displayText, '- minus');
      expect(removed.numberText, '2');
    });

    test('unchanged lines get two-space prefix and new-line number', () {
      final r = buildDiffRenderLines(lines, hideContextLines: false);
      final unchanged = r[0];
      expect(unchanged.displayText, '  ctx');
      expect(unchanged.numberText, '1');
    });

    test('sourceIndex tracks the original list position', () {
      final r = buildDiffRenderLines(lines, hideContextLines: false);
      expect(r.map((e) => e.sourceIndex).toList(), [0, 1, 2]);
    });

    test('hideContextLines drops unchanged lines but keeps sourceIndex', () {
      final r = buildDiffRenderLines(lines, hideContextLines: true);
      expect(r.length, 2);
      expect(r[0].type, DiffLineType.added);
      expect(r[0].sourceIndex, 1);
      expect(r[1].type, DiffLineType.removed);
      expect(r[1].sourceIndex, 2);
    });

    test('empty input yields empty output', () {
      expect(buildDiffRenderLines(const [], hideContextLines: false), isEmpty);
    });

    test('empty line numbers render as empty gutter text', () {
      final r = buildDiffRenderLines([
        _line(DiffLineType.added, 'x'),
      ], hideContextLines: false);
      expect(r.single.numberText, isEmpty);
    });
  });

  group('estimateDiffHeight', () {
    test(
      'scales with line count, font size and line height, plus safety margin',
      () {
        expect(estimateDiffHeight(10), closeTo(10 * 12 * 1.3 + 8 + 2, 0.01));
      },
    );

    test('allows custom font metrics', () {
      expect(
        estimateDiffHeight(
          5,
          fontSize: 14,
          fontHeight: 1.5,
          verticalPadding: 10,
        ),
        closeTo(5 * 14 * 1.5 + 10 + 2, 0.01),
      );
    });
  });
}
