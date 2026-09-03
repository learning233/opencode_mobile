import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../utils/translations.dart';
import 'session_indicator.dart';

/// Home 页面专用的顶层 AppBar 组件。
/// 封装了会话标题、多会话指示器、Token 上下文用量进度条与侧栏/工具栏触发按钮。
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({
    super.key,
    required this.sessionCtrl,
    required this.opened,
    required this.sessionId,
    required this.title,
    this.showMenu = true,
    this.showEndDrawer = true,
    this.showToolPanelToggle = false,
    this.isTablet = false,
    this.onSelectSession,
  });

  final SessionController sessionCtrl;
  final List<String> opened;
  final String sessionId;
  final String title;
  final bool showMenu;
  final bool showEndDrawer;
  final bool showToolPanelToggle;
  final bool isTablet;
  final ValueChanged<String>? onSelectSession;

  @override
  Size get preferredSize => Size.fromHeight(
    (isTablet ? 40.0 : kToolbarHeight) + (opened.isNotEmpty ? 28.0 : 0.0),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      toolbarHeight: isTablet ? 40.0 : kToolbarHeight,
      centerTitle: true,
      title: opened.isNotEmpty
          ? SessionIndicator(
              openedIds: opened,
              activeId: sessionId,
              onTap: (id) {
                if (onSelectSession != null) {
                  onSelectSession!(id);
                } else {
                  sessionCtrl.selectSession(id);
                }
              },
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
