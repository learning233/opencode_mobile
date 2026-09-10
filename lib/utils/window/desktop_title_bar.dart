import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import '../../controllers/project_controller.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../init.dart';
import '../../utils/translations.dart';
import 'window_button.dart';
import 'window_controller.dart';

/// Top-level independent title bar for desktop platforms (Windows / macOS / Linux).
/// Spans across the entire window width, separate from any page-level AppBars.
class DesktopTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const DesktopTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final controller = Get.find<TitleBarController>();
    final projectCtrl = Get.isRegistered<ProjectController>()
        ? Get.find<ProjectController>()
        : null;

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (details) async {
          await windowManager.startDragging();
        },
        onPanEnd: controller.stopDragging,
        onDoubleTap: () async {
          if (controller.isMax) {
            await controller.pressUnMax();
          } else {
            await controller.pressMax();
          }
        },
        child: Container(
          height: Global.titleBarHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.12),
                width: 0.8,
              ),
            ),
          ),
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              if (projectCtrl != null)
                Obx(() {
                  final proj = projectCtrl.activeProject.value;
                  final title = (proj?.displayName.isNotEmpty == true)
                      ? proj!.displayName
                      : 'OpenCode';
                  return Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.85,
                      ),
                    ),
                  );
                })
              else
                Text(
                  'OpenCode',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.85,
                    ),
                  ),
                ),
              // Draggable middle area
              const Spacer(),
              // Panel layout toggle button (right panel)
              if (Get.isRegistered<TabletToolController>())
                Obx(() {
                  final toolCtrl = Get.find<TabletToolController>();
                  final isVisible = toolCtrl.isVisible.value;
                  return IconButton(
                    onPressed: () => toolCtrl.togglePanel(),
                    iconSize: 15,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    tooltip: LocaleKeys.tabletToggleToolPanel.tr,
                    icon: Icon(
                      CupertinoIcons.sidebar_right,
                      color: isVisible
                          ? theme.colorScheme.primary
                          : theme.textTheme.bodyMedium?.color?.withValues(
                              alpha: 0.7,
                            ),
                    ),
                  );
                }),
              const SizedBox(width: 2),
              // Window buttons on the far right
              WindowsButtons(controller: controller),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(Global.titleBarHeight);
}
