import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../api/models/snapshot_file_diff.dart';
import '../../../../controllers/session_controller.dart';
import '../../../../controllers/tablet_tool_controller.dart';
import '../../../../utils/app_logger.dart';
import '../../../../utils/diff_paths.dart';
import '../../../../utils/layout_utils.dart';
import '../../../../utils/translations.dart';
import '../../../../widgets/detail_bottom_sheet.dart';
import '../../../tablet/diff_view.dart';

/// Compact file-change summary card. Tapping opens a BottomSheet modal
/// that fetches `GET /session/$sessionId/diff?messageID=$userMessageId` on demand
/// to display the exact server Git Snapshot unified diffs.
///
/// On tablet layouts the tap instead jumps to the right-side Review tab
/// scoped to this message.
class MessageDiffCard extends StatefulWidget {
  final String sessionId;
  final String userMessageId;
  final List<SnapshotFileDiff> diffs;

  const MessageDiffCard({
    super.key,
    required this.sessionId,
    required this.userMessageId,
    required this.diffs,
  });

  @override
  State<MessageDiffCard> createState() => _MessageDiffCardState();
}

class _MessageDiffCardState extends State<MessageDiffCard> {
  /// 本卡片自身的选中文件（仅用于高亮）。独立于 Review tab 的
  /// `reviewSelectedFile`，避免点其他卡片/列表时此处跟着变。
  String _selected = '';

  void _handleTap() {
    final context = this.context;
    if (isTabletLayout(context)) {
      Get.find<TabletToolController>().openReviewMessage(
        widget.sessionId,
        widget.userMessageId,
      );
      return;
    }
    showDetailBottomSheet(
      context: context,
      title: LocaleKeys.chatChangedFilesTitle.tr,
      bodyBuilder: (ctx) => _DiffSheetContent(
        sessionId: widget.sessionId,
        userMessageId: widget.userMessageId,
        fallbackDiffs: widget.diffs,
      ),
    );
  }

  void _handleFileTap(String file) {
    setState(() {
      _selected = file;
    });
    Get.find<TabletToolController>().openReviewMessageFile(
      widget.sessionId,
      widget.userMessageId,
      selectFile: file,
    );
  }

  @override
  Widget build(BuildContext context) {
    final diffs = widget.diffs;
    if (diffs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTablet = isTabletLayout(context);
    var totalAdd = 0;
    var totalDel = 0;
    for (final d in diffs) {
      totalAdd += d.additions;
      totalDel += d.deletions;
    }

    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.doc_text,
            size: 13,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            LocaleKeys.chatChangedFilesTitle.tr,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${diffs.length}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const Spacer(),
          if (totalAdd > 0)
            Text(
              '+$totalAdd',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4CAF50),
              ),
            ),
          if (totalAdd > 0 && totalDel > 0) const SizedBox(width: 6),
          if (totalDel > 0)
            Text(
              '-$totalDel',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE57373),
              ),
            ),
          const SizedBox(width: 6),
          Icon(
            CupertinoIcons.chevron_right,
            size: 12,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
          ),
        ],
      ),
    );

    final fileList = Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: isTablet
          // 高亮取本卡片本地 _selected，各卡片/列表互不影响。
          ? Column(
              children: [
                for (final d in diffs)
                  _FileRow(
                    diff: d,
                    onTap: () => _handleFileTap(d.file),
                    selectedFile: _selected,
                  ),
              ],
            )
          : Column(children: [for (final d in diffs) _FileRow(diff: d)]),
    );

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F29) : const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.15 : 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: isTablet
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(onTap: _handleTap, child: header),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
                fileList,
              ],
            )
          : InkWell(
              onTap: _handleTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  header,
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                  fileList,
                ],
              ),
            ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final SnapshotFileDiff diff;

  /// When set (tablet layout), the row becomes tappable and highlights when it
  /// matches the file selected in the Review tab. Null on phone keeps the row
  /// inert exactly as before.
  final VoidCallback? onTap;

  /// Current Review-tab selected file (tablet layout). The enclosing single
  /// Obx supplies this so rows don't each subscribe to the selection Rx.
  final String? selectedFile;

  const _FileRow({required this.diff, this.onTap, this.selectedFile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: _buildRow(context, theme, active: false),
      );
    }
    final active = diffPathsEqual(selectedFile ?? '', diff.file);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: _buildRow(context, theme, active: active),
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    ThemeData theme, {
    required bool active,
  }) {
    return Row(
      children: [
        Icon(
          _statusIcon(diff.status),
          size: 12,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            diff.displayName,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11.5,
              fontFamily: 'monospace',
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active
                  ? theme.colorScheme.primary
                  : theme.textTheme.bodySmall?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (diff.additions > 0)
          Text(
            '+${diff.additions}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4CAF50),
            ),
          ),
        if (diff.additions > 0 && diff.deletions > 0) const SizedBox(width: 4),
        if (diff.deletions > 0)
          Text(
            '-${diff.deletions}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE57373),
            ),
          ),
      ],
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'added':
        return CupertinoIcons.plus_circle;
      case 'deleted':
        return CupertinoIcons.minus_circle;
      default:
        return CupertinoIcons.pencil_circle;
    }
  }
}

/// Content inside the Detail BottomSheet. On creation, fetches
/// `GET /session/$sessionId/diff?messageID=$userMessageId` on demand.
class _DiffSheetContent extends StatefulWidget {
  final String sessionId;
  final String userMessageId;
  final List<SnapshotFileDiff> fallbackDiffs;

  const _DiffSheetContent({
    required this.sessionId,
    required this.userMessageId,
    required this.fallbackDiffs,
  });

  @override
  State<_DiffSheetContent> createState() => _DiffSheetContentState();
}

class _DiffSheetContentState extends State<_DiffSheetContent> {
  bool _loading = true;
  List<SnapshotFileDiff> _diffs = const [];

  @override
  void initState() {
    super.initState();
    _fetchDiffs();
  }

  Future<void> _fetchDiffs() async {
    if (widget.sessionId.isEmpty || widget.userMessageId.isEmpty) {
      if (mounted) {
        setState(() {
          _diffs = widget.fallbackDiffs;
          _loading = false;
        });
      }
      return;
    }

    try {
      final sessionCtrl = Get.find<SessionController>();
      final parsed = await sessionCtrl.fetchMessageDiff(
        widget.sessionId,
        widget.userMessageId,
      );

      if (mounted) {
        setState(() {
          _diffs = parsed.isNotEmpty ? parsed : widget.fallbackDiffs;
          _loading = false;
        });
        return;
      }
    } catch (e) {
      AppLogger.e('_DiffSheetContent fetch failed: $e');
    }

    if (mounted) {
      setState(() {
        _diffs = widget.fallbackDiffs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    if (_diffs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(LocaleKeys.mobileNoDiff.tr),
        ),
      );
    }

    // 单文件：上限取 sheet 视口高（内容放得下就不内部滚动）；
    // 多文件：保留固定上限，避免每个文件按内容撑高、虚拟化失效。
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cap = _diffs.length == 1
            ? (constraints.maxHeight.isFinite ? constraints.maxHeight : 320.0)
            : 320.0;
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _diffs.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                DiffFileView(diff: _diffs[i], maxHeight: cap),
              ],
            ],
          ),
        );
      },
    );
  }
}
