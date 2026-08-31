import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/session_controller.dart';
import '../../init.dart';
import '../../routes.dart';
import '../../services/e2b_workspace_service.dart';
import '../../utils/translations.dart';

/// Shared right-sidebar content used by both the phone drawer and the tablet
/// permanent rail. `isDrawer` only toggles the "close after action" behavior.
class RightPanelContent extends StatelessWidget {
  const RightPanelContent({super.key, required this.isDrawer});

  /// true when shown inside a sliding Drawer (phone), false for a permanent rail.
  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          Padding(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
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
          ),
          Expanded(
            child: Obx(() {
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
            }),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(
              LocaleKeys.mobileAllSessions.tr,
              style: const TextStyle(fontSize: 14),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              Get.toNamed(AppRoutes.sessionList);
            },
          ),
          const Divider(height: 1),
          Padding(
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
                    _showVisionModelSheet(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVisionModelSheet(BuildContext context) {
    final ctrl = Get.find<SessionController>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      LocaleKeys.mobileSelectVisionModel.tr,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                ),
                Flexible(
                  child: Obx(() {
                    final models = ctrl.availableModels
                        .where((m) => m.supportsImage)
                        .toList();
                    if (models.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          LocaleKeys.mobileNoVisionModelsHint.tr,
                          style: Theme.of(ctx).textTheme.bodyMedium,
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: models.length,
                      itemBuilder: (_, i) {
                        final m = models[i];
                        final selected = m.key == ctrl.visionModelKey;
                        return ListTile(
                          dense: true,
                          title: Text(
                            m.name.isNotEmpty ? m.name : m.id,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '${m.providerId}/${m.id}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: selected
                              ? const Icon(Icons.check, size: 18)
                              : null,
                          onTap: () {
                            ctrl.setVisionModel(m.key);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
}
