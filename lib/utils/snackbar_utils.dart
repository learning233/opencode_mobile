import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_theme.dart';
import 'layout_utils.dart';
import 'translations.dart';

class Snack {
  static void success(String message, {String? title}) {
    final colors = _colors();
    _show(
      title ?? LocaleKeys.snackSuccess.tr,
      message,
      indicatorColor: colors.success,
      icon: Icon(Icons.check_circle_outline, color: colors.success),
      duration: const Duration(seconds: 2),
    );
  }

  static void error(String message, {String? title}) {
    final colors = _colors();
    _show(
      title ?? LocaleKeys.snackError.tr,
      message,
      indicatorColor: colors.error,
      icon: Icon(Icons.error_outline, color: colors.error),
      duration: const Duration(seconds: 3),
    );
  }

  static void info(String message, {String? title}) {
    final colors = _colors();
    _show(
      title ?? LocaleKeys.snackInfo.tr,
      message,
      indicatorColor: colors.info,
      icon: Icon(Icons.info_outline, color: colors.info),
      duration: const Duration(seconds: 2),
    );
  }

  static void warning(
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colors = _colors();
    _show(
      title ?? LocaleKeys.snackWarning.tr,
      message,
      indicatorColor: colors.warning,
      icon: Icon(Icons.warning_amber_outlined, color: colors.warning),
      duration: duration,
    );
  }

  /// 主题感知的颜色，避免硬编码 green/red/blue 与品牌色冲突。
  static ({
    Color success,
    Color warning,
    Color error,
    Color info,
  }) _colors() {
    final theme = Get.theme;
    final scheme = theme.colorScheme;
    final app = theme.extension<AppThemeColors>() ?? AppThemeColors.dark;
    return (
      success: app.success,
      warning: app.warning,
      error: scheme.error,
      info: scheme.primary,
    );
  }

  static void _show(
    String title,
    String message, {
    required Color indicatorColor,
    required Widget icon,
    required Duration duration,
  }) {
    // 严格遵守主题色，从 Get.theme 获取以确保全项目统一
    final theme = Get.theme;
    final colorScheme = theme.colorScheme;

    // 使用主题配色：背景用 surface，文字用 onSurface；增加透明度使其具有呼吸感
    final bgColor = colorScheme.surface.withValues(alpha: 0.9);
    final titleStyle =
        theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: colorScheme.onSurface,
        ) ??
        TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: colorScheme.onSurface,
        );

    final messageStyle =
        theme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: colorScheme.onSurface.withValues(alpha: 0.8),
        ) ??
        TextStyle(
          fontSize: 12,
          color: colorScheme.onSurface.withValues(alpha: 0.8),
        );

    final isPc = isDesktop;

    Get.rawSnackbar(
      snackPosition: isPc ? SnackPosition.BOTTOM : SnackPosition.TOP,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      margin: isPc
          ? const EdgeInsets.only(bottom: 20, right: 0, left: 20)
          : const EdgeInsets.only(top: 10, right: 12, left: 12),
      duration: duration,
      animationDuration: const Duration(milliseconds: 300),
      isDismissible: true,
      dismissDirection: isPc ? DismissDirection.horizontal : DismissDirection.up,
      overlayBlur: 0, // 不模糊背景
      overlayColor: Colors.transparent, // 透明遮罩，不阻止点击
      titleText: const SizedBox.shrink(),
      messageText: isPc
          // 桌面端：右下角自适应宽度贴边卡片
          ? Align(
              alignment: Alignment.bottomRight,
              child: IntrinsicWidth(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    border: Border(
                      left: BorderSide(color: indicatorColor, width: 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.onSurface.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: messageStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          // 移动端：顶部全宽悬浮药丸卡片（平板/Web 居中限宽 600）
          : Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: indicatorColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: messageStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
