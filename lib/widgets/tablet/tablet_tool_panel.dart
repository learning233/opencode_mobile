import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../utils/file_kind.dart';
import '../../utils/translations.dart';
import '../../widgets/multi_view/audio_player_view.dart';
import '../../widgets/multi_view/code_viewer.dart';
import '../../widgets/multi_view/image_viewer.dart';
import '../../widgets/browser/in_app_browser_view.dart';
import '../../pages/home/terminal_page.dart';
import 'review_page.dart';

/// Right-side tool panel for tablet mode with Code / Terminal / Web / Review tabs.
class TabletToolPanel extends StatefulWidget {
  const TabletToolPanel({super.key});

  @override
  State<TabletToolPanel> createState() => _TabletToolPanelState();
}

class _TabletToolPanelState extends State<TabletToolPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Worker? _tabWorker;
  final Map<String, GlobalKey> _tabKeys = {};

  /// Last tab the file tab bar auto-scrolled to. Prevents every Obx rebuild
  /// from yanking the horizontal scroll back to the active tab (fighting the
  /// user's manual scroll); only a *changed* selection triggers ensureVisible.
  String _lastEnsuredTab = '';
  PageController? _codePageController;

  @override
  void dispose() {
    _codePageController?.dispose();
    _tabWorker?.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _syncCodePageController(int targetIndex) {
    if (targetIndex < 0) return;
    if (_codePageController == null) {
      _codePageController = PageController(initialPage: targetIndex);
    } else if (!_codePageController!.hasClients) {
      // 换行开关不再卸载 PageView，但防御：若 controller 曾 detach，
      // 重建以让 initialPage 反映当前激活页，避免复用到过期位置。
      final old = _codePageController!;
      _codePageController = PageController(initialPage: targetIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
      });
    } else {
      // animateToPage is a build side effect; defer out of build to avoid
      // assertion risks and double-frame jitter.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_codePageController!.hasClients) return;
        if (_codePageController!.page?.round() != targetIndex) {
          _codePageController!.animateToPage(
            targetIndex,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final toolCtrl = Get.find<TabletToolController>();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: toolCtrl.activeTabIndex.value,
    );
    _tabController.addListener(_onTabChanged);

    // Sync tab controller when activeTabIndex changes externally
    _tabWorker = ever(toolCtrl.activeTabIndex, (int index) {
      if (mounted &&
          _tabController.index != index &&
          !_tabController.indexIsChanging) {
        _tabController.animateTo(index);
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      Get.find<TabletToolController>().activeTabIndex.value =
          _tabController.index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 0,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: true,
        bottom: true,
        left: false,
        right: false,
        child: Stack(
          children: [
            // 1. Main full-width tab content (Persistent KeepAlive with IndexedStack)
            Positioned.fill(
              child: Obx(() {
                final toolCtrl = Get.find<TabletToolController>();
                final activeIdx = toolCtrl.activeTabIndex.value.clamp(0, 3);
                return IndexedStack(
                  index: activeIdx,
                  children: [
                    _buildCodeTab(theme),
                    const TerminalPanelBody(showToolbar: true),
                    _buildWebTab(theme),
                    const ReviewPage(),
                  ],
                );
              }),
            ),
            // 2. Floating Thumb Rail on the right edge (Stack Overlay)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRailIcon(
                        index: TabletToolController.tabCode,
                        icon: CupertinoIcons.chevron_left_slash_chevron_right,
                        tooltip: LocaleKeys.tabletCodeTab.tr,
                        theme: theme,
                      ),
                      const SizedBox(height: 10),
                      _buildRailIcon(
                        index: TabletToolController.tabTerminal,
                        icon: Icons.terminal,
                        tooltip: LocaleKeys.tabletTerminalTab.tr,
                        theme: theme,
                      ),
                      const SizedBox(height: 10),
                      _buildRailIcon(
                        index: TabletToolController.tabWeb,
                        icon: CupertinoIcons.eye,
                        tooltip: LocaleKeys.tabletWebTab.tr,
                        theme: theme,
                      ),
                      const SizedBox(height: 10),
                      _buildRailIcon(
                        index: TabletToolController.tabReview,
                        icon: CupertinoIcons.doc_text_search,
                        tooltip: LocaleKeys.tabletReviewTab.tr,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRailIcon({
    required int index,
    required IconData icon,
    required String tooltip,
    required ThemeData theme,
  }) {
    return Obx(() {
      final toolCtrl = Get.find<TabletToolController>();
      final isSelected = toolCtrl.activeTabIndex.value == index;

      return Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => toolCtrl.activeTabIndex.value = index,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCodeTab(ThemeData theme) {
    final toolCtrl = Get.find<TabletToolController>();

    return Stack(
      children: [
        Column(
          children: [
            // File Tab Bar
            _buildFileTabBar(theme, toolCtrl),
            const Divider(height: 1),
            // File Content Stack
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
                          CupertinoIcons.doc,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          LocaleKeys.tabletNoFileOpen.tr,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          LocaleKeys.selectFileFromLeftMenu.tr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final activeIdx = files.indexWhere(
                  (f) =>
                      TabletToolController.fileKey(f.path, f.worktree) ==
                      activeKey,
                );
                final safeIdx = activeIdx != -1 ? activeIdx : 0;
                final isWrap = toolCtrl.isWordWrap.value;

                // 恒用单一 PageView：换行开关只切换滑动能力（关时用页签/
                // 浮动按钮切换），不再在 PageView/IndexedStack 间切换结构，
                // 避免销毁重建所有编辑器 State（丢预览/搜索/行号等）和
                // PageController 位置漂移（换行后跳到别的文件）。
                _syncCodePageController(safeIdx);
                return PageView.builder(
                  controller: _codePageController,
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
                    final tabKey = ValueKey(
                      'tablet_tab_${TabletToolController.fileKey(file.path, file.worktree)}',
                    );
                    switch (file.kind) {
                      case FileKind.image:
                        return ImageViewer(
                          key: tabKey,
                          filePath: file.path,
                          worktree: file.worktree,
                        );
                      case FileKind.audio:
                        return AudioPlayerView(
                          key: tabKey,
                          filePath: file.path,
                          worktree: file.worktree,
                        );
                      case FileKind.code:
                      case FileKind.markdown:
                        return FileEditorPage(
                          key: tabKey,
                          filePath: file.path,
                          fileName: file.name,
                          worktree: file.worktree,
                          initialContent: file.initialContent,
                          initialLine: file.targetLine,
                        );
                    }
                  },
                );
              }),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: Obx(() {
            final isWrap = toolCtrl.isWordWrap.value;
            final files = toolCtrl.openedFiles;

            // Hide floating buttons if isWordWrap is true (打开自动换行时手势划切，隐藏按钮) or <= 1 files open
            if (isWrap || files.length <= 1) return const SizedBox.shrink();

            final activeKey = toolCtrl.activeFileKey;
            final activeIdx = files.indexWhere(
              (f) =>
                  TabletToolController.fileKey(f.path, f.worktree) == activeKey,
            );

            final canPrev = activeIdx > 0;
            final canNext = activeIdx != -1 && activeIdx < files.length - 1;

            return Material(
              type: MaterialType.transparency,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'tablet_code_prev_tab',
                    onPressed: canPrev
                        ? () => toolCtrl.selectFile(
                            files[activeIdx - 1].path,
                            worktree: files[activeIdx - 1].worktree,
                          )
                        : null,
                    tooltip: LocaleKeys.edPreviousTab.tr,
                    backgroundColor: canPrev
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.8,
                          ),
                    foregroundColor: canPrev
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                    child: const Icon(CupertinoIcons.chevron_left),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton.small(
                    heroTag: 'tablet_code_next_tab',
                    onPressed: canNext
                        ? () => toolCtrl.selectFile(
                            files[activeIdx + 1].path,
                            worktree: files[activeIdx + 1].worktree,
                          )
                        : null,
                    tooltip: LocaleKeys.edNextTab.tr,
                    backgroundColor: canNext
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.8,
                          ),
                    foregroundColor: canNext
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                    child: const Icon(CupertinoIcons.chevron_right),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFileTabBar(ThemeData theme, TabletToolController toolCtrl) {
    return Obx(() {
      final files = toolCtrl.openedFiles;
      final activeKey = toolCtrl.activeFileKey;

      if (files.isEmpty) {
        _lastEnsuredTab = '';
        return const SizedBox.shrink();
      }

      // Prune keys of closed files; _tabKeys is only ever appended otherwise.
      final keys = files
          .map((f) => TabletToolController.fileKey(f.path, f.worktree))
          .toSet();
      _tabKeys.removeWhere((path, _) => !keys.contains(path));

      if (activeKey != _lastEnsuredTab) {
        _lastEnsuredTab = activeKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (activeKey.isEmpty) return;
          final key = _tabKeys[activeKey];
          final ctx = key?.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          } else {
            // 目标页签尚未被懒构建（在视口+cacheExtent 之外）：重置去重
            // 标记，让后续 rebuild 重试，避免"打开文件自动滚到页签"一次性
            // 失败后不再自愈。
            _lastEnsuredTab = '';
          }
        });
      }

      return Container(
        height: 40,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: files.length,
          itemBuilder: (ctx, index) {
            final file = files[index];
            final fileKey = TabletToolController.fileKey(
              file.path,
              file.worktree,
            );
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
                        isImageFilePath(file.name)
                            ? CupertinoIcons.photo
                            : CupertinoIcons.doc,
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
                        onTap: () => toolCtrl.closeFile(
                          file.path,
                          worktree: file.worktree,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Icon(
                            CupertinoIcons.xmark,
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

  Widget _buildWebTab(ThemeData theme) {
    return const InAppBrowserView();
  }
}
