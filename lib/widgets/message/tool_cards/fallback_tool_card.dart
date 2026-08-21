import 'package:flutter/material.dart';
import '../../../api/models/message.dart';

class FallbackToolCard extends StatelessWidget {
  final Part part;

  const FallbackToolCard({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tool = part.toolName;
    final status = part.toolStatus;
    final isError = status == ToolStateStatus.error;
    final displayName = tool.isNotEmpty ? tool : 'Tool';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Flexible(
            child: Text(
              displayName,
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
