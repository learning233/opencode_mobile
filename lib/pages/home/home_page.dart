import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/project_controller.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../utils/layout_utils.dart';
import '../left_drawer/left_drawer.dart';
import '../left_drawer/left_panel_content.dart';
import '../right_drawer/right_drawer.dart';
import '../../utils/translations.dart';
import '../../widgets/browser/in_app_browser_view.dart';
import '../../widgets/tablet/resizable_divider.dart';
import '../../widgets/tablet/tablet_tool_panel.dart';
import 'chat_view.dart';
import 'prompt_input.dart';
import 'session_indicator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late PageController _pageController;
  Worker? _activeSessionWorker;
  Worker? _openedSessionsWorker;
  Worker? _browserSheetWorker;
  int? _swipeStartPage;
  bool _isSmartNavigating = false;

  /// Whether the phone-layout browser layer has ever been opened. Once true,
  /// the layer stays mounted forever (WebView survives close); before that it
  /// is not built at all so cold start never pays for an idle WebView.
  bool _browserEverOpened = false;

  // Tablet nested navigator key
  final GlobalKey<NavigatorState> _leftNavKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    final sessionCtrl = Get.find<SessionController>();
    final initialActiveId = sessionCtrl.activeSessionId.value;
    final initialOpened = sessionCtrl.openedSessionIds.toList();
    final initialIdx = initialOpened.indexOf(initialActiveId);

    _pageController = PageController(
      initialPage: initialIdx != -1 ? initialIdx : 0,
    );

    void syncPageToActiveSession({bool immediate = false}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        final activeId = sessionCtrl.activeSessionId.value;
        final opened = sessionCtrl.openedSessionIds.toList();
        final idx = opened.indexOf(activeId);
        if (idx != -1 && _pageController.page?.round() != idx) {
          if (immediate) {
            _pageController.jumpToPage(idx);
          } else {
            _pageController.animateToPage(
              idx,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            );
          }
        }
      });
    }

    _activeSessionWorker = ever(
      sessionCtrl.activeSessionId,
      (_) => syncPageToActiveSession(),
    );
    _openedSessionsWorker = ever(
      sessionCtrl.openedSessionIds,
      (_) => syncPageToActiveSession(),
    );

    // 手机布局：首次打开浏览器 sheet 后常驻保活层（WebView 不随关闭销毁）。
    _browserSheetWorker = ever(
      Get.find<TabletToolController>().browserSheetVisible,
      (visible) {
        if (visible == true && !_browserEverOpened) {
          _browserEverOpened = true;
          if (mounted) setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _activeSessionWorker?.dispose();
    _openedSessionsWorker?.dispose();
    _browserSheetWorker?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToOpened(
    SessionController sessionCtrl,
    List<String> opened,
    String id,
  ) {
    sessionCtrl.selectSession(id);
  }

  Widget _buildChatBody(
    BuildContext context,
    ProjectController projectCtrl,
    SessionController sessionCtrl,
  ) {
    final project = projectCtrl.activeProject.value;
    final opened = sessionCtrl.openedSessionIds.toList();

    if (project == null) {
      return Center(child: Text(LocaleKeys.mobileSelectProject.tr));
    }

    if (opened.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              LocaleKeys.mobileNoActiveSessions.tr,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => sessionCtrl.createNewSession(),
              child: Text(LocaleKeys.cmdNewSession.tr),
            ),
          ],
        ),
      );
    }

    // Ensure PageController is synced to active session when returning/building
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      final activeId = sessionCtrl.activeSessionId.value;
      final idx = opened.indexOf(activeId);
      if (idx != -1 && _pageController.page?.round() != idx) {
        _pageController.jumpToPage(idx);
      }
    });

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          if (_pageController.hasClients) {
            _swipeStartPage = _pageController.page?.round();
          }
        } else if (notification is ScrollEndNotification) {
          final startPage = _swipeStartPage;
          _swipeStartPage = null;
          if (startPage != null &&
              _pageController.hasClients &&
              !_isSmartNavigating) {
            final currentPage = _pageController.page?.round() ?? startPage;
            if (currentPage != startPage) {
              // Re-fetch latest opened list to avoid stale closure
              final latestOpened = sessionCtrl.openedSessionIds.toList();
              final isForward = currentPage > startPage;
              final targetIdx = sessionCtrl.getNextAttentionPageIndex(
                currentIndex: startPage,
                openedIds: latestOpened,
                isForward: isForward,
              );
              // 若算法匹配到的待办卡片非相邻卡片（如由 Page 1 智能滑跃至 Page 4）
              if (targetIdx != currentPage &&
                  targetIdx >= 0 &&
                  targetIdx < latestOpened.length &&
                  (targetIdx - startPage).abs() > 1) {
                _isSmartNavigating = true;
                _pageController
                    .animateToPage(
                      targetIdx,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    )
                    .whenComplete(() {
                      _isSmartNavigating = false;
                    });
                sessionCtrl.selectSession(latestOpened[targetIdx]);
              }
            }
          }
        }
        return false;
      },
      child: PageView.builder(
        controller: _pageController,
        itemCount: opened.length,
        allowImplicitScrolling: true,
        onPageChanged: (page) {
          if (!_isSmartNavigating && page >= 0) {
            // Re-read the latest opened list so a list change during the swipe
            // gesture cannot select a stale session.
            final latestOpened = sessionCtrl.openedSessionIds.toList();
            if (page < latestOpened.length) {
              sessionCtrl.selectSession(latestOpened[page]);
            }
          }
        },
        itemBuilder: (context, index) {
          final sid = opened[index];
          return Column(
            key: ValueKey('page_$sid'),
            children: [
              Expanded(child: ChatView(sessionId: sid)),
              PromptInput(sessionId: sid),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    SessionController sessionCtrl,
    List<String> opened,
    String sessionId,
    String title, {
    bool showMenu = true,
    bool showEndDrawer = true,
    bool showToolPanelToggle = false,
    bool isTablet = false,
  }) {
    final theme = Theme.of(context);

    return AppBar(
      toolbarHeight: isTablet ? 40.0 : kToolbarHeight,
      centerTitle: true,
      title: opened.isNotEmpty
          ? SessionIndicator(
              openedIds: opened,
              activeId: sessionId,
              onTap: (id) => _jumpToOpened(sessionCtrl, opened, id),
            )
          : Text(title, style: const TextStyle(fontSize: 16)),
      automaticallyImplyLeading: showMenu,
      actions: [
        if (showToolPanelToggle)
          Obx(() {
            final toolCtrl = Get.find<TabletToolController>();
            return IconButton(
              icon: Icon(
                toolCtrl.isVisible.value
                    ? Icons.view_sidebar
                    : Icons.view_sidebar_outlined,
                color: toolCtrl.isVisible.value
                    ? theme.colorScheme.primary
                    : null,
              ),
              tooltip: LocaleKeys.tabletToggleToolPanel.tr,
              onPressed: () => toolCtrl.togglePanel(),
            );
          }),
        if (showEndDrawer)
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.tune_outlined),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
      ],
      bottom: opened.isNotEmpty
          ? PreferredSize(
              preferredSize: const Size.fromHeight(28),
              child: Obx(() {
                final tokens = sessionCtrl.activeSessionMessageTokens(
                  sessionId,
                );
                final maxLimit = sessionCtrl.modelContextLimitFor(sessionId);
                final hasLimit = maxLimit > 0 && tokens > 0;
                final ratio = hasLimit
                    ? (tokens / maxLimit).clamp(0.0, 1.0)
                    : 0.0;

                final barColor = ratio >= 0.9
                    ? Colors.red
                    : ratio >= 0.75
                    ? Colors.orange
                    : theme.colorScheme.primary;

                return Container(
                  width: double.infinity,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.2,
                    ),
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                        width: 0.5,
                      ),
                      bottom: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Centered Session Title
                      Positioned.fill(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      // Context Token Usage Progress Bar (Bottom Divider Line)
                      if (hasLimit)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 1.5,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: ratio,
                              child: Container(
                                color: barColor.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectCtrl = Get.find<ProjectController>();
    final sessionCtrl = Get.find<SessionController>();
    final width = MediaQuery.of(context).size.width;
    final isTablet = isTabletLayout(context);

    if (!isTablet) {
      // 会话标题/页签依赖收窄到此分支的 Obx：SSE 会话变更只重建左侧聊天，不波及 tool 面板。
      final toolCtrl = Get.find<TabletToolController>();
      return Stack(
        children: [
          Obx(() {
            final sessionId = sessionCtrl.activeSessionId.value;
            final opened = sessionCtrl.openedSessionIds.toList();
            final title = sessionId.isNotEmpty
                ? sessionCtrl.getSessionName(sessionId)
                : 'OpenCode';

            return Scaffold(
              appBar: _buildAppBar(sessionCtrl, opened, sessionId, title),
              drawer: const LeftDrawer(),
              endDrawer: const RightDrawer(),
              body: _buildChatBody(context, projectCtrl, sessionCtrl),
            );
          }),
          // 常驻浏览器层：首次打开后永不卸载，关闭只下滑隐藏，WebView 保活。
          if (_browserEverOpened)
            _PhoneBrowserLayer(
              controller: toolCtrl,
              onClose: toolCtrl.closeBrowserSheet,
            ),
        ],
      );
    }

    // ── Tablet: Left chat (with drawers, same as phone) + Right tool panel ──
    // 外层不包 Obx：只有 tool 面板可见性/宽度包窄 Obx，拖 ResizableDivider 不再重建整页；
    // 左侧 Navigator 内部自带 Obx 处理会话标题/页签。
    final toolCtrl = Get.find<TabletToolController>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leftNav = _leftNavKey.currentState;
        if (leftNav != null && await leftNav.maybePop()) {
          return;
        }
        SystemNavigator.pop();
      },
      child: Row(
        children: [
          // Left side: full chat experience with drawers (nested Navigator)
          Expanded(
            child: Navigator(
              key: _leftNavKey,
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => Obx(() {
                  final curSessionId = sessionCtrl.activeSessionId.value;
                  final curOpened = sessionCtrl.openedSessionIds.toList();
                  final curTitle = curSessionId.isNotEmpty
                      ? sessionCtrl.getSessionName(curSessionId)
                      : 'OpenCode';
                  return Scaffold(
                    appBar: _buildAppBar(
                      sessionCtrl,
                      curOpened,
                      curSessionId,
                      curTitle,
                      showToolPanelToggle: true,
                      isTablet: true,
                    ),
                    drawer: const LeftDrawer(
                      initialMode: DrawerMode.projects,
                    ),
                    endDrawer: const RightDrawer(),
                    body: _buildChatBody(context, projectCtrl, sessionCtrl),
                  );
                }),
              ),
            ),
          ),
          // Right side: resizable divider + tool panel
          // Visibility(maintainState) keeps the panel subtree alive when
          // hidden, so toggling visibility does NOT destroy the webview,
          // editors, terminal or ReviewPage state (plain `if` would).
          Obx(() {
            final toolVisible = toolCtrl.isVisible.value;
            final toolWidth = toolCtrl.getPixelWidth(width);
            return Visibility(
              visible: toolVisible,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: false,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ResizableDivider(
                    onDrag: (dx) => toolCtrl.adjustWidth(dx, width),
                    onDragEnd: () => toolCtrl.commitWidth(),
                  ),
                  SizedBox(
                    width: toolWidth,
                    child: const TabletToolPanel(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Phone-layout persistent browser layer.
///
/// Mounted in [HomePage] once the browser sheet has ever been opened and never
/// unmounted afterwards: closing it just slides the sheet down behind an
/// [IgnorePointer] gate, so the underlying [InAppBrowserView] / WebView state
/// (scroll position, JS state, form input) survives and is reused on re-open.
class _PhoneBrowserLayer extends StatelessWidget {
  final TabletToolController controller;
  final VoidCallback onClose;

  const _PhoneBrowserLayer({
    required this.controller,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final visible = controller.browserSheetVisible.value;
      return PopScope(
        canPop: !visible,
        onPopInvokedWithResult: (didPop, result) {
          // 系统返回键：sheet 打开时先关闭它，而非退出页面。
          if (didPop) return;
          if (controller.browserSheetVisible.value) {
            controller.closeBrowserSheet();
          }
        },
        child: IgnorePointer(
          ignoring: !visible,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 半透明遮罩（点按关闭）
              AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: GestureDetector(
                  onTap: visible ? onClose : null,
                  child: const ColoredBox(color: Colors.black54),
                ),
              ),
              // 浏览器 sheet：关闭时整体下滑到屏外，状态保留。
              // Material 提供 IconButton/Tooltip/TextField 所需的祖先。
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedSlide(
                  offset: visible ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: SafeArea(
                      child: InAppBrowserView(onClose: onClose),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
