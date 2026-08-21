import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../utils/translations.dart';
import '../../../api/models/message.dart';

class GlobCard extends StatelessWidget {
  final Part part;

  const GlobCard({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final input = part.toolInput;
    final pattern = input['pattern'] as String? ?? '';
    // Backend glob/list inputs carry the base directory as `path`.
    final dir = (input['path'] ?? input['directory'])?.toString() ?? '';
    final status = part.toolStatus;

    final output = part.toolOutput;
    final fileCount = output.isEmpty
        ? 0
        : output.split('\n').where((l) => l.trim().isNotEmpty).length;

    final label = dir.isNotEmpty ? dir : pattern;
    final suffix = fileCount > 0 ? '$fileCount files' : '';
    final isError = status == ToolStateStatus.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        children: [
          Text(
            LocaleKeys.cardVisGlob.tr,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isError
                  ? theme.colorScheme.error.withValues(alpha: 0.7)
                  : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
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
