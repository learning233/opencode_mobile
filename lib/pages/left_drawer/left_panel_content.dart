import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../api/models/project.dart';
import '../../api/models/search_result.dart';
import '../../api/sidecar_manager.dart';
import '../../controllers/file_search_controller.dart';
import '../../controllers/project_controller.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../init.dart';
import '../../models/e2b_sandbox_info.dart';
import '../../routes.dart';
import '../../services/e2b_workspace_service.dart';
import '../../utils/layout_utils.dart';
import '../../utils/snackbar_utils.dart';
import '../../utils/translations.dart';
import 'file_tree_view.dart';
import 'vad_settings_sheet.dart';
import '../settings/connect/cloud_workspace_launch_dialog.dart';
import '../settings/connect/cloud_workspace_sheet.dart';
import '../settings/connect/e2b_api_key_dialog.dart';
import '../settings/connect/self_hosted_connection_sheet.dart';
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
  final ScrollController _projectsScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Worker? _projectWorker;
  bool _hiddenProjectsExpanded = false;
  String _appVersion = 'v0.9.8';

  bool _isSwitchingBackend = false;
  String? _switchingMessage;

  @override
  void initState() {
    super.initState();
    drawerMode = (widget.initialMode ?? DrawerMode.projects).obs;
    _loadVersion();
    if (Get.isRegistered<ProjectController>()) {
      Get.find<ProjectController>().fetchSandboxes();
    }

    if (Get.isRegistered<ProjectController>()) {
      _projectWorker = ever(Get.find<ProjectController>().activeProject, (_) {
        _searchController.clear();
        if (Get.isRegistered<FileSearchController>()) {
          Get.find<FileSearchController>().clear();
        }
      });
    }
  }

  @override
  void dispose() {
    _projectWorker?.dispose();
    _projectsScrollController.dispose();
    _searchController.dispose();
    super.dispose();
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

  Future<void> _fetchSandboxes() async {
    if (Get.isRegistered<ProjectController>()) {
      await Get.find<ProjectController>().fetchSandboxes();
    }
  }

  Future<void> _switchToSelfHosted() async {
    if (_isSwitchingBackend) return;
    final url = Global.settings.selfHostedServerUrl?.trim() ?? '';
    if (url.isEmpty) {
      final saved = await SelfHostedConnectionSheet.show(context);
      if (saved == true && mounted) {
        setState(() {});
      }
      return;
    }
    setState(() {
      _isSwitchingBackend = true;
      _switchingMessage = LocaleKeys.drawerSwitchingBackend.tr;
    });
    try {
      E2bWorkspaceService.instance.stopKeepAlive();
      final user =
          (Global.settings.selfHostedServerUsername?.trim().isEmpty ?? true)
          ? 'opencode'
          : Global.settings.selfHostedServerUsername!.trim();
      final pass = Global.settings.selfHostedServerPassword ?? '';
      final res = await SidecarManager.instance.updateConnection(
        url,
        user,
        pass,
      );
      if (!res.success) {
        Snack.error(res.error ?? LocaleKeys.mobileConnectionFailed.tr);
        return;
      }
      final projectCtrl = Get.find<ProjectController>();
      await projectCtrl.refreshAfterConnect();
      if (Get.isRegistered<SessionController>()) {
        Get.find<SessionController>().initializeAfterConnect();
      }
      if (Get.isRegistered<SettingsController>()) {
        Get.find<SettingsController>().checkHealth();
      }
    } catch (e) {
      Snack.error('$e');
    } finally {
      if (mounted) setState(() => _isSwitchingBackend = false);
    }
  }

  Future<void> _switchToSandbox(E2bSandboxInfo sb) async {
    if (_isSwitchingBackend) return;
    if (Global.serverUrl.contains(sb.sandboxId)) return;

    final config = Global.settings.cloudWorkspaceConfig;
    setState(() {
      _isSwitchingBackend = true;
      _switchingMessage =
          '${LocaleKeys.e2bConnectingSandbox.tr} (${sb.sandboxId})...';
    });
    try {
      final res = await E2bWorkspaceService.instance.connectSandbox(
        config: config,
        sandboxId: sb.sandboxId,
        endpointUrl: sb.endpointUrl,
        onProgress: (msg) {
          if (mounted) setState(() => _switchingMessage = msg);
        },
      );
      if (!res.success) {
        Snack.error(res.error ?? LocaleKeys.e2bConnectFailed.tr);
        return;
      }

      final password = res.password ?? '';
      final sidecarRes = await SidecarManager.instance.updateConnection(
        sb.endpointUrl,
        'opencode',
        password,
      );
      if (!sidecarRes.success) {
        Snack.error(sidecarRes.error ?? LocaleKeys.mobileConnectionFailed.tr);
        return;
      }

      await Global.settings.updateCloudWorkspaceConfig((curr) {
        return curr.copyWith(
          activeSandboxId: sb.sandboxId,
          activeSandboxUrl: sb.endpointUrl,
          activeSandboxPassword: password,
          activeSandboxEnvdToken: res.envdAccessToken,
          activeSandboxStatus: 'running',
          lastConnectedAt: DateTime.now(),
        );
      });

      E2bWorkspaceService.instance.startKeepAlive(
        sandboxId: sb.sandboxId,
        apiKey: config.e2bApiKey,
        timeoutSeconds: E2bWorkspaceService.sanitizeTimeoutSeconds(
          config.ttlHours,
        ),
        domain: res.domain,
      );

      final projectCtrl = Get.find<ProjectController>();
      await projectCtrl.refreshAfterConnect();
      if (Get.isRegistered<SessionController>()) {
        Get.find<SessionController>().initializeAfterConnect();
      }
      if (Get.isRegistered<SettingsController>()) {
        Get.find<SettingsController>().checkHealth();
      }
      await _fetchSandboxes();
    } catch (e) {
      Snack.error('$e');
    } finally {
      if (mounted) setState(() => _isSwitchingBackend = false);
    }
  }

  Widget _buildProjectsMode(
    BuildContext context,
    ThemeData theme,
    ProjectController projectCtrl,
  ) {
    return Obx(() {
      final isCloud = E2bWorkspaceService.isCloudUrl(Global.serverUrl);
      final hasHidden = projectCtrl.hiddenProjectKeys.isNotEmpty;
      final visibleProjects = projectCtrl.projects
          .where((p) => !projectCtrl.isProjectHidden(p))
          .toList(growable: false);

      return Column(
        children: [
          if (_isSwitchingBackend)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _switchingMessage ?? LocaleKeys.drawerSwitchingBackend.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  projectCtrl.fetchProjects(),
                  _fetchSandboxes(),
                ]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _projectsScrollController,
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  _buildSelfHostedSection(
                    context,
                    theme,
                    projectCtrl,
                    !isCloud && Global.serverUrl.isNotEmpty,
                    visibleProjects,
                  ),
                  const SizedBox(height: 8),
                  _buildCloudSandboxesSection(
                    context,
                    theme,
                    projectCtrl,
                    isCloud,
                    visibleProjects,
                  ),
                  if (hasHidden) ...[
                    const SizedBox(height: 8),
                    _buildHiddenProjectsSection(projectCtrl, theme),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildSelfHostedSection(
    BuildContext context,
    ThemeData theme,
    ProjectController projectCtrl,
    bool isConnected,
    List<ProjectModel> visibleProjects,
  ) {
    const successColor = Color(0xFF34C759);
    final hasSelfHosted =
        Global.settings.selfHostedServerUrl?.trim().isNotEmpty == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: isConnected ? null : _switchToSelfHosted,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.dns_outlined,
                      size: 18,
                      color: isConnected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        LocaleKeys.drawerSelfHostedSection.tr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isConnected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isConnected) ...[
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: const BoxDecoration(
                          color: successColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        icon: const Icon(CupertinoIcons.add, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: LocaleKeys.mobileAddProject.tr,
                        onPressed: () =>
                            _showAddProjectDialog(context, projectCtrl),
                      ),
                    ] else ...[
                      if (!hasSelfHosted)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                          ),
                          onPressed: () async {
                            final saved = await SelfHostedConnectionSheet.show(
                              context,
                            );
                            if (saved == true && mounted) setState(() {});
                          },
                          icon: const Icon(Icons.settings_outlined, size: 14),
                          label: Text(
                            LocaleKeys.mobileServerConnection.tr,
                            style: const TextStyle(fontSize: 11),
                          ),
                        )
                      else ...[
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: LocaleKeys.mobileServerConnection.tr,
                          onPressed: () async {
                            final saved = await SelfHostedConnectionSheet.show(
                              context,
                            );
                            if (saved == true && mounted) setState(() {});
                          },
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                          ),
                          onPressed:
                              _isSwitchingBackend ? null : _switchToSelfHosted,
                          icon: const Icon(Icons.swap_horiz, size: 14),
                          label: Text(
                            LocaleKeys.drawerClickToConnect.tr,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (isConnected) ...[
              if (visibleProjects.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      LocaleKeys.mobileNoProjects.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleProjects.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    final project = visibleProjects[index];
                    final isActive =
                        projectCtrl.activeProject.value?.id == project.id;
                    return Slidable(
                      key: ValueKey('project_slide_${project.worktree}'),
                      endActionPane: ActionPane(
                        motion: const BehindMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) => projectCtrl.hideProject(project),
                            backgroundColor: theme.colorScheme.errorContainer,
                            foregroundColor: theme.colorScheme.onErrorContainer,
                            icon: Icons.visibility_off_outlined,
                            label: LocaleKeys.mobileHideProject.tr,
                          ),
                        ],
                      ),
                      child: ProjectTile(
                        project: project,
                        isActive: isActive,
                        onTap: () {
                          projectCtrl.selectProject(project);
                          if (widget.isDrawer) {
                            Navigator.pop(context);
                          }
                        },
                        onBrowseFiles: () {
                          projectCtrl.selectProject(project);
                          if (widget.isDrawer) {
                            Navigator.pop(context);
                          }
                          Get.toNamed(AppRoutes.fileList);
                        },
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCloudSandboxesSection(
    BuildContext context,
    ThemeData theme,
    ProjectController projectCtrl,
    bool isCloudConnected,
    List<ProjectModel> visibleProjects,
  ) {
    final cloudConfig = Global.settings.cloudWorkspaceConfig;
    final hasKey = cloudConfig.e2bApiKey.trim().isNotEmpty;
    const successColor = Color(0xFF34C759);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_outlined,
                  size: 18,
                  color: isCloudConnected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    LocaleKeys.drawerCloudSection.tr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isCloudConnected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCloudConnected) ...[
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: const BoxDecoration(
                      color: successColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 2),
                ],
                if (!hasKey) ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                    ),
                    icon: const Icon(Icons.key, size: 13),
                    label: Text(
                      LocaleKeys.e2bConfigApiKey.tr,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () async {
                      final saved = await E2bApiKeyDialog.show(context);
                      if (saved == true) {
                        if (mounted) setState(() {});
                        _fetchSandboxes();
                      }
                    },
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(CupertinoIcons.add, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: LocaleKeys.e2bCreateSandbox.tr,
                    onPressed: () async {
                      await CloudWorkspaceSheet.show(
                        context,
                        onLaunch: (cfg) => CloudWorkspaceLaunchDialog.show(
                          context,
                          config: cfg,
                        ),
                      );
                      _fetchSandboxes();
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            if (!hasKey)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    LocaleKeys.e2bNoApiKeyDesc.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else if (projectCtrl.isLoadingSandboxes.value &&
                projectCtrl.sandboxes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CupertinoActivityIndicator()),
              )
            else if (projectCtrl.sandboxesError.value != null &&
                projectCtrl.sandboxes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _fetchSandboxes,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: Text(
                      LocaleKeys.retry.tr,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              )
            else if (projectCtrl.sandboxes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    LocaleKeys.e2bNoSandboxes.tr,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              _buildCloudProjectsList(
                context,
                theme,
                projectCtrl,
                isCloudConnected,
                visibleProjects,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudProjectsList(
    BuildContext context,
    ThemeData theme,
    ProjectController projectCtrl,
    bool isCloudConnected,
    List<ProjectModel> visibleProjects,
  ) {
    final items = <Widget>[];

    for (final sb in projectCtrl.sandboxes) {
      final isCurrentActiveSandbox =
          isCloudConnected && Global.serverUrl.contains(sb.sandboxId);

      if (isCurrentActiveSandbox) {
        if (visibleProjects.isNotEmpty) {
          for (final project in visibleProjects) {
            final isActive = projectCtrl.activeProject.value?.id == project.id;
            items.add(
              Slidable(
                key: ValueKey('project_slide_${project.worktree}'),
                endActionPane: ActionPane(
                  motion: const BehindMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (_) => projectCtrl.hideProject(project),
                      backgroundColor: theme.colorScheme.errorContainer,
                      foregroundColor: theme.colorScheme.onErrorContainer,
                      icon: Icons.visibility_off_outlined,
                      label: LocaleKeys.mobileHideProject.tr,
                    ),
                  ],
                ),
                child: ProjectTile(
                  project: project,
                  isActive: isActive,
                  onTap: () {
                    projectCtrl.selectProject(project);
                    if (widget.isDrawer) {
                      Navigator.pop(context);
                    }
                  },
                  onBrowseFiles: () {
                    projectCtrl.selectProject(project);
                    if (widget.isDrawer) {
                      Navigator.pop(context);
                    }
                    Get.toNamed(AppRoutes.fileList);
                  },
                ),
              ),
            );
          }
        } else {
          final projName = sb.repoName.isNotEmpty ? sb.repoName : sb.sandboxId;
          items.add(
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                projName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: sb.repoName.isEmpty ? 'monospace' : null,
                ),
              ),
              dense: true,
              selected: true,
            ),
          );
        }
      } else {
        final projName = sb.repoName.isNotEmpty ? sb.repoName : sb.sandboxId;
        final isPaused = sb.isPaused;

        items.add(
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: Icon(
              isPaused ? Icons.pause_circle_outline : Icons.cloud_outlined,
              size: 18,
              color: isPaused
                  ? theme.colorScheme.outline
                  : theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              projName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                fontFamily: sb.repoName.isEmpty ? 'monospace' : null,
                color: isPaused ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
            trailing: isPaused
                ? Text(
                    LocaleKeys.e2bSandboxStatusPaused.tr,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.outline,
                    ),
                  )
                : null,
            dense: true,
            enabled: !_isSwitchingBackend,
            onTap: _isSwitchingBackend ? null : () => _switchToSandbox(sb),
          ),
        );
      }
    }

    return Column(mainAxisSize: MainAxisSize.min, children: items);
  }

  void _toggleHiddenProjects() {
    final nextExpanded = !_hiddenProjectsExpanded;
    setState(() {
      _hiddenProjectsExpanded = nextExpanded;
    });
    if (nextExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_projectsScrollController.hasClients) return;
        final currentOffset = _projectsScrollController.offset;
        final maxOffset = _projectsScrollController.position.maxScrollExtent;
        final targetOffset = (currentOffset + 120.0).clamp(0.0, maxOffset);
        if (targetOffset > currentOffset) {
          _projectsScrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Widget _buildHiddenProjectsSection(
    ProjectController projectCtrl,
    ThemeData theme,
  ) {
    final keys = projectCtrl.hiddenProjectKeys.toList();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: _toggleHiddenProjects,
            leading: Icon(
              Icons.visibility_off_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              '${LocaleKeys.mobileHiddenProjects.tr} (${keys.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: AnimatedRotation(
              turns: _hiddenProjectsExpanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_hiddenProjectsExpanded) ...[
            const Divider(height: 1),
            for (final key in keys)
              _buildHiddenProjectRow(projectCtrl, theme, key),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildHiddenProjectRow(
    ProjectController projectCtrl,
    ThemeData theme,
    String key,
  ) {
    // 服务器列表里已不存在的项目（localOnly 或仅存于隐藏记录）也要能展示并
    // 恢复，所以显示名在匹配不到 ProjectModel 时兜底取路径末段。
    final project = projectCtrl.projects.firstWhereOrNull(
      (p) => ProjectController.hiddenKeyFor(p) == key,
    );
    final fallbackName = key.split('/').where((s) => s.isNotEmpty).lastOrNull;
    final name = project?.displayName ?? (fallbackName ?? key);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.visibility_outlined, size: 20),
        padding: EdgeInsets.zero,
        onPressed: () => projectCtrl.unhideProjectByKey(key),
        tooltip: LocaleKeys.mobileUnhideProject.tr,
      ),
    );
  }

  Widget _buildFilesMode(
    BuildContext context,
    ThemeData theme,
    ProjectController projectCtrl,
    ProjectModel activeProj,
  ) {
    final searchCtrl = Get.find<FileSearchController>();

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
        // Search Bar with Mode Dropdown in Front
        _buildSearchBar(context, theme, searchCtrl, activeProj),
        const Divider(height: 1),
        // Content Area: Search Results or File Tree
        Expanded(
          child: Obx(() {
            if (searchCtrl.hasQuery) {
              return _buildSearchResults(
                context,
                theme,
                searchCtrl,
                activeProj,
              );
            }
            return FileTreeView(
              key: ValueKey('tree_${activeProj.id}_${activeProj.worktree}'),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    ThemeData theme,
    FileSearchController searchCtrl,
    ProjectModel activeProj,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            // Dropdown menu in front: Code / File
            _buildSearchModeDropdown(context, theme, searchCtrl, activeProj),
            Container(
              height: 18,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            // Text Input
            Expanded(
              child: Obx(() {
                final isFiles = searchCtrl.mode.value == SearchMode.files;
                final hint = isFiles
                    ? LocaleKeys.searchFilesPlaceholder.tr
                    : LocaleKeys.searchTextPlaceholder.tr;

                return TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.65,
                      ),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (val) {
                    searchCtrl.onQueryChanged(
                      val,
                      worktree: activeProj.worktree,
                    );
                  },
                );
              }),
            ),
            // Status Indicator / Match Count / Clear Button
            Obx(() {
              if (searchCtrl.isSearching.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: CupertinoActivityIndicator(radius: 7),
                );
              }
              if (searchCtrl.hasQuery) {
                final count = searchCtrl.totalMatchCount;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: () {
                        _searchController.clear();
                        searchCtrl.clear();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          CupertinoIcons.clear_circled_solid,
                          size: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchModeDropdown(
    BuildContext context,
    ThemeData theme,
    FileSearchController searchCtrl,
    ProjectModel activeProj,
  ) {
    return Obx(() {
      final currentMode = searchCtrl.mode.value;
      final isFiles = currentMode == SearchMode.files;
      final icon = isFiles
          ? Icons.insert_drive_file_outlined
          : CupertinoIcons.chevron_left_slash_chevron_right;
      final label = isFiles
          ? LocaleKeys.searchFiles.tr
          : LocaleKeys.searchText.tr;

      return Theme(
        data: theme.copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: PopupMenuButton<SearchMode>(
          tooltip: '',
          offset: const Offset(0, 34),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          color: theme.colorScheme.surface,
          elevation: 3,
          initialValue: currentMode,
          onSelected: (mode) {
            searchCtrl.setMode(mode, worktree: activeProj.worktree);
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: SearchMode.text,
              height: 36,
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.chevron_left_slash_chevron_right,
                    size: 15,
                    color: !isFiles
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    LocaleKeys.searchText.tr,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: !isFiles
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: !isFiles
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (!isFiles) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuItem(
              value: SearchMode.files,
              height: 36,
              child: Row(
                children: [
                  Icon(
                    Icons.insert_drive_file_outlined,
                    size: 15,
                    color: isFiles
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    LocaleKeys.searchFiles.tr,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isFiles ? FontWeight.w600 : FontWeight.normal,
                      color: isFiles
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (isFiles) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13.5, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 1),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSearchResults(
    BuildContext context,
    ThemeData theme,
    FileSearchController searchCtrl,
    ProjectModel activeProj,
  ) {
    return Obx(() {
      if (searchCtrl.isSearching.value &&
          searchCtrl.fileResults.isEmpty &&
          searchCtrl.textResults.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 10),
              const SizedBox(height: 8),
              Text(
                LocaleKeys.searchLoading.tr,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }

      if (searchCtrl.errorMessage.value != null &&
          searchCtrl.fileResults.isEmpty &&
          searchCtrl.textResults.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_circle,
                  size: 24,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 8),
                Text(
                  searchCtrl.errorMessage.value!,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () =>
                      searchCtrl.performSearch(worktree: activeProj.worktree),
                  child: Text(LocaleKeys.retry.tr),
                ),
              ],
            ),
          ),
        );
      }

      if (searchCtrl.mode.value == SearchMode.files) {
        if (searchCtrl.fileResults.isEmpty) {
          return Center(
            child: Text(
              LocaleKeys.searchNoResults.tr,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: searchCtrl.fileResults.length,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemBuilder: (ctx, idx) {
            final path = searchCtrl.fileResults[idx];
            final fileName = path.contains('/') ? path.split('/').last : path;
            final dirPath = path.contains('/')
                ? path.substring(0, path.lastIndexOf('/'))
                : '';

            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              leading: Icon(
                Icons.insert_drive_file_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              title: _buildHighlightedText(
                fileName,
                searchCtrl.query.value.trim(),
                normalStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
                matchStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.15,
                  ),
                ),
              ),
              subtitle: dirPath.isNotEmpty
                  ? Text(
                      dirPath,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              onTap: () => _onSearchResultTap(path, null, activeProj.worktree),
            );
          },
        );
      } else {
        if (searchCtrl.textResults.isEmpty) {
          return Center(
            child: Text(
              LocaleKeys.searchNoResults.tr,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: searchCtrl.textResults.length,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemBuilder: (ctx, groupIdx) {
            final group = searchCtrl.textResults[groupIdx];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group Header
                InkWell(
                  onTap: () => searchCtrl.toggleGroupExpanded(groupIdx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.25,
                    ),
                    child: Row(
                      children: [
                        AnimatedRotation(
                          turns: group.isExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.insert_drive_file_outlined,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            group.fileName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${group.matches.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Group Matches
                if (group.isExpanded)
                  ...group.matches.map((match) {
                    return InkWell(
                      onTap: () => _onSearchResultTap(
                        group.path,
                        match.lineNumber,
                        activeProj.worktree,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 5,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'L${match.lineNumber}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildHighlightedCodeMatch(
                                match,
                                searchCtrl.query.value.trim(),
                                normalStyle: TextStyle(
                                  fontSize: 11.5,
                                  fontFamily: 'monospace',
                                  color: theme.colorScheme.onSurface,
                                ),
                                matchStyle: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: theme.colorScheme.primary,
                                  backgroundColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const Divider(height: 1),
              ],
            );
          },
        );
      }
    });
  }

  static int _byteOffsetToCharIndex(
    List<int> bytes,
    int byteOffset,
    int textLength,
  ) {
    if (byteOffset <= 0) return 0;
    if (byteOffset >= bytes.length) return textLength;
    try {
      return utf8.decode(bytes.sublist(0, byteOffset)).length;
    } catch (_) {
      return byteOffset.clamp(0, textLength);
    }
  }

  Widget _buildHighlightedCodeMatch(
    TextSearchMatch match,
    String query, {
    required TextStyle normalStyle,
    required TextStyle matchStyle,
  }) {
    final text = match.lineText;
    if (text.isEmpty) return const SizedBox.shrink();

    if (match.submatches.isNotEmpty) {
      final bytes = utf8.encode(text);
      final sorted = List<TextSubmatch>.from(match.submatches)
        ..sort((a, b) => a.start.compareTo(b.start));

      final spans = <TextSpan>[];
      int curChar = 0;

      for (final sub in sorted) {
        final startChar = _byteOffsetToCharIndex(bytes, sub.start, text.length);
        final endChar = _byteOffsetToCharIndex(bytes, sub.end, text.length);

        if (startChar > curChar && startChar <= text.length) {
          spans.add(
            TextSpan(
              text: text.substring(curChar, startChar),
              style: normalStyle,
            ),
          );
        }

        final safeEnd = endChar.clamp(startChar, text.length);
        if (safeEnd > startChar) {
          spans.add(
            TextSpan(
              text: text.substring(startChar, safeEnd),
              style: matchStyle,
            ),
          );
          curChar = safeEnd;
        }
      }

      if (curChar < text.length) {
        spans.add(TextSpan(text: text.substring(curChar), style: normalStyle));
      }

      return RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(children: spans),
      );
    }

    return _buildHighlightedText(
      text.trim(),
      query,
      normalStyle: normalStyle,
      matchStyle: matchStyle,
      maxLines: 2,
    );
  }

  Widget _buildHighlightedText(
    String text,
    String query, {
    required TextStyle normalStyle,
    required TextStyle matchStyle,
    int maxLines = 1,
  }) {
    if (query.isEmpty) {
      return Text(
        text,
        style: normalStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: normalStyle));
        }
        break;
      }
      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: normalStyle),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: matchStyle,
        ),
      );
      start = index + query.length;
    }
    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }

  void _onSearchResultTap(String path, int? lineNumber, String worktree) {
    final fileName = path.contains('/') ? path.split('/').last : path;
    final toolCtrl = Get.find<TabletToolController>();
    toolCtrl.openFile(
      path,
      fileName,
      worktree: worktree,
      targetLine: lineNumber,
    );

    final isTablet = isTabletLayout(context);
    if (!isTablet) {
      final scaffoldState = Scaffold.maybeOf(context);
      if (scaffoldState?.isDrawerOpen ?? false) {
        scaffoldState?.closeDrawer();
      }
      if (Get.currentRoute != AppRoutes.fileList) {
        Get.toNamed(AppRoutes.fileList);
      }
    }
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
      (p) =>
          ProjectController.normalizeDirectory(p.worktree) ==
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
