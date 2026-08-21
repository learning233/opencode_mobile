import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../api/models/message.dart';
import '../../controllers/session_controller.dart';
import '../../init.dart';
import '../../utils/app_theme.dart';
import '../../widgets/message/message_bubble.dart';

/// Mobile chat timeline — ported from desktop `MessageTimeline`.
///
/// Key behaviors:
/// - CustomScrollView centered on the last user message
/// - Zero-lag streaming follow via [_FollowScrollPosition]
/// - New user message jumps to center; replies grow below
/// - ThinkingBubble while assistant is empty during generation
class ChatView extends StatefulWidget {
  final String sessionId;

  const ChatView({super.key, required this.sessionId});

  @override
  State<ChatView> createState() => _ChatViewState();
}

/// [ScrollPosition] that zero-lag follows the bottom when [shouldFollow] is true.
class _FollowScrollPosition extends ScrollPositionWithSingleContext {
  _FollowScrollPosition({
    required super.physics,
    required super.context,
    required super.initialPixels,
    super.oldPosition,
  });

  bool shouldFollow = false;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final result = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    if (shouldFollow &&
        hasPixels &&
        maxScrollExtent > 0 &&
        pixels != maxScrollExtent) {
      // Per Flutter's ScrollPosition contract, after adjusting [pixels] during
      // layout we must return false so the RenderViewport re-lays out its
      // slivers against the corrected offset. Returning true leaves the slivers
      // laid out at the stale offset while [pixels] claims a different position,
      // which shows a blank viewport for lazily-built (tall) messages.
      correctBy(maxScrollExtent - pixels);
      return false;
    }
    return result;
  }
}

class _FollowScrollController extends ScrollController {
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _FollowScrollPosition(
      physics: physics,
      context: context,
      initialPixels: 0.0,
      oldPosition: oldPosition,
    );
  }

  _FollowScrollPosition? get followPosition =>
      hasClients && position is _FollowScrollPosition
      ? position as _FollowScrollPosition
      : null;
}

class _ChatViewState extends State<ChatView> {
  final _FollowScrollController _scrollController = _FollowScrollController();

  bool _shouldFollowStreaming = true;
  bool _userDisabledFollow = false;
  bool _inProgrammaticScroll = false;

  String? _lastUserMsgId;
  bool _pendingCenterJump = false;
  bool _frameCallbackPending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _lastUserMsgId = null;
      _shouldFollowStreaming = true;
      _userDisabledFollow = false;
      _pendingCenterJump = false;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _syncFollowPosition() {
    _scrollController.followPosition?.shouldFollow =
        _shouldFollowStreaming && !_userDisabledFollow;
  }

  void _onScroll() {
    if (_inProgrammaticScroll || !_scrollController.hasClients) return;
    final cur = _scrollController.position.pixels;
    final maxExt = _scrollController.position.maxScrollExtent;
    final nearEnd = (maxExt - cur).abs() <= 8;
    if (nearEnd) {
      _userDisabledFollow = false;
      _shouldFollowStreaming = true;
    } else {
      _userDisabledFollow = true;
      _shouldFollowStreaming = false;
    }
    _syncFollowPosition();
  }

  void _followStreamingBottom() {
    if (!_scrollController.hasClients) return;
    if (_userDisabledFollow) return;
    if (!_shouldFollowStreaming) return;
    final distance =
        (_scrollController.position.maxScrollExtent -
                _scrollController.position.pixels)
            .abs();
    if (distance <= 2) return;
    _inProgrammaticScroll = true;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    _inProgrammaticScroll = false;
  }

