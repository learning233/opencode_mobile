import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../api/models/message.dart';
import '../../api/models/session.dart';
import '../../controllers/session_controller.dart';
import '../../init.dart';
import '../../models/session_runtime_state.dart';
import '../../utils/card_visibility.dart';
import '../../api/models/snapshot_file_diff.dart';
import 'message_part.dart';
import 'compaction_part.dart';
import 'tool_cards/message_diff_card.dart';
import 'tool_cards/subtask_group_card.dart';
import 'user_text_card.dart';

/// Renders a single message bubble — layout aligned with desktop MessageBubble.
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool showAvatar;
  final bool isStreaming;

  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
    this.isStreaming = false,
  });

  static bool isPartVisible(
    Part part, {
    required bool isStreaming,
    required bool showReasoning,
  }) {
    switch (part.type) {
      case PartType.stepStart:
      case PartType.stepFinish:
      case PartType.snapshot:
      case PartType.patch:
      case PartType.compaction:
        return false;

      case PartType.reasoning:
        if (!showReasoning) return false;
        if (!Global.isCardVisible('reasoning')) return false;
        return part.reasoningText.isNotEmpty || isStreaming;

      case PartType.text:
        return part.text.isNotEmpty;

      case PartType.tool:
        final toolName = part.toolName.toLowerCase();
        if (toolName.contains('todo')) return false;
        if (toolName == 'question') {
          final status = part.toolStatus;
          final isPending =
              status == ToolStateStatus.running ||
              status == ToolStateStatus.pending;
          if (isPending) return false;
        }
        return Global.isCardVisible(cardVisibilityKeyForTool(toolName));

      case PartType.file:
        return Global.isCardVisible('file');

      case PartType.agent:
        return Global.isCardVisible('agent');

      case PartType.subtask:
        return Global.isCardVisible('subtask');

      case PartType.retry:
        return true;
    }
  }

  static bool isMessageEmpty(
    MessageModel message, {
    required bool isStreaming,
    required bool showReasoning,
    bool hasTurnDiffs = false,
  }) {
    // Task/subtask headers always count (desktop: always render).
    for (final p in message.parts) {
      final tool = p.type == PartType.tool ? p.toolName.toLowerCase() : '';
      if (tool == 'task' || p.type == PartType.subtask || tool == 'subtask') {
        return false;
      }
    }
    final visibleParts = message.parts.where(
      (p) => isPartVisible(
        p,
        isStreaming: isStreaming,
        showReasoning: showReasoning,
      ),
    );
    if (visibleParts.isNotEmpty) return false;
    if (hasTurnDiffs && Global.isCardVisible('diff') && !isStreaming) {
      return false;
    }
    return message.content.trim().isEmpty;
  }

  static List<SnapshotFileDiff> _collectTurnDiffs(
    List<MessageModel> messages,
    int currentIdx, {
    String? sessionId,
    String? userMessageId,
  }) {
    if (currentIdx < 0 || currentIdx >= messages.length) return const [];

    // Diff card renders on the LAST assistant message in a consecutive AI turn block
    // (or single assistant message), placing it at the very bottom of the response turn.
    final isLastInTurn =
        (currentIdx + 1 >= messages.length) ||
        (messages[currentIdx + 1].role == MessageRole.user);

    if (!isLastInTurn) {
      return const [];
    }

    var startIdx = currentIdx;
    while (startIdx > 0 &&
        messages[startIdx - 1].role == MessageRole.assistant) {
      startIdx--;
    }

    SessionRuntimeState? state;
    if (sessionId != null && sessionId.isNotEmpty) {
      try {
        state = Get.find<SessionController>().sessionRuntimeStates[sessionId];
      } catch (_) {}
    }

    // Per-message cache keyed by a signature of the turn so streaming updates
    // invalidate only what actually changed (avoids re-parsing every patch in
    // the whole turn on each 80ms delta flush).
    final signature = _turnDiffSignature(
      messages,
      startIdx,
      currentIdx,
      subtaskDiffs: (userMessageId != null && userMessageId.isNotEmpty)
          ? state?.messageSubtaskDiffs[userMessageId]
          : null,
    );
    final cache = state?.turnDiffCache;
    final cached = cache?[messages[currentIdx].id];
    if (cached != null && cached.signature == signature) return cached.diffs;

    final diffs = _computeTurnDiffs(
      messages,
      startIdx,
      currentIdx,
      sessionId: sessionId,
      userMessageId: userMessageId,
    );
    cache?[messages[currentIdx].id] = TurnDiffCacheEntry(
      signature: signature,
      diffs: diffs,
    );
    return diffs;
  }

  /// Signature of a turn's messages + the current message's tool part statuses
  /// + the subtask diff aggregation — anything that can change the turn diffs.
  static String _turnDiffSignature(
    List<MessageModel> messages,
    int startIdx,
    int currentIdx, {
    List<SnapshotFileDiff>? subtaskDiffs,
  }) {
    final sb = StringBuffer();
    for (var i = startIdx; i <= currentIdx; i++) {
      final msg = messages[i];
      sb.write(msg.id);
      sb.write('#');
      sb.write(msg.parts.length);
      sb.write(';');
    }
    final cur = messages[currentIdx];
    for (final p in cur.parts) {
      if (p.type == PartType.tool) {
        sb.write(p.id);
        sb.write('=');
        sb.write(p.toolStatus.name);
        sb.write(',');
      }
    }
    if (subtaskDiffs != null) {
      sb.write('S');
      for (final d in subtaskDiffs) {
        sb.write(d.file);
        sb.write('+');
        sb.write(d.additions);
        sb.write('-');
        sb.write(d.deletions);
        sb.write(';');
      }
    }
    return sb.toString();
  }

  static List<SnapshotFileDiff> _computeTurnDiffs(
    List<MessageModel> messages,
    int startIdx,
    int currentIdx, {
    String? sessionId,
    String? userMessageId,
  }) {
    final Map<String, SnapshotFileDiff> map = {};

    void mergeDiff(SnapshotFileDiff d) {
      if (d.file.isEmpty) return;
      if (map.containsKey(d.file)) {
        map[d.file] = SnapshotFileDiff.merge(map[d.file]!, d);
      } else {
        map[d.file] = d;
      }
    }

    for (var i = startIdx; i <= currentIdx; i++) {
      final msg = messages[i];
      final diffs = msg.toolDiffs.isNotEmpty ? msg.toolDiffs : msg.summaryDiffs;
      for (final d in diffs) {
        mergeDiff(d);
      }
    }

    if (sessionId != null &&
        sessionId.isNotEmpty &&
        userMessageId != null &&
        userMessageId.isNotEmpty) {
      try {
        final sessionCtrl = Get.find<SessionController>();
        final subtaskDiffs = sessionCtrl
            .sessionRuntimeStates[sessionId]
            ?.messageSubtaskDiffs[userMessageId];
        if (subtaskDiffs != null && subtaskDiffs.isNotEmpty) {
          for (final d in subtaskDiffs) {
            mergeDiff(d);
          }
        }
      } catch (_) {}
    }

    return map.values.toList();
  }

  static String _findTurnUserMessageId(
    List<MessageModel> messages,
    int currentIdx,
  ) {
    if (currentIdx < 0 || currentIdx >= messages.length) return '';
    var startIdx = currentIdx;
    while (startIdx > 0 &&
        messages[startIdx - 1].role == MessageRole.assistant) {
      startIdx--;
    }
    if (startIdx > 0 && messages[startIdx - 1].role == MessageRole.user) {
      return messages[startIdx - 1].id;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sessionCtrl = Get.find<SessionController>();
      final showReasoning = sessionCtrl.showReasoning.value;
      // Touch display prefs
      final padScale = Global.messagePaddingScale;
      final fontScale = Global.fontScaleRx.value;
      final _ = Map<String, bool>.from(Global.cardVisibilityRx);
      // Touch child-session list so matching updates.
      final childSessions =
          sessionCtrl.sessionRuntimeStates[message.sessionID]?.childSessions ??
          const <SessionModel>[];

      // Hide user compaction checkpoint messages (desktop Msg A).
      for (final p in message.parts) {
        if (p.type == PartType.compaction) {
          return const SizedBox.shrink();
        }
      }

      // Compaction summary (assistant + summary==true)
      final summaryInfo = message.raw['info'];
      final summaryFlag =
          (summaryInfo is Map ? summaryInfo['summary'] : null) ??
          message.raw['summary'];
      if (message.role == MessageRole.assistant && summaryFlag == true) {
        final compacting =
            sessionCtrl
                .sessionRuntimeStates[message.sessionID]
                ?.isCompacting
                .value ??
            false;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CompactionSummaryWidget(
            summary: message.content,
            isCompacting: compacting,
          ),
        );
      }

      final state = sessionCtrl.sessionRuntimeStates[message.sessionID];
      final allMsgs = state?.messages ?? const <MessageModel>[];
      final isGenerating = state?.isGenerating.value ?? false;
      final isLastMsg = allMsgs.isNotEmpty && allMsgs.last.id == message.id;
      final isStreaming = isGenerating && isLastMsg;
      final msgIdx = allMsgs.indexWhere((m) => m.id == message.id);
      final turnUserMsgId = _findTurnUserMessageId(allMsgs, msgIdx);
      final turnDiffs = _collectTurnDiffs(
        allMsgs,
        msgIdx,
        sessionId: message.sessionID,
        userMessageId: turnUserMsgId,
      );

      if (isMessageEmpty(
        message,
        isStreaming: isStreaming,
        showReasoning: showReasoning,
        hasTurnDiffs: turnDiffs.isNotEmpty,
      )) {
        return const SizedBox.shrink();
      }

      final isUser = message.role == MessageRole.user;
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(fontScale)),
        child: isUser
            ? _UserBubble(
                message: message,
                showAvatar: showAvatar,
                padScale: padScale,
              )
            : _AssistantBubble(
                message: message,
                isStreaming: isStreaming,
                showReasoning: showReasoning,
                padScale: padScale,
                childSessions: childSessions,
                turnDiffs: turnDiffs,
                turnUserMsgId: turnUserMsgId,
              ),
      );
    });
  }
}

