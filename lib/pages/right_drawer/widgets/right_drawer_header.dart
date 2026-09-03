import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/session_controller.dart';
import '../../../utils/translations.dart';

/// 右抽屉顶部标题与清空会话操作栏。
class RightDrawerHeader extends StatelessWidget {
  const RightDrawerHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            LocaleKeys.mobileOpenSessions.tr,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Obx(() {
            if (ctrl.openedSessionIds.isEmpty) {
              return const SizedBox.shrink();
            }
            return InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => ctrl.clearAllOpenedSessions(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  LocaleKeys.mobileClearAllSessions.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
