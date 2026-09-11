import 'package:flutter/material.dart';

import '../../../api/models/snapshot_file_diff.dart';
import '../../../models/diff_line.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/file_kind.dart';
import 'diff_code_view.dart';
import 'multi_view/audio_player_view.dart';
import 'multi_view/image_viewer.dart';

/// Shared single-file diff viewer with full unified-diff patch rendering.
///
/// Extracted from `message_diff_card.dart` so message bottom sheets render
/// patches identically. [SnapshotFileDiff] is used because both
/// `GET /session/{id}/diff` and `GET /vcs/diff` return the same
/// `{file, patch, additions, deletions, status}` shape.
///
/// The code body is a [DiffCodeView] (re_editor 行虚拟化), so the diff no
/// longer builds all rows at once nor relies on `IntrinsicWidth`. Height is
/// capped by [maxHeight] so each file gets its own scroll region in sheets.
class DiffFileView extends StatefulWidget {
  final SnapshotFileDiff diff;

  /// Whether to show the file path header (name + +/- stats) above the diff.
  final bool showHeader;

  /// Whether to show the leading line-number column per diff row.
  final bool showLineNumbers;

  /// Whether to hide unchanged context lines and render only changed lines.
  final bool hideContextLines;

  /// Sheet 内高度上限：`min(内容高, maxHeight)`，保证 re_editor 纵向虚拟化生效。
  final double? maxHeight;

  /// 文件所属 worktree（多 worktree/E2B 下图片/音频按此目录读取）。
  /// null 时回退到当前活跃项目（单工作区行为不变）。
  final String? worktree;

  const DiffFileView({
    super.key,
    required this.diff,
    this.showHeader = true,
    this.showLineNumbers = true,
    this.hideContextLines = false,
    this.maxHeight = 320,
    this.worktree,
  });

  @override
  State<DiffFileView> createState() => _DiffFileViewState();
}

class _DiffFileViewState extends State<DiffFileView> {
  List<DiffLine> _lines = const [];

  @override
  void initState() {
    super.initState();
    _lines = parsePatchLines(widget.diff.patch);
  }

  @override
  void didUpdateWidget(DiffFileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diff.patch != widget.diff.patch) {
      _lines = parsePatchLines(widget.diff.patch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final isDark = theme.brightness == Brightness.dark;

    final lines = _lines;

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
          // File path header
          if (widget.showHeader) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: theme.dividerColor.withValues(alpha: isDark ? 0.1 : 0.05),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.diff.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  if (widget.diff.additions > 0)
                    Text(
                      '+${widget.diff.additions} ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: appColors.success,
                      ),
                    ),
                  if (widget.diff.deletions > 0)
                    Text(
                      '-${widget.diff.deletions}',
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
          ],

          // Binary (Image / Audio) or Code Diff Lines
          if (isImageFilePath(widget.diff.file))
            if (widget.diff.status == 'deleted')
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Image file deleted.',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            else if (!isPreviewableImageFilePath(widget.diff.file))
              _UnsupportedImageBlock(
                filePath: widget.diff.file,
                patch: widget.diff.patch,
                lines: lines,
                hideContextLines: widget.hideContextLines,
                showLineNumbers: widget.showLineNumbers,
                maxHeight: widget.maxHeight,
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxHeight ?? 320),
                child: ImageViewer(
                  key: ValueKey(
                    'diff_image_${widget.worktree ?? ''}_${widget.diff.file}',
                  ),
                  filePath: widget.diff.file,
                  worktree: widget.worktree,
                ),
              )
          else if (isAudioFilePath(widget.diff.file))
            if (widget.diff.status == 'deleted')
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Audio file deleted.',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxHeight ?? 320),
                child: AudioPlayerView(
                  key: ValueKey(
                    'diff_audio_${widget.worktree ?? ''}_${widget.diff.file}',
                  ),
                  filePath: widget.diff.file,
                  worktree: widget.worktree,
                ),
              )
          else if (lines.isEmpty || widget.diff.patch.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'No patch preview available.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            )
          else
            DiffCodeView(
              lines: lines,
              hideContextLines: widget.hideContextLines,
              showLineNumbers: widget.showLineNumbers,
              maxHeight: widget.maxHeight,
            ),
        ],
      ),
    );
  }
}