class _UserBubble extends StatelessWidget {
  final MessageModel message;
  final bool showAvatar;
  final double padScale;

  const _UserBubble({
    required this.message,
    required this.showAvatar,
    required this.padScale,
  });

  @override
  Widget build(BuildContext context) {
    final textParts = message.parts
        .where((p) => p.type == PartType.text)
        .map((p) => p.text)
        .join('\n');
    final userPromptText = textParts.isNotEmpty ? textParts : message.content;

    final fileParts = message.parts
        .where((p) => p.type == PartType.file && Global.isCardVisible('file'))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 48,
        right: 12,
        top: (showAvatar ? 20 : 10) * padScale,
        bottom: 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.82,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (fileParts.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      children: fileParts
                          .map((p) => MessagePartWidget(part: p))
                          .toList(),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (userPromptText.isNotEmpty)
                    UserTextCard(message: message, displayText: userPromptText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final MessageModel message;
  final bool isStreaming;
  final bool showReasoning;
  final double padScale;
  final List<SessionModel> childSessions;
  final List<SnapshotFileDiff> turnDiffs;
  final String turnUserMsgId;

  const _AssistantBubble({
    required this.message,
    required this.isStreaming,
    required this.showReasoning,
    required this.padScale,
    required this.childSessions,
    this.turnDiffs = const [],
    this.turnUserMsgId = '',
  });

  String? _findChildSessionId(Part part) {
    final metaSessionId =
        part.toolMetadata?['sessionId'] ?? part.toolMetadata?['sessionID'];
    if (metaSessionId != null && metaSessionId.toString().isNotEmpty) {
      return metaSessionId.toString();
    }

    final inputTaskId = part.toolInput['task_id'] ?? part.toolInput['taskId'];
    if (inputTaskId != null && inputTaskId.toString().isNotEmpty) {
      return inputTaskId.toString();
    }

    final description = part.subtaskDescription;
    if (description.isNotEmpty) {
      for (final s in childSessions) {
        if (s.title == description) return s.id;
        if (description.length >= 10 &&
            (s.title.contains(description) || description.contains(s.title))) {
          return s.id;
        }
      }
    }

    final agent = part.subtaskAgent;
    if (agent.isNotEmpty) {
      for (final s in childSessions) {
        if (s.agent == agent) return s.id;
      }
    }

    return null;
  }

  /// Desktop-aligned part columns: task/subtask → SubtaskGroupCard; sub-steps
  /// are skipped in the flat list (they render inside the group when expanded).
  List<Widget> _buildPartColumns(List<Part> parts) {
    final widgets = <Widget>[];
    String? parentHeader;

    for (final part in parts) {
      final toolNameLower = part.type == PartType.tool
          ? part.toolName.toLowerCase()
          : '';
      final isTask = toolNameLower == 'task';
      final isSubtask =
          part.type == PartType.subtask || toolNameLower == 'subtask';

      // Task/subtask headers always render (even while streaming/pending).
      if (isTask || isSubtask) {
        final key = isTask ? 'task' : 'subtask';
        if (!Global.isCardVisible(key)) {
          // Still mark parent so following sub-steps stay grouped/hidden when
          // the header itself is toggled off.
          if (isTask) {
            parentHeader = 'task';
          } else if (parentHeader != 'task') {
            parentHeader = 'subtask';
          }
          continue;
        }

        if (isTask) {
          parentHeader = 'task';
        } else if (parentHeader != 'task') {
          parentHeader = 'subtask';
        }

        final childSessionId = _findChildSessionId(part);
        final children = SubtaskGroupCard.findChildren(part, parts);

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SubtaskGroupCard(
              header: part,
              childSessionId: childSessionId,
              fallbackChildren: children,
              isStreaming: isStreaming,
              showReasoning: showReasoning,
            ),
          ),
        );
        continue;
      }

      if (!MessageBubble.isPartVisible(
        part,
        isStreaming: isStreaming,
        showReasoning: showReasoning,
      )) {
        continue;
      }

      var isSubstep = false;
      if (parentHeader == 'task') {
        if (!isTask) isSubstep = true;
      } else if (parentHeader == 'subtask') {
        if (!isSubtask && !isTask) isSubstep = true;
      }

      if (isSubstep) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: MessagePartWidget(
            part: part,
            isStreaming: isStreaming,
            sessionId: message.sessionID,
          ),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final children = _buildPartColumns(message.parts);

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10 * padScale,
        bottom: 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...children,
          if (!isStreaming &&
              turnDiffs.isNotEmpty &&
              Global.isCardVisible('diff'))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: MessageDiffCard(
                sessionId: message.sessionID,
                userMessageId: turnUserMsgId,
                diffs: turnDiffs,
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown while the model is generating but has no visible parts yet.
class ThinkingBubble extends StatelessWidget {
  const ThinkingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 0),
      child: Row(
        children: [
          Text(
            'Thinking...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
