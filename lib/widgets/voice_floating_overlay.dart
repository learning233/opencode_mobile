import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/voice_input_controller.dart';
import '../utils/translations.dart';

class VoiceFloatingOverlay extends StatelessWidget {
  final VoiceInputController controller;

  const VoiceFloatingOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Obx(() {
      if (!controller.isLongPressMode.value) {
        return const SizedBox.shrink();
      }

      final isCancel = controller.isCancelZone.value;
      final isInsert = controller.isInsertZone.value;
      final text = controller.recognizedText.value;
      final level = controller.soundLevel.value;

      final cardBg = isCancel
          ? (isDark
                ? Colors.red.shade900.withValues(alpha: 0.9)
                : Colors.red.shade50.withValues(alpha: 0.95))
          : isInsert
          ? (isDark
                ? Colors.blue.shade900.withValues(alpha: 0.9)
                : Colors.blue.shade50.withValues(alpha: 0.95))
          : (isDark
                ? theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.95,
                  )
                : Colors.white.withValues(alpha: 0.95));

      final borderColor = isCancel
          ? Colors.redAccent
          : isInsert
          ? Colors.blueAccent
          : theme.colorScheme.primary.withValues(alpha: 0.5);

      final textColor = isCancel
          ? (isDark ? Colors.red.shade100 : Colors.red.shade900)
          : isInsert
          ? (isDark ? Colors.blue.shade100 : Colors.blue.shade900)
          : theme.colorScheme.onSurface;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: 320,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: (isCancel || isInsert) ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isCancel
                          ? Colors.red
                          : (isInsert ? Colors.blue : Colors.black))
                      .withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 声浪 & 图标
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AudioWaveform(
                  level: level,
                  isCancel: isCancel,
                  isInsert: isInsert,
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCancel
                        ? Colors.red.withValues(alpha: 0.2)
                        : isInsert
                        ? Colors.blue.withValues(alpha: 0.2)
                        : theme.colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCancel
                        ? CupertinoIcons.delete
                        : isInsert
                        ? CupertinoIcons.arrow_right_to_line
                        : CupertinoIcons.mic,
                    color: isCancel
                        ? Colors.redAccent
                        : isInsert
                        ? Colors.blueAccent
                        : theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                _AudioWaveform(
                  level: level,
                  isCancel: isCancel,
                  isInsert: isInsert,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 文本显示框
            Container(
              constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: Text(
                  text.isNotEmpty ? text : LocaleKeys.voiceListening.tr,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: text.isNotEmpty
                        ? textColor
                        : theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.5,
                          ),
                    fontSize: 13.5,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 操作提示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCancel
                      ? CupertinoIcons.xmark_circle
                      : isInsert
                      ? CupertinoIcons.arrow_right_to_line
                      : CupertinoIcons.up_arrow,
                  size: 14,
                  color: isCancel
                      ? Colors.redAccent
                      : isInsert
                      ? Colors.blueAccent
                      : theme.colorScheme.secondary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    isCancel
                        ? LocaleKeys.voiceReleaseCancel.tr
                        : isInsert
                        ? LocaleKeys.voiceReleaseInsert.tr
                        : LocaleKeys.voiceReleaseHint.tr,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: (isCancel || isInsert)
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isCancel
                          ? Colors.redAccent
                          : isInsert
                          ? Colors.blueAccent
                          : theme.colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _AudioWaveform extends StatelessWidget {
  final double level;
  final bool isCancel;
  final bool isInsert;

  const _AudioWaveform({
    required this.level,
    required this.isCancel,
    required this.isInsert,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = isCancel
        ? Colors.redAccent
        : isInsert
        ? Colors.blueAccent
        : theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final heightMultiplier = (i % 2 == 0 ? 0.6 : 1.0) * (0.3 + level * 0.7);
        final barHeight = (12.0 + heightMultiplier * 16.0).clamp(6.0, 26.0);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 3.5,
          height: barHeight,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.4 + (i * 0.15)),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
