import 'package:flutter/material.dart';
import '../../../api/models/message.dart';

class TaskCard extends StatelessWidget {
  final Part part;

  const TaskCard({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final input = part.toolInput;
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

    final status = part.toolStatus;
    final isError = status == ToolStateStatus.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (description.toString().isNotEmpty)
            Flexible(
              child: Text(
                description.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isError
                      ? theme.colorScheme.error.withValues(alpha: 0.7)
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (isError && part.toolError.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                part.toolError,
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.colorScheme.error.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
