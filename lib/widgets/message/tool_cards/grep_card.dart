import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../utils/translations.dart';
import '../../../api/models/message.dart';

class GrepCard extends StatelessWidget {
  final Part part;

  const GrepCard({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final input = part.toolInput;
    final query = (input['query'] ?? input['pattern'] ?? '') as String;
    final status = part.toolStatus;

    final output = part.toolOutput;
    final resultCount = output.isEmpty
        ? 0
        : output.split('\n').where((l) => l.trim().isNotEmpty).length;

    final suffix = resultCount > 0 ? '$resultCount results' : '';
    final isError = status == ToolStateStatus.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              LocaleKeys.cardVisGrep.tr,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isError
                    ? theme.colorScheme.error.withValues(alpha: 0.7)
                    : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              query,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (suffix.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              suffix,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
