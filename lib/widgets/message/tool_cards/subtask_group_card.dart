import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../utils/translations.dart';
import '../../../api/models/message.dart';
import '../../../controllers/session_controller.dart';
import '../../detail_bottom_sheet.dart';
import '../message_part.dart';

/// Task/subtask header only. Children open in a BottomSheet.
class SubtaskGroupCard extends StatelessWidget {
  final Part header;
  final String? childSessionId;
  final List<Part> fallbackChildren;
  final bool isStreaming;
  final bool showReasoning;

  const SubtaskGroupCard({
    super.key,
    required this.header,
    this.childSessionId,
    required this.fallbackChildren,
    required this.isStreaming,
    this.showReasoning = true,
  });

  /// Scan forward from [header]'s position in [allParts] to collect children
  /// until the next task/subtask boundary.
  static List<Part> findChildren(Part header, List<Part> allParts) {
    final idx = allParts.indexWhere((p) => p.id == header.id);
    if (idx < 0 || idx + 1 >= allParts.length) return [];

    final result = <Part>[];
    for (int i = idx + 1; i < allParts.length; i++) {
      final child = allParts[i];
      final tool = child.type == PartType.tool
          ? child.toolName.toLowerCase()
          : '';
      if (tool == 'task' ||
          child.type == PartType.subtask ||
          tool == 'subtask') {
        break;
      }
      result.add(child);
    }
    return result;
  }

  void _openSheet(BuildContext context) {
    final toolName = header.type == PartType.tool
        ? header.toolName.toLowerCase()
        : '';
    final isTask = toolName == 'task';
    showDetailBottomSheet(
      context: context,
      title: isTask ? LocaleKeys.cardVisTask.tr : LocaleKeys.cardVisSubtask.tr,
      bodyBuilder: (ctx) => _SubtaskSheetBody(
        header: header,
        childSessionId: childSessionId,
        fallbackChildren: fallbackChildren,
        isStreaming: isStreaming,
        showReasoning: showReasoning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = header.type == PartType.tool
        ? header.toolName.toLowerCase()
        : '';
    final isTask = toolName == 'task';
    final status = header.type == PartType.tool ? header.toolStatus : null;
    final isError = status == ToolStateStatus.error;

    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            isTask
                ? Icon(
                    CupertinoIcons.square_grid_2x2,
                    size: 14,
                    color: isError
                        ? Colors.red.withValues(alpha: 0.7)
                        : theme.colorScheme.secondary,
                  )
                : Icon(
                    CupertinoIcons.flowchart,
                    size: 13,
                    color: isError
                        ? Colors.red.withValues(alpha: 0.7)
                        : theme.colorScheme.secondary,
                  ),
            const SizedBox(width: 6),
            Flexible(
              child: isTask
                  ? _buildTaskHeader(theme)
                  : _buildSubtaskHeader(theme),
            ),
            if (isError && header.toolError.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  header.toolError,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.red.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_right,
              size: 12,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskHeader(ThemeData theme) {
    final input = header.toolInput;
    var description =
        input['description'] ??
        input['task'] ??
        input['content'] ??
        input['title'] ??
        input['instruction'] ??
        '';
    if (description.toString().isEmpty && input.isNotEmpty) {
      description = input.values.map((v) => v.toString()).join(', ');
    }
    if (description.toString().isEmpty) {
      return Text(
        'Task',
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
        ),
      );
    }
    return Text(
      description.toString(),
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSubtaskHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header.subtaskDescription.isNotEmpty
              ? 'Subtask: ${header.subtaskDescription}'
              : 'Subtask',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (header.subtaskPrompt.isNotEmpty)
          Text(
            header.subtaskPrompt,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _SubtaskSheetBody extends StatefulWidget {
  final Part header;
  final String? childSessionId;
  final List<Part> fallbackChildren;
  final bool isStreaming;
  final bool showReasoning;

  const _SubtaskSheetBody({
    required this.header,
    required this.childSessionId,
    required this.fallbackChildren,
    required this.isStreaming,
    required this.showReasoning,
  });

  @override
  State<_SubtaskSheetBody> createState() => _SubtaskSheetBodyState();
}

class _SubtaskSheetBodyState extends State<_SubtaskSheetBody> {
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

  @override
  Widget build(BuildContext context) {
    if (widget.childSessionId != null) {
      final sessionCtrl = Get.find<SessionController>();
      return Obx(() {
        // stateOf creates the runtime state synchronously (idempotent); reading
        // .messages registers a reactive dependency so the Obx rebuilds once
        // loadMessages() fills the timeline. (Previously the state was created
        // in a post-frame callback only, leaving the Obx with no dependency
        // and a permanently spinning loader.)
        final childState = sessionCtrl.stateOf(widget.childSessionId!);
        final childMessages = childState.messages.toList();
        if (childMessages.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            sessionCtrl.loadMessages(widget.childSessionId!);
          });
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final childrenParts = <Part>[];
        for (final msg in childMessages) {
          if (msg.role == MessageRole.assistant) {
            for (final p in msg.parts) {
              if (p.type == PartType.reasoning && !widget.showReasoning) {
                continue;
              }
              childrenParts.add(p);
            }
          }
        }

        if (childrenParts.isEmpty) {
          return Center(child: Text(LocaleKeys.mobileNoStepsYet.tr));
        }

        _scrollToBottom();
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: childrenParts.length,
          itemBuilder: (_, i) {
            final child = childrenParts[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: MessagePartWidget(
                part: child,
                isStreaming: widget.isStreaming,
                sessionId: child.sessionID.isNotEmpty
                    ? child.sessionID
                    : widget.header.sessionID,
              ),
            );
          },
        );
      });
    }

    final kids = widget.fallbackChildren
        .where((c) => c.type != PartType.reasoning || widget.showReasoning)
        .toList();
    if (kids.isEmpty) {
      return Center(child: Text(LocaleKeys.mobileNoSteps.tr));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: kids.length,
      itemBuilder: (_, i) {
        final child = kids[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: MessagePartWidget(
            part: child,
            isStreaming: widget.isStreaming,
            sessionId: child.sessionID.isNotEmpty
                ? child.sessionID
                : widget.header.sessionID,
          ),
        );
      },
    );
  }
}
