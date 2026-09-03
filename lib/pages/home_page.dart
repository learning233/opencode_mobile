import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:opencode_app/pages/left_drawer/left_drawer_mode.dart';
import '../controllers/session_controller.dart';
import '../controllers/tablet_tool_controller.dart';
import '../utils/layout_utils.dart';
import '../utils/translations.dart';
import 'home/home_app_bar.dart';
import 'home/home_chat_body.dart';
import 'home/tablet/resizable_divider.dart';
import 'home/tablet/tablet_tool_panel.dart';
import 'home/widgets/phone_brower.dart';
import 'left_drawer.dart';
import 'right_drawer.dart';

/// page 根目录主页结构文件：主要放页面框架、响应式布局组织和退出逻辑，
/// 具体的 UI 元素放入对应文件夹中（如 lib/pages/home/）。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Worker? _browserSheetWorker;

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
    _browserSheetWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          ? tabletWidget(sessionCtrl, toolCtrl, width)
          : phoneWidget(sessionCtrl, toolCtrl),
    );
  }

  Widget phoneWidget(
    SessionController sessionCtrl,
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
            appBar: HomeAppBar(
              sessionCtrl: sessionCtrl,
              opened: opened,
              sessionId: sessionId,
              title: title,
            ),
            drawer: const LeftDrawer(),
            endDrawer: const RightDrawer(),
            body: const HomeChatBody(),
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
                  appBar: HomeAppBar(
                    sessionCtrl: sessionCtrl,
                    opened: curOpened,
                    sessionId: curSessionId,
                    title: curTitle,
                    showToolPanelToggle: true,
                    isTablet: true,
                  ),
                  drawer: const LeftDrawer(initialMode: DrawerMode.projects),
                  endDrawer: const RightDrawer(),
                  body: const HomeChatBody(),
                );
              }),
            ),
          ),
        ),
        // Right side: resizable divider + tool panel
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
}
