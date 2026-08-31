import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../init.dart';
import '../../../models/e2b_sandbox_info.dart';
import '../../../services/e2b_workspace_service.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import 'cloud_workspace_launch_dialog.dart';
import 'cloud_workspace_sheet.dart';

/// E2B 沙盒选择与管理 BottomSheet
class E2bSandboxPickerSheet extends StatefulWidget {
  const E2bSandboxPickerSheet({
    super.key,
    this.onSelect,
  });

  final ValueChanged<E2bSandboxInfo>? onSelect;

  static Future<E2bSandboxInfo?> show(
    BuildContext context, {
    ValueChanged<E2bSandboxInfo>? onSelect,
  }) {
    return showModalBottomSheet<E2bSandboxInfo>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => E2bSandboxPickerSheet(onSelect: onSelect),
    );
  }

  @override
  State<E2bSandboxPickerSheet> createState() => _E2bSandboxPickerSheetState();
}

class _E2bSandboxPickerSheetState extends State<E2bSandboxPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<E2bSandboxInfo> _sandboxes = [];
  List<E2bSandboxInfo> _filteredSandboxes = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSandboxes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSandboxes() async {
    final apiKey = Global.settings.cloudWorkspaceConfig.e2bApiKey.trim();
    if (apiKey.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = LocaleKeys.e2bApiKeyRequiredDesc.tr;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await E2bWorkspaceService.instance.fetchSandboxes(apiKey);
      if (mounted) {
        setState(() {
          _sandboxes = list;
          _filterSandboxes(_searchCtrl.text);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = LocaleKeys.e2bFetchSandboxesFailed.trParams({
            'error': e.toString(),
          });
        });
      }
    }
  }

  void _filterSandboxes(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredSandboxes = _sandboxes;
      } else {
        _filteredSandboxes = _sandboxes.where((sb) {
          return sb.sandboxId.toLowerCase().contains(q) ||
              sb.templateId.toLowerCase().contains(q) ||
              sb.alias.toLowerCase().contains(q) ||
              sb.repoName.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Future<void> _pauseSandbox(E2bSandboxInfo sb) async {
    final apiKey = Global.settings.cloudWorkspaceConfig.e2bApiKey.trim();
    if (apiKey.isEmpty) return;

    setState(() => _isActionInProgress = true);
    try {
      final res = await E2bWorkspaceService.instance.pauseSandbox(
        sb.sandboxId,
        apiKey,
      );
      if (res.success) {
        final currentActiveId =
            Global.settings.cloudWorkspaceConfig.activeSandboxId;
        if (currentActiveId == sb.sandboxId) {
          await Global.settings.updateCloudWorkspaceConfig(
            (curr) => curr.copyWith(activeSandboxStatus: 'paused'),
          );
        }
        Snack.success(
          LocaleKeys.e2bSandboxPausedSuccess.trParams({'id': sb.sandboxId}),
        );
        await _loadSandboxes();
      } else {
        Snack.error(
          LocaleKeys.e2bSandboxPauseFailed.trParams({'error': res.error ?? ''}),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _resumeSandbox(E2bSandboxInfo sb) async {
    final apiKey = Global.settings.cloudWorkspaceConfig.e2bApiKey.trim();
    if (apiKey.isEmpty) return;

    setState(() => _isActionInProgress = true);
    try {
      final res = await E2bWorkspaceService.instance.resumeSandbox(
        sb.sandboxId,
        apiKey,
      );
      if (res.success) {
        final currentActiveId =
            Global.settings.cloudWorkspaceConfig.activeSandboxId;
        if (currentActiveId == sb.sandboxId) {
          await Global.settings.updateCloudWorkspaceConfig(
            (curr) => curr.copyWith(activeSandboxStatus: 'running'),
          );
        }
        Snack.success(
          LocaleKeys.e2bSandboxResumedSuccess.trParams({'id': sb.sandboxId}),
        );
        await _loadSandboxes();
      } else {
        Snack.error(
          LocaleKeys.e2bSandboxResumeFailed.trParams({
            'error': res.error ?? '',
          }),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _destroySandbox(E2bSandboxInfo sb) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.e2bConfirmDestroy.tr),
        content: Text(
          '${LocaleKeys.e2bSandboxLabel.trParams({'id': sb.sandboxId})}\n${LocaleKeys.e2bConfirmDestroyDesc.tr}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(LocaleKeys.cancel.tr),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(LocaleKeys.delete.tr),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final apiKey = Global.settings.cloudWorkspaceConfig.e2bApiKey.trim();
    if (apiKey.isEmpty) return;

    setState(() => _isActionInProgress = true);
    try {
      final res = await E2bWorkspaceService.instance.destroySandbox(
        sb.sandboxId,
        apiKey,
      );
      if (res.success) {
        final currentActiveId =
            Global.settings.cloudWorkspaceConfig.activeSandboxId;
        if (currentActiveId == sb.sandboxId) {
          await Global.settings.updateCloudWorkspaceConfig(
            (curr) => curr.copyWith(clearActiveSandbox: true),
          );
        }
        Snack.success(
          LocaleKeys.e2bSandboxDestroyedSuccess.trParams({'id': sb.sandboxId}),
        );
        await _loadSandboxes();
      } else {
        Snack.error(
          LocaleKeys.e2bSandboxDestroyFailed.trParams({
            'error': res.error ?? '',
          }),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _onSandboxTapped(E2bSandboxInfo sb) async {
    if (_isActionInProgress) return;

    // 更新持久化数据库中的 activeSandbox 记录
    await Global.settings.updateCloudWorkspaceConfig((curr) {
      return curr.copyWith(
        activeSandboxId: sb.sandboxId,
        activeSandboxUrl: sb.endpointUrl,
        activeSandboxStatus: sb.state,
      );
    });

    Snack.success(
      LocaleKeys.e2bSwitchedSandbox.trParams({'id': sb.sandboxId}),
    );

    if (mounted) {
      Navigator.of(context).pop(sb);
      widget.onSelect?.call(sb);
    }
  }

  Future<void> _openNewSandbox() async {
    final navigator = Navigator.of(context);
    final launched = await CloudWorkspaceSheet.show(
      context,
      onLaunch: (cfg) => CloudWorkspaceLaunchDialog.show(
        context,
        config: cfg,
      ),
    );
    if (launched == true && mounted) {
      navigator.pop();
    } else if (mounted) {
      _loadSandboxes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentActiveId =
        Global.settings.cloudWorkspaceConfig.activeSandboxId;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 顶部拖动条
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_outlined,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    LocaleKeys.e2bSelectSandbox.tr,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: LocaleKeys.e2bRefreshList.tr,
                    onPressed: _isLoading || _isActionInProgress
                        ? null
                        : _loadSandboxes,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 搜索框
            if (!_isLoading && _errorMessage == null && _sandboxes.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: LocaleKeys.search.tr,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _filterSandboxes('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _filterSandboxes,
                ),
              ),

            if (_isActionInProgress)
              const LinearProgressIndicator(minHeight: 2),

            const Divider(height: 1),

            // 主列表内容
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            LocaleKeys.e2bFetchingSandboxes.tr,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 40,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonal(
                              onPressed: _loadSandboxes,
                              child: Text(LocaleKeys.retry.tr),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _filteredSandboxes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              LocaleKeys.e2bNoSandboxes.tr,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              LocaleKeys.e2bNoSandboxesDesc.tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: _filteredSandboxes.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final sb = _filteredSandboxes[index];
                        final isActive = sb.sandboxId == currentActiveId;
                        final isRunning = sb.isRunning;
                        final isPaused = sb.isPaused;

                        final statusColor = isRunning
                            ? Colors.green
                            : isPaused
                            ? Colors.orange
                            : theme.colorScheme.outline;

                        final statusText = isRunning
                            ? LocaleKeys.e2bSandboxStatusRunning.tr
                            : isPaused
                            ? LocaleKeys.e2bSandboxStatusPaused.tr
                            : sb.state;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isRunning
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.terminal,
                                  color: isRunning
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.surface,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sb.sandboxId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    LocaleKeys.e2bCurrentActive.tr,
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                '${LocaleKeys.e2bTemplate.tr}: ${sb.templateId} • $statusText',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (sb.repoName.isNotEmpty)
                                Text(
                                  LocaleKeys.e2bRepoPrefix.trParams({
                                    'repo': sb.repoName,
                                  }),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (action) {
                              switch (action) {
                                case 'connect':
                                  _onSandboxTapped(sb);
                                  break;
                                case 'pause':
                                  _pauseSandbox(sb);
                                  break;
                                case 'resume':
                                  _resumeSandbox(sb);
                                  break;
                                case 'destroy':
                                  _destroySandbox(sb);
                                  break;
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'connect',
                                child: Row(
                                  children: [
                                    const Icon(Icons.login, size: 18),
                                    const SizedBox(width: 8),
                                    Text(LocaleKeys.e2bConnectSandbox.tr),
                                  ],
                                ),
                              ),
                              if (isRunning)
                                PopupMenuItem(
                                  value: 'pause',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.pause, size: 18),
                                      const SizedBox(width: 8),
                                      Text(LocaleKeys.e2bPauseSandbox.tr),
                                    ],
                                  ),
                                ),
                              if (isPaused)
                                PopupMenuItem(
                                  value: 'resume',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.play_arrow, size: 18),
                                      const SizedBox(width: 8),
                                      Text(LocaleKeys.e2bResumeSandbox.tr),
                                    ],
                                  ),
                                ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'destroy',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: theme.colorScheme.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      LocaleKeys.e2bDestroySandbox.tr,
                                      style: TextStyle(
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _onSandboxTapped(sb),
                        );
                      },
                    ),
            ),

            // 底部「新建沙盒」按钮
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _openNewSandbox,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: Text(
                    LocaleKeys.e2bNewSandbox.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