/// 非原生可解码图片（svg/ico/tiff/avif/heic 等）的占位：
/// 显示“不支持”而非空白；若有 patch 文本则继续展示 patch，避免信息丢失。
class _UnsupportedImageBlock extends StatelessWidget {
  final String filePath;
  final String patch;
  final List<DiffLine> lines;
  final bool hideContextLines;
  final bool showLineNumbers;
  final double? maxHeight;

  const _UnsupportedImageBlock({
    required this.filePath,
    required this.patch,
    required this.lines,
    required this.hideContextLines,
    required this.showLineNumbers,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hide_image_outlined,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Unsupported image format',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$filePath\nPNG / JPG / GIF / WebP / BMP / WBMP 以外暂不支持预览',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
        if (lines.isNotEmpty && patch.trim().isNotEmpty)
          DiffCodeView(
            lines: lines,
            hideContextLines: hideContextLines,
            showLineNumbers: showLineNumbers,
            maxHeight: maxHeight,
          ),
      ],
    );
  }
}

/// Parses a unified diff patch into typed lines for rendering.
List<DiffLine> parsePatchLines(String patch) {
  if (patch.trim().isEmpty) return const [];
  final lines = patch.replaceAll('\r\n', '\n').split('\n');
  final result = <DiffLine>[];
  final hunkRe = RegExp(r'^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@');
  var oldLine = 1;
  var newLine = 1;
  var sawHunk = false;

  for (final line in lines) {
    final match = hunkRe.firstMatch(line);
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
    if (line.isEmpty || line.startsWith('\\')) continue;

    final marker = line[0];
    final content = line.substring(1);
    if (marker == '-') {
      result.add(DiffLine(DiffLineType.removed, content, oldLineNum: oldLine));
      oldLine++;
    } else if (marker == '+') {
      result.add(DiffLine(DiffLineType.added, content, newLineNum: newLine));
      newLine++;
    } else if (marker == ' ') {
      result.add(
        DiffLine(
          DiffLineType.unchanged,
          content,
          oldLineNum: oldLine,
          newLineNum: newLine,
        ),
      );
      oldLine++;
      newLine++;
    }
  }

  if (!sawHunk) {
    // Fallback for loose patches
    for (final line in lines) {
      if (line.startsWith('+') && !line.startsWith('+++ ')) {
        result.add(DiffLine(DiffLineType.added, line.substring(1)));
      } else if (line.startsWith('-') && !line.startsWith('--- ')) {
        result.add(DiffLine(DiffLineType.removed, line.substring(1)));
      } else if (line.startsWith(' ')) {
        result.add(DiffLine(DiffLineType.unchanged, line.substring(1)));
      }
    }
  }

  return result;
}

/// Splits parsed diff lines into change blocks: runs of consecutive
/// [DiffLineType.added] / [DiffLineType.removed] lines separated by at least
/// one unchanged line. Returns each block's inclusive `[start, end]` line
/// indices into [lines]. Used for change-to-change navigation.
List<List<int>> computeChangeBlocks(List<DiffLine> lines) {
  final blocks = <List<int>>[];
  var start = -1;
  for (var i = 0; i < lines.length; i++) {
    final isChange =
        lines[i].type == DiffLineType.added ||
        lines[i].type == DiffLineType.removed;
    if (isChange && start == -1) start = i;
    if (!isChange && start != -1) {
      blocks.add([start, i - 1]);
      start = -1;
    }
  }
  if (start != -1) blocks.add([start, lines.length - 1]);
  return blocks;
}
