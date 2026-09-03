import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/session_controller.dart';
import '../../../init.dart';
import '../../../services/e2b_workspace_service.dart';
import '../../../utils/translations.dart';

/// 右抽屉当前打开的会话列表组件。
class RightDrawerSessionList extends StatelessWidget {
  const RightDrawerSessionList({super.key, this.isDrawer = true});

  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();
    final theme = Theme.of(context);

    return Obx(() {
      final ids = ctrl.openedSessionIds;
      if (ids.isEmpty) {
        return Center(
          child: Text(
            LocaleKeys.mobileNoOpenSessions.tr,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        );
      }
      return ListView.builder(
        itemCount: ids.length,
        itemBuilder: (_, i) {
          final id = ids[i];
          final isActive = id == ctrl.activeSessionId.value;
          final name = ctrl.getSessionName(id);
          return ListTile(
            dense: true,
            selected: isActive,
            leading: Icon(
              E2bWorkspaceService.isCloudUrl(Global.serverUrl)
                  ? Icons.cloud_outlined
                  : Icons.dns_outlined,
              size: 18,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(name, style: const TextStyle(fontSize: 13)),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => ctrl.closeSession(id),
            ),
            onTap: () {
              ctrl.selectSession(id);
              if (isDrawer) Navigator.pop(context);
            },
          );
        },
      );
    });
  }
}
