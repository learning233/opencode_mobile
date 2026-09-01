import 'package:flutter/material.dart';
import '../../../../api/models/message.dart';
import '../../../../widgets/detail_bottom_sheet.dart';
import 'markdown_view.dart';

/// Compact divider for a compaction checkpoint part (rarely shown — Msg A is hidden).
class CompactionPartWidget extends StatelessWidget {
  final Part part;

  const CompactionPartWidget({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Container(height: 0.5, color: dividerColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.compress,
                  size: 11,
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  part.compactionAuto ? 'Auto-compacted' : 'Context compressed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.5,
                    ),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Container(height: 0.5, color: dividerColor)),
        ],
      ),
    );
  }
}

/// Compaction summary header. Full markdown opens in a BottomSheet.
class CompactionSummaryWidget extends StatelessWidget {
  final String summary;
  final bool auto;
  final bool isCompacting;

  const CompactionSummaryWidget({
    super.key,
    required this.summary,
    this.auto = false,
    this.isCompacting = false,
  });

  void _openSheet(BuildContext context) {
    showDetailBottomSheet(
      context: context,
      title: auto ? 'Auto-compact' : 'Context compress',
      bodyBuilder: (ctx) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (summary.trim().isEmpty)
            Text(
              'No summary',
              style: Theme.of(
                ctx,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).hintColor),
            )
          else
            MarkdownView(content: summary),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor.withValues(alpha: 0.3);
    final subColor = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5);

    // Outer vertical padding is deliberately small: the rest moved inside the
    // InkWell so the tap target is tall enough while visual spacing stays put.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: isCompacting || summary.trim().isEmpty
            ? null
            : () => _openSheet(context),
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: [
            Expanded(child: Container(height: 0.5, color: dividerColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.compress, size: 11, color: subColor),
                  const SizedBox(width: 6),
                  Text(
                    auto ? 'Auto-compact' : 'Context compress',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: subColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  isCompacting
                      ? Text('...', style: TextStyle(color: subColor))
                      : Icon(Icons.open_in_new, size: 12, color: subColor),
                ],
              ),
            ),
            Expanded(child: Container(height: 0.5, color: dividerColor)),
          ],
        ),
      ),
    );
  }
}
