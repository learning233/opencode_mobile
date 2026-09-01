import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../utils/translations.dart';

import '../../../../api/models/message.dart';
import '../../../../utils/app_theme.dart';
import '../../../../widgets/detail_bottom_sheet.dart';
import '../../../tablet/diff_code_view.dart';
import '../../../tablet/diff_view.dart';

/// Renders the real `apply_patch` tool as a batch-oriented patch card.
class BatchCard extends StatefulWidget {
  final Part part;

  const BatchCard({super.key, required this.part});

  @override
  State<BatchCard> createState() => _BatchCardState();
}

class _BatchCardState extends State<BatchCard> {
  List<_BatchFileDiff>? _diffs;

  void _calculateDiffs() {
    if (_diffs != null) return;
    final files = _collectBatchFiles(widget.part);
    _diffs = [
      for (final file in files)
        _BatchFileDiff(
          displayPath: file.displayPath,
          type: file.type,
          additions: file.additions,
          deletions: file.deletions,
          lines: file.buildLines(),
        ),
    ];
  }

  @override
  void didUpdateWidget(covariant BatchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.part != widget.part) {
      _diffs = null;
    }
  }

  void _openSheet() {
    _calculateDiffs();
    final diffs = _diffs ?? const <_BatchFileDiff>[];
    showDetailBottomSheet(
      context: context,
      title: LocaleKeys.cardVisBatch.tr,
      bodyBuilder: (ctx) {
        if (diffs.isEmpty) {
          return Center(child: Text(LocaleKeys.mobileNoDiff.tr));
        }
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < diffs.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                _buildFileLabel(ctx, diffs[i]),
                const SizedBox(height: 4),
                DiffCodeView(
                  lines: [for (final l in diffs[i].lines) _toBatchDiffLine(l)],
                  hideContextLines: false,
                  showLineNumbers: true,
                  maxHeight: 320,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static DiffLine _toBatchDiffLine(_BatchDiffLine l) {
    return DiffLine(
      switch (l.type) {
        _BatchDiffType.added => DiffLineType.added,
        _BatchDiffType.removed => DiffLineType.removed,
        _BatchDiffType.unchanged => DiffLineType.unchanged,
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
    final files = _collectBatchFiles(widget.part);
    final status = widget.part.toolStatus;
    final isRunning =
        status == ToolStateStatus.running || status == ToolStateStatus.pending;
    final isError = status == ToolStateStatus.error;

    var addedLines = 0;
    var removedLines = 0;
    for (final file in files) {
      addedLines += file.additions;
      removedLines += file.deletions;
    }
    if (addedLines == 0 && removedLines == 0) {
      for (final file in files) {
        final stats = _countPatchChanges(file.patch);
        addedLines += stats.$1;
        removedLines += stats.$2;
      }
    }

    final hasContent = files.any((file) => file.patch.isNotEmpty);
    final canExpand = hasContent && !isRunning;
    final headerPath = files.length == 1
        ? files.first.displayPath
        : '${files.length} files';

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
                  width: 44,
                  child: Text(
                    'Batch',
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
                Expanded(
                  child: Text(
                    headerPath.isNotEmpty ? headerPath : '...',
                    style: headerPath.isNotEmpty
                        ? TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: theme.textTheme.bodySmall?.color,
                          )
                        : theme.textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                            color: theme.hintColor,
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (addedLines > 0 || removedLines > 0) ...[
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
                        const TextSpan(text: ' '),
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

  Widget _buildFileLabel(BuildContext context, _BatchFileDiff fileDiff) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
      child: Row(
        children: [
          Text(
            _typeLabel(fileDiff.type),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              fileDiff.displayPath,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (fileDiff.additions > 0 || fileDiff.deletions > 0)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '+${fileDiff.additions}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: appColors.success,
                    ),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: '-${fileDiff.deletions}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _BatchDiffType { unchanged, added, removed }

class _BatchDiffLine {
  final _BatchDiffType type;
  final String text;
  final int? oldLineNum;
  final int? newLineNum;

  const _BatchDiffLine(
    this.type,
    this.text, {
    this.oldLineNum,
    this.newLineNum,
  });
}

class _BatchFileDiff {
  final String displayPath;
  final String type;
  final int additions;
  final int deletions;
  final List<_BatchDiffLine> lines;

  const _BatchFileDiff({
    required this.displayPath,
    required this.type,
    required this.additions,
    required this.deletions,
    required this.lines,
  });
}

class _BatchFileEntry {
  final String displayPath;
  final String type;
  final String patch;
  final int additions;
  final int deletions;
  final List<String> faithfulLines;

  const _BatchFileEntry({
    required this.displayPath,
    required this.type,
    required this.patch,
    this.additions = 0,
    this.deletions = 0,
    this.faithfulLines = const [],
  });

  List<_BatchDiffLine> buildLines() {
    if (patch.isEmpty) return const [];
    final indent = _recoverStrippedIndent(patch, faithfulLines);
    final parsed = _parseUnifiedDiff(patch, restoreIndent: indent);
    if (parsed.isNotEmpty) return parsed;
    return _parseLoosePatch(patch);
  }
}

List<_BatchFileEntry> _collectBatchFiles(Part part) {
  final metadata = part.toolMetadata;
  final files = metadata?['files'];
  if (files is! List || files.isEmpty) return const [];

  final faithfulByFile = _splitPatchTextByFile(
    _str(part.toolInput['patchText'] ?? part.toolInput['patch']),
  );
  final entries = <_BatchFileEntry>[];
  for (final raw in files) {
    if (raw is! Map) continue;
    final relativePath = _str(raw['relativePath']);
    final filePath = _str(raw['filePath']);
    final movePath = _str(raw['movePath']);
    final displayPath = movePath.isNotEmpty
        ? movePath
        : relativePath.isNotEmpty
        ? relativePath
        : filePath;
    final patch = _str(raw['patch'] ?? raw['diff']);
    if (displayPath.isEmpty && patch.isEmpty) continue;

    entries.add(
      _BatchFileEntry(
        displayPath: displayPath.isNotEmpty ? displayPath : '(unknown)',
        type: _str(raw['type']).isNotEmpty ? _str(raw['type']) : 'update',
        patch: patch,
        additions: (raw['additions'] as num?)?.toInt() ?? 0,
        deletions: (raw['deletions'] as num?)?.toInt() ?? 0,
        faithfulLines: _matchFaithfulLines(
          faithfulByFile,
          relativePath,
          filePath,
        ),
      ),
    );
  }
  return _mergeBatchFiles(entries);
}

List<_BatchFileEntry> _mergeBatchFiles(List<_BatchFileEntry> entries) {
  if (entries.length < 2) return entries;

  final merged = <String, _MutableBatchFileEntry>{};
  final order = <String>[];
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final path = entry.displayPath == '(unknown)' ? '' : entry.displayPath;
    final key = path.isEmpty ? '#unknown:$i' : _normalizeBatchPath(path);
    final current = merged[key];
    if (current == null) {
      merged[key] = _MutableBatchFileEntry(entry);
      order.add(key);
    } else {
      current.add(entry);
    }
  }

  return [for (final key in order) merged[key]!.build()];
}

String _normalizeBatchPath(String path) => path.replaceAll('\\', '/');

class _MutableBatchFileEntry {
  final String displayPath;
  final List<String> types;
  final List<String> patches;
  final List<String> faithfulLines;
  int additions;
  int deletions;

  _MutableBatchFileEntry(_BatchFileEntry entry)
    : displayPath = entry.displayPath,
      types = [entry.type],
      patches = [if (entry.patch.isNotEmpty) entry.patch],
      faithfulLines = [...entry.faithfulLines],
      additions = entry.additions,
      deletions = entry.deletions;

  void add(_BatchFileEntry entry) {
    types.add(entry.type);
    if (entry.patch.isNotEmpty) patches.add(entry.patch);
    faithfulLines.addAll(entry.faithfulLines);
    additions += entry.additions;
    deletions += entry.deletions;
  }

  _BatchFileEntry build() {
    return _BatchFileEntry(
      displayPath: displayPath,
      type: _mergedBatchType(types),
      patch: patches.join('\n'),
      additions: additions,
      deletions: deletions,
      faithfulLines: faithfulLines,
    );
  }
}

String _mergedBatchType(List<String> types) {
  if (types.isEmpty) return 'update';
  final unique = types.toSet();
  if (unique.length == 1) return unique.first;
  if (unique.contains('move')) return 'move';
  return 'update';
}

String _str(Object? value) => value is String ? value : '';

String _typeLabel(String type) {
  switch (type) {
    case 'add':
      return 'Add';
    case 'delete':
      return 'Delete';
    case 'move':
      return 'Move';
    case 'update':
    default:
      return 'Update';
  }
}

final _hunkHeaderRe = RegExp(
  r'^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@',
);

List<_BatchDiffLine> _parseUnifiedDiff(
  String patch, {
  String restoreIndent = '',
}) {
  final lines = patch.replaceAll('\r\n', '\n').split('\n');
  final result = <_BatchDiffLine>[];
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
    if (line.isEmpty) continue;
    if (line.startsWith('\\')) continue;

    final marker = line[0];
    final raw = line.substring(1);
    final content = restoreIndent.isEmpty || raw.isEmpty
        ? raw
        : restoreIndent + raw;
    if (marker == '-') {
      result.add(
        _BatchDiffLine(_BatchDiffType.removed, content, oldLineNum: oldLine),
      );
      oldLine++;
    } else if (marker == '+') {
      result.add(
        _BatchDiffLine(_BatchDiffType.added, content, newLineNum: newLine),
      );
      newLine++;
    } else if (marker == ' ') {
      result.add(
        _BatchDiffLine(
          _BatchDiffType.unchanged,
          content,
          oldLineNum: oldLine,
          newLineNum: newLine,
        ),
      );
      oldLine++;
      newLine++;
    }
  }

  return sawHunk ? result : const [];
}

List<_BatchDiffLine> _parseLoosePatch(String patch) {
  final result = <_BatchDiffLine>[];
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
      result.add(_BatchDiffLine(_BatchDiffType.removed, line.substring(1)));
    } else if (line.startsWith('+')) {
      result.add(_BatchDiffLine(_BatchDiffType.added, line.substring(1)));
    } else if (line.startsWith(' ')) {
      result.add(_BatchDiffLine(_BatchDiffType.unchanged, line.substring(1)));
    }
  }
  return result;
}

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
    if (faithfulSet.contains(trimmed)) return '';
    for (final faithful in faithfulLines) {
      if (faithful.length > trimmed.length && faithful.endsWith(trimmed)) {
        final prefix = faithful.substring(0, faithful.length - trimmed.length);
        if (prefix.trim().isEmpty) return prefix;
      }
    }
  }
  return '';
}

Map<String, List<String>> _splitPatchTextByFile(String patchText) {
  final result = <String, List<String>>{};
  if (patchText.isEmpty) return result;
  final fileRe = RegExp(r'^\*\*\* (?:Update|Add|Delete) File: (.+)$');
  String? current;
  List<String>? lines;
  void flush() {
    final path = current;
    final fileLines = lines;
    if (path != null && fileLines != null) {
      result.putIfAbsent(path, () => <String>[]).addAll(fileLines);
    }
  }

  for (final line in patchText.replaceAll('\r\n', '\n').split('\n')) {
    final fileMatch = fileRe.firstMatch(line);
    if (fileMatch != null) {
      flush();
      current = fileMatch.group(1)!.trim().replaceAll('\\', '/');
      lines = <String>[];
      continue;
    }
    if (line.startsWith('*** ') || line.startsWith('@@')) continue;
    if (lines != null && line.isNotEmpty) {
      final marker = line[0];
      if (marker == ' ' || marker == '+' || marker == '-') {
        lines.add(line.substring(1));
      }
    }
  }
  flush();
  return result;
}

List<String> _matchFaithfulLines(
  Map<String, List<String>> byFile,
  String relativePath,
  String filePath,
) {
  if (byFile.isEmpty) return const [];
  if (byFile.length == 1) return byFile.values.first;
  final candidates = [
    relativePath,
    filePath,
  ].where((p) => p.isNotEmpty).map((p) => p.replaceAll('\\', '/')).toList();
  for (final key in byFile.keys) {
    for (final candidate in candidates) {
      if (key == candidate ||
          key.endsWith('/$candidate') ||
          candidate.endsWith('/$key')) {
        return byFile[key]!;
      }
    }
  }
  return const [];
}
