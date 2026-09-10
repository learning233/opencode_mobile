import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import 'window_controller.dart';
import '../../api/sidecar_manager.dart';
import '../../init.dart';

class WindowsButtons extends StatelessWidget {
  final TitleBarController? controller;

  const WindowsButtons({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ctrl = controller ?? Get.find<TitleBarController>();

    return Container(
      height: Global.titleBarHeight,
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Theme Toggle Button
          IconButton(
            onPressed: () => Global.toggleTheme(),
            iconSize: 15,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: isDark ? '浅色模式' : '深色模式',
            icon: Icon(
              isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon,
              color: theme.textTheme.bodyMedium?.color?.withValues(
                alpha: 0.7,
              ),
            ),
          ),
          // Pin Button
          GetBuilder<TitleBarController>(
            init: ctrl,
            builder: (c) {
              return IconButton(
                onPressed: c.pressTop,
                iconSize: 15,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                tooltip: c.onTop ? '取消置顶' : '窗口置顶',
                icon: Icon(
                  c.onTop ? CupertinoIcons.pin_fill : CupertinoIcons.pin,
                  color: c.onTop
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.7,
                        ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          // Minimize Button
          IconButton(
            onPressed: ctrl.pressMini,
            iconSize: 15,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: '最小化',
            icon: Icon(
              CupertinoIcons.minus,
              color: theme.textTheme.bodyMedium?.color?.withValues(
                alpha: 0.7,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Maximize / Restore Button
          GetBuilder<TitleBarController>(
            init: ctrl,
            builder: (c) {
              return IconButton(
                onPressed: c.isMax ? c.pressUnMax : c.pressMax,
                iconSize: 15,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                tooltip: c.isMax ? '向下还原' : '最大化',
                icon: Icon(
                  c.isMax
                      ? CupertinoIcons.square_on_square
                      : CupertinoIcons.square,
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          // Close Button
          IconButton(
            onPressed: () async {
              try {
                await SidecarManager.instance.stop();
              } catch (_) {}
              await windowManager.close();
            },
            iconSize: 15,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            hoverColor: Colors.red,
            tooltip: '关闭',
            style: IconButton.styleFrom(
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            icon: const Icon(CupertinoIcons.clear),
          ),
        ],
      ),
    );
  }
}
