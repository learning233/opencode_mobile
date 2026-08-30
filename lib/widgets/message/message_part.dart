import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../api/models/message.dart';
import '../../controllers/session_controller.dart';
import '../../utils/app_logger.dart';
import '../../utils/image_cache.dart';
import '../../utils/tool_call_detector.dart';
import 'compaction_part.dart';
import 'markdown_view.dart';
import 'reasoning_part.dart';
import 'tool_call_card.dart';
import 'tool_cards/subtask_header_card.dart';
import 'tool_cards/tool_part_dispatcher.dart';

/// 文本 part 中遗留 thinking 标记的清理模式（历史格式兼容）。
final RegExp _thinkingTagPattern = RegExp(
  r'</?thinking>',
  caseSensitive: false,
);

/// file:// 附件图片的 provider 缓存：同一路径复用同一 MemoryImage 实例，
/// 滚动往返（State 销毁重建）命中 Flutter ImageCache，跳过重复 IO + 解码。
/// FIFO 上限防无界增长。
final Map<String, MemoryImage> _fileImageProviderCache = {};
const int _fileImageCacheLimit = 32;

/// data: URI 附件图片的 provider 缓存（G3）：key 为 `$messageID:$partId`，
/// 与 file:// 同模式——滚动往返直接复用已解码 provider 命中 ImageCache，
/// 跳过磁盘读 + 解码（磁盘缓存只做冷启动兜底）。FIFO 上限防无界增长。
final Map<String, MemoryImage> _dataImageProviderCache = {};
const int _dataImageCacheLimit = 32;

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
        if (isStreaming && sessionId != null && sessionId!.isNotEmpty) {
          // 流式中的文本改读细粒度通道（delta flush 不再更新列表，见
          // SessionRuntimeState.streamingPartText），仅本部件局部重建。
          return _StreamingTextMarkdown(part: part, sessionId: sessionId!);
        }
        var text = part.text;
        if (text.isEmpty && !isStreaming) return const SizedBox.shrink();
        text = text.replaceAll(_thinkingTagPattern, '');
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

  /// 图片缓存 provider（命中时替代逐次 IO/解码渲染路径）。file:// 与 data:
  /// 两条路径共用：分别由各自的顶层 provider 缓存（_fileImageProviderCache /
  /// _dataImageProviderCache）填充。
  MemoryImage? _fileImage;

  @override
  void initState() {
    super.initState();
    _detectAndLoad();
  }

  @override
  void didUpdateWidget(covariant _FileAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.part.fileUrl != widget.part.fileUrl) {
      _fileImage = null;
      _detectAndLoad();
    }
  }

  void _detectAndLoad() {
    final part = widget.part;
    final mime = part.fileMime.toLowerCase();
    final name =
        (part.fileName.isNotEmpty
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
      // G3：内存 provider 缓存优先（key `$messageID:$partId`，FIFO 上限 32）
      // ——滚动往返（State 销毁重建）直接复用已解码 provider，跳过磁盘 IO
      // 与解码。磁盘缓存只做冷启动兜底；缓存也无条目时退回解码 data: URL。
      final key = '${widget.part.messageID}:${widget.part.id}';
      final cachedProvider = _dataImageProviderCache[key];
      if (cachedProvider != null) {
        if (!mounted) return;
        setState(() => _fileImage = cachedProvider);
        return;
      }
      MemoryImage? provider;
      final cached = await defaultImageCache.find(
        widget.part.messageID,
        widget.part.id,
      );
      if (cached != null) {
        try {
          provider = MemoryImage(await cached.readAsBytes());
        } catch (e) {
          AppLogger.e('_FileAttachment load cached image failed: $e');
        }
      }
      if (provider == null) {
        final comma = url.indexOf(',');
        if (comma == -1) return;
        try {
          provider = MemoryImage(base64Decode(url.substring(comma + 1)));
        } catch (e) {
          AppLogger.e('_FileAttachment decode data image failed: $e');
          return;
        }
      }
      if (_dataImageProviderCache.length >= _dataImageCacheLimit) {
        _dataImageProviderCache.remove(_dataImageProviderCache.keys.first);
      }
      _dataImageProviderCache[key] = provider;
      if (!mounted) return;
      setState(() => _fileImage = provider);
      return;
    }
    if (!url.startsWith('file://')) return;
    try {
      final path = Uri.parse(url).toFilePath();
      // provider 缓存命中：跳过 IO 与解码（State 滚出视口销毁、滚回重建时
      // 会重新走 initState 加载，未缓存前每次都重复 readAsBytes）。
      final cached = _fileImageProviderCache[path];
      if (cached != null) {
        if (!mounted) return;
        setState(() => _fileImage = cached);
        return;
      }
      final file = File(path);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final provider = MemoryImage(bytes);
      if (_fileImageProviderCache.length >= _fileImageCacheLimit) {
        _fileImageProviderCache.remove(_fileImageProviderCache.keys.first);
      }
      _fileImageProviderCache[path] = provider;
      if (!mounted) return;
      setState(() => _fileImage = provider);
    } catch (e) {
      AppLogger.e('_FileAttachment load image failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage) {
      final image = _fileImage;
      if (image != null) {
        return _ImageAttachmentThumbnail(image: image);
      }
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
  /// 已缓存的解码 provider（file:// 与 data: 两条路径统一，见
  /// _FileAttachmentState._fileImage）。
  final MemoryImage image;

  const _ImageAttachmentThumbnail({required this.image});

  void _showPreview(BuildContext context) {
    // 解码宽度按屏幕物理分辨率封顶（见 build 内预览分支的注释）。
    final previewWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round();
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
                    // 预览按屏幕物理分辨率限制解码宽度：保持 1:1 观感的同时
                    // 避免全尺寸位图的内存尖峰（放大超过 1x 后略糊，可接受）。
                    // Image 主构造器无 cacheWidth，用 ResizeImage 限制解码
                    // 尺寸（内部 provider 实例不变，同尺寸解码仍命中
                    // ImageCache）。
                    child: Image(
                      image: ResizeImage(image, width: previewWidth),
                      fit: BoxFit.contain,
                    ),
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
            // 缩略图无需全分辨率解码（点击预览另有全尺寸入口），
            // 限制缓存尺寸避免长会话多图时内存放大。
            child: Image(
              image: ResizeImage(image, width: 440),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// 流式中的文本 part：订阅 [SessionRuntimeState.streamingPartText] 的
/// per-part RxString，delta flush 时仅本部件局部重建（列表不再整表广播）。
/// 流结束（isGenerating 翻转 / 通道 finalize 落库）后，上层改走普通
/// part.text 渲染路径，本部件随之卸载。
class _StreamingTextMarkdown extends StatefulWidget {
  final Part part;
  final String sessionId;

  const _StreamingTextMarkdown({required this.part, required this.sessionId});

  @override
  State<_StreamingTextMarkdown> createState() => _StreamingTextMarkdownState();
}

class _StreamingTextMarkdownState extends State<_StreamingTextMarkdown> {
  RxString? _rx;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant _StreamingTextMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.part.id != widget.part.id ||
        oldWidget.sessionId != widget.sessionId) {
      _attach();
    }
  }

  void _attach() {
    try {
      final state =
          Get.find<SessionController>().sessionRuntimeStates[widget.sessionId];
      if (state == null) {
        _rx = null;
        return;
      }
      // 通道项由 delta flush（_applyPartDelta）与本部件共同惰性创建，
      // 初值都取列表当前文本，两侧一致。
      _rx = state.streamingPartText.putIfAbsent(
        '${widget.part.id}\u0000text',
        () => widget.part.text.obs,
      );
    } catch (_) {
      _rx = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rx = _rx;
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
      child: rx != null
          ? Obx(() {
              final text = rx.value.replaceAll(_thinkingTagPattern, '');
              return MarkdownView(content: text, isStreaming: true);
            })
          : MarkdownView(content: widget.part.text, isStreaming: true),
    );
  }
}
