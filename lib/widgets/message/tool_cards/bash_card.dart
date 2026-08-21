import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../utils/translations.dart';
import '../../../api/models/message.dart';
import '../../../utils/app_theme.dart';
import '../../detail_bottom_sheet.dart';
import '../../../controllers/session_controller.dart';

String stripAnsi(String text) {
  return text
      .replaceAll(RegExp(r'\x1B\[[\x20-\x3F]*[\x20-\x2F]*[\x40-\x7E]'), '')
      .replaceAll(RegExp(r'\x1B\].*?(?:\x07|\x1B\\)'), '')
      .replaceAll(RegExp(r'\x1B.'), '');
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
      bodyBuilder: (ctx) => _BashSheetBody(
        controller: ctrl,
        sessionId: sid,
        fallback: part,
      ),
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
        onTap: (hasContent || isRunning)
            ? () => _openSheet(context)
            : null,
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
      return _content(theme, appColors: appColors, part: widget.fallback);
    }
    return Obx(
      () {
        final part = _lookup();
        // 只在 part 被流式替换后自动跟随底部；打开已完成卡时停在顶部。
        if (part != widget.fallback) _scrollToBottom();
        return _content(theme, appColors: appColors, part: part);
      },
    );
  }

  Widget _content(
    ThemeData theme, {
    required AppThemeColors appColors,
    required Part part,
  }) {
    final input = part.toolInput;
    final command = (input['command'] ?? input['cmd'] ?? '') as String;
    final output = part.toolOutput;
    final error = part.toolError;
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
              stripAnsi(output),
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
              stripAnsi(error),
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
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
            ),
          ),
      ],
    );
  }
}
