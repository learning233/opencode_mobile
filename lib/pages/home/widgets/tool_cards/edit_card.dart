import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../utils/translations.dart';
import '../../../../api/models/message.dart';
import '../../../../utils/app_theme.dart';
import '../../../../widgets/detail_bottom_sheet.dart';
import '../../tablet/diff_code_view.dart';
import '../../tablet/diff_view.dart';

/// E2：`_collectEntries` 与 header 统计的按 part 实例 memo（Part 不可变、
/// 更新即整体换实例）。Expando 随 part 回收，无需淘汰。
class _EditCardData {
  final List<_FileEntry> entries;
  final int addedLines;
  final int removedLines;

  const _EditCardData(this.entries, this.addedLines, this.removedLines);
}

final Expando<_EditCardData> _editCardDataCache = Expando<_EditCardData>();

/// `@@ -L,N +M,K @@` hunk 头（含 loose 形式 `@@ -L`）。E2：提为顶层 final。
final RegExp _startLineHunkRe = RegExp(
  r'^@@\s+-(\d+)(?:,\d+)?\s+\+(\d+)(?:,\d+)?\s+@@',
);
final RegExp _fallbackHunkRe = RegExp(r'@@\s+-(\d+)', multiLine: true);

/// Renders the diff for `edit` / `write` tool parts.
///
/// Prefers the standard unified diff opencode already provides in tool
/// metadata (which carries real numeric `@@ -L,N +M,K @@` line numbers):
///   - `edit` / `write` → `metadata.filediff.patch` / `metadata.diff`
///
/// Line numbers are read directly from the `@@` headers — no original-file
/// lookup or anchor inference. The loose / old-string fallbacks are only used
/// when no metadata-provided unified diff is available.
class EditCard extends StatefulWidget {
  final Part part;

  const EditCard({super.key, required this.part});

  @override
  State<EditCard> createState() => _EditCardState();
}

class _EditCardState extends State<EditCard> {
  List<_FileDiff>? _diffs;

  void _calculateDiffs() {
    if (_diffs != null) return;
    final entries = _collectEntries(widget.part);
    _diffs = [
      for (final entry in entries)
        _FileDiff(
          displayPath: entry.displayPath,
          type: entry.type,
          additions: entry.additions,
          deletions: entry.deletions,
          lines: entry.buildLines(),
        ),
    ];
  }

