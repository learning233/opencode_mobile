import '../pages/tablet/diff_view.dart';

/// 单行 diff 的渲染描述：文本 + 前缀 + 行号栏文本 + 源索引。
///
/// 由 [buildDiffRenderLines] 生成，喂给 re_editor 虚拟化渲染。
class DiffRenderLine {
  final DiffLineType type;

  /// 无前缀的原文内容。
  final String text;

  /// 带前缀的展示文本（`+ ` / `- ` / `  `）。
  final String displayText;

  /// 行号栏显示的文本（新增/未变取新行号，删除取旧行号；缺失为空）。
  final String numberText;

  /// 在原始（未过滤）diff 行列表中的下标，用于变更块跳转映射。
  final int sourceIndex;

  const DiffRenderLine({
    required this.type,
    required this.text,
    required this.displayText,
    required this.numberText,
    required this.sourceIndex,
  });
}

/// 把 [lines] 转换成带前缀与行号的渲染行。
///
/// [hideContextLines] 为 true 时过滤未变更行（保留 [DiffRenderLine.sourceIndex]，
/// 供变更块在过滤后仍能定位到原始行）。
List<DiffRenderLine> buildDiffRenderLines(
  List<DiffLine> lines, {
  required bool hideContextLines,
}) {
  final result = <DiffRenderLine>[];
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (hideContextLines && l.type == DiffLineType.unchanged) continue;

    final String prefix;
    final String numberText;
    switch (l.type) {
      case DiffLineType.added:
        prefix = '+ ';
        numberText = l.newLineNum?.toString() ?? '';
      case DiffLineType.removed:
        prefix = '- ';
        numberText = l.oldLineNum?.toString() ?? '';
      case DiffLineType.unchanged:
        prefix = '  ';
        numberText = l.newLineNum?.toString() ?? '';
    }

    result.add(
      DiffRenderLine(
        type: l.type,
        text: l.text,
        displayText: '$prefix${l.text}',
        numberText: numberText,
        sourceIndex: i,
      ),
    );
  }
  return result;
}

/// 估算渲染行高（px），用于弹窗内限制 diff 编辑器高度。
///
/// 额外加 2px 安全余量，避免"内容恰好等于上限"时因亚像素差异误出滚动条。
double estimateDiffHeight(
  int lineCount, {
  double fontSize = 12,
  double fontHeight = 1.3,
  double verticalPadding = 8,
}) {
  return lineCount * (fontSize * fontHeight) + verticalPadding + 2;
}
