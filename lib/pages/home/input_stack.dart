import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../api/models/snapshot_file_diff.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../init.dart';
import '../../models/session_runtime_state.dart';
import '../../utils/diff_paths.dart';
import '../../utils/layout_utils.dart';
import '../../utils/translations.dart';
import 'widgets/message/tool_cards/question_card.dart';

/// Stack of resident status panels (todo / changed files) with a temporary
/// overlay layer for pending question / permission cards.
///
/// The resident panels are mutually exclusive — only one may be expanded at a
/// time so the slot stays bounded. Pending question / permission cards cover
/// them while active and disappear on their own once resolved.
class SessionStatusStack extends StatefulWidget {
  final String sessionId;

  const SessionStatusStack({super.key, required this.sessionId});

  @override
  State<SessionStatusStack> createState() => _SessionStatusStackState();
}

class _SessionStatusStackState extends State<SessionStatusStack> {
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();
    final state = ctrl.stateOf(widget.sessionId);

    return Obx(() {
      // 读取 expandedSection 使 Obx 对其变化响应；展开状态按会话存储，
      // sendPrompt 可折叠 changefiles，切换 session 逻辑可读取。
      final expanded = state.expandedSection.value;
      // E3：不再 touch messages——pendingQuestionInTree 已短路为 per-state
      // 惰性布尔（hasPendingQuestion）+ 权限槽（pendingPermission）遍历，
      // 流式/工具高峰期的列表整表替换不再重建本 Obx，pending 状态变化才重建。
      final hasQuestion = ctrl.pendingQuestionInTree(widget.sessionId) != null;
      final hasPermission =
          ctrl.sessionIdWithPendingPermission(widget.sessionId) != null;

      return Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TodoPanel(
                sessionId: widget.sessionId,
                expanded: expanded == SessionExpandedSection.todo,
                onToggle: () {
                  state.expandedSection.value =
                      expanded == SessionExpandedSection.todo
                      ? SessionExpandedSection.none
                      : SessionExpandedSection.todo;
                },
              ),
              SessionDiffPanel(
                sessionId: widget.sessionId,
                expanded: expanded == SessionExpandedSection.diff,
                onToggle: () {
                  final willExpand = expanded != SessionExpandedSection.diff;
                  if (isTabletLayout(context) && willExpand) {
                    Get.find<TabletToolController>().openReviewSession(
                      widget.sessionId,
                    );
                  }
                  state.expandedSection.value = willExpand
                      ? SessionExpandedSection.diff
                      : SessionExpandedSection.none;
                },
              ),
            ],
          ),
          if (hasQuestion || hasPermission) ...[
            // Opaque backdrop covering the resident panels entirely so they
            // never peek through or around the overlay cards.
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasQuestion)
                  PendingQuestionCard(sessionId: widget.sessionId),
                if (hasPermission)
                  PendingPermissionCard(sessionId: widget.sessionId),
              ],
            ),
          ],
        ],
      );
    });
  }
}

/// Todo collapsible panel above the prompt input.
class TodoPanel extends StatelessWidget {
  final String sessionId;
  final bool expanded;
  final VoidCallback onToggle;

  const TodoPanel({
    super.key,
    required this.sessionId,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();

    return Obx(() {
      final _ = Map<String, bool>.from(Global.cardVisibilityRx);
      if (!Global.isCardVisible('input_todo')) return const SizedBox.shrink();
      final todos = ctrl.stateOf(sessionId).todos.toList();
      if (todos.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _CollapsiblePanel(
          title: LocaleKeys.chatTodoTitle.tr,
          icon: CupertinoIcons.checkmark_circle,
          count: todos.length,
          expanded: expanded,
          onToggle: onToggle,
          child: _TodoList(todos: todos),
        ),
      );
    });
  }
}

class _TodoList extends StatelessWidget {
  final List<Map<String, dynamic>> todos;

