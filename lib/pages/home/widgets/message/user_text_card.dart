import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../utils/translations.dart';
import '../../../../api/models/message.dart';
import '../../../../api/models/snapshot_file_diff.dart';
import '../../../../controllers/session_controller.dart';
import '../../../../models/session_runtime_state.dart';
import '../../../../utils/app_logger.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/snackbar_utils.dart';

/// User message text — aligned with desktop UserTextCard:
/// collapsed uses [Text] with maxLines: 5 + ellipsis (height follows real lines).
/// Action buttons sit below the box (mobile).
class UserTextCard extends StatefulWidget {
  final MessageModel message;
  final String displayText;

  const UserTextCard({
    super.key,
    required this.message,
    required this.displayText,
  });

  @override
  State<UserTextCard> createState() => _UserTextCardState();
}

class _UserTextCardState extends State<UserTextCard> {
  bool _isExpanded = false;

  String? _measuredText;
  TextStyle? _measuredStyle;
  double? _measuredWidth;
  bool _cachedIsLongText = false;

  /// TextPainter measurement is cached per (content, style, width): the whole
  /// timeline rebuilds on every streaming delta flush, and this layout work
  /// would otherwise re-run for every user message each time.
  bool _isLongText(String content, TextStyle? style, double maxWidth) {
    if (_measuredText == content &&
        _measuredStyle == style &&
        _measuredWidth == maxWidth) {
      return _cachedIsLongText;
    }
    _measuredText = content;
    _measuredStyle = style;
    _measuredWidth = maxWidth;
    final textPainter = TextPainter(
      text: TextSpan(text: content, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: maxWidth > 0 ? maxWidth : 100.0);
    _cachedIsLongText = textPainter.computeLineMetrics().length > 5;
    return _cachedIsLongText;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = widget.displayText;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13.5,
      height: 1.5,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Same measurement as desktop: real line count under card width.
        final textMaxWidth = constraints.maxWidth - 24;
        final isLongText = _isLongText(
          content,
          textStyle,
          textMaxWidth > 0 ? textMaxWidth : 100.0,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            TapRegion(
              onTapOutside: (_) {
                if (_isExpanded) setState(() => _isExpanded = false);
              },
              child: GestureDetector(
                onTap: () {
                  if (isLongText && !_isExpanded) {
                    setState(() => _isExpanded = true);
                  }
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 120),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: PremiumColors.inputBg(theme.brightness),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: PremiumColors.divider(
                          theme.brightness,
                        ).withValues(alpha: 0.55),
                        width: 0.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            // Desktop uses Text (not SelectableText) so maxLines
                            // only sizes to real line count — "?" stays one line.
                            child: Text(
                              content,
                              maxLines: _isExpanded ? null : 5,
                              overflow: _isExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: textStyle,
                            ),
                          ),
                          if (isLongText && !_isExpanded) ...[
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 48,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      PremiumColors.inputBg(
                                        theme.brightness,
                                      ).withValues(alpha: 0.0),
                                      PremiumColors.inputBg(
                                        theme.brightness,
                                      ).withValues(alpha: 0.85),
                                      PremiumColors.inputBg(theme.brightness),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 2,
                              child: Center(
                                child: Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 14,
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _UserActionBar(message: widget.message, displayText: content),
          ],
        );
      },
    );
  }
}

class _UserActionBar extends StatefulWidget {
  final MessageModel message;
  final String displayText;

  const _UserActionBar({required this.message, required this.displayText});

  @override
  State<_UserActionBar> createState() => _UserActionBarState();
}

class _UserActionBarState extends State<_UserActionBar> {
  bool _copied = false;
  bool _forking = false;
  bool _reverting = false;

