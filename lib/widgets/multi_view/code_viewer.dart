import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:get/get.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/endpoints.dart';
import '../../api/models/file_content.dart';
import '../../api/opencode_client.dart';
import '../../controllers/project_controller.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../init.dart';
import '../../utils/app_logger.dart';
import '../../utils/diff_paths.dart';
import '../../utils/file_kind.dart';
import '../../utils/snackbar_utils.dart';
import '../../utils/translations.dart';
import 'audio_player_view.dart';
import 'image_viewer.dart';

class FileEditorPage extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String? initialContent;
  final String? fileType;
  final String? worktree;
  final int? initialLine;

  const FileEditorPage({
    super.key,
    required this.filePath,
    required this.fileName,
    this.initialContent,
    this.fileType,
    this.worktree,
    this.initialLine,
  });

  @override
  State<FileEditorPage> createState() => _FileEditorPageState();
}

class _FileEditorPageState extends State<FileEditorPage> {
  late CodeLineEditingController _controller;
  late CodeFindController _findController;
  late final CodeScrollController _scrollController;
  final FocusNode _focusNode = FocusNode();
  final OpenCodeClient _client = OpenCodeClient();
  StreamSubscription<int>? _fileChangeSub;
  StreamSubscription<int>? _reconnectSub;
  Timer? _reloadDebounce;
  bool _isLoading = false;
  bool _isImage = false;
  bool _isAudio = false;
  String? _error;
  int _requestSeq = 0;
  Worker? _wordWrapWorker;
  Worker? _lineWorker;

  // Selected line highlight state
  int? _selectedLineIndex;

  // Editor settings state
  bool _wordWrap = false;
  bool _showLineNumbers = true;
  double _fontSize = 13.0;
  bool _isMarkdownPreview = true;

