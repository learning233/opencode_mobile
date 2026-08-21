import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_theme.dart';
import 'translations.dart';

class Snack {
  static void success(String message, {String? title}) {
    final colors = _appColors;
    _show(
      title ?? LocaleKeys.snackSuccess.tr,
      message,
      leftBarIndicatorColor: colors.success,
      icon: Icon(Icons.check_circle_outline, color: colors.success),
      duration: const Duration(seconds: 2),
    );
  }

  static void error(String message, {String? title}) {
    final error = Get.theme.colorScheme.error;
    _show(
      title ?? LocaleKeys.snackError.tr,
      message,
      leftBarIndicatorColor: error,
      icon: Icon(Icons.error_outline, color: error),
      duration: const Duration(seconds: 3),
    );
  }

  static void info(String message, {String? title}) {
    final primary = Get.theme.colorScheme.primary;
    _show(
      title ?? LocaleKeys.snackInfo.tr,
      message,
      leftBarIndicatorColor: primary,
      icon: Icon(Icons.info_outline, color: primary),
      duration: const Duration(seconds: 2),
    );
  }

  static void warning(
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colors = _appColors;
    _show(
      title ?? LocaleKeys.snackWarning.tr,
      message,
      leftBarIndicatorColor: colors.warning,
      icon: Icon(Icons.warning_amber_outlined, color: colors.warning),
      duration: duration,
    );
  }

  static AppThemeColors get _appColors =>
      Get.theme.extension<AppThemeColors>() ?? AppThemeColors.dark;

  static void _show(
    String title,
    String message, {
    required Color leftBarIndicatorColor,
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

    Get.rawSnackbar(
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(top: 10, right: 12, left: 12),
      duration: duration,
      animationDuration: const Duration(milliseconds: 300),
      isDismissible: true,
      dismissDirection: DismissDirection.up,
      overlayBlur: 0, // 不模糊背景
      overlayColor: Colors.transparent, // 透明遮罩，不阻止点击
      titleText: const SizedBox.shrink(),
      messageText: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: leftBarIndicatorColor.withValues(alpha: 0.5),
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
    );
  }
}