  @override
  void didUpdateWidget(covariant EditCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.part != widget.part) {
      _diffs = null;
    }
  }

  void _openSheet() {
    _calculateDiffs();
    final diffs = _diffs ?? const <_FileDiff>[];
    showDetailBottomSheet(
      context: context,
      title: LocaleKeys.cardVisEdit.tr,
      bodyBuilder: (ctx) {
        if (diffs.isEmpty) {
          return Center(child: Text(LocaleKeys.mobileNoDiff.tr));
        }
        // 单文件：上限取 sheet 视口高（内容放得下就不内部滚动）；
        // 多文件：保留固定上限，避免每个文件按内容撑高、虚拟化失效。
        return LayoutBuilder(
          builder: (ctx, constraints) {
            final cap = diffs.length == 1
                ? (constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : 320.0)
                : 320.0;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < diffs.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    _buildFileDiffCard(ctx, diffs[i], maxHeight: cap),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFileDiffCard(
    BuildContext context,
    _FileDiff fileDiff, {
    required double maxHeight,
  }) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: appColors.toolCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.2 : 0.4),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: theme.dividerColor.withValues(alpha: isDark ? 0.1 : 0.05),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fileDiff.displayPath,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (fileDiff.additions > 0)
                  Text(
                    '+${fileDiff.additions} ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: appColors.success,
                    ),
                  ),
                if (fileDiff.deletions > 0)
                  Text(
                    '-${fileDiff.deletions}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          DiffCodeView(
            lines: [for (final l in fileDiff.lines) _toDiffLine(l)],
            hideContextLines: false,
            showLineNumbers: true,
            maxHeight: maxHeight,
          ),
        ],
      ),
    );
  }

  static DiffLine _toDiffLine(_DiffLine l) {
    return DiffLine(
      switch (l.type) {
        _DiffType.added => DiffLineType.added,
        _DiffType.removed => DiffLineType.removed,
        _DiffType.unchanged => DiffLineType.unchanged,
      },
      l.text,
      oldLineNum: l.oldLineNum,
      newLineNum: l.newLineNum,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;

    // E2：entries 与 header 统计按 part 实例 memo，每次 build 不再重跑
    // 整 patch split / 逐行正则 / LCS。
    final data = _editCardDataCache[widget.part] ??= _computeCardData(
      widget.part,
    );
    final entries = data.entries;
    final status = widget.part.toolStatus;
    final isRunning =
        status == ToolStateStatus.running || status == ToolStateStatus.pending;
    final isError = status == ToolStateStatus.error;

    final single = entries.isEmpty ? null : entries.first;
    final isPureWrite = single != null && entries.length == 1 && single.isWrite;

    // Header label + path.
    final headerLabel = single == null ? 'Edit' : _typeLabel(single.type);
    final headerPath = single?.displayPath ?? '';

    // Header added/removed stats (prefer metadata counts).
    final addedLines = data.addedLines;
    final removedLines = data.removedLines;

    final hasContent = entries.any(
      (e) =>
          (e.patch != null && e.patch!.isNotEmpty) ||
          e.oldStr.isNotEmpty ||
          e.newStr.isNotEmpty,
    );
    final canExpand = hasContent && !isRunning;

    return Container(
      margin: const EdgeInsets.only(left: 0, right: 0, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: appColors.toolCardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canExpand ? _openSheet : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    headerLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isError
                          ? theme.colorScheme.error.withValues(alpha: 0.7)
                          : theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.6,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (headerPath.isNotEmpty)
                  Expanded(
                    child: Text(
                      headerPath,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      '...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: theme.hintColor,
                      ),
                    ),
                  ),
                if (!isPureWrite && (addedLines > 0 || removedLines > 0)) ...[
                  const SizedBox(width: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '+$addedLines',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: appColors.success,
                          ),
                        ),
                        const TextSpan(
                          text: ' ',
                          style: TextStyle(fontSize: 11.5),
                        ),
                        TextSpan(
                          text: '-$removedLines',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (canExpand) ...[
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 12,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _DiffType { unchanged, added, removed }

class _DiffLine {
  final _DiffType type;
  final String text;
  final int? oldLineNum;
  final int? newLineNum;
  _DiffLine(this.type, this.text, {this.oldLineNum, this.newLineNum});
}

/// A single file's parsed diff, ready for rendering.
class _FileDiff {
  final String displayPath;
  final String type;
  final int additions;
  final int deletions;
  final List<_DiffLine> lines;

  _FileDiff({
    required this.displayPath,
    required this.type,
    required this.additions,
    required this.deletions,
    required this.lines,
  });
}

/// A file entry collected from tool metadata/input before its diff lines are
/// parsed. Cheap to build; line parsing happens lazily in [buildLines].
class _FileEntry {
  final String displayPath;
  final String type; // add / update / delete / move / edit / write
  final String? patch; // standard unified diff (preferred) or raw fallback
  final String oldStr;
  final String newStr;
  final bool isWrite;
  final int additions;
  final int deletions;

  /// First-hunk start line, derived from the patch `@@ -L` header. Used to give
  /// the old/new-string diff body real absolute line numbers without searching
  /// the file. Defaults to 1.
  final int startLine;

  /// Untrimmed source lines from oldString+newString. Used only to recover the leading
  /// indentation that opencode's trimDiff() stripped from the metadata patch,
  /// so the rendered diff keeps the file's real indentation.
  final List<String> faithfulLines;

  _FileEntry({
    required this.displayPath,
    required this.type,
    this.patch,
    this.oldStr = '',
    this.newStr = '',
    this.isWrite = false,
    this.additions = 0,
    this.deletions = 0,
    this.startLine = 1,
    this.faithfulLines = const [],
  });

  List<_DiffLine> buildLines() {
    // edit / write: when a metadata-provided unified diff (patch) is available
    // it carries correct absolute line numbers from the `@@` headers — always
    // prefer it. The patch content has been through opencode's trimDiff() which
    // strips common leading indentation, but line numbers stay intact.
    final patch = this.patch;
    if (patch != null && patch.isNotEmpty) {
      final indent = _recoverStrippedIndent(patch, faithfulLines);
      final parsed = _parseUnifiedDiff(patch, restoreIndent: indent);
      if (parsed != null && parsed.isNotEmpty) return parsed;
    }

    if (isWrite) {
      if (newStr.isEmpty) return const [];
      final lines = newStr.split('\n');
      return [
        for (var i = 0; i < lines.length; i++)
          _DiffLine(_DiffType.added, lines[i], newLineNum: startLine + i),
      ];
    }
    if (oldStr.isNotEmpty || newStr.isNotEmpty) {
      return _getDiff(oldStr, newStr, startLine: startLine);
    }
    // Fallback: no old/new strings available and no valid patch parsed above.
    if (patch != null && patch.isNotEmpty) {
      return _parseLoosePatch(patch);
    }
    return const [];
  }
}

String _str(Object? value) => value is String ? value : '';

/// Last two path segments, for a compact file label.
String _displayName(String filePath) {
  if (filePath.isEmpty) return '';
  final parts = filePath.replaceAll('\\', '/').split('/');
  if (parts.length > 2) {
    return '${parts[parts.length - 2]}/${parts.last}';
  }
  return parts.isNotEmpty ? parts.last : '';
}

String _typeLabel(String type) {
  switch (type) {
    case 'add':
      return 'Add';
    case 'delete':
      return 'Delete';
    case 'move':
      return 'Move';
    case 'write':
      return 'Write';
    case 'update':
      return 'Update';
    case 'edit':
    default:
      return 'Edit';
  }
}

/// Collect the per-file entries to render for this tool part, plus the header
/// added/removed stats. Runs once per part instance (see [_editCardDataCache]).
///
/// Order of preference:
///   1. `edit`/`write` → `metadata.filediff.patch` / `metadata.diff`
///   2. raw `toolInput` patch / old-new strings (fallback)
_EditCardData _computeCardData(Part part) {
  final entries = _collectEntries(part);
  var addedLines = 0;
  var removedLines = 0;
  for (final entry in entries) {
    addedLines += entry.additions;
    removedLines += entry.deletions;
  }
  if (addedLines == 0 && removedLines == 0) {
    for (final entry in entries) {
      final patch = entry.patch;
      if (patch != null && patch.isNotEmpty) {
        final stats = _countPatchChanges(patch);
        addedLines += stats.$1;
        removedLines += stats.$2;
      } else if (entry.isWrite && entry.newStr.isNotEmpty) {
        addedLines += entry.newStr.split('\n').length;
      } else {
        if (entry.oldStr.isNotEmpty) {
          removedLines += entry.oldStr.split('\n').length;
        }
        if (entry.newStr.isNotEmpty) {
          addedLines += entry.newStr.split('\n').length;
        }
      }
    }
  }
  return _EditCardData(entries, addedLines, removedLines);
}

/// Collect the per-file entries to render for this tool part.
///
/// Order of preference:
///   1. `edit`/`write` → `metadata.filediff.patch` / `metadata.diff`
///   2. raw `toolInput` patch / old-new strings (fallback)
List<_FileEntry> _collectEntries(Part part) {
  final tool = part.toolName.toLowerCase();
  final input = part.toolInput;
  final metadata = part.toolMetadata;

  // edit / write / single-file.
  final isWrite = tool == 'write';
  final filediff = metadata?['filediff'];
  final filediffMap = filediff is Map ? filediff : const {};

  var patch = _str(filediffMap['patch']);
  if (patch.isEmpty) patch = _str(metadata?['diff']);
  if (patch.isEmpty) patch = _rawPatchFromInput(input);

  var file = _str(filediffMap['file']);
  if (file.isEmpty) {
    file = _str(
      input['filePath'] ?? input['file'] ?? input['uri'] ?? input['path'],
    );
  }

  final oldStr = _firstNonEmpty([
    _str(filediffMap['before']),
    _str(input['oldString']),
  ]);
  final newStr = _firstNonEmpty([
    _str(filediffMap['after']),
    _str(input['newString']),
    _str(input['content']),
  ]);

  return [
    _FileEntry(
      displayPath: _displayName(file),
      type: isWrite ? 'write' : 'edit',
      patch: patch.isEmpty ? null : patch,
      oldStr: oldStr,
      newStr: newStr,
      isWrite: isWrite,
      additions: (filediffMap['additions'] as num?)?.toInt() ?? 0,
      deletions: (filediffMap['deletions'] as num?)?.toInt() ?? 0,
      startLine: _startLineFromPatch(patch),
      // oldString/newString are the exact, untrimmed text — use them to
      // restore the indentation trimDiff() stripped from `patch`.
      faithfulLines: [
        if (oldStr.isNotEmpty) ...oldStr.split('\n'),
        if (newStr.isNotEmpty) ...newStr.split('\n'),
      ],
    ),
  ];
}

/// Recover the constant leading indentation that opencode's `trimDiff()`
/// stripped from a metadata patch, by matching a trimmed content line against
/// the untrimmed [faithfulLines]. `trimDiff()` slices the same number of
/// leading characters off every content line, so the recovered prefix from any
/// single line applies to the whole patch. Returns `''` when nothing was
/// stripped or no match is found.
String _recoverStrippedIndent(String patch, List<String> faithfulLines) {
  if (faithfulLines.isEmpty) return '';
  final faithfulSet = <String>{for (final l in faithfulLines) l};
  for (final line in patch.replaceAll('\r\n', '\n').split('\n')) {
    if (line.isEmpty) continue;
    final marker = line[0];
    if (marker != '+' && marker != '-' && marker != ' ') continue;
    if (line.startsWith('+++ ') || line.startsWith('--- ')) continue;
    final trimmed = line.substring(1);
    if (trimmed.trim().isEmpty) continue;
    if (faithfulSet.contains(trimmed)) return ''; // nothing was stripped
    for (final faithful in faithfulLines) {
      if (faithful.length > trimmed.length && faithful.endsWith(trimmed)) {
        final prefix = faithful.substring(0, faithful.length - trimmed.length);
        if (prefix.trim().isEmpty) return prefix; // leading whitespace only
      }
    }
  }
  return '';
}

/// Find the real line number of the first changed line (`-` or `+`) in a
/// unified diff patch. This gives the correct starting line for the edited
/// fragment rather than the first context line of the hunk.
///
/// Returns 1 when absent (e.g. OpenAI-style `@@ <context> @@` or no patch).
int _startLineFromPatch(String patch) {
  if (patch.isEmpty) return 1;
  final lines = patch.replaceAll('\r\n', '\n').split('\n');
  int oldLine = 1;
  int newLine = 1;
  bool inHunk = false;

  for (final line in lines) {
    final hunkMatch = _startLineHunkRe.firstMatch(line);
    if (hunkMatch != null) {
      oldLine = int.parse(hunkMatch.group(1)!);
      newLine = int.parse(hunkMatch.group(2)!);
      inHunk = true;
      continue;
    }
    if (!inHunk) {
      // File header lines (--- path / +++ path) only appear before the first
      // hunk; inside a hunk a leading '--- '/'+++ ' is content.
      if (line.startsWith('--- ') || line.startsWith('+++ ')) continue;
      continue;
    }
    if (line.startsWith('\\')) continue;
    if (line.isEmpty) continue;

    final marker = line[0];
    if (marker == '-') {
      // First removed line — return its real line number in the old file.
      return oldLine;
    } else if (marker == '+') {
      // First added line — return its real line number in the new file.
      return newLine;
    } else if (marker == ' ') {
      // Context line — advance both counters.
      oldLine++;
      newLine++;
    }
  }
  // Fallback: no change lines found, use first hunk start.
  final fallback = _fallbackHunkRe.firstMatch(patch);
  if (fallback != null) return int.tryParse(fallback.group(1)!) ?? 1;
  return 1;
}

String _firstNonEmpty(List<String> values) {
  for (final v in values) {
    if (v.isNotEmpty) return v;
  }
  return '';
}

/// Extract a raw patch from tool input (used only when metadata has none).
String _rawPatchFromInput(Map<String, dynamic> input) {
  final patch = _str(input['patch'] ?? input['patch_text']);
  if (patch.isNotEmpty) return patch;
  final content = _str(input['content']);
  return content.contains('*** Begin Patch') || content.contains('@@')
      ? content
      : '';
}

final _hunkHeaderRe = RegExp(
  r'^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@',
);

/// Parse a STANDARD unified diff (numeric `@@ -L,N +M,K @@` headers) into diff
/// lines, reading line numbers directly from the headers.
///
/// [restoreIndent] is the leading whitespace opencode's trimDiff() stripped; it
/// is re-prepended to non-empty content lines so the rendered diff keeps the
/// file's real indentation. Line numbers are unaffected by trimDiff().
///
/// Returns `null` when the patch has no numeric hunk headers (e.g. an
/// OpenAI-style `@@ <context> @@` patch), so the caller can fall back.
List<_DiffLine>? _parseUnifiedDiff(String patch, {String restoreIndent = ''}) {
  final lines = patch.replaceAll('\r\n', '\n').split('\n');
  final result = <_DiffLine>[];
  var oldLine = 1;
  var newLine = 1;
  var sawHunk = false;

  for (final line in lines) {
    final match = _hunkHeaderRe.firstMatch(line);
    if (match != null) {
      oldLine = int.parse(match.group(1)!);
      newLine = int.parse(match.group(3)!);
      sawHunk = true;
      continue;
    }
    if (!sawHunk) {
      // File header lines (--- path / +++ path) only appear before the first
      // hunk. After sawHunk a leading '--- '/'+++ ' is content, so the skip
      // must NOT apply inside a hunk.
      if (line.startsWith('--- ') || line.startsWith('+++ ')) continue;
      continue;
    }
    if (line.isEmpty) continue; // trailing artifact (blank context is " ")
    if (line.startsWith('\\')) continue; // "\ No newline at end of file"

    final marker = line[0];
    final raw = line.substring(1);
    final content = (restoreIndent.isEmpty || raw.isEmpty)
        ? raw
        : restoreIndent + raw;
    if (marker == '-') {
      result.add(_DiffLine(_DiffType.removed, content, oldLineNum: oldLine));
      oldLine++;
    } else if (marker == '+') {
      result.add(_DiffLine(_DiffType.added, content, newLineNum: newLine));
      newLine++;
    } else if (marker == ' ') {
      result.add(
        _DiffLine(
          _DiffType.unchanged,
          content,
          oldLineNum: oldLine,
          newLineNum: newLine,
        ),
      );
      oldLine++;
      newLine++;
    }
  }

  return sawHunk ? result : null;
}

/// Fallback parser for patches without numeric line numbers (OpenAI-style
/// `*** Begin Patch` / `@@ <context> @@`). Renders content without line
/// numbers — used only when no standard unified diff is available.
List<_DiffLine> _parseLoosePatch(String patch) {
  final result = <_DiffLine>[];
  for (final line in patch.replaceAll('\r\n', '\n').split('\n')) {
    if (line.startsWith('***') ||
        line.startsWith('@@') ||
        line.startsWith('diff ') ||
        line.startsWith('Index:') ||
        line.startsWith('--- ') ||
        line.startsWith('+++ ') ||
        line.startsWith('\\')) {
      continue;
    }
    if (line.startsWith('-')) {
      result.add(_DiffLine(_DiffType.removed, line.substring(1)));
    } else if (line.startsWith('+')) {
      result.add(_DiffLine(_DiffType.added, line.substring(1)));
    } else if (line.startsWith(' ')) {
      result.add(_DiffLine(_DiffType.unchanged, line.substring(1)));
    }
  }
  return result;
}

/// Count `+` / `-` lines in a patch for the header stats.
(int, int) _countPatchChanges(String patch) {
  var added = 0;
  var removed = 0;
  for (final line in patch.replaceAll('\r\n', '\n').split('\n')) {
    if (line.startsWith('+++ ') || line.startsWith('--- ')) continue;
    if (line.startsWith('+')) {
      added++;
    } else if (line.startsWith('-')) {
      removed++;
    }
  }
  return (added, removed);
}

/// LCS line diff between two strings — fallback when only old/new strings are
/// available (no patch). Line numbers are relative (start at 1).
List<_DiffLine> _getDiff(String oldStr, String newStr, {int startLine = 1}) {
  final oldLines = oldStr.split('\n');
  final newLines = newStr.split('\n');

  if (oldLines.length > 150 ||
      newLines.length > 150 ||
      oldLines.length * newLines.length > 10000) {
    final List<_DiffLine> result = [];
    int oldLine = startLine;
    for (final line in oldLines) {
      result.add(_DiffLine(_DiffType.removed, line, oldLineNum: oldLine));
      oldLine++;
    }
    int newLine = startLine + oldLines.length;
    for (final line in newLines) {
      result.add(_DiffLine(_DiffType.added, line, newLineNum: newLine));
      newLine++;
    }
    return result;
  }

  int m = oldLines.length;
  int n = newLines.length;
  List<List<int>> dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

  for (int i = 1; i <= m; i++) {
    for (int j = 1; j <= n; j++) {
      if (oldLines[i - 1] == newLines[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
      }
    }
  }

  // Backtrack LCS into a single parallel list of (type, oldI, newI).
  final ops = <({_DiffType type, int oldI, int newI})>[];
  int i = m, j = n;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1]) {
      ops.add((type: _DiffType.unchanged, oldI: i - 1, newI: j - 1));
      i--;
      j--;
    } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      ops.add((type: _DiffType.added, oldI: -1, newI: j - 1));
      j--;
    } else {
      ops.add((type: _DiffType.removed, oldI: i - 1, newI: -1));
      i--;
    }
  }

  // Reverse (backtrack produces last-to-first) and build DiffLines.
  final result = <_DiffLine>[];
  for (int k = ops.length - 1; k >= 0; k--) {
    final op = ops[k];
    switch (op.type) {
      case _DiffType.unchanged:
        result.add(
          _DiffLine(
            _DiffType.unchanged,
            oldLines[op.oldI],
            oldLineNum: startLine + op.oldI,
            newLineNum: startLine + op.newI,
          ),
        );
      case _DiffType.added:
        result.add(
          _DiffLine(
            _DiffType.added,
            newLines[op.newI],
            newLineNum: startLine + op.newI,
          ),
        );
      case _DiffType.removed:
        result.add(
          _DiffLine(
            _DiffType.removed,
            oldLines[op.oldI],
            oldLineNum: startLine + op.oldI,
          ),
        );
    }
  }
  return result;
}