  Widget _buildMessageItem(
    MessageModel msg,
    bool showAvatar,
    bool isStreaming,
  ) {
    return SelectionArea(
      child: MessageBubble(
        key: ValueKey('msg_${msg.id}'),
        message: msg,
        showAvatar: showAvatar,
        isStreaming: isStreaming,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SessionController>();
    final sessionId = widget.sessionId;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Obx(() {
                // Display prefs
                Global.fontScaleRx.value;
                Global.messageDensityRx.value;

                final state = controller.stateOf(sessionId);
                final allMsgs = state.messages;
                final revertId = state.revertMessageID.value;

                final List<MessageModel> msgs;
                if (revertId.isNotEmpty) {
                  final revertIdx = allMsgs.indexWhere((m) => m.id == revertId);
                  msgs = revertIdx != -1
                      ? allMsgs.sublist(0, revertIdx)
                      : allMsgs.toList();
                } else {
                  msgs = allMsgs.toList();
                }

                final isWorking = state.isGenerating.value;
                final showReasoning = controller.showReasoning.value;
                final lastUserIdx = msgs.lastIndexWhere(
                  (m) => m.role == MessageRole.user,
                );

                // Detect new user message → center jump
                if (lastUserIdx >= 0) {
                  final curId = msgs[lastUserIdx].id;
                if (curId != _lastUserMsgId) {
                  final isFirst = _lastUserMsgId == null;
                  _lastUserMsgId = curId;
                  if (!isFirst) {
                    _pendingCenterJump = true;
                    _shouldFollowStreaming = true;
                    _userDisabledFollow = false;
                    _syncFollowPosition();
                    // 不在 build 期同步 jumpTo：统一由下方 post-frame 回调
                    // （_pendingCenterJump）执行居中跳转，避免重复跳转/布局竞态。
                  }
                }
                }

                final bool showThinking;
                if (isWorking && msgs.isNotEmpty) {
                  final lastMsg = msgs.last;
                  showThinking =
                      lastMsg.role == MessageRole.assistant &&
                      MessageBubble.isMessageEmpty(
                        lastMsg,
                        isStreaming: true,
                        showReasoning: showReasoning,
                      );
                } else if (isWorking && msgs.isEmpty) {
                  showThinking = true;
                } else {
                  showThinking = false;
                }

                if (!_frameCallbackPending) {
                  _frameCallbackPending = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _frameCallbackPending = false;
                    if (!mounted) return;
                    _syncFollowPosition();
                    if (_pendingCenterJump) {
                      _pendingCenterJump = false;
                      if (_scrollController.hasClients) {
                        _inProgrammaticScroll = true;
                        _scrollController.jumpTo(0);
                        _inProgrammaticScroll = false;
                      }
                    } else {
                      _followStreamingBottom();
                    }
                  });
                }

                if (msgs.isEmpty && !showThinking) {
                  return Center(
                    child: Text(
                      'Start a conversation',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }

                final List<Widget> slivers = [];

                if (lastUserIdx >= 0) {
                  // History before last user message (reverse order in sliver
                  // so they sit above the center).
                  if (lastUserIdx > 0) {
                    slivers.add(
                      SliverList(
                        key: const ValueKey('history'),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final msgIdx = lastUserIdx - 1 - i;
                          final msg = msgs[msgIdx];
                          final showAvatar =
                              msgIdx == 0 || msg.role != msgs[msgIdx - 1].role;
                          return _buildMessageItem(msg, showAvatar, false);
                        }, childCount: lastUserIdx),
                      ),
                    );
                  }

                  final centerMsg = msgs[lastUserIdx];
                  final centerShowAvatar =
                      lastUserIdx == 0 ||
                      centerMsg.role != msgs[lastUserIdx - 1].role;
                  slivers.add(
                    SliverToBoxAdapter(
                      key: ValueKey('center_${centerMsg.id}'),
                      child: _buildMessageItem(
                        centerMsg,
                        centerShowAvatar,
                        false,
                      ),
                    ),
                  );

                  final replyCount = msgs.length - lastUserIdx - 1;
                  if (replyCount > 0) {
                    slivers.add(
                      SliverList(
                        key: const ValueKey('replies'),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final msgIdx = lastUserIdx + 1 + i;
                          final msg = msgs[msgIdx];
                          final showAvatar = msg.role != msgs[msgIdx - 1].role;
                          final isStreaming =
                              isWorking &&
                              msgIdx == msgs.length - 1 &&
                              msg.role == MessageRole.assistant;
                          return _buildMessageItem(
                            msg,
                            showAvatar,
                            isStreaming,
                          );
                        }, childCount: replyCount),
                      ),
                    );
                  }

                  slivers.add(
                    SliverToBoxAdapter(
                      key: const ValueKey('sentinel'),
                      child: showThinking
                          ? const ThinkingBubble()
                          : const SizedBox.shrink(),
                    ),
                  );

                  final lastError = state.lastError.value;
                  if (lastError != null && lastError.isNotEmpty) {
                    slivers.add(
                      SliverToBoxAdapter(
                        key: const ValueKey('chat_error_card'),
                        child: _ChatErrorCard(error: lastError),
                      ),
                    );
                  }

                  return CustomScrollView(
                    controller: _scrollController,
                    center: ValueKey('center_${centerMsg.id}'),
                    anchor: 0.0,
                    slivers: slivers,
                  );
                }

                // Flat list fallback (no user message yet)
                if (msgs.isNotEmpty) {
                  slivers.add(
                    SliverList(
                      key: const ValueKey('flat_list'),
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final msg = msgs[i];
                        final showAvatar =
                            i == 0 || msg.role != msgs[i - 1].role;
                        final isStreaming =
                            isWorking &&
                            i == msgs.length - 1 &&
                            msg.role == MessageRole.assistant;
                        return _buildMessageItem(msg, showAvatar, isStreaming);
                      }, childCount: msgs.length),
                    ),
                  );
                }
                slivers.add(
                  SliverToBoxAdapter(
                    child: showThinking
                        ? const ThinkingBubble()
                        : const SizedBox.shrink(),
                  ),
                );

                final lastError = state.lastError.value;
                if (lastError != null && lastError.isNotEmpty) {
                  slivers.add(
                    SliverToBoxAdapter(
                      key: const ValueKey('chat_error_card'),
                      child: _ChatErrorCard(error: lastError),
                    ),
                  );
                }

                return CustomScrollView(
                  controller: _scrollController,
                  slivers: slivers,
                );
              });
            },
          ),
        ),
      ],
    );
  }
}

class _ChatErrorCard extends StatelessWidget {
  final String error;

  const _ChatErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = context.appColors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appColors.errorOutline, width: 1),
      ),
      child: SelectableText(
        error,
        style: TextStyle(
          fontSize: 12,
          color: cs.onErrorContainer,
          height: 1.4,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
