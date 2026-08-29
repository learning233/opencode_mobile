import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/translations.dart';
import '../../api/models/file_entry.dart';
import '../../controllers/project_controller.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../routes.dart';
import '../../utils/app_logger.dart';
import '../../widgets/multi_view/audio_player_view.dart';
import '../../widgets/multi_view/image_viewer.dart';

class FileListPage extends StatefulWidget {
  final String? initialPath;

  const FileListPage({super.key, this.initialPath});

  @override
  State<FileListPage> createState() => _FileListPageState();
}

class _FileListPageState extends State<FileListPage> {
  final _entries = <FileEntry>[].obs;
  final _isLoading = false.obs;
  final _error = Rxn<String>();
  final _pathHistory = <String>['.'];

  String get _currentPath => _pathHistory.last;

  @override
  void initState() {
    super.initState();
    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      _pathHistory.clear();
      _pathHistory.add(widget.initialPath!);
    }
    _loadDirectory();
  }

  Future<void> _loadDirectory({bool force = false}) async {
    _isLoading.value = true;
    _error.value = null;
    try {
      final projectCtrl = Get.find<ProjectController>();
      final list = await projectCtrl.loadDirectory(_currentPath, force: force);
      _entries.assignAll(list);
    } catch (e) {
      AppLogger.e('Failed to load directory: $e');
      _error.value = e.toString();
    } finally {
      _isLoading.value = false;
    }
  }

  void _navigateTo(String path) {
    _pathHistory.add(path);
    _loadDirectory();
  }

  void _goBack() {
    if (_pathHistory.length > 1) {
      _pathHistory.removeLast();
      _loadDirectory();
    }
  }

  bool _isImageFile(String path) {
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    return {
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'bmp',
      'ico',
      'svg',
    }.contains(ext);
  }

  bool _isAudioFile(String path) {
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    return {'mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'wma'}.contains(ext);
  }

  void _previewFile(FileEntry entry) {
    final directory =
        Get.find<ProjectController>().activeProject.value?.worktree ?? '';

    if (_isImageFile(entry.path)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ImageViewer(filePath: entry.path, worktree: directory),
        ),
      );
    } else if (_isAudioFile(entry.path)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AudioPlayerView(filePath: entry.path, worktree: directory),
        ),
      );
    } else {
      // 统一走页签体系，与文件树打开路径行为一致。
      final toolCtrl = Get.find<TabletToolController>();
      toolCtrl.openFile(entry.path, entry.name, worktree: directory);
      if (Get.currentRoute != AppRoutes.fileList) {
        Get.toNamed(AppRoutes.fileList);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.mobileFiles.tr,
          style: const TextStyle(fontSize: 16),
        ),
        bottom: _pathHistory.length > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _goBack,
                        child: Icon(
                          CupertinoIcons.chevron_back,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            _currentPath,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: Obx(() {
        if (_isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error.value != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error: ${_error.value}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _loadDirectory,
                  child: Text(LocaleKeys.retry.tr),
                ),
              ],
            ),
          );
        }
        if (_entries.isEmpty) {
          return Center(child: Text(LocaleKeys.mobileEmptyDirectory.tr));
        }
        return RefreshIndicator(
          onRefresh: () => _loadDirectory(force: true),
          child: ListView.builder(
            itemCount: _entries.length,
            itemBuilder: (_, i) {
              final entry = _entries[i];
              return ListTile(
                leading: Icon(
                  entry.isDirectory ? Icons.folder : Icons.insert_drive_file,
                  size: 20,
                  color: entry.isDirectory
                      ? Colors.amber.shade700
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(entry.name, style: const TextStyle(fontSize: 14)),
                subtitle: entry.ignored
                    ? Text(
                        LocaleKeys.mobileIgnoredFile.tr,
                        style: const TextStyle(fontSize: 11),
                      )
                    : null,
                onTap: () {
                  if (entry.isDirectory) {
                    _navigateTo(entry.path);
                  } else {
                    _previewFile(entry);
                  }
                },
              );
            },
          ),
        );
      }),
    );
  }
}
