import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../utils/translations.dart';
import '../../../api/models/message.dart';

class ReadCard extends StatelessWidget {
  final Part part;

  const ReadCard({super.key, required this.part});

  String _resolveRangeText(Map<String, dynamic> input, String output) {
    final startVal =
        input['StartLine'] ??
        input['startLine'] ??
        input['start'] ??
        input['start_line'];
    final endVal =
        input['EndLine'] ??
        input['endLine'] ??
        input['end'] ??
        input['end_line'];
    final start = startVal != null ? int.tryParse(startVal.toString()) : null;
    final end = endVal != null ? int.tryParse(endVal.toString()) : null;

    if (start != null && end != null) return ':$start-$end';
    if (start != null) return ':$start+';
    if (end != null) return ':1-$end';

    // Backend read tool inputs are `offset` (1-based start line) and
    // `limit` (line count) — the outputs carry no line numbers, so derive
    // the range from these two.
    final offsetVal =
        input['offset'] ??
        input['Offset'] ??
        input['start_line'] ??
        input['startLine'];
    final limitVal = input['limit'] ?? input['Limit'] ?? input['count'];
    final offset =
        offsetVal != null ? int.tryParse(offsetVal.toString()) : null;
    final limit = limitVal != null ? int.tryParse(limitVal.toString()) : null;
    if (offset != null && offset > 0) {
      if (limit != null && limit > 0) return ':$offset-${offset + limit - 1}';
      return ':$offset+';
    }

    if (output.isEmpty) return '';
    final lineNumRe = RegExp(r'^\s*(\d+):[ \t]', multiLine: true);
    final matches = lineNumRe.allMatches(output).toList();
    if (matches.isEmpty) return '';
    final firstLine = int.tryParse(matches.first.group(1)!);
    final lastLine = int.tryParse(matches.last.group(1)!);
    if (firstLine == null || lastLine == null) return '';
    if (firstLine == lastLine) return ':$firstLine';
    return ':$firstLine-$lastLine';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final input = part.toolInput;
    final output = part.toolOutput;

    final filePath =
        (input['filePath'] ?? input['file'] ?? input['path'] ?? '') as String;
    final normalizedPath = filePath.replaceAll('\\', '/');
    final pathParts = normalizedPath.split('/');
    final fileName = pathParts.length > 2
        ? '${pathParts[pathParts.length - 2]}/${pathParts.last}'
        : (pathParts.isNotEmpty ? pathParts.last : '');

    final rangeText = _resolveRangeText(input, output);
    final status = part.toolStatus;
    final isError = status == ToolStateStatus.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              LocaleKeys.cardVisRead.tr,
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
          if (filePath.isNotEmpty)
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: fileName.isNotEmpty ? fileName : filePath,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isError
                            ? theme.colorScheme.error.withValues(alpha: 0.7)
                            : theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    if (rangeText.isNotEmpty)
                      TextSpan(
                        text: rangeText,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          fontWeight: FontWeight.normal,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            Text(
              '...',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 13,
                color: theme.hintColor,
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
