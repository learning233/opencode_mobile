import 'package:flutter/material.dart';

/// Opens a scrollable detail sheet. [bodyBuilder] runs only when the sheet
/// is shown, so heavy content stays off the chat main tree.
Future<T?> showDetailBottomSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder bodyBuilder,
  double heightFactor = 0.75,
}) {
  final maxHeight = MediaQuery.sizeOf(context).height * heightFactor;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              const Divider(height: 1),
              Expanded(child: bodyBuilder(ctx)),
            ],
          ),
        ),
      );
    },
  );
}
