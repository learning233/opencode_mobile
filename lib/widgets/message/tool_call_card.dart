import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../utils/tool_call_detector.dart';
import 'markdown_view.dart';

/// Permission-style card when tool-call XML is detected in assistant text.
class ToolCallCard extends StatefulWidget {
  final ToolCallInfo toolCall;
  final String sessionId;
  final String partId;
  final String originalText;

  const ToolCallCard({
    super.key,
    required this.toolCall,
    required this.sessionId,
    required this.partId,
    this.originalText = '',
  });

  @override
  State<ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<ToolCallCard> {
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();
    final responded = ctrl
        .stateOf(widget.sessionId)
        .respondedToolCallIds
        .contains(widget.partId);

    // Already answered (Allow/Deny): render the original text instead of the
    // permission card, and never re-offer the buttons (session-scoped state
    // survives lazy-list rebuilds, so no duplicate approval can be sent).
    if (responded) {
      final text = widget.originalText;
      if (text.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
        child: MarkdownView(content: text),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    Map<String, dynamic> perm = {};
    try {
      perm = Get.find<SettingsController>().permission ?? {};
    } catch (_) {}
    final currentPerm = SettingsController.permissionFor(
      perm,
      widget.toolCall.toolName,
    );

    final paramLines = widget.toolCall.params.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E1C0F) : const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: currentPerm == 'deny'
              ? Colors.red.withValues(alpha: 0.5)
              : const Color(0xFFE28743).withValues(alpha: isDark ? 0.35 : 0.6),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: currentPerm == 'deny'
                      ? Colors.red.withValues(alpha: 0.15)
                      : const Color(0xFFE28743).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  currentPerm == 'deny'
                      ? CupertinoIcons.xmark_circle
                      : CupertinoIcons.shield_fill,
                  color: currentPerm == 'deny'
                      ? Colors.red
                      : const Color(0xFFE28743),
                  size: 13,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentPerm == 'deny' ? 'Denied' : 'Permission request',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: currentPerm == 'deny'
                        ? Colors.red
                        : const Color(0xFFE28743),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: currentPerm == 'deny'
                      ? Colors.red.withValues(alpha: 0.2)
                      : const Color(0xFFE28743).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  currentPerm == 'deny' ? 'DENIED' : 'PENDING',
                  style: TextStyle(
                    fontSize: 9,
                    color: currentPerm == 'deny'
                        ? Colors.red
                        : const Color(0xFFE28743),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Requesting tool: ${widget.toolCall.toolName}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (paramLines.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1F29)
                    : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: theme.dividerColor.withValues(
                    alpha: isDark ? 0.15 : 0.3,
                  ),
                  width: 0.5,
                ),
              ),
              child: Text(
                paramLines,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFFE5C07B)
                      : const Color(0xFFB57C1E),
                ),
              ),
            ),
          ],
          if (currentPerm != 'deny') ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _handleDeny,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: theme.colorScheme.error.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    minimumSize: const Size(64, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Deny',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleAllow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    minimumSize: const Size(72, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Allow',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleAllow() {
    final ctrl = Get.find<SessionController>();
    ctrl.stateOf(widget.sessionId).respondedToolCallIds.add(widget.partId);
    setState(() {});
    unawaited(
      ctrl.sendPrompt(
        'Approved tool: ${widget.toolCall.toolName}',
        targetSessionId: widget.sessionId,
      ),
    );
  }

  void _handleDeny() {
    final ctrl = Get.find<SessionController>();
    ctrl.stateOf(widget.sessionId).respondedToolCallIds.add(widget.partId);
    setState(() {});
    unawaited(
      ctrl.sendPrompt(
        'Denied tool: ${widget.toolCall.toolName}',
        targetSessionId: widget.sessionId,
      ),
    );
  }
}
