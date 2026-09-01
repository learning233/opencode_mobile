import 'package:flutter/material.dart';
import '../../../../api/models/message.dart';
import 'bash_card.dart';
import 'batch_card.dart';
import 'edit_card.dart';
import 'fallback_tool_card.dart';
import 'glob_card.dart';
import 'grep_card.dart';
import 'question_card.dart';
import 'read_card.dart';
import 'skill_card.dart';
import 'subtask_header_card.dart';
import 'task_card.dart';
import 'todo_card.dart';
import 'web_card.dart';

/// Dispatches a tool [Part] to a desktop-aligned card (mobile adapted).
class ToolPartDispatcher extends StatelessWidget {
  final Part part;
  final bool isStreaming;
  final String? sessionId;

  const ToolPartDispatcher({
    super.key,
    required this.part,
    this.isStreaming = false,
    this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    final tool = part.toolName.toLowerCase();

    switch (tool) {
      case 'read':
        return ReadCard(part: part);
      case 'bash':
      case 'shell':
        return BashCard(
          part: part,
          isStreaming: isStreaming,
          sessionId: sessionId,
        );
      case 'edit':
      case 'write':
        return EditCard(part: part);
      case 'apply_patch':
        return BatchCard(part: part);
      case 'glob':
      case 'list':
        return GlobCard(part: part);
      case 'grep':
        return GrepCard(part: part);
      case 'webfetch':
      case 'websearch':
        return WebCard(part: part);
      case 'question':
        return QuestionCard(part: part, isInlinePlaceholder: true);
      case 'task':
        return TaskCard(part: part);
      case 'subtask':
        return SubtaskHeaderCard(part: part);
      case 'todo':
      case 'todowrite':
      case 'todo_write':
        return TodoCard(part: part);
      case 'skill':
        return SkillCard(part: part);
      default:
        if (tool.contains('todo')) {
          return TodoCard(part: part);
        }
        if (tool.contains('skill')) {
          return SkillCard(part: part);
        }
        return FallbackToolCard(part: part);
    }
  }
}