  const _TodoList({required this.todos});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: todos.map((t) {
        final content = t['content']?.toString() ?? '';
        final status = t['status']?.toString() ?? 'pending';
        final isDone = status == 'completed';
        final isInProgress = status == 'in_progress';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isDone
                    ? CupertinoIcons.check_mark_circled_solid
                    : isInProgress
                    ? CupertinoIcons.clock_solid
                    : CupertinoIcons.circle,
                size: 13,
                color: isDone
                    ? const Color(0xFF4CAF50)
                    : isInProgress
                    ? const Color(0xFFFF9800)
                    : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  content,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone
                        ? theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.4,
                          )
                        : theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.8,
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Session-level file change list above the prompt input.
/// Automatically computes aggregated file diffs from session tool calls.
class SessionDiffPanel extends StatelessWidget {
  final String sessionId;
  final bool expanded;
  final VoidCallback onToggle;

  const SessionDiffPanel({
    super.key,
    required this.sessionId,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();

    return Obx(() {
      final _ = Map<String, bool>.from(Global.cardVisibilityRx);
      if (!Global.isCardVisible('input_session_diff')) {
        return const SizedBox.shrink();
      }
      final state = ctrl.stateOf(sessionId);
      // Access messages length & sessionDiffs length so Obx registers reactive dependencies.
      state.messages.length;
      state.sessionDiffs.length;
      final diffs = state.effectiveSessionDiffs;
      if (diffs.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _CollapsiblePanel(
          title: 'Changed Files',
          icon: CupertinoIcons.doc_text,
          count: diffs.length,
          expanded: expanded,
          onToggle: onToggle,
          child: _SessionDiffList(
            diffs: diffs,
            onFileTap: isTabletLayout(context)
                ? (file) => Get.find<TabletToolController>()
                      .openReviewSessionFile(sessionId, selectFile: file)
                : null,
          ),
        ),
      );
    });
  }
}

class _SessionDiffList extends StatefulWidget {
  final List<SnapshotFileDiff> diffs;

  /// When set (tablet layout), rows become tappable and highlight the last file
  /// tapped in this list. When null (phone), rows stay inert.
  final ValueChanged<String>? onFileTap;

  const _SessionDiffList({required this.diffs, this.onFileTap});

  @override
  State<_SessionDiffList> createState() => _SessionDiffListState();
}

class _SessionDiffListState extends State<_SessionDiffList> {
  /// 本列表自身的选中文件（仅用于高亮）。独立于 Review tab 的
  /// `reviewSelectedFile`，避免点其他列表/右侧页签时此处跟着变。
  String _selected = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onFileTap = widget.onFileTap;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final d in widget.diffs) _buildRow(theme, d, onFileTap)],
    );
  }

  Widget _buildRow(
    ThemeData theme,
    SnapshotFileDiff d,
    ValueChanged<String>? onFileTap,
  ) {
    final active = diffPathsEqual(_selected, d.file);
    final row = Row(
      children: [
        Icon(
          _statusIcon(d.status),
          size: 12,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            d.displayName,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11.5,
              fontFamily: 'monospace',
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active
                  ? theme.colorScheme.primary
                  : theme.textTheme.bodySmall?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (onFileTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: InkWell(
        onTap: () {
          setState(() {
            _selected = d.file;
          });
          onFileTap(d.file);
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: row,
        ),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'added':
        return CupertinoIcons.plus_circle;
      case 'deleted':
        return CupertinoIcons.minus_circle;
      default:
        return CupertinoIcons.pencil_circle;
    }
  }
}

/// Pending permission card above the prompt input.
///
/// [sessionId] is the root session; pending permission requests from descendant
/// subtask sessions are surfaced here too, and replies target the session that
/// actually holds the request.
class PendingPermissionCard extends StatelessWidget {
  final String sessionId;

  const PendingPermissionCard({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Obx(() {
      final realSessionId =
          ctrl.sessionIdWithPendingPermission(sessionId) ?? sessionId;
      final pending = ctrl.stateOf(realSessionId).pendingPermission.value;
      if (pending == null) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2E1C0F) : const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(
              0xFFE28743,
            ).withValues(alpha: isDark ? 0.35 : 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.shield_fill,
                  color: Color(0xFFE28743),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    LocaleKeys.piSecurityRequest.tr,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE28743),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.chatPermissionRequestDesc.trParams({
                'type': pending.displayType,
              }),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (pending.patterns.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1F29)
                      : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pending.displayPattern,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _PermButton(
                  onPressed: () => ctrl.respondPermission(
                    pending.id,
                    'deny',
                    sessionId: realSessionId,
                  ),
                  label: LocaleKeys.piDenyOperation.tr,
                  variant: 'outlined',
                ),
                const SizedBox(width: 6),
                _PermButton(
                  onPressed: () => ctrl.respondPermission(
                    pending.id,
                    'allow',
                    sessionId: realSessionId,
                  ),
                  label: LocaleKeys.piAllowExecute.tr,
                  variant: 'filled',
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _PermButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final String variant;

  const _PermButton({
    required this.onPressed,
    required this.label,
    required this.variant,
  });

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
    );
    const textStyle = TextStyle(fontSize: 12);

    switch (variant) {
      case 'outlined':
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: padding,
            shape: shape,
            visualDensity: VisualDensity.compact,
            textStyle: textStyle,
          ),
          child: Text(label),
        );
      case 'text':
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: padding,
            shape: shape,
            visualDensity: VisualDensity.compact,
            textStyle: textStyle,
          ),
          child: Text(label),
        );
      default:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: padding,
            shape: shape,
            visualDensity: VisualDensity.compact,
            textStyle: textStyle,
          ),
          child: Text(label),
        );
    }
  }
}

