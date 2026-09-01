import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/diff_render.dart';
import 'diff_view.dart';

/// 基于 re_editor 的只读 diff 行渲染。
///
/// 用 CodeEditor 的行虚拟化替代 `SingleChildScrollView + IntrinsicWidth + Column`：
/// - 只构建可见行（大 diff 不再全量建 widget）；
/// - 横向滚动长行（`wordWrap: false`）由编辑器原生处理；
/// - 增/删行用「前缀 + 整行前景色」表达（方案 A）。
///
/// [maxHeight] 非空时把自身限制在 `min(内容高, maxHeight)`（弹窗内用，保证虚拟化
/// 生效）；为 null 时填充父容器约束（平板 Review 面板用）。
class DiffCodeView extends StatefulWidget {
  final List<DiffLine> lines;
  final bool hideContextLines;
  final bool showLineNumbers;
  final double? maxHeight;

  const DiffCodeView({
    super.key,
    required this.lines,
    this.hideContextLines = false,
    this.showLineNumbers = true,
    this.maxHeight,
  });

  @override
  State<DiffCodeView> createState() => DiffCodeViewState();
}

class DiffCodeViewState extends State<DiffCodeView> {
  static const double _fontSize = 12;
  static const double _fontHeight = 1.3;

  CodeLineEditingController? _controller;
  CodeScrollController? _scrollController;
  List<DiffRenderLine> _render = const [];
  List<List<int>> _blocks = const [];

  /// 上次内容签名。可空哨兵：首次必算（非空 int 签名与 null 恒不等），
  /// 避免 `Object.hash` 恰好算出初始值 -1 时首帧被当作「内容未变」跳过、
  /// controller 保持 null 导致整块 diff 永久空白。
  int? _lastSig;

  /// diff 行号（oldLineNum/newLineNum）的最大位数，用于固定行号栏宽度，
  /// 避免单位数涨到两位数/多位数时行号被裁剪或代码横向跳动。
  int _maxNumberDigits = 1;

  /// 变更块数量（基于原始未过滤行计算，切换 [DiffCodeView.hideContextLines] 时保持稳定）。
  int get changeBlockCount => _blocks.length;

  @override
  void initState() {
    super.initState();
    _scrollController = CodeScrollController();
    _update();
  }

  @override
  void didUpdateWidget(DiffCodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines != widget.lines ||
        oldWidget.hideContextLines != widget.hideContextLines) {
      _update();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  void _update() {
    final newRender = buildDiffRenderLines(
      widget.lines,
      hideContextLines: widget.hideContextLines,
    );
    final newBlocks = computeChangeBlocks(widget.lines);

    // 内容签名：相同内容（如 Review 每次 setState 重建）不重设 codeLines，
    // 避免编辑器整体重渲染造成闪烁。
    var sig = 0;
    var maxDigits = 1;
    for (final l in newRender) {
      sig = Object.hash(
        sig,
        l.type,
        l.displayText,
        l.numberText,
        l.sourceIndex,
      );
      final n = l.numberText.length;
      if (n > maxDigits) maxDigits = n;
    }
    sig = Object.hash(sig, newBlocks.length);
    if (sig == _lastSig) return;
    _lastSig = sig;

    _render = newRender;
    _blocks = newBlocks;
    _maxNumberDigits = maxDigits;

    final codeLines = CodeLines.of([
      for (final l in _render) CodeLine(l.displayText),
    ]);
    final c = _controller;
    if (c == null) {
      _controller = CodeLineEditingController(
        codeLines: codeLines,
        spanBuilder: _spanBuilder,
      );
    } else {
      c.codeLines = codeLines;
    }
  }

  /// 滚动到第 [index] 个变更块（使其可见/居中）。
  void jumpToChange(int index) {
    if (index < 0 || index >= _blocks.length) return;
    final block = _blocks[index];
    int? target;
    for (var i = 0; i < _render.length; i++) {
      final s = _render[i].sourceIndex;
      if (s >= block[0] && s <= block[1]) {
        target = i;
        break;
      }
    }
    if (target == null) return;
    _scrollController?.makeCenterIfInvisible(
      CodeLinePosition(index: target, offset: 0),
    );
  }

  TextSpan _spanBuilder({
    required BuildContext context,
    required int index,
    required CodeLine codeLine,
    required TextSpan textSpan,
    required TextStyle style,
  }) {
    if (index < 0 || index >= _render.length) return textSpan;
    final type = _render[index].type;
    Color? color;
    if (type == DiffLineType.added) {
      color = context.appColors.success;
    } else if (type == DiffLineType.removed) {
      color = Theme.of(context).colorScheme.error;
    }
    if (color == null) return textSpan;
    final newStyle = (textSpan.style ?? style).copyWith(color: color);
    return TextSpan(
      text: textSpan.text,
      children: textSpan.children,
      style: newStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final editor = CodeEditor(
      controller: controller,
      scrollController: _scrollController,
      readOnly: true,
      showCursorWhenReadOnly: false,
      wordWrap: false,
      autofocus: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      style: CodeEditorStyle(
        fontSize: _fontSize,
        fontFamily: 'monospace',
        fontHeight: _fontHeight,
        textColor: theme.colorScheme.onSurface,
        backgroundColor: Colors.transparent,
      ),
      indicatorBuilder: widget.showLineNumbers
          ? (context, editingController, chunkController, notifier) {
              return Padding(
                // 行号栏不从编辑器左缘开始（编辑器 padding 只作用于代码区），
                // 给左侧留出内边距，避免行号顶到屏幕/卡片边缘。
                padding: const EdgeInsets.only(left: 8),
                child: DefaultCodeLineNumber(
                  controller: editingController,
                  notifier: notifier,
                  minNumberCount: _maxNumberDigits,
                  textStyle: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.45,
                    ),
                  ),
                  // 只读编辑器无选区时 focusedIndex 恒为 0（首行），把聚焦样式
                  // 设成与普通行号一致，避免第一行行号被渲染成正文色（黑色）。
                  focusedTextStyle: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.45,
                    ),
                  ),
                  customLineIndex2Text: (i) =>
                      i >= 0 && i < _render.length ? _render[i].numberText : '',
                ),
              );
            }
          : null,
    );

    final maxHeight = widget.maxHeight;
    if (maxHeight == null) return editor;
    final contentHeight = estimateDiffHeight(
      _render.length,
      fontSize: _fontSize,
      fontHeight: _fontHeight,
    );
    final height = math.min(contentHeight, maxHeight).toDouble();
    return SizedBox(height: height, child: editor);
  }
}
