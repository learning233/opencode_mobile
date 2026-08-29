import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../pages/left_drawer/left_drawer.dart';
import '../../pages/left_drawer/left_panel_content.dart';
import '../../utils/translations.dart';
import '../../widgets/multi_view/code_viewer.dart';

/// Unified Multi-Tab File Editor Page for Mobile & Tablet.
class FilePage extends StatefulWidget {
  const FilePage({super.key});

  @override
  State<FilePage> createState() => _FilePageState();
}

class _FilePageState extends State<FilePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Map<String, GlobalKey> _tabKeys = {};
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    // Force drawer to show files mode and auto-open drawer when navigating to FilePage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scaffoldKey.currentState?.openDrawer();
      }
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _syncPageController(int targetIndex) {
    if (targetIndex < 0) return;
    if (_pageController == null) {
      _pageController = PageController(initialPage: targetIndex);
    } else if (!_pageController!.hasClients) {
      // 换行开关不再卸载 PageView，但防御：若 controller 曾 detach，
      // 重建以让 initialPage 反映当前激活页，避免复用到过期位置。
      final old = _pageController!;
      _pageController = PageController(initialPage: targetIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
      });
    } else {
      // animateToPage is a side effect; defer it out of build to avoid
      // restarting the scroll animation mid-frame / assertion risks.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController!.hasClients) return;
        if (_pageController!.page?.round() != targetIndex) {
          _pageController!.animateToPage(
            targetIndex,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolCtrl = Get.find<TabletToolController>();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Obx(() {
          final activeFile = toolCtrl.activeFile;
          return Text(
            activeFile != null ? activeFile.name : LocaleKeys.mobileFiles.tr,
            style: const TextStyle(fontSize: 16),
          );
        }),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: LocaleKeys.mobileProjects.tr,
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: const LeftDrawer(initialMode: DrawerMode.files),
      body: Stack(
        children: [
          // Main Body: Tab Bar + Code PageView
          Column(
            children: [
              // Top File Tab Bar
              _buildFileTabBar(context, theme, toolCtrl),
              const Divider(height: 1),
              // Main Code PageView
              Expanded(
                child: Obx(() {
                  final files = toolCtrl.openedFiles;
                  final activeKey = toolCtrl.activeFileKey;

                  if (files.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.code,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            LocaleKeys.tabletNoFileOpen.tr,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                            icon: const Icon(Icons.folder_open),
                            label: Text(LocaleKeys.selectFileFromSidebar.tr),
                          ),
                        ],
                      ),
                    );
                  }

                  final activeIdx = files.indexWhere(
                    (f) => TabletToolController.fileKey(f.path, f.worktree) == activeKey,
                  );
                  final safeIdx = activeIdx != -1 ? activeIdx : 0;
                  final isWrap = toolCtrl.isWordWrap.value;

                  // 恒用单一 PageView：换行开关只切换滑动能力（关时用页签/
                  // 浮动按钮切换），不再在 PageView/IndexedStack 间切换结构，
                  // 避免销毁重建所有编辑器 State（丢预览/搜索/行号等）和
                  // PageController 位置漂移（换行后跳到别的文件）。
                  _syncPageController(safeIdx);
                  return PageView.builder(
                    controller: _pageController,
                    physics: isWrap
                        ? const PageScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    itemCount: files.length,
                    onPageChanged: (index) {
                      if (index >= 0 && index < files.length) {
                        toolCtrl.selectFile(
                          files[index].path,
                          worktree: files[index].worktree,
                        );
                      }
                    },
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return FileEditorPage(
                        key: ValueKey(
                          'file_page_${TabletToolController.fileKey(file.path, file.worktree)}',
                        ),
                        filePath: file.path,
                        fileName: file.name,
                        worktree: file.worktree,
                        initialContent: file.initialContent,
                        initialLine: file.targetLine,
                      );
                    },
                  );
                }),
              ),
            ],
          ),
          // Positioned Floating Action Buttons Overlay (Auto-hidden when isWordWrap is false)
          Positioned(
            right: 16,
            bottom: 24,
            child: Obx(() {
              final isWrap = toolCtrl.isWordWrap.value;
              final files = toolCtrl.openedFiles;

              // Hide floating buttons if isWordWrap is true (打开自动换行时按钮自动隐藏) or <= 1 files open
              if (isWrap || files.length <= 1) return const SizedBox.shrink();

              final activeKey = toolCtrl.activeFileKey;
              final activeIdx = files.indexWhere(
                (f) => TabletToolController.fileKey(f.path, f.worktree) == activeKey,
              );

              final canPrev = activeIdx > 0;
              final canNext = activeIdx != -1 && activeIdx < files.length - 1;

              return Material(
                type: MaterialType.transparency,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'file_prev_tab_overlay',
                      onPressed: canPrev
                          ? () => toolCtrl.selectFile(
                                files[activeIdx - 1].path,
                                worktree: files[activeIdx - 1].worktree,
                              )
                          : null,
                      tooltip: LocaleKeys.edPreviousTab.tr,
                      backgroundColor: canPrev
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.8),
                      foregroundColor: canPrev
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                      child: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton.small(
                      heroTag: 'file_next_tab_overlay',
                      onPressed: canNext
                          ? () => toolCtrl.selectFile(
                                files[activeIdx + 1].path,
                                worktree: files[activeIdx + 1].worktree,
                              )
                          : null,
                      tooltip: LocaleKeys.edNextTab.tr,
                      backgroundColor: canNext
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.8),
                      foregroundColor: canNext
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                      child: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTabBar(
    BuildContext context,
    ThemeData theme,
    TabletToolController toolCtrl,
  ) {
    return Obx(() {
      final files = toolCtrl.openedFiles;
      final activeKey = toolCtrl.activeFileKey;

      if (files.isEmpty) {
        _tabKeys.clear();
        return const SizedBox.shrink();
      }

      // Prune keys of closed files; _tabKeys is only ever appended otherwise.
      final keys = files
          .map((f) => TabletToolController.fileKey(f.path, f.worktree))
          .toSet();
      _tabKeys.removeWhere((path, _) => !keys.contains(path));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (activeKey.isNotEmpty) {
          final key = _tabKeys[activeKey];
          if (key?.currentContext != null) {
            Scrollable.ensureVisible(
              key!.currentContext!,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          }
        }
      });

      return Container(
        height: 38,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: files.length,
          itemBuilder: (ctx, index) {
            final file = files[index];
            final fileKey = TabletToolController.fileKey(file.path, file.worktree);
            final isActive = fileKey == activeKey;
            final key = _tabKeys.putIfAbsent(fileKey, () => GlobalKey());

            return Padding(
              key: key,
              padding: const EdgeInsets.only(
                left: 4,
                right: 2,
                top: 4,
                bottom: 4,
              ),
              child: InkWell(
                onTap: () =>
                    toolCtrl.selectFile(file.path, worktree: file.worktree),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive
                          ? theme.colorScheme.primary.withValues(alpha: 0.5)
                          : theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        size: 14,
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        file.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () =>
                            toolCtrl.closeFile(file.path, worktree: file.worktree),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
