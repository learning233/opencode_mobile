import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../api/endpoints.dart';
import '../../api/opencode_client.dart';
import '../../controllers/project_controller.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../utils/app_logger.dart';
import '../../utils/translations.dart';

export '../../utils/file_kind.dart' show isAudioFilePath, kAudioExtensions;

/// Top-level function for safe compute execution without capturing class instances.
Uint8List _decodeAudioBase64Sync(String raw) {
  final clean = raw.replaceAll(RegExp(r'\s+'), '');
  return base64Decode(clean);
}

/// Audio player view with play/pause, seek, volume, and time display.
class AudioPlayerView extends StatefulWidget {
  final Uint8List? bytes;
  final String filePath;
  final String? worktree;

  const AudioPlayerView({
    super.key,
    this.bytes,
    required this.filePath,
    this.worktree,
  });

  @override
  State<AudioPlayerView> createState() => _AudioPlayerViewState();
}

class _AudioPlayerViewState extends State<AudioPlayerView> {
  late final AudioPlayer _player;
  final OpenCodeClient _client = OpenCodeClient();
  Uint8List? _bytes;
  bool _isLoading = false;
  String? _error;
  String _fileName = '';

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  PlayerState _state = PlayerState.stopped;
  double _volume = 1.0;

  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completeSub;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _fileName = widget.filePath.split(RegExp(r'[/\\]')).last;
    _player = AudioPlayer();
    _listenStreams();
    if (widget.bytes != null) {
      _bytes = widget.bytes;
      _loadAudio();
    } else {
      if (widget.filePath.isNotEmpty &&
          Get.isRegistered<TabletToolController>()) {
        final cached = Get.find<TabletToolController>().cachedBinaryContent(
          widget.filePath,
          worktree: widget.worktree,
        );
        if (cached != null) {
          _bytes = cached;
          _loadAudio();
          return;
        }
      }
      _isLoading = true;
      _fetchAudioBytes();
    }
  }

  Future<void> _fetchAudioBytes() async {
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

        // 数 MB base64 的正则清洗 + 解码放后台 isolate，打开大附件不占 UI 线程。
        final Uint8List bytes = await compute(
          _decodeAudioBase64Sync,
          base64Content,
        );
        // isolate 解码期间可能已有更新的请求完成或页面已销毁，丢弃过期结果。
        if (seq != _requestSeq || !mounted) return;

        if (widget.filePath.isNotEmpty &&
            Get.isRegistered<TabletToolController>()) {
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
          _loadAudio();
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load audio (${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      AppLogger.e('Failed to read binary audio file: $e');
      if (seq != _requestSeq || !mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _listenStreams() {
    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _state = PlayerState.completed;
        });
      }
    });
  }

  Future<void> _loadAudio() async {
    if (_bytes == null) return;
    try {
      await _player.setSourceBytes(
        _bytes!,
        mimeType: _mimeFor(widget.filePath),
      );
    } catch (e) {
      AppLogger.e('Failed to load audio source: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load audio: $e';
        });
      }
    }
  }

  /// Best-effort MIME type from the file extension so non-MP3 formats
  /// (.wav/.ogg/.flac/.aac/...) decode correctly instead of silently failing.
  String _mimeFor(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'wav':
        return 'audio/wav';
      case 'ogg':
      case 'oga':
      case 'opus':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      default:
        return 'audio/mpeg';
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  bool get _isPlaying => _state == PlayerState.playing;

  Future<void> _togglePlay() async {
    if (_bytes == null) return;
    if (_isPlaying) {
      await _player.pause();
    } else if (_state == PlayerState.paused) {
      await _player.resume();
    } else {
      await _player.play(
        BytesSource(_bytes!, mimeType: _mimeFor(widget.filePath)),
      );
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    if (mounted) {
      setState(() {
        _position = Duration.zero;
      });
    }
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hr = d.inHours;
    if (hr > 0) return '$hr:$min:$sec';
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                onPressed: _fetchAudioBytes,
                child: Text(LocaleKeys.retry.tr),
              ),
            ],
          ),
        ),
      );
    }

    final maxMs = _duration.inMilliseconds.toDouble().clamp(
      1.0,
      double.infinity,
    );
    final currentMs = _position.inMilliseconds.toDouble().clamp(0.0, maxMs);

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
      body: Container(
        color: isDark ? const Color(0xFF12131A) : const Color(0xFFFAFBFC),
        child: Column(
          children: [
            const Spacer(),
            // ── Player Card ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1F28) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // File name
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.music_note,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fileName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Seek bar
                  Row(
                    children: [
                      Text(
                        _isLoading ? '--:--' : _formatDuration(_position),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                      Expanded(
                        child: _isLoading
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    minHeight: 3,
                                    backgroundColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              )
                            : SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 5,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12,
                                  ),
                                  activeTrackColor: theme.colorScheme.primary,
                                  inactiveTrackColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.15),
                                  thumbColor: theme.colorScheme.primary,
                                ),
                                child: Slider(
                                  value: currentMs,
                                  min: 0,
                                  max: maxMs,
                                  onChanged: (v) {
                                    _player.seek(
                                      Duration(milliseconds: v.round()),
                                    );
                                  },
                                ),
                              ),
                      ),
                      Text(
                        _isLoading ? '--:--' : _formatDuration(_duration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ControlBtn(
                        tooltip: 'Stop',
                        icon: CupertinoIcons.stop_fill,
                        size: 24,
                        onTap: _stop,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(width: 16),
                      _ControlBtn(
                        tooltip: _isPlaying ? 'Pause' : 'Play',
                        icon: _isPlaying
                            ? CupertinoIcons.pause_circle_fill
                            : CupertinoIcons.play_circle_fill,
                        size: 44,
                        color: _isLoading
                            ? theme.disabledColor
                            : theme.colorScheme.primary,
                        onTap: _togglePlay,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 90,
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 4,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 10,
                            ),
                            activeTrackColor: _isLoading
                                ? theme.disabledColor
                                : theme.hintColor,
                            inactiveTrackColor:
                                (_isLoading
                                        ? theme.disabledColor
                                        : theme.hintColor)
                                    .withValues(alpha: 0.15),
                            thumbColor: _isLoading
                                ? theme.disabledColor
                                : theme.hintColor,
                          ),
                          child: Slider(
                            value: _isLoading ? 0.0 : _volume,
                            min: 0,
                            max: 1,
                            onChanged: _isLoading
                                ? null
                                : (v) {
                                    setState(() => _volume = v);
                                    _player.setVolume(v);
                                  },
                          ),
                        ),
                      ),
                      Icon(
                        _volume > 0.5
                            ? Icons.volume_up
                            : _volume > 0
                            ? Icons.volume_down
                            : Icons.volume_off,
                        size: 16,
                        color: _isLoading
                            ? theme.disabledColor
                            : theme.hintColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final double size;
  final Color? color;
  final VoidCallback onTap;
  final bool enabled;

  const _ControlBtn({
    required this.tooltip,
    required this.icon,
    required this.size,
    this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: enabled ? tooltip : '',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Icon(
          icon,
          size: size,
          color: enabled ? (color ?? theme.hintColor) : theme.disabledColor,
        ),
      ),
    );
  }
}
