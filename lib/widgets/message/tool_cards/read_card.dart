import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../api/models/message.dart';
import '../../../controllers/project_controller.dart';
import '../../../controllers/tablet_tool_controller.dart';
import '../../../routes.dart';
import '../../../utils/layout_utils.dart';
import '../../../utils/translations.dart';

/// 行号前缀（`123:`）匹配模式。E2：提为顶层 final，避免每次 build 新建。
final RegExp _lineNumRe = RegExp(r'^\s*(\d+):[ \t]', multiLine: true);

/// E2：`_resolveRangeText` 结果按 part 实例 memo（Part 不可变、更新即整体换
/// 实例）——大输出逐次 build 重扫全量的开销随重建频次放大。Expando 随 part
/// 实例回收，无需淘汰。
final Expando<String> _rangeTextCache = Expando<String>();

class ReadCard extends StatelessWidget {
  final Part part;

  const ReadCard({super.key, required this.part});

  /// 从尾部反向找最后一个带行号前缀的行（与 `allMatches().last` 等价，
  /// 但不物化全部 Match）。
  Match? _lastLineNumMatch(String output) {
    var end = output.length;
    while (end > 0) {
      final nl = output.lastIndexOf('\n', end - 1);
      final m = _lineNumRe.firstMatch(output.substring(nl + 1, end));
      if (m != null) return m;
      if (nl == -1) break;
      end = nl;
    }
    return null;
  }

  String _resolveRangeText(Map<String, dynamic> input, String output) {
    final cached = _rangeTextCache[part];
    if (cached != null) return cached;
    final result = _computeRangeText(input, output);
    _rangeTextCache[part] = result;
    return result;
  }

  String _computeRangeText(Map<String, dynamic> input, String output) {
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
    final offset = offsetVal != null
        ? int.tryParse(offsetVal.toString())
        : null;
    final limit = limitVal != null ? int.tryParse(limitVal.toString()) : null;
    if (offset != null && offset > 0) {
      if (limit != null && limit > 0) return ':$offset-${offset + limit - 1}';
      return ':$offset+';
    }

    if (output.isEmpty) return '';
    // E2：firstMatch 取首行行号 + 反向查找取末行行号，不再
    // allMatches().toList() 物化全部 Match（千行文件 = 千个 Match/build）。
    final first = _lineNumRe.firstMatch(output);
    if (first == null) return '';
    final last = _lastLineNumMatch(output);
    final firstLine = int.tryParse(first.group(1)!);
    final lastLine = last == null ? null : int.tryParse(last.group(1)!);
    if (firstLine == null || lastLine == null) return '';
    if (firstLine == lastLine) return ':$firstLine';
    return ':$firstLine-$lastLine';
  }

  void _openFile(BuildContext context, String filePath, String shortFileName) {
    if (filePath.isEmpty) return;

    if (Get.isRegistered<TabletToolController>()) {
      final toolCtrl = Get.find<TabletToolController>();
      final worktree = Get.isRegistered<ProjectController>()
          ? (Get.find<ProjectController>().activeProject.value?.worktree ?? '')
          : '';

      toolCtrl.openFile(filePath, shortFileName, worktree: worktree);

      final isTablet = isTabletLayout(context);
      if (!isTablet) {
        if (Get.currentRoute != AppRoutes.fileList) {
          Get.toNamed(AppRoutes.fileList);
        }
      }
    }
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
    final shortFileName = pathParts.isNotEmpty ? pathParts.last : filePath;
    final fileName = pathParts.length > 2
        ? '${pathParts[pathParts.length - 2]}/${pathParts.last}'
        : shortFileName;

    final rangeText = _resolveRangeText(input, output);
    final status = part.toolStatus;
    final isError = status == ToolStateStatus.error;
    final canOpen = filePath.isNotEmpty;

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
            Flexible(
              child: Tooltip(
                message: filePath + (rangeText.isNotEmpty ? rangeText : ''),
                waitDuration: const Duration(milliseconds: 500),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: canOpen
                        ? () => _openFile(context, filePath, shortFileName)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1.5,
                      ),
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
                                    ? theme.colorScheme.error.withValues(
                                        alpha: 0.7,
                                      )
                                    : (theme.textTheme.bodySmall?.color ??
                                          theme.colorScheme.primary),
                              ),
                            ),
                            if (rangeText.isNotEmpty)
                              TextSpan(
                                text: rangeText,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.normal,
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.45),
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
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
