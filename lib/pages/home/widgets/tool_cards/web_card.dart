import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../utils/translations.dart';
import '../../../../api/models/message.dart';
import '../../../tablet/in_app_browser_view.dart';

class WebCard extends StatelessWidget {
  final Part part;

  const WebCard({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final input = part.toolInput;
    final url = (input['url'] ?? input['uri'] ?? '') as String;
    final query = input['query'] as String? ?? '';
    final isSearch = part.toolName == 'websearch';
    final status = part.toolStatus;
    final isError = status == ToolStateStatus.error;

    final label = isSearch ? query : url;
    final shortLabel = label.length > 60
        ? '${label.substring(0, 60)}...'
        : label;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Text(
            isSearch ? LocaleKeys.cardVisSearch.tr : LocaleKeys.cardVisWeb.tr,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isError
                  ? theme.colorScheme.error.withValues(alpha: 0.7)
                  : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: !isSearch && url.isNotEmpty
                  ? () => openUrlInApp(context, url)
                  : null,
              child: Text(
                shortLabel,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: !isSearch && url.isNotEmpty
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.7,
                        ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