  Future<void> _handleCopy() async {
    final text = widget.displayText.isNotEmpty
        ? widget.displayText
        : widget.message.content;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _handleFork() async {
    if (_forking) return;
    setState(() => _forking = true);
    try {
      await Get.find<SessionController>().forkSessionAt(widget.message.id);
    } finally {
      if (mounted) setState(() => _forking = false);
    }
  }

  Future<void> _handleRevert() async {
    if (_reverting) return;
    final controller = Get.find<SessionController>();
    final state = controller.stateOf(widget.message.sessionID);
    if (state.isGenerating.value) {
      Snack.warning(LocaleKeys.shRevertBlockedGenerating.tr);
      return;
    }
    final preview = _computeRevertPreview(state);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.shConfirmRevert.tr),
        content: _RevertPreviewContent(preview: preview),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(LocaleKeys.cancel.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(LocaleKeys.shConfirmRevert.tr),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _reverting = true);
    try {
      await controller.revertMessage(widget.message.id);
    } catch (e) {
      AppLogger.e('UserTextCard revert: $e');
    } finally {
      if (mounted) setState(() => _reverting = false);
    }
  }

  /// Aggregates the file impact of all messages that would be hidden when
  /// reverting to this message (i.e. this message onwards in the timeline).
  ({int files, int additions, int deletions}) _computeRevertPreview(
    SessionRuntimeState state,
  ) {
    final allMsgs = state.messages;
    final idx = allMsgs.indexWhere((m) => m.id == widget.message.id);
    if (idx < 0) return (files: 0, additions: 0, deletions: 0);
    final map = <String, SnapshotFileDiff>{};
    void mergeDiff(SnapshotFileDiff d) {
      if (d.file.isEmpty) return;
      map[d.file] = map.containsKey(d.file)
          ? SnapshotFileDiff.merge(map[d.file]!, d)
          : d;
    }

    for (var i = idx; i < allMsgs.length; i++) {
      final msg = allMsgs[i];
      if (msg.role == MessageRole.assistant) {
        for (final d in msg.toolDiffs) {
          mergeDiff(d);
        }
      } else if (msg.role == MessageRole.user) {
        final sub = state.messageSubtaskDiffs[msg.id];
        if (sub != null) {
          for (final d in sub) {
            mergeDiff(d);
          }
        }
      }
    }
    var additions = 0;
    var deletions = 0;
    for (final d in map.values) {
      additions += d.additions;
      deletions += d.deletions;
    }
    return (files: map.length, additions: additions, deletions: deletions);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.45);

    String timeStr = '';
    final timeInfo = widget.message.time;
    if (timeInfo != null) {
      final created = timeInfo['created'] as num?;
      if (created != null) {
        try {
          final dt = DateTime.fromMillisecondsSinceEpoch(created.toInt());
          timeStr =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {}
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (timeStr.isNotEmpty) ...[
          Text(
            timeStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(width: 8),
        ],
        _ActionIcon(
          icon: _copied ? Icons.check : Icons.copy_outlined,
          color: _copied ? Colors.green : muted,
          onTap: _handleCopy,
        ),
        const SizedBox(width: 4),
        _ActionIcon(
          icon: Icons.call_split,
          color: muted,
          loading: _forking,
          onTap: _forking ? null : _handleFork,
        ),
        const SizedBox(width: 4),
        _ActionIcon(
          icon: CupertinoIcons.arrow_uturn_left,
          color: muted,
          loading: _reverting,
          onTap: _reverting ? null : _handleRevert,
        ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionIcon({
    required this.icon,
    this.color,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.2),
              )
            : Icon(icon, size: 14, color: color),
      ),
    );
  }
}

/// Revert confirm dialog body: shows the message-level description plus the
/// aggregate file impact that will be rolled back.
class _RevertPreviewContent extends StatelessWidget {
  final ({int files, int additions, int deletions}) preview;

  const _RevertPreviewContent({required this.preview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desc = LocaleKeys.shConfirmRevertDesc.tr;
    if (preview.files <= 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(desc),
          const SizedBox(height: 8),
          Text(
            LocaleKeys.shConfirmRevertNoFiles.tr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(desc),
        const SizedBox(height: 8),
        Text(
          LocaleKeys.shConfirmRevertSummary.trParams({
            'files': '${preview.files}',
            'add': '${preview.additions}',
            'del': '${preview.deletions}',
          }),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
