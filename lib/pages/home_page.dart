import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/project_controller.dart';
import '../controllers/session_controller.dart';
import '../controllers/tablet_tool_controller.dart';
import '../utils/layout_utils.dart';
import 'home/widgets/phone_brower.dart';
import 'left_drawer.dart';
import 'left_drawer/left_panel_content.dart';
import 'right_drawer.dart';
import '../utils/translations.dart';
import 'home/tablet/resizable_divider.dart';
import 'home/tablet/tablet_tool_panel.dart';
import 'home/chat_view.dart';
import 'home/prompt_input.dart';
import 'home/session_indicator.dart';

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

  /// 上次点击系统返回键的时间（用于双击返回退出）
  DateTime? _lastBackTime;

  /// 处理双击返回退出应用
  Future<void> _handlePop(BuildContext context) async {
    final toolCtrl = Get.find<TabletToolController>();

    // 1. 如果手机端内置浏览器打开着，先关闭浏览器
    if (toolCtrl.browserSheetVisible.value) {
      toolCtrl.closeBrowserSheet();
      return;
    }

    // 2. 如果是平板且左侧内嵌路由可以返回，先 pop 内嵌路由
    final leftNav = _leftNavKey.currentState;
    if (leftNav != null && await leftNav.maybePop()) {
      return;
    }

    // 3. 双击时间差判定 (2秒内)
    final now = DateTime.now();
    if (_lastBackTime == null ||
        now.difference(_lastBackTime!) > const Duration(seconds: 2)) {
      _lastBackTime = now;
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocaleKeys.pressBackAgainToExit.tr),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        );
      }
      return;
    }

    // 4. 2秒内再次按下，真正退出应用
    SystemNavigator.pop();
  }

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

  @override
  Widget build(BuildContext context) {
    final projectCtrl = Get.find<ProjectController>();
    final sessionCtrl = Get.find<SessionController>();
    final toolCtrl = Get.find<TabletToolController>();
    final width = MediaQuery.of(context).size.width;
    final isTablet = isTabletLayout(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handlePop(context);
      },
      child: isTablet
          ? tabletWidget(sessionCtrl, projectCtrl, toolCtrl, width)
          : phoneWidget(sessionCtrl, projectCtrl, toolCtrl),
    );
  }

  Widget phoneWidget(
    SessionController sessionCtrl,
    ProjectController projectCtrl,
    TabletToolController toolCtrl,
  ) {
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
          PhoneBrowserLayer(
            controller: toolCtrl,
            onClose: toolCtrl.closeBrowserSheet,
          ),
      ],
    );
  }

  Widget tabletWidget(
    SessionController sessionCtrl,
    ProjectController projectCtrl,
    TabletToolController toolCtrl,
    final double width,
  ) {
    return Row(
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
                  drawer: const LeftDrawer(initialMode: DrawerMode.projects),
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
                SizedBox(width: toolWidth, child: const TabletToolPanel()),
              ],
            ),
          );
        }),
      ],
    );
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
}