  @override
  void initState() {
    super.initState();
    _fontSize = Global.settings.editorFontSize;
    _showLineNumbers = Global.settings.editorShowLineNumbers;
    _scrollController = CodeScrollController();

    String? initial;
    if (Get.isRegistered<TabletToolController>()) {
      final toolCtrl = Get.find<TabletToolController>();
      _wordWrap = toolCtrl.isWordWrap.value;
      // 换行开关是全局状态：编辑器 State 现在跨开关持久存活，
      // 必须监听全局 Rx，否则别的编辑器切换换行后本编辑器不同步。
      _wordWrapWorker = ever(toolCtrl.isWordWrap, (value) {
        if (mounted) {
          setState(() {
            _wordWrap = value;
          });
        }
      });
      // 监听外部跳转行号请求（如搜索结果点击）
      _lineWorker = ever(toolCtrl.fileLineJumpRequest, (req) {
        if (req != null &&
            req.path == widget.filePath &&
            (req.worktree == null ||
                widget.worktree == null ||
                req.worktree == widget.worktree) &&
            mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _jumpToLine(req.line);
          });
        }
      });
      // 惰性重建时优先取内容缓存，避免重新下载。
      initial =
          widget.initialContent ??
          toolCtrl.cachedContent(widget.filePath, worktree: widget.worktree);
    } else {
      _wordWrap = Global.settings.editorWordWrap;
      initial = widget.initialContent;
    }
    if (isImageFilePath(widget.filePath)) {
      _isImage = true;
      _controller = _createController();
      _initFindController();
    } else if (initial != null) {
      _controller = _createController(text: initial);
      _initFindController();
      if (widget.initialLine != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _jumpToLine(widget.initialLine!);
        });
      }
    } else {
      _controller = _createController();
      _initFindController();
      _isLoading = true;
      _loadFile();
    }
    // 订阅文件变更：agent 编辑/新建后刷新当前文件内容（防抖合并）。
    if (Get.isRegistered<TabletToolController>()) {
      final ctrl = Get.find<TabletToolController>();
      _fileChangeSub = ctrl.fileChangeTick.listen((_) {
        _reloadDebounce?.cancel();
        _reloadDebounce = Timer(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          // 防抖结束后在事件窗口内匹配自身路径。连续多文件变更时每个
          // 事件都会重排定时器，单槽「最后变更文件」会让除最后一个外的
          // 挂载编辑器匹配失败、永久漏刷。
          final matched = ctrl.recentChangedFiles.any(
            (e) => diffPathsEqual(e.path, widget.filePath),
          );
          if (matched) _loadFile();
        });
      });
      // SSE 重连补偿：断线窗口内的文件事件不会补发，内容可能已过期，
      // 直接重载（每编辑器一次请求，挂载中的编辑器数量有限）。
      _reconnectSub = ctrl.fileReconnectTick.listen((_) {
        if (mounted) _loadFile();
      });
    }
  }

  static String _normalizeNewlines(String text) {
    return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  CodeLineEditingController _createController({String? text}) {
    final normalized = text != null ? _normalizeNewlines(text) : null;
    final lines = normalized != null
        ? CodeLines.of(
            normalized.split('\n').map((line) => CodeLine(line)).toList(),
          )
        : CodeLines.of(const [CodeLine('')]);
    return CodeLineEditingController(
      codeLines: lines,
      spanBuilder: _buildLineSpan,
    );
  }

  TextSpan _buildLineSpan({
    required BuildContext context,
    required int index,
    required CodeLine codeLine,
    required TextSpan textSpan,
    required TextStyle style,
  }) {
    if (_selectedLineIndex != null && index == _selectedLineIndex) {
      final theme = Theme.of(context);
      final highlightColor = theme.colorScheme.primary.withValues(alpha: 0.18);
      return TextSpan(
        text: textSpan.text,
        children: textSpan.children,
        style: (textSpan.style ?? style).copyWith(
          backgroundColor: highlightColor,
        ),
      );
    }
    return textSpan;
  }

  @override
  void didUpdateWidget(covariant FileEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLine != null &&
        widget.initialLine != oldWidget.initialLine) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _jumpToLine(widget.initialLine!);
      });
    }
  }

  void _jumpToLine(int line) {
    if (line <= 0) return;
    final totalLines = _controller.lineCount;
    final lineIndex = (line - 1).clamp(0, totalLines > 0 ? totalLines - 1 : 0);

    // 将目标行平滑居中到可视区域
    _scrollController.makeCenterIfInvisible(
      CodeLinePosition(index: lineIndex, offset: 0),
    );

    // 光标定位在行首（不全选行，保证语法高亮完全清晰）
    _controller.selection = CodeLineSelection.fromPosition(
      position: CodeLinePosition(index: lineIndex, offset: 0),
    );

    // 为当前选中的目标行应用淡色高亮背景（持续保留该行高亮）
    _selectedLineIndex = lineIndex;
    _controller.codeLines = _controller.codeLines;

    // 立即消费目标行状态，避免 PageView 回收重建时重复触发陈旧跳转
    if (Get.isRegistered<TabletToolController>()) {
      final toolCtrl = Get.find<TabletToolController>();
      final idx = toolCtrl.openedFiles.indexWhere(
        (f) => f.path == widget.filePath && f.worktree == widget.worktree,
      );
      if (idx != -1) {
        toolCtrl.openedFiles[idx].targetLine = null;
      }
    }
  }

  void _initFindController() {
    _findController = CodeFindController(_controller);
  }

  Future<void> _loadFile() async {
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

      if (response.statusCode == 200) {
        final parsed = FileContent.parse(response.data);
        if (parsed.isBinary) {
          if (parsed.mimeType?.startsWith('image/') == true ||
              isImageFilePath(widget.filePath)) {
            if (mounted) {
              setState(() {
                _isImage = true;
                _isLoading = false;
              });
            }
            return;
          }
          if (parsed.mimeType?.startsWith('audio/') == true ||
              isAudioFilePath(widget.filePath)) {
            if (mounted) {
              setState(() {
                _isAudio = true;
                _isLoading = false;
              });
            }
            return;
          }
          if (mounted) {
            setState(() {
              _error = LocaleKeys.unsupportedBinaryFile.trParams({
                'file': widget.fileName,
              });
              _isLoading = false;
            });
          }
          return;
        }
        final content = parsed.content;
        if (mounted) {
          if (Get.isRegistered<TabletToolController>()) {
            Get.find<TabletToolController>().cacheFileContent(
              widget.filePath,
              content,
              worktree: widget.worktree,
            );
          }
          final oldController = _controller;
          _findController.dispose();
          _controller = _createController(text: content);
          _initFindController();
          setState(() {
            _isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            oldController.dispose();
            if (widget.initialLine != null && mounted) {
              _jumpToLine(widget.initialLine!);
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load file (${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      AppLogger.e('Failed to read file: $e');
      if (seq != _requestSeq || !mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _wordWrapWorker?.dispose();
    _lineWorker?.dispose();
    _reloadDebounce?.cancel();
    _fileChangeSub?.cancel();
    _fileChangeSub = null;
    _reconnectSub?.cancel();
    _reconnectSub = null;
    _findController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    if (_findController.value != null) {
      _findController.close();
    } else {
      _findController.findMode();
    }
    // AppBar 搜索图标颜色读取 _findController.value，面板自身有监听会重建，
    // 但本 State 不会，需主动 setState 刷新图标高亮。
    if (mounted) setState(() {});
  }

  void _closeSearch() {
    _findController.close();
    if (mounted) setState(() {});
  }

  void _toggleWordWrap() {
    if (Get.isRegistered<TabletToolController>()) {
      final toolCtrl = Get.find<TabletToolController>();
      toolCtrl.isWordWrap.value = !toolCtrl.isWordWrap.value;
    } else {
      setState(() {
        _wordWrap = !_wordWrap;
      });
      Global.settings.setEditorWordWrap(_wordWrap);
    }
  }

  String _resolveLanguage(String? fileType, String fileName) {
    if (fileType != null && fileType.isNotEmpty) {
      final lower = fileType.toLowerCase();
      if (builtinLanguages.containsKey(lower)) {
        return lower;
      }
    }

    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'dart':
        return 'dart';
      case 'js':
      case 'jsx':
        return 'javascript';
      case 'ts':
      case 'tsx':
        return 'typescript';
      case 'json':
        return 'json';
      case 'md':
      case 'markdown':
        return 'markdown';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'py':
        return 'python';
      case 'html':
      case 'htm':
      case 'xml':
        return 'xml';
      case 'css':
      case 'scss':
        return 'css';
      case 'c':
      case 'cpp':
      case 'h':
      case 'hpp':
        return 'cpp';
      case 'java':
        return 'java';
      case 'go':
        return 'go';
      case 'rs':
        return 'rust';
      case 'sh':
      case 'bash':
        return 'bash';
      case 'sql':
        return 'sql';
      default:
        return ext;
    }
  }

  PreferredSizeWidget _buildFindPanel(
    BuildContext context,
    CodeFindController controller,
    bool _,
  ) {
    return _CodeFindPanel(controller: controller, onClose: _closeSearch);
  }

  List<Widget> _buildAppBarActions(ThemeData theme, bool isMarkdown) {
    return [
      if (isMarkdown)
        IconButton(
          icon: Icon(
            _isMarkdownPreview
                ? CupertinoIcons.chevron_left_slash_chevron_right
                : CupertinoIcons.book,
            size: 20,
          ),
          tooltip: _isMarkdownPreview
              ? LocaleKeys.edSourceMode.tr
              : LocaleKeys.edPreviewMode.tr,
          onPressed: () {
            setState(() {
              _isMarkdownPreview = !_isMarkdownPreview;
              if (_isMarkdownPreview) {
                _findController.close();
              }
            });
          },
        ),
      if (!isMarkdown || !_isMarkdownPreview) ...[
        IconButton(
          icon: Icon(
            CupertinoIcons.search,
            size: 20,
            color: _findController.value != null
                ? theme.colorScheme.primary
                : null,
          ),
          tooltip: LocaleKeys.search.tr,
          onPressed: _toggleSearch,
        ),
        IconButton(
          icon: Icon(
            _wordWrap ? Icons.wrap_text : Icons.wrap_text_outlined,
            size: 20,
            color: _wordWrap ? theme.colorScheme.primary : null,
          ),
          tooltip: _wordWrap
              ? LocaleKeys.edDisableWordWrap.tr
              : LocaleKeys.edEnableWordWrap.tr,
          onPressed: _toggleWordWrap,
        ),
      ],
      PopupMenuButton<String>(
        icon: const Icon(CupertinoIcons.ellipsis_vertical, size: 20),
        tooltip: LocaleKeys.edEditorSettings.tr,
        onSelected: (value) {
          switch (value) {
            case 'word_wrap':
              _toggleWordWrap();
              break;
            case 'line_numbers':
              setState(() {
                _showLineNumbers = !_showLineNumbers;
              });
              Global.settings.setEditorShowLineNumbers(_showLineNumbers);
              break;
            case 'copy':
              Clipboard.setData(ClipboardData(text: _controller.text));
              Snack.info(
                LocaleKeys.clipboardCopied.tr,
                title: LocaleKeys.edCopied.tr,
              );
              break;
            case 'reload':
              _loadFile();
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'word_wrap',
            child: Row(
              children: [
                Icon(
                  _wordWrap ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: _wordWrap ? theme.colorScheme.primary : null,
                ),
                const SizedBox(width: 10),
                Text(LocaleKeys.edWordWrap.tr),
              ],
            ),
          ),
          if (!isMarkdown || !_isMarkdownPreview)
            PopupMenuItem<String>(
              value: 'line_numbers',
              child: Row(
                children: [
                  Icon(
                    _showLineNumbers
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: _showLineNumbers ? theme.colorScheme.primary : null,
                  ),
                  const SizedBox(width: 10),
                  Text(LocaleKeys.edShowLineNumbers.tr),
                ],
              ),
            ),
          const PopupMenuDivider(),
          _FontSizeMenuItem(
            fontSize: _fontSize,
            onChanged: (newSize) {
              setState(() {
                _fontSize = newSize;
              });
              Global.settings.setEditorFontSize(newSize);
            },
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'copy',
            child: Row(
              children: [
                const Icon(CupertinoIcons.doc_on_clipboard, size: 18),
                const SizedBox(width: 10),
                Text(LocaleKeys.edCopyAll.tr),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'reload',
            child: Row(
              children: [
                const Icon(CupertinoIcons.refresh, size: 18),
                const SizedBox(width: 10),
                Text(LocaleKeys.reload.tr),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage || isImageFilePath(widget.filePath)) {
      return ImageViewer(
        filePath: widget.filePath,
        worktree: widget.worktree,
      );
    }
    if (_isAudio || isAudioFilePath(widget.filePath)) {
      return AudioPlayerView(
        filePath: widget.filePath,
        worktree: widget.worktree,
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isMarkdown = isMarkdownFilePath(widget.fileName);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 40,
          title: Text(
            widget.filePath,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 40,
          title: Text(
            widget.filePath,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
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
                onPressed: _loadFile,
                child: Text(LocaleKeys.retry.tr),
              ),
            ],
          ),
        ),
      );
    }

    final syntaxTheme = isDark ? atomOneDarkTheme : atomOneLightTheme;

    final langKey = _resolveLanguage(widget.fileType, widget.fileName);
    final langMode = builtinLanguages[langKey];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        title: Text(
          widget.filePath,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: _buildAppBarActions(theme, isMarkdown),
      ),
      body: isMarkdown && _isMarkdownPreview
          ? SafeArea(
              child: Markdown(
                data: _controller.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: TextStyle(fontSize: _fontSize, height: 1.6),
                  code: TextStyle(
                    fontSize: _fontSize,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    fontFamily: 'monospace',
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onTapLink: (text, href, title) {
                  if (href != null) {
                    launchUrl(
                      Uri.tryParse(href) ?? Uri(),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
              ),
            )
          : CodeEditorTapRegion(
              child: CodeEditor(
                controller: _controller,
                scrollController: _scrollController,
                findController: _findController,
                focusNode: _focusNode,
                readOnly: true,
                wordWrap: _wordWrap,
                findBuilder: _buildFindPanel,
                style: CodeEditorStyle(
                  fontSize: _fontSize,
                  fontFamily: 'monospace',
                  textColor: theme.colorScheme.onSurface,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  codeTheme: langMode != null
                      ? CodeHighlightTheme(
                          languages: {
                            langKey: CodeHighlightThemeMode(mode: langMode),
                          },
                          theme: syntaxTheme,
                        )
                      : null,
                ),
                indicatorBuilder: _showLineNumbers
                    ? (context, editingController, chunkController, notifier) {
                        return Row(
                          children: [
                            DefaultCodeLineNumber(
                              controller: editingController,
                              notifier: notifier,
                            ),
                            DefaultCodeChunkIndicator(
                              width: 20,
                              controller: chunkController,
                              notifier: notifier,
                            ),
                          ],
                        );
                      }
                    : null,
              ),
            ),
    );
  }
}

class _CodeFindPanel extends StatefulWidget implements PreferredSizeWidget {
  final CodeFindController controller;
  final VoidCallback onClose;

  const _CodeFindPanel({required this.controller, required this.onClose});

  @override
  Size get preferredSize =>
      controller.value == null ? Size.zero : const Size.fromHeight(44);

  @override
  State<_CodeFindPanel> createState() => _CodeFindPanelState();
}

class _CodeFindPanelState extends State<_CodeFindPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 面板常驻（findBuilder 恒接线），仅在查找模式激活时抢焦点，
      // 避免每次编辑器挂载都弹出键盘。
      if (mounted && widget.controller.value != null) {
        widget.controller.focusOnFindInput();
      }
    });
  }

  @override
  void didUpdateWidget(_CodeFindPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `_loadFile` reload replaces the find controller while the panel stays
    // mounted; without re-attaching, the panel keeps listening to the disposed
    // old controller and search results never update.
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // 未在查找模式（value == null）时保持不可见，但 findBuilder 恒接线，
    // 让 re_editor 的 Ctrl+F / Esc 快捷键始终可用。
    if (widget.controller.value == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final value = widget.controller.value;
    final result = value?.result;
    final matches = result?.matches ?? [];
    final currentIndex = (matches.isEmpty || result == null)
        ? 0
        : (result.index + 1);
    final totalCount = matches.length;

    final option =
        value?.option ??
        const CodeFindOption(pattern: '', caseSensitive: false, regex: false);
    final pattern = option.pattern;

    String resultText = '';
    if (pattern.isNotEmpty) {
      resultText = totalCount > 0
          ? '$currentIndex/$totalCount'
          : LocaleKeys.edFindNoResult.tr;
    }

    return CodeEditorTapRegion(
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 32,
                child: TextField(
                  controller: widget.controller.findInputController,
                  focusNode: widget.controller.findInputFocusNode,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: LocaleKeys.edFindPlaceholder.tr,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  onSubmitted: (_) {
                    widget.controller.nextMatch();
                  },
                ),
              ),
            ),
            if (resultText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                resultText,
                style: TextStyle(
                  fontSize: 12,
                  color: totalCount > 0
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(CupertinoIcons.chevron_up, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: LocaleKeys.edFindPrevious.tr,
              onPressed: totalCount > 0
                  ? widget.controller.previousMatch
                  : null,
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.chevron_down, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: LocaleKeys.edFindNext.tr,
              onPressed: totalCount > 0 ? widget.controller.nextMatch : null,
            ),
            IconButton(
              icon: Icon(
                Icons.text_fields,
                size: 16,
                color: option.caseSensitive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip:
                  '${LocaleKeys.edCaseSensitive.tr} (${option.caseSensitive ? LocaleKeys.on_.tr : LocaleKeys.off.tr})',
              onPressed: widget.controller.toggleCaseSensitive,
            ),
            IconButton(
              icon: Icon(
                Icons.data_object,
                size: 16,
                color: option.regex
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip:
                  '${LocaleKeys.edRegex.tr} (${option.regex ? LocaleKeys.on_.tr : LocaleKeys.off.tr})',
              onPressed: widget.controller.toggleRegex,
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.xmark, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: LocaleKeys.edCloseSearch.tr,
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Font Size Control Menu Item ──

class _FontSizeMenuItem extends PopupMenuEntry<String> {
  final double fontSize;
  final ValueChanged<double> onChanged;

  const _FontSizeMenuItem({required this.fontSize, required this.onChanged});

  @override
  double get height => 44;

  @override
  bool represents(String? value) => false;

  @override
  State<_FontSizeMenuItem> createState() => _FontSizeMenuItemState();
}

class _FontSizeMenuItemState extends State<_FontSizeMenuItem> {
  late double _currentFontSize;

  @override
  void initState() {
    super.initState();
    _currentFontSize = widget.fontSize;
  }

  @override
  void didUpdateWidget(covariant _FontSizeMenuItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize) {
      _currentFontSize = widget.fontSize;
    }
  }

  void _updateFontSize(double next) {
    setState(() {
      _currentFontSize = next;
    });
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            LocaleKeys.edFontSize.tr,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Container(
            height: 30,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    final next = (_currentFontSize - 1).clamp(9.0, 32.0);
                    _updateFontSize(next);
                  },
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Icon(
                      CupertinoIcons.minus,
                      size: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '${_currentFontSize.toInt()} pt',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    final next = (_currentFontSize + 1).clamp(9.0, 32.0);
                    _updateFontSize(next);
                  },
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Icon(
                      CupertinoIcons.plus,
                      size: 13,
                      color: theme.colorScheme.onSurface,
                    ),
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
