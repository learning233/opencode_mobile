import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../utils/layout_utils.dart';
import '../../../utils/translations.dart';
import '../left_drawer_mode.dart';

/// 左抽屉模式切换条（项目列表 <-> 文件浏览）。
class DrawerModeSwitcher extends StatelessWidget {
  const DrawerModeSwitcher({super.key, required this.drawerMode});

  final Rx<DrawerMode> drawerMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = isTabletLayout(context);

    return Obx(() {
      final isFiles = drawerMode.value == DrawerMode.files;
      // On phone (non-tablet), do not show mode switcher tile at all
      if (!isTablet) {
        return const SizedBox.shrink();
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            minLeadingWidth: 24,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            onTap: () {
              drawerMode.value = isFiles
                  ? DrawerMode.projects
                  : DrawerMode.files;
            },
            leading: Icon(
              isFiles
                  ? Icons.folder_special_outlined
                  : Icons.folder_copy_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              isFiles
                  ? LocaleKeys.drawerBackToProjects.tr
                  : LocaleKeys.drawerBrowseFiles.tr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    });
  }
}