/// Pending question overlay card above the prompt input — same source as
/// desktop: the running/pending `question` tool part anywhere in the session
/// tree (including descendant subtask sessions).
class PendingQuestionCard extends StatelessWidget {
  final String sessionId;

  const PendingQuestionCard({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();

    return Obx(() {
      // E3：pendingQuestionInTree 先走 per-state 惰性布尔短路，仅当树内确有
      // 挂起问题时才做一次全量扫描取 part（此时回合被阻塞，事件低频）；
      // 本 Obx 不再注册 messages 依赖。
      final part = ctrl.pendingQuestionInTree(sessionId);
      if (part == null) return const SizedBox.shrink();

      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      // Solid tinted card (opaque) so the resident panels behind it never
      // show through.
      final cardColor = Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.07),
        theme.scaffoldBackgroundColor,
      );
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(
              alpha: isDark ? 0.35 : 0.6,
            ),
          ),
        ),
        child: QuestionCard(part: part, isInlinePlaceholder: false),
      );
    });
  }
}

/// Queued prompt bar shown while generation is in progress.
class PendingPromptBar extends StatelessWidget {
  final String sessionId;

  const PendingPromptBar({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Obx(() {
      final state = ctrl.stateOf(sessionId);
      if (!state.hasPendingPrompt) return const SizedBox.shrink();

      final text = state.pendingPromptText.value;
      final fileCount = state.pendingPromptAttachedFiles.length;
      final imageCount = state.pendingPromptImages.length;

      final parts = <String>[];
      final cleanText = text.replaceAll('\n', ' ').trim();
      if (cleanText.isNotEmpty) parts.add(cleanText);
      if (fileCount > 0) {
        parts.add(
          '[${LocaleKeys.chatFileCount.trParams({'count': fileCount.toString()})}]',
        );
      }
      if (imageCount > 0) {
        parts.add(
          '[${LocaleKeys.chatImageCount.trParams({'count': imageCount.toString()})}]',
        );
      }

      final displayText = parts.isNotEmpty
          ? LocaleKeys.chatQueuingWithParts.trParams({'parts': parts.join(' ')})
          : LocaleKeys.chatQueuing.tr;

      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.clock,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayText,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => ctrl.sendPendingPromptImmediately(sessionId),
              child: Text(LocaleKeys.piSendNow.tr),
            ),
            TextButton(
              onPressed: () => ctrl.clearPendingPrompt(sessionId),
              child: Text(LocaleKeys.cancel.tr),
            ),
          ],
        ),
      );
    });
  }
}

/// Start execution button shown after plan agent completes.
class StartExecutionButton extends StatelessWidget {
  final String sessionId;

  const StartExecutionButton({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();

    return Obx(() {
      final show = ctrl.stateOf(sessionId).showStartExecutionButton.value;
      if (!show) return const SizedBox.shrink();

      final isTablet = isTabletLayout(context);

      final planBtn = OutlinedButton(
        onPressed: () async {
          if (sessionId != ctrl.activeSessionId.value) {
            ctrl.selectSession(sessionId);
          }
          await ctrl.sendPrompt(
            LocaleKeys.makePlan.tr,
            targetSessionId: sessionId,
          );
        },
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(100, 30),
        ),
        child: Text(
          LocaleKeys.makePlan.tr,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );

      final execBtn = FilledButton(
        onPressed: () async {
          if (sessionId != ctrl.activeSessionId.value) {
            ctrl.selectSession(sessionId);
          }
          ctrl.selectAgent('build');
          await ctrl.sendPrompt(
            LocaleKeys.startExecution.tr,
            targetSessionId: sessionId,
          );
        },
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(100, 30),
        ),
        child: Text(
          LocaleKeys.startExecution.tr,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );

      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: isTablet
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: isTablet
              ? [execBtn, const SizedBox(width: 8), planBtn]
              : [planBtn, const SizedBox(width: 8), execBtn],
        ),
      );
    });
  }
}

class _CollapsiblePanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _CollapsiblePanel({
    required this.title,
    required this.icon,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F29) : const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.15 : 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(CupertinoIcons.chevron_down, size: 12),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: child,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
