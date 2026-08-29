import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../api/endpoints.dart';
import '../../api/opencode_client.dart';
import '../../controllers/project_controller.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../utils/app_logger.dart';
import '../../utils/translations.dart';

/// Image viewer with zoom controls and dimension info.
class ImageViewer extends StatefulWidget {
  final Uint8List? bytes;
  final String filePath;
  final String? worktree;

  const ImageViewer({
    super.key,
    this.bytes,
    required this.filePath,
    this.worktree,
  });

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  final TransformationController _controller = TransformationController();
  final ValueNotifier<double> _scaleNotifier = ValueNotifier<double>(1.0);
  final OpenCodeClient _client = OpenCodeClient();
  ui.Image? _decodedImage;
  Uint8List? _bytes;
  bool _isLoading = false;
  String? _error;
  String _fileName = '';
  int _requestSeq = 0;

  static const double _minScale = 0.1;
  static const double _maxScale = 10.0;
  static const double _scaleStep = 0.25;

  @override
  void initState() {
    super.initState();
    _fileName = widget.filePath.split(RegExp(r'[/\\]')).last;
    if (widget.bytes != null) {
      _bytes = widget.bytes;
      _decodeImageInfo();
    } else {
      if (Get.isRegistered<TabletToolController>()) {
        final cached = Get.find<TabletToolController>().cachedBinaryContent(
          widget.filePath,
          worktree: widget.worktree,
        );
        if (cached != null) {
          _bytes = cached;
          _decodeImageInfo();
          return;
        }
      }
      _isLoading = true;
      _fetchImageBytes();
    }
  }

  Future<void> _fetchImageBytes() async {
    final seq = ++_requestSeq;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final activeProject = Get.find<ProjectController>().activeProject.value;
      final directory = widget.worktree ?? activeProject?.worktree ?? '';

      final response = await _client.get(
        ApiEndpoints.fsRead(widget.filePath),
        queryParameters: {'path': widget.filePath},
        directory: directory.isNotEmpty ? directory : null,
      );

      if (seq != _requestSeq || !mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        String base64Content = '';
        if (data is Map) {
          base64Content = data['content']?.toString() ?? '';
        } else if (data is String) {
          try {
            final parsed = jsonDecode(data);
            if (parsed is Map) {
              base64Content = parsed['content']?.toString() ?? '';
            }
          } catch (_) {
            base64Content = data;
          }
        }

        final Uint8List bytes = base64Decode(
          base64Content.replaceAll(RegExp(r'\s+'), ''),
        );

        if (Get.isRegistered<TabletToolController>()) {
          Get.find<TabletToolController>().cacheBinaryContent(
            widget.filePath,
            bytes,
            worktree: widget.worktree,
          );
        }

        if (mounted) {
          setState(() {
            _bytes = bytes;
            _isLoading = false;
          });
          _decodeImageInfo();
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load image (${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      AppLogger.e('Failed to read binary file: $e');
      if (seq != _requestSeq || !mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scaleNotifier.dispose();
    _decodedImage?.dispose();
    _decodedImage = null;
    super.dispose();
  }

  Future<void> _decodeImageInfo() async {
    if (_bytes == null) return;
    try {
      final codec = await ui.instantiateImageCodec(_bytes!);
      try {
        final frame = await codec.getNextFrame();
        if (mounted) {
          _decodedImage?.dispose();
          setState(() => _decodedImage = frame.image);
        } else {
          // Widget already disposed: release the decoded frame immediately.
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // Ignore decode errors
    }
  }

  void _zoomIn() {
    final newScale = (_scaleNotifier.value + _scaleStep).clamp(
      _minScale,
      _maxScale,
    );
    _applyScale(newScale);
  }

  void _zoomOut() {
    final newScale = (_scaleNotifier.value - _scaleStep).clamp(
      _minScale,
      _maxScale,
    );
    _applyScale(newScale);
  }

  void _resetScale() => _applyScale(1.0);

  void _applyScale(double scale) {
    _scaleNotifier.value = scale;
    _controller.value = Matrix4.identity()
      ..scaleByDouble(scale, scale, scale, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_fileName, style: const TextStyle(fontSize: 16)),
              Text(
                widget.filePath,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_fileName, style: const TextStyle(fontSize: 16)),
              Text(
                widget.filePath,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _fetchImageBytes,
                child: Text(LocaleKeys.retry.tr),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_fileName, style: const TextStyle(fontSize: 16)),
            Text(
              widget.filePath,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Toolbar ──
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1F28) : const Color(0xFFF6F7F9),
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                _ToolBtn(
                  tooltip: 'Zoom Out',
                  icon: CupertinoIcons.minus,
                  onTap: _zoomOut,
                ),
                const SizedBox(width: 4),
                _ToolBtn(
                  tooltip: 'Reset (1:1)',
                  icon: CupertinoIcons.fullscreen,
                  onTap: _resetScale,
                ),
                const SizedBox(width: 4),
                _ToolBtn(
                  tooltip: 'Zoom In',
                  icon: CupertinoIcons.add,
                  onTap: _zoomIn,
                ),
                const SizedBox(width: 12),
                ValueListenableBuilder<double>(
                  valueListenable: _scaleNotifier,
                  builder: (context, scale, _) => Text(
                    '${(scale * 100).round()}%',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ),
                const Spacer(),
                if (_decodedImage != null)
                  Text(
                    '${_decodedImage!.width} × ${_decodedImage!.height}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Image Display Area ──
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF12131A) : const Color(0xFFFAFBFC),
              child: InteractiveViewer(
                transformationController: _controller,
                panEnabled: true,
                scaleEnabled: true,
                minScale: _minScale,
                maxScale: _maxScale,
                onInteractionUpdate: (details) {
                  final scale = _controller.value.getMaxScaleOnAxis();
                  if (scale != _scaleNotifier.value) {
                    _scaleNotifier.value = scale;
                  }
                },
                child: _bytes != null
                    ? Center(
                        child: Image.memory(
                          _bytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _ToolBtn({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: theme.hintColor),
        ),
      ),
    );
  }
}
