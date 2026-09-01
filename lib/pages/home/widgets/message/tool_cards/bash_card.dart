import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../utils/translations.dart';
import '../../../../../api/models/message.dart';
import '../../../../../utils/app_theme.dart';
import '../../../../../widgets/detail_bottom_sheet.dart';
import '../../../../../controllers/session_controller.dart';

/// ANSI 转义清洗用的三个模式。E2：提为顶层 final，避免每次调用新建
/// RegExp（stripAnsi 在流式期间对全量输出反复执行）。
final RegExp _ansiCsiRe = RegExp(r'\x1B\[[\x20-\x3F]*[\x20-\x2F]*[\x40-\x7E]');
final RegExp _ansiOscRe = RegExp(r'\x1B\].*?(?:\x07|\x1B\\)');
final RegExp _ansiShortRe = RegExp(r'\x1B.');

String stripAnsi(String text) {
  return text
      .replaceAll(_ansiCsiRe, '')
      .replaceAll(_ansiOscRe, '')
      .replaceAll(_ansiShortRe, '');
}

/// Compact bash header. Full command/output opens in a BottomSheet.
///
/// The sheet body re-looks up the live [Part] by id from the session state
/// (see [_BashSheetBody]) instead of holding a widget-State-owned notifier:
/// streaming replaces part instances wholesale, and the message list may
/// recycle/recreate this widget while the sheet is open — same pattern as the
/// reasoning card.
class BashCard extends StatelessWidget {
  final Part part;
  final bool isStreaming;
  final String? sessionId;

  const BashCard({
    super.key,
    required this.part,
    this.isStreaming = false,
    this.sessionId,
  });

  void _openSheet(BuildContext context) {
    final ctrl = Get.find<SessionController>();
    final sid = sessionId ?? part.sessionID;
    showDetailBottomSheet(
      context: context,
      title: LocaleKeys.cardVisBash.tr,
      bodyBuilder: (ctx) =>
          _BashSheetBody(controller: ctrl, sessionId: sid, fallback: part),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final input = part.toolInput;
    final command = (input['command'] ?? input['cmd'] ?? '') as String;
    final description = input['description'] as String?;
    final output = part.toolOutput;
    final error = part.toolError;
    final status = part.toolStatus;
    final isRunning =
        status == ToolStateStatus.running || status == ToolStateStatus.pending;
    final hasContent =
        output.isNotEmpty || error.isNotEmpty || command.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: appColors.toolCardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: (hasContent || isRunning) ? () => _openSheet(context) : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  (description?.isNotEmpty == true) ? description! : command,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: appColors.bashAccent,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 转圈只在该 tool 真正随会话流式生成时显示；历史/静止中的
              // running/pending（如中断未收尾的旧记录）不再假转圈。
              if (isRunning && isStreaming)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.2),
                )
              else if (hasContent)
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 12,
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.35,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live bash content inside the BottomSheet.
///
/// Same pattern as the reasoning card: streaming replaces the `Part` instance
/// in `state.messages` (never mutates in place), so this re-looks up the
/// current part by id on every change and subscribes to the reactive
/// `messages` list — the sheet stays in sync with the streaming flush instead
/// of holding a one-time snapshot (which would freeze if the source widget's
/// State is recycled while the sheet is open).
class _BashSheetBody extends StatefulWidget {
  final SessionController controller;
  final String sessionId;
  final Part fallback;

  const _BashSheetBody({
    required this.controller,
    required this.sessionId,
    required this.fallback,
  });

  @override
  State<_BashSheetBody> createState() => _BashSheetBodyState();
}

class _BashSheetBodyState extends State<_BashSheetBody> {
  final _scrollController = ScrollController();
  bool _userDisabledFollow = false;
  bool _inProgrammaticScroll = false;

  // E4：stripAnsi 结果缓存（见 _applyStripCache）。
  final _StripMemo _outputMemo = _StripMemo();
  final _StripMemo _errorMemo = _StripMemo();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_inProgrammaticScroll || !_scrollController.hasClients) return;
    final cur = _scrollController.position.pixels;
    final maxExt = _scrollController.position.maxScrollExtent;
    _userDisabledFollow = (maxExt - cur).abs() > 8;
  }

  void _scrollToBottom() {
    if (_userDisabledFollow) return;
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final distance = (pos.maxScrollExtent - pos.pixels).abs();
      if (distance <= 2) return;
      _inProgrammaticScroll = true;
      _scrollController.jumpTo(pos.maxScrollExtent);
      _inProgrammaticScroll = false;
    });
  }

  Part _lookup() {
    final state = widget.controller.sessionRuntimeStates[widget.sessionId];
    if (state == null) return widget.fallback;
    final msgId = widget.fallback.messageID;
    final partId = widget.fallback.id;
    for (final msg in state.messages) {
      if (msgId.isEmpty || msg.id == msgId) {
        for (final p in msg.parts) {
          if (partId.isEmpty || p.id == partId) return p;
        }
        if (msgId.isNotEmpty) break;
      }
    }
    return widget.fallback;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final state = widget.controller.sessionRuntimeStates[widget.sessionId];
    if (state == null) {
      return _content(
        theme,
        appColors: appColors,
        part: widget.fallback,
        output: widget.fallback.toolOutput,
      );
    }
    return Obx(() {
      final part = _lookup();
      // 输出内容订阅 per-part 通道（key `$partId\u0000output`，E1）：工具流式
      // 期间列表不再随输出增长整表替换，弹窗跟随通道 flush 局部重建。通道项
      // 惰性创建、初值取列表当前值（与 _StreamingTextMarkdown 两侧一致约定
      // 相同）；流式时通道由 delta flush / 全量快照对齐持续更新。
      final rx = state.streamingPartText.putIfAbsent(
        '${part.id}\u0000output',
        () => part.toolOutput.obs,
      );
      final output = rx.value;
      // 只在 part 被流式替换后自动跟随底部；打开已完成卡时停在顶部。
      if (part != widget.fallback) _scrollToBottom();
      return _content(theme, appColors: appColors, part: part, output: output);
    });
  }

  Widget _content(
    ThemeData theme, {
    required AppThemeColors appColors,
    required Part part,
    required String output,
  }) {
    final input = part.toolInput;
    final command = (input['command'] ?? input['cmd'] ?? '') as String;
    final error = part.toolError;
    // E4：stripAnsi 按 (part 实例, 输入字符串实例) 缓存——流式期间每次
    // flush 输出都是新字符串、必须重算一次；其余内容未变的重建（状态翻转、
    // 主题/可见性变化等）直接复用上次结果，不再对全量输出重跑 3 遍正则。
    final cleanOutput = _applyStripCache(_outputMemo, part, output);
    final cleanError = _applyStripCache(_errorMemo, part, error);
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (command.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '\$ $command',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appColors.bashAccent,
                height: 1.4,
              ),
            ),
          ),
        if (output.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              cleanOutput,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.85,
                ),
                height: 1.4,
              ),
            ),
          ),
        if (error.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: appColors.errorSoftBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              cleanError,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.colorScheme.error.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ),
        ],
        if (command.isEmpty && output.isEmpty && error.isEmpty)
          Text(
            'No output yet',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
      ],
    );
  }
}

/// E4：单条 stripAnsi 结果的缓存槽（part 实例 + 输入字符串实例 + 结果）。
class _StripMemo {
  Part? part;
  String? from;
  String value = '';
}

String _applyStripCache(_StripMemo memo, Part part, String input) {
  if (memo.part == part && identical(memo.from, input)) return memo.value;
  memo
    ..part = part
    ..from = input
    ..value = stripAnsi(input);
  return memo.value;
}
