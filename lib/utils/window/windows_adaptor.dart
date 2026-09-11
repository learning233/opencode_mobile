import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../init.dart';
import '../layout_utils.dart';

/// Adapter class for configuring desktop window dimensions, window options,
/// restoration bounds (maximize states), and centering parameters using `window_manager`.
class WindowsAdapter {
  static Future<void> setSize() async {
    if (!isDesktop) return;

    await windowManager.ensureInitialized();

    // 拦截原生关闭信号，使 TitleBarController.onWindowClose 能执行
    // sidecar 清理；否则点系统 X / Alt+F4 会直接退出留下孤儿进程。
    await windowManager.setPreventClose(true);

    final isMax = Global.settings.isMax;
    final windowSize = Global.settings.windowSize;
    final windowPosition = Global.settings.windowPosition;
    final onTop = Global.settings.onTop;

    // 安全解析窗口尺寸，防止存储数据损坏导致崩溃
    Size? safeSize;
    if (windowSize.length >= 2) {
      final w = double.tryParse(windowSize[0]);
      final h = double.tryParse(windowSize[1]);
      if (w != null && h != null && w > 0 && h > 0) {
        safeSize = Size(w, h);
      }
    }

    WindowOptions windowOptions = WindowOptions(
      size: safeSize,
      minimumSize: const Size(800, 500),
      center: windowPosition.isEmpty,
      backgroundColor: Colors.transparent,
      alwaysOnTop: onTop,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // Frameless custom title bar
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (!isMax) {
        if (safeSize != null) {
          await windowManager.setSize(safeSize);
        }
        if (windowPosition.length >= 2) {
          final x = double.tryParse(windowPosition[0]);
          final y = double.tryParse(windowPosition[1]);
          // Prevent window from flying off-screen
          if (x != null &&
              y != null &&
              x >= -100 &&
              y >= -100 &&
              x < 10000 &&
              y < 10000) {
            await windowManager.setPosition(Offset(x, y));
          }
        }
      }
      await windowManager.show();
      if (isMax) {
        await windowManager.maximize();
      }
      await windowManager.focus();
    });
  }
}
