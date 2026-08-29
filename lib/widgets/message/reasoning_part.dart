import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/session_controller.dart';
import '../../utils/translations.dart';
import '../../api/models/message.dart';
import '../detail_bottom_sheet.dart';
import 'text_shimmer.dart';

/// Compact reasoning header. Full text opens in a BottomSheet (not in main tree).
class ReasoningPartWidget extends StatelessWidget {
  final Part part;
  final bool isStreaming;
  final String? sessionId;

  const ReasoningPartWidget({
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
      title: LocaleKeys.cardVisThinking.tr,
      bodyBuilder: (ctx) =>
          _ReasoningSheetBody(controller: ctrl, sessionId: sid, fallback: part),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = part.reasoningText;
    final show = text.isNotEmpty || isStreaming || !part.reasoningCompleted;
    if (!show && text.isEmpty && !isStreaming) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final stillThinking =
        isStreaming || text.isEmpty || !part.reasoningCompleted;
    final label = stillThinking ? 'Thinking...' : 'Thought a bit';

    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => _openSheet(context),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology_outlined,
                size: 16,
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              stillThinking && text.isEmpty
                  ? TextShimmer(
                      text: 'Thinking...',
                      active: true,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    )
                  : Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
              const SizedBox(width: 4),
              Icon(
                Icons.open_in_new,
                size: 12,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live reasoning content inside the BottomSheet.
///
/// Streaming replaces the `Part` instance in `state.messages` (never mutates
/// in place), so this re-looks up the current part by id on every change and
/// subscribes to the reactive `messages` list — the sheet stays in sync with
/// the streaming flush instead of holding a one-time text snapshot.
class _ReasoningSheetBody extends StatefulWidget {
  final SessionController controller;
  final String sessionId;
  final Part fallback;

  const _ReasoningSheetBody({
    required this.controller,
    required this.sessionId,
    required this.fallback,
  });

  @override
  State<_ReasoningSheetBody> createState() => _ReasoningSheetBodyState();
}

class _ReasoningSheetBodyState extends State<_ReasoningSheetBody> {
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
    final state = widget.controller.sessionRuntimeStates[widget.sessionId];
    if (state == null) {
      return _content(theme, text: widget.fallback.reasoningText);
    }
    return Obx(() {
      final part = _lookup();
      _scrollToBottom();
      return _content(theme, text: part.reasoningText);
    });
  }

  Widget _content(ThemeData theme, {required String text}) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: text.isEmpty
          ? Text(
              'Thinking...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            )
          : SelectableText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5,
                fontSize: 12.5,
                color: theme.textTheme.bodySmall?.color?.withValues(
                  alpha: 0.85,
                ),
              ),
            ),
    );
  }
}
