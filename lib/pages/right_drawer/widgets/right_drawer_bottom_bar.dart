import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes.dart';
import '../../../utils/translations.dart';
import 'vision_model_sheet.dart';

/// 右抽屉底部快捷工具栏（显示设置、关键词唤醒、快捷短语、视觉模型）。
class RightDrawerBottomBar extends StatelessWidget {
  const RightDrawerBottomBar({super.key, this.isDrawer = true});

  final bool isDrawer;

  Widget _buildBottomButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 4),
                SizedBox(
                  height: 26,
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          _buildBottomButton(
            context: context,
            icon: Icons.display_settings_outlined,
            label: LocaleKeys.mobileDisplay.tr,
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              Get.toNamed(AppRoutes.displaySettings);
            },
          ),
          _buildBottomButton(
            context: context,
            icon: Icons.keyboard,
            label: LocaleKeys.mobileKeywordDetection.tr,
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              Get.toNamed(AppRoutes.keywordSettings);
            },
          ),
          _buildBottomButton(
            context: context,
            icon: Icons.quickreply_outlined,
            label: LocaleKeys.csQuickPhrases.tr,
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              Get.toNamed(AppRoutes.quickPhrases);
            },
          ),
          _buildBottomButton(
            context: context,
            icon: Icons.image_search,
            label: LocaleKeys.mobileVisionSettings.tr,
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              VisionModelSheet.show(context);
            },
          ),
        ],
      ),
    );
  }
}
