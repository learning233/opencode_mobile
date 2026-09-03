import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../init.dart';
import '../../../routes.dart';
import '../../../utils/translations.dart';
import '../vad_settings_sheet.dart';

/// 左抽屉底部设置快捷工具栏（主题切换、语言切换、语音 VAD 设置、设置主页）。
class DrawerBottomBar extends StatelessWidget {
  const DrawerBottomBar({super.key, this.isDrawer = true});

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
      child: Obx(() {
        final isLight = Global.themeIsLightRx.value;
        final isZh = Global.languageRx.value?.languageCode == 'zh';

        return Row(
          children: [
            _buildBottomButton(
              context: context,
              icon: isLight
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              label: LocaleKeys.colorTheme.tr,
              onTap: () => Global.toggleTheme(),
            ),
            _buildBottomButton(
              context: context,
              icon: Icons.language,
              label: LocaleKeys.language.tr,
              onTap: () {
                final newLocale = isZh
                    ? const Locale('en', 'US')
                    : const Locale('zh', 'CN');
                Global.setLanguage(newLocale);
              },
            ),
            _buildBottomButton(
              context: context,
              icon: Icons.graphic_eq,
              label: LocaleKeys.vadSettingsTitle.tr,
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                VadSettingsSheet.show(context);
              },
            ),
            _buildBottomButton(
              context: context,
              icon: Icons.settings_outlined,
              label: LocaleKeys.mobileSettings.tr,
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                Get.toNamed(AppRoutes.opencodeSettings);
              },
            ),
          ],
        );
      }),
    );
  }
}
