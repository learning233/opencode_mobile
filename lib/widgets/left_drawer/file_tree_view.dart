import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../../api/endpoints.dart';
import '../../api/models/file_entry.dart';
import '../../api/opencode_client.dart';
import '../../controllers/project_controller.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../utils/file_tree_rows.dart';
import '../../utils/layout_utils.dart';
import '../../routes.dart';
import '../../utils/app_logger.dart';
import '../../utils/translations.dart';

/// An inline expandable directory tree component for the left drawer.
class FileTreeView extends StatefulWidget {
  final String? rootPath;

  const FileTreeView({super.key, this.rootPath});

  @override
  State<FileTreeView> createState() => _FileTreeViewState();
}

class _FileTreeViewState extends State<FileTreeView> {
  final OpenCodeClient _client = OpenCodeClient();
  final Map<String, List<FileEntry>> _dirCache = {};
  final Map<String, bool> _expanded = {};
  final Map<String, bool> _loading = {};
  final Map<String, String?> _errors = {};
  Timer? _refreshDebounce;
  StreamSubscription<int>? _fileChangeSub;

  // 单点选态：树级订阅各 Rx，行级只挂 ValueListenableBuilder，避免每行一个 Obx。
  final ValueNotifier<_TreeSelection?> _selection = ValueNotifier(null);
  final List<Worker> _selectionWorkers = [];
  bool _selectionReady = false;

  String get _currentRoot => widget.rootPath ?? '.';

  @override
  void initState() {
    super.initState();
    _loadDirectory(_currentRoot);
    _expanded[_currentRoot] = true;
    _initSelection();
    // 订阅文件变更事件：agent 编辑/新建文件后失效缓存并重载根目录。
    // 用防抖合并连续事件（file.watcher.updated 可能高频触发）。
    if (Get.isRegistered<TabletToolController>()) {
      _fileChangeSub = Get
          .find<TabletToolController>()
          .fileChangeTick
          .listen((_) => _scheduleRefresh());
    }
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _fileChangeSub?.cancel();
    _fileChangeSub = null;
    for (final w in _selectionWorkers) {
      w.dispose();
    }
    _selection.dispose();
    super.dispose();
  }

  void _initSelection() {
    if (_selectionReady) return;
    if (!Get.isRegistered<TabletToolController>() ||
        !Get.isRegistered<ProjectController>()) {
      return;
    }
    _selectionReady = true;
    final toolCtrl = Get.find<TabletToolController>();
    final projectCtrl = Get.find<ProjectController>();
    _selectionWorkers.addAll([
      ever(toolCtrl.activeFilePath, (_) => _syncSelection()),
      ever(toolCtrl.activeFileWorktree, (_) => _syncSelection()),
      ever(projectCtrl.activeProject, (_) => _syncSelection()),
    ]);
    _syncSelection();
  }

