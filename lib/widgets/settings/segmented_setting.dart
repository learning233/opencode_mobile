import 'package:flutter/material.dart';

class SegmentedSetting extends StatelessWidget {
  final String title;
  final String? desc;
  final String value;
  final List<String> options;
  final List<String> labels;
  final ValueChanged<String> onChanged;

  const SegmentedSetting({
    super.key,
    required this.title,
    this.desc,
    required this.value,
    required this.options,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveValue = options.contains(value) ? value : options.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (desc != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc!,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildSegmented(theme, effectiveValue),
        ],
      ),
    );
  }

  Widget _buildSegmented(ThemeData theme, String current) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: List.generate(options.length, (i) {
        return ButtonSegment<String>(value: options[i], label: Text(labels[i]));
      }),
      selected: {current},
      onSelectionChanged: (sel) => onChanged(sel.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const WidgetStatePropertyAll(Size(64, 30)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return theme.colorScheme.primary;
          }
          return Colors.transparent;
        }),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}
