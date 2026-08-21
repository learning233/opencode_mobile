import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../api/models/project.dart';
import '../../controllers/project_controller.dart';
import '../../init.dart';
import '../../routes.dart';
import '../../utils/translations.dart';
import '../../widgets/left_drawer/file_tree_view.dart';
import '../../widgets/vad_settings_sheet.dart';
import '../../utils/layout_utils.dart';
import '../../utils/snackbar_utils.dart';
import 'project_tile.dart';

enum DrawerMode { projects, files }

/// Shared left-sidebar content used by both the phone drawer and the tablet panel.
class LeftPanelContent extends StatefulWidget {
  const LeftPanelContent({super.key, required this.isDrawer, this.initialMode});

  /// true when shown inside a sliding Drawer (phone), false for a permanent rail.
  final bool isDrawer;

  /// Optional initial mode override (e.g. projects for HomePage, files for FilePage).
  final DrawerMode? initialMode;

  @override
  State<LeftPanelContent> createState() => _LeftPanelContentState();
}

class _LeftPanelContentState extends State<LeftPanelContent> {
  late final Rx<DrawerMode> drawerMode;
  String _appVersion = 'v0.9.8';

  @override
  void initState() {
    super.initState();
    drawerMode = (widget.initialMode ?? DrawerMode.projects).obs;
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${info.version}';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectCtrl = Get.find<ProjectController>();

    return SafeArea(
      child: Column(
        children: [
          // Header / Content Body
          Expanded(
            child: Obx(() {
              final mode = drawerMode.value;
              final activeProj = projectCtrl.activeProject.value;

              if (mode == DrawerMode.files && activeProj != null) {
                return _buildFilesMode(context, theme, projectCtrl, activeProj);
              }
              return _buildProjectsMode(context, theme, projectCtrl);
            }),
          ),
          // Mode Switcher Tile (above settings bar)
          _buildModeSwitcherTile(context, theme, projectCtrl),
          const Divider(height: 1),
          // Bottom Settings Bar
          Padding(
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
                      if (widget.isDrawer) Navigator.pop(context);
                      VadSettingsSheet.show(context);
                    },
                  ),
                  _buildBottomButton(
                    context: context,
                    icon: Icons.settings_outlined,
                    label: LocaleKeys.mobileSettings.tr,
                    onTap: () {
                      if (widget.isDrawer) Navigator.pop(context);
                      Get.toNamed(AppRoutes.opencodeSettings);
                    },
                  ),
                ],
              );
            }),
          ),
          // Version Tile (below settings bar)
          _buildVersionTile(context, theme),
        ],
      ),
    );
  }

  Widget _buildProjectsMode(
    BuildContext context,
    ThemeData theme,
    ProjectController projectCtrl,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                LocaleKeys.mobileProjects.tr,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _showAddProjectDialog(context, projectCtrl),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    CupertinoIcons.add,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Obx(() {
            if (projectCtrl.projects.isEmpty) {
              final error = projectCtrl.projectsError.value;
              if (error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_circle,
                          size: 28,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          LocaleKeys.mobileProjectsLoadFailed.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: projectCtrl.fetchProjects,
                          child: Text(LocaleKeys.retry.tr),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Center(
                child: Text(
                  LocaleKeys.mobileNoProjects.tr,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => projectCtrl.fetchProjects(),
              child: ListView.builder(
                itemCount: projectCtrl.projects.length,
                padding: const EdgeInsets.symmetric(vertical: 3),
                itemBuilder: (context, index) {
                  final project = projectCtrl.projects[index];
                  final isActive =
                      projectCtrl.activeProject.value?.id == project.id;
                  return ProjectTile(
                    project: project,
                    isActive: isActive,
                    onTap: () {
                      projectCtrl.selectProject(project);
                      if (widget.isDrawer) Navigator.pop(context);
                    },
                    onBrowseFiles: () {
                      projectCtrl.selectProject(project);
                      if (widget.isDrawer) Navigator.pop(context);
                      Get.toNamed(AppRoutes.fileList);
                    },
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFilesMode(
    BuildContext context,
    ThemeData theme,
    ProjectController projectCtrl,
    ProjectModel activeProj,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active Project Header
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          minVerticalPadding: 2,
          minLeadingWidth: 24,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          tileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          leading: Icon(
            Icons.workspaces_filled,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            activeProj.displayName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: activeProj.worktree.isNotEmpty
              ? Text(
                  activeProj.worktree,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
        ),
        const Divider(height: 1),
        // File Tree View taking full remaining space
        Expanded(
          child: FileTreeView(
            key: ValueKey('tree_${activeProj.id}_${activeProj.worktree}'),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSwitcherTile(
    BuildContext context,
    ThemeData theme,
    ProjectController projectCtrl,
  ) {
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
              drawerMode.value =
                  isFiles ? DrawerMode.projects : DrawerMode.files;
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

  Widget _buildVersionTile(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        InkWell(
          onTap: () {
            if (widget.isDrawer) Navigator.pop(context);
            Get.toNamed(AppRoutes.about);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Text(
              _appVersion,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
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

void _showAddProjectDialog(BuildContext context, ProjectController ctrl) {
  showDialog<void>(
    context: context,
    builder: (_) => _AddProjectDialog(ctrl: ctrl),
  );
}

/// 添加项目对话框：持有自己的 TextEditingController，随 widget 生命周期
/// 在 dispose() 中释放，避免退出动画期间 use-after-dispose 崩溃。
class _AddProjectDialog extends StatefulWidget {
  final ProjectController ctrl;

  const _AddProjectDialog({required this.ctrl});

  @override
  State<_AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<_AddProjectDialog> {
  late final TextEditingController _controller;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '/home/ubuntu/');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final path = _controller.text.trim();
    if (path.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final ok = await widget.ctrl.addProjectByPath(path);
    if (!mounted) return;
    if (!ok) {
      setState(() => _submitting = false);
      Snack.error(LocaleKeys.mobileAddProjectFailed.tr);
      return;
    }
    Navigator.pop(context);
    final added = widget.ctrl.projects.firstWhereOrNull(
      (p) => ProjectController.normalizeDirectory(p.worktree) ==
          ProjectController.normalizeDirectory(path),
    );
    if (added != null) {
      await widget.ctrl.selectProject(added);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(LocaleKeys.mobileAddProject.tr),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: LocaleKeys.mobileServerPath.tr,
          hintText: '/home/ubuntu/new_project',
          border: const OutlineInputBorder(),
        ),
        autofocus: true,
        enabled: !_submitting,
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text(LocaleKeys.cancel.tr),
        ),
        FilledButton(
          onPressed: _submit,
          child: _submitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : Text(LocaleKeys.add.tr),
        ),
      ],
    );
  }
}