  void _syncSelection() {
    if (!_selectionReady) return;
    final toolCtrl = Get.find<TabletToolController>();
    final projectCtrl = Get.find<ProjectController>();
    // 只高亮当前项目 worktree 内打开的页签；同相对路径的其它 worktree 页签不误选。
    final projectWorktree = projectCtrl.activeProject.value?.worktree ?? '';
    final activePath = toolCtrl.activeFilePath.value;
    final activeWorktree = toolCtrl.activeFileWorktree.value;
    if (activePath.isEmpty || activeWorktree != projectWorktree) {
      _selection.value = null;
    } else {
      _selection.value = _TreeSelection(path: activePath);
    }
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _dirCache.clear();
      // 记录当前已展开的目录，清缓存后一并重载，避免展开子树渲染空白。
      final expandedDirs = _expanded.entries
          .where((e) => e.value && e.key != _currentRoot)
          .map((e) => e.key)
          .toList();
      _loadDirectory(_currentRoot);
      for (final dir in expandedDirs) {
        _loadDirectory(dir);
      }
    });
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _loading[path] = true;
      _errors[path] = null;
    });

    try {
      final worktree =
          Get.find<ProjectController>().activeProject.value?.worktree ?? '';
      final response = await _client.get(
        ApiEndpoints.fsList,
        queryParameters: {'path': path},
        directory: worktree.isNotEmpty ? worktree : null,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = response.data;
        final rawList = (data is Map && data['data'] is List)
            ? data['data'] as List
            : data is List
            ? data
            : [];
        final list = rawList
            .map((json) => FileEntry.fromJson(json as Map<String, dynamic>))
            .toList();

        // Sort: directories first, then files alphabetically
        list.sort((a, b) {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

        setState(() {
          _dirCache[path] = list;
        });
      } else {
        setState(() {
          _errors[path] = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      AppLogger.e('Failed to load directory "$path": $e');
      if (!mounted) return;
      setState(() {
        _errors[path] = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading[path] = false;
        });
      }
    }
  }

  void _toggleExpand(String path) {
    final isExp = _expanded[path] ?? false;
    setState(() {
      _expanded[path] = !isExp;
    });
    if (!isExp && !_dirCache.containsKey(path)) {
      _loadDirectory(path);
    }
  }

  void _onFileTap(FileEntry entry) {
    final worktree =
        Get.find<ProjectController>().activeProject.value?.worktree ?? '';
    final toolCtrl = Get.find<TabletToolController>();

    toolCtrl.openFile(entry.path, entry.name, worktree: worktree);

    final isTablet = isTabletLayout(context);

    // On phone (non-tablet mode), dismiss drawer and navigate to FilePage if needed
    if (!isTablet) {
      final scaffoldState = Scaffold.maybeOf(context);
      if (scaffoldState?.isDrawerOpen ?? false) {
        scaffoldState?.closeDrawer();
      }

      if (Get.currentRoute != AppRoutes.fileList) {
        Get.toNamed(AppRoutes.fileList);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _initSelection();
    final theme = Theme.of(context);
    final rows = flattenFileTree(
      root: _currentRoot,
      dirCache: _dirCache,
      expanded: _expanded,
      loading: _loading,
      errors: _errors,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          minVerticalPadding: 2,
          minLeadingWidth: 24,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(
            Icons.folder_copy_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            LocaleKeys.mobileFiles.tr,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: LocaleKeys.retry.tr,
            onPressed: () {
              _dirCache.clear();
              _loadDirectory(_currentRoot);
            },
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: rows.length,
            itemBuilder: (context, index) => _buildRow(rows[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(FileTreeRow row) {
    switch (row.kind) {
      case FileTreeRowKind.folder:
        return _buildFolderTile(row.entry!, depth: row.depth);
      case FileTreeRowKind.file:
        return _buildFileTile(row.entry!, depth: row.depth);
      case FileTreeRowKind.loading:
      case FileTreeRowKind.error:
        return _buildStatusRow(row);
    }
  }

  Widget _buildStatusRow(FileTreeRow row) {
    final padding = EdgeInsets.only(
      left: 16.0 * (row.depth + 1),
      top: 6,
      bottom: 6,
    );
    if (row.kind == FileTreeRowKind.loading) {
      return Padding(
        padding: padding,
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Loading...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    final dir = row.dir ?? _currentRoot;
    return Padding(
      padding: padding,
      child: InkWell(
        onTap: () => _loadDirectory(dir),
        child: Text(
          'Error: ${row.error} (Tap to retry)',
          style: const TextStyle(fontSize: 11, color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildFolderTile(FileEntry entry, {required int depth}) {
    final theme = Theme.of(context);
    final isExpanded = _expanded[entry.path] ?? false;
    final expandable = depth < kFileTreeMaxDepth;

    return InkWell(
      onTap: expandable ? () => _toggleExpand(entry.path) : null,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12.0 + (depth * 14.0),
          right: 12,
          top: 5,
          bottom: 5,
        ),
        child: Row(
          children: [
            if (expandable)
              Icon(
                isExpanded
                    ? CupertinoIcons.chevron_down
                    : CupertinoIcons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              )
            else
              const SizedBox(width: 18),
            const SizedBox(width: 4),
            Icon(
              isExpanded ? Icons.folder_open : Icons.folder,
              size: 18,
              color: Colors.amber.shade700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTile(FileEntry entry, {required int depth}) {
    final theme = Theme.of(context);
    final dimmed = entry.ignored;

    return ValueListenableBuilder<_TreeSelection?>(
      valueListenable: _selection,
      builder: (context, selection, _) {
        final isSelected = selection != null && selection.path == entry.path;
        final fgColor = isSelected
            ? theme.colorScheme.primary
            : dimmed
            ? theme.colorScheme.outline
            : theme.colorScheme.onSurface;

        return InkWell(
          onTap: () => _onFileTap(entry),
          child: Container(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            padding: EdgeInsets.only(
              left: 34.0 + (depth * 14.0),
              right: 12,
              top: 5,
              bottom: 5,
            ),
            child: Row(
              children: [
                Icon(
                  _getFileIcon(entry.name),
                  size: 16,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: fgColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'dart':
        return Icons.code;
      case 'json':
      case 'yaml':
      case 'yml':
      case 'toml':
        return CupertinoIcons.doc_text;
      case 'md':
      case 'txt':
        return CupertinoIcons.doc_text;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'svg':
        return CupertinoIcons.photo;
      case 'mp3':
      case 'wav':
        return CupertinoIcons.music_note;
      default:
        return CupertinoIcons.doc;
    }
  }
}

class _TreeSelection {
  const _TreeSelection({required this.path});

  final String path;
}
