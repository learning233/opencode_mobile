import 'package:flutter/material.dart';

import 'settings_row.dart';

class DropdownSetting extends StatelessWidget {
  final String title;
  final String? desc;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final String Function(String) display;
  final bool isLoading;

  const DropdownSetting({
    super.key,
    required this.title,
    this.desc,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.display,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 400;
        if (narrow) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTitle(context),
                const SizedBox(height: 8),
                _buildDropdown(context, fullWidth: true),
              ],
            ),
          );
        }
        return SettingsRow(
          title: title,
          desc: desc,
          child: _buildDropdown(context, fullWidth: false),
        );
      },
    );
  }

  Widget _buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
          Text(desc!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
        ],
      ],
    );
  }

  Widget _buildDropdown(BuildContext context, {required bool fullWidth}) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Container(
        height: 28,
        width: fullWidth ? double.infinity : 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final uniqueItems = items.toSet().toList();
    if (uniqueItems.isEmpty) {
      return Text(
        'No options',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.disabledColor,
          fontSize: 12,
        ),
      );
    }

    final effectiveValue = uniqueItems.contains(value)
        ? value
        : uniqueItems.first;
    final validValue = uniqueItems.contains(effectiveValue)
        ? effectiveValue
        : null;

    final dropdown = DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: validValue,
        isDense: true,
        isExpanded: true,
        hint: Text(
          validValue == null && value.isNotEmpty ? value : 'Select...',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.disabledColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
        iconSize: 16,
        items: uniqueItems.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              display(item),
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );

    if (fullWidth) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: dropdown,
      );
    }

    return SizedBox(
      width: 120,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: dropdown,
      ),
    );
  }
}
