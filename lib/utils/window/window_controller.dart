import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import '../app_logger.dart';
import '../../init.dart';
import '../../api/sidecar_manager.dart';

/// Controls the application window's title bar interactions: minimize,
/// maximize/restore, always-on-top, and drag state. Also handles graceful
/// shutdown on window close to prevent orphaned child processes.
class TitleBarController extends GetxController with WindowListener {
  /// Whether the window is currently maximized.
  bool isMax = Global.settings.isMax;

  /// Whether the window is set to stay on top of other windows.
  bool onTop = Global.settings.onTop;
  bool _restoringSize = false; // 标记正在恢复尺寸，跳过 onWindowResized 保存
  bool _sidecarStopped = false; // 保证 stop 只执行一次

  @override
  void onInit() {
    windowManager.addListener(this);
    super.onInit();
  }

  @override
  void onClose() {
    windowManager.removeListener(this);
    super.onClose();
  }

  /// Called when a title bar drag ends. If the window was maximized, it
  /// restores to normal state (unmaximizes) as a result of the drag.
  Future<void> stopDragging(DragEndDetails details) async {
    if (isMax) {
      isMax = false;
      await Global.settings.setIsMax(false);
      update();
    }
  }

  /// Minimizes the application window.
  Future<void> pressMini() async {
    await windowManager.minimize();
  }

  /// Toggles the "always on top" state of the window and persists the setting.
  Future<void> pressTop() async {
    bool isOnTop = await windowManager.isAlwaysOnTop();
    if (isOnTop) {
      await windowManager.setAlwaysOnTop(false);
      await Global.settings.setOnTop(false);
      onTop = false;
    } else {
      await windowManager.setAlwaysOnTop(true);
      await Global.settings.setOnTop(true);
      onTop = true;
    }
    update();
  }

  /// Maximizes the window. Saves the current window size before maximizing so
  /// it can be restored later.
  Future<void> pressMax() async {
    if (!isMax) {
      final size = await windowManager.getSize();
      await Global.settings.setWindowSize([
        size.width.toString(),
        size.height.toString(),
      ]);
    }
    await windowManager.maximize();
    isMax = true;
    await Global.settings.setIsMax(true);
    update();
  }

  /// Restores the window from maximized to normal state.
  Future<void> pressUnMax() async {
    _restoringSize = true;
    await windowManager.unmaximize();
    isMax = false;
    await Global.settings.setIsMax(false);
    update();
    Future.delayed(const Duration(milliseconds: 200), () {
      _restoringSize = false;
    });
  }

  /// Intercepts window close to cleanup sidecar / connections.
  @override
  void onWindowClose() async {
    if (!_sidecarStopped) {
      _sidecarStopped = true;
      try {
        await SidecarManager.instance.stop();
      } catch (e) {
        AppLogger.e('WindowController onWindowClose stop sidecar error', e);
      }
    }
    await windowManager.destroy();
    super.onWindowClose();
  }

  @override
  void onWindowMaximize() {
    if (!isMax) {
      isMax = true;
      Global.settings.setIsMax(true);
      update();
    }
    super.onWindowMaximize();
  }

  @override
  void onWindowUnmaximize() {
    if (isMax) {
      isMax = false;
      Global.settings.setIsMax(false);
      update();
    }
    super.onWindowUnmaximize();
  }

  @override
  void onWindowResized() async {
    final isMaximized = await windowManager.isMaximized();
    final isMinimized = await windowManager.isMinimized();
    if (isMaximized || isMinimized || _restoringSize) {
      super.onWindowResized();
      return;
    }
    Size size = await windowManager.getSize();
    await Global.settings.setWindowSize([
      size.width.toString(),
      size.height.toString(),
    ]);
    super.onWindowResized();
  }

  @override
  void onWindowMoved() async {
    final isMaximized = await windowManager.isMaximized();
    final isMinimized = await windowManager.isMinimized();
    if (isMaximized || isMinimized) {
      super.onWindowMoved();
      return;
    }
    Offset windowPosition = await windowManager.getPosition();
    await Global.settings.setWindowPosition([
      windowPosition.dx.toString(),
      windowPosition.dy.toString(),
    ]);
    super.onWindowMoved();
  }
}
