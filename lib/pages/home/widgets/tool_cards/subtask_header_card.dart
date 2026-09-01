import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../api/models/message.dart';

class SubtaskHeaderCard extends StatelessWidget {
  final Part part;

  const SubtaskHeaderCard({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.secondary.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.flowchart,
                  size: 13,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    part.subtaskDescription.isNotEmpty
                        ? 'Subtask: ${part.subtaskDescription}'
                        : 'Subtask',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (part.subtaskPrompt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                part.subtaskPrompt,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
