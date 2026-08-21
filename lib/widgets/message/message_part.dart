import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../api/models/message.dart';
import '../../utils/app_logger.dart';
import '../../utils/image_cache.dart';
import '../../utils/tool_call_detector.dart';
import 'compaction_part.dart';
import 'markdown_view.dart';
import 'reasoning_part.dart';
import 'tool_call_card.dart';
import 'tool_cards/subtask_header_card.dart';
import 'tool_cards/tool_part_dispatcher.dart';

/// Renders a single message [Part] — aligned with desktop MessagePartWidget.
class MessagePartWidget extends StatelessWidget {
  final Part part;
  final bool isStreaming;
  final String? sessionId;

  const MessagePartWidget({
    super.key,
    required this.part,
    this.isStreaming = false,
    this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (part.type) {
      case PartType.text:
        var text = part.text;
        if (text.isEmpty && !isStreaming) return const SizedBox.shrink();
        text = text.replaceAll(
          RegExp(r'</?thinking>', caseSensitive: false),
          '',
        );
        final info = !isStreaming ? ToolCallDetector.detect(text) : null;
        if (info != null) {
          return ToolCallCard(
            toolCall: info,
            sessionId: sessionId ?? part.sessionID,
            partId: part.id,
            originalText: text,
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
          child: MarkdownView(content: text, isStreaming: isStreaming),
        );

      case PartType.reasoning:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ReasoningPartWidget(
            part: part,
            isStreaming: isStreaming,
            sessionId: sessionId ?? part.sessionID,
          ),
        );

      case PartType.tool:
        return ToolPartDispatcher(
          part: part,
          isStreaming: isStreaming,
          sessionId: sessionId ?? part.sessionID,
        );

      case PartType.file:
        return _FileAttachment(part: part);

      case PartType.agent:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.smart_toy_outlined,
                size: 12,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Agent: ${part.agentName.isNotEmpty ? part.agentName : 'agent'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

      case PartType.retry:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh, size: 12, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  'Retry attempt ${part.retryAttempt}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );

      case PartType.subtask:
        return SubtaskHeaderCard(part: part);

      case PartType.compaction:
        return CompactionPartWidget(part: part);

      case PartType.stepStart:
      case PartType.stepFinish:
      case PartType.patch:
      case PartType.snapshot:
        return const SizedBox.shrink();
    }
  }
}

class _FileAttachment extends StatefulWidget {
  final Part part;

  const _FileAttachment({required this.part});

  @override
  State<_FileAttachment> createState() => _FileAttachmentState();
}

class _FileAttachmentState extends State<_FileAttachment> {
  static const _imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
  };

  bool _isImage = false;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _detectAndLoad();
  }

  @override
  void didUpdateWidget(covariant _FileAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.part.fileUrl != widget.part.fileUrl) {
      _imageBytes = null;
      _detectAndLoad();
    }
  }

  void _detectAndLoad() {
    final part = widget.part;
    final mime = part.fileMime.toLowerCase();
    final name = (part.fileName.isNotEmpty
            ? part.fileName
            : (part.raw['name']?.toString() ??
                  part.raw['path']?.toString() ??
                  ''))
        .toLowerCase();
    _isImage =
        mime.startsWith('image/') ||
        _imageExtensions.any((ext) => name.endsWith(ext));
    if (_isImage) {
      _loadImageBytes();
    }
  }

  Future<void> _loadImageBytes() async {
    final url = widget.part.fileUrl;
    if (url.startsWith('data:image/')) {
      // Prefer the local disk cache (written when the image was sent) so
      // re-rendering history does not base64-decode large strings on the main
      // thread. Falls back to decoding the data URL when the cache has no entry
      // (e.g. the app was reinstalled or the image predates the cache).
      final cached = await defaultImageCache.find(
        widget.part.messageID,
        widget.part.id,
      );
      if (cached != null) {
        try {
          final bytes = await cached.readAsBytes();
          if (!mounted) return;
          setState(() => _imageBytes = bytes);
          return;
        } catch (e) {
          AppLogger.e('_FileAttachment load cached image failed: $e');
        }
      }
      final comma = url.indexOf(',');
      if (comma == -1) return;
      try {
        final bytes = base64Decode(url.substring(comma + 1));
        if (!mounted) return;
        setState(() => _imageBytes = bytes);
      } catch (e) {
        AppLogger.e('_FileAttachment decode data image failed: $e');
      }
      return;
    }
    if (!url.startsWith('file://')) return;
    try {
      final path = Uri.parse(url).toFilePath();
      final file = File(path);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (e) {
      AppLogger.e('_FileAttachment load image failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _imageBytes;
    if (_isImage && bytes != null) {
      return _ImageAttachmentThumbnail(bytes: bytes);
    }
    return _buildFileRow(context);
  }

  Widget _buildFileRow(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = widget.part.fileName.isNotEmpty
        ? widget.part.fileName
        : (widget.part.raw['name']?.toString() ??
              widget.part.raw['path']?.toString() ??
              'File');

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.paperclip, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              fileName,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a sent image attachment as a thumbnail with tap-to-zoom preview.
class _ImageAttachmentThumbnail extends StatelessWidget {
  final Uint8List bytes;

  const _ImageAttachmentThumbnail({required this.bytes});

  void _showPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: SizedBox(
          width: MediaQuery.sizeOf(ctx).width - 16,
          height: MediaQuery.sizeOf(ctx).height * 0.85,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Center(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _showPreview(context),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7.5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
