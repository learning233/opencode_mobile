import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../api/sidecar_manager.dart';
import '../../../controllers/project_controller.dart';
import '../../../controllers/session_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../init.dart';
import '../../../models/cloud_workspace_config.dart';
import '../../../models/e2b_sandbox_info.dart';
import '../../../routes.dart';
import '../../../services/e2b_workspace_service.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../../../utils/url_utils.dart';
import 'cloud_workspace_launch_dialog.dart';
import 'cloud_workspace_sheet.dart';

class OpencodeConnectionPage extends StatefulWidget {
  const OpencodeConnectionPage({super.key});

  @override
  State<OpencodeConnectionPage> createState() => _OpencodeConnectionPageState();
}

class _OpencodeConnectionPageState extends State<OpencodeConnectionPage> {
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _saving = false;
  bool _navigatedAway = false;
  bool _isActionInProgress = false;

  // 0: 自建服务器, 1: E2B 云端沙盒
  int _selectedMode = 0;

  // E2B 沙盒列表状态
  List<E2bSandboxInfo> _sandboxes = [];
  bool _loadingSandboxes = false;
  String? _sandboxesError;
  CancelToken? _connectCancelToken;

  // 云端活跃沙盒健康探测状态(null = 未探测/网络不通)
  bool _cloudChecking = false;
  int? _activeProbeStatus;

  SettingsController get _settings => Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = Global.selfHostedServerUrl;
    _userCtrl.text = Global.selfHostedServerUsername;
    _passCtrl.text = Global.selfHostedServerPassword;

    final cloudConfig = Global.settings.cloudWorkspaceConfig;
    final argMode = Get.arguments is Map
        ? (Get.arguments as Map)['mode'] as int?
        : null;
    if (argMode != null) {
      _selectedMode = argMode;
    } else if (cloudConfig.hasActiveSandbox ||
        E2bWorkspaceService.isCloudUrl(Global.serverUrl)) {
      _selectedMode = 1;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 云端模式显示云端自身状态,不做自建服务器健康检查
      if (_selectedMode == 1) {
        _fetchSandboxList();
        _probeActiveSandbox();
      } else {
        _settings.checkHealth();
      }
    });
  }

  @override
  void dispose() {
    _connectCancelToken?.cancel('Connection page disposed');
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// 获取当前 E2B 账户下的沙盒列表
  Future<void> _fetchSandboxList() async {
    final apiKey = Global.settings.cloudWorkspaceConfig.e2bApiKey.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _sandboxes = [];
        _loadingSandboxes = false;
        _sandboxesError = null;
      });
      return;
    }

    setState(() {
      _loadingSandboxes = true;
      _sandboxesError = null;
    });

    try {
      final list = await E2bWorkspaceService.instance.fetchSandboxes(apiKey);
      if (mounted) {
        setState(() {
          _sandboxes = list;
          _loadingSandboxes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingSandboxes = false;
          _sandboxesError = '$e';
        });
      }
    }
  }

  /// 探测当前活跃沙盒的应用端口,供云端状态条展示真实连接状态
  Future<void> _probeActiveSandbox() async {
    final config = Global.settings.cloudWorkspaceConfig;
    final url = config.activeSandboxUrl;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _activeProbeStatus = null);
      return;
    }
    if (mounted) setState(() => _cloudChecking = true);
    final status = await E2bWorkspaceService.instance.probeSandboxHealth(
      url,
      password: config.activeSandboxPassword,
    );
    if (mounted) {
      setState(() {
        _activeProbeStatus = status;
        _cloudChecking = false;
      });
    }
  }

  /// 刷新云端状态(列表 + 活跃沙盒探测)
  Future<void> _refreshCloudStatus() async {
    await Future.wait([_fetchSandboxList(), _probeActiveSandbox()]);
  }

  Future<void> _saveAndReconnect() async {
    final url = normalizeServerUrl(_urlCtrl.text);
    if (url == null) {
      Snack.error(LocaleKeys.connectionValidUrlRequired.tr);
      return;
    }
    _urlCtrl.text = url;
    setState(() => _saving = true);
    try {
      // 切回自建服务器时停止云端沙盒的 TTL keep-alive
      E2bWorkspaceService.instance.stopKeepAlive();
      final result = await SidecarManager.instance.updateConnection(
        url,
        _userCtrl.text.trim().isEmpty ? 'opencode' : _userCtrl.text.trim(),
        _passCtrl.text,
      );
      if (!result.success) {
        await _settings.checkHealth();
        if (mounted) {
          Snack.error(
            result.error?.isNotEmpty == true
                ? result.error!
                : LocaleKeys.mobileConnectionFailed.tr,
          );
        }
        return;
      }
      String? refreshError;
      try {
        final projectCtrl = Get.find<ProjectController>();
        await projectCtrl.refreshAfterConnect();
      } catch (e) {
        refreshError = maskIpsInText('$e');
      }
      Get.find<SessionController>().initializeAfterConnect();
      await _settings.checkHealth();
      if (mounted) {
        if (refreshError != null) {
          Snack.error(
            '${LocaleKeys.connectionRefreshFailed.tr}: $refreshError',
          );
        } else {
          Snack.success(LocaleKeys.connectionReconnected.tr);
        }
        _navigatedAway = true;
        Get.offNamed(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        Snack.error(
          '${LocaleKeys.connectionReconnectFailed.tr}: ${maskIpsInText('$e')}',
        );
      }
    } finally {
      if (mounted && !_navigatedAway) setState(() => _saving = false);
    }
  }

  /// 连接并进入指定沙盒
  Future<void> _connectToSandbox(E2bSandboxInfo item) async {
    final config = Global.settings.cloudWorkspaceConfig;
    setState(() => _isActionInProgress = true);
    try {
      _connectCancelToken?.cancel();
      _connectCancelToken = CancelToken();

      final res = await E2bWorkspaceService.instance.connectSandbox(
        config: config,
        sandboxId: item.sandboxId,
        endpointUrl: item.endpointUrl,
        onProgress: (msg) {
          if (mounted) Snack.info(msg);
        },
        cancelToken: _connectCancelToken,
      );

      if (_connectCancelToken?.isCancelled == true) return;

      if (!res.success) {
        if (mounted) {
          Snack.error(res.error ?? LocaleKeys.e2bConnectFailed.tr);
        }
        return;
      }

      final password = res.password!;
      final result = await SidecarManager.instance.updateConnection(
        item.endpointUrl,
        'opencode',
        password,
      );

      if (!result.success) {
        if (mounted) {
          Snack.error(result.error ?? LocaleKeys.e2bServiceUnreachable.tr);
        }
        return;
      }

      await Global.settings.updateCloudWorkspaceConfig((curr) {
        return curr.copyWith(
          activeSandboxId: item.sandboxId,
          activeSandboxUrl: item.endpointUrl,
          activeSandboxPassword: password,
          activeSandboxEnvdToken: res.envdAccessToken,
          activeSandboxStatus: 'running',
          lastConnectedAt: DateTime.now(),
        );
      });

      // 连接成功后启动 TTL keep-alive,防止长会话被回收
      E2bWorkspaceService.instance.startKeepAlive(
        sandboxId: item.sandboxId,
        apiKey: config.e2bApiKey,
        timeoutSeconds: config.ttlHours * 3600 < 600
            ? 600
            : config.ttlHours * 3600,
        domain: res.domain,
      );

      try {
        final projectCtrl = Get.find<ProjectController>();
        await projectCtrl.refreshAfterConnect();
      } catch (_) {}

      Get.find<SessionController>().initializeAfterConnect();
      Get.find<SettingsController>().checkHealth();

      if (mounted) {
        Snack.success(
          LocaleKeys.e2bConnectedToSandbox.trParams({'id': item.sandboxId}),
        );
        _navigatedAway = true;
        Get.offNamed(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        Snack.error(
          LocaleKeys.e2bConnectionError.trParams({'error': e.toString()}),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  /// 挂起休眠沙盒
  Future<void> _pauseSandbox(E2bSandboxInfo item) async {
    final config = Global.settings.cloudWorkspaceConfig;
    if (config.e2bApiKey.isEmpty) return;
    setState(() => _isActionInProgress = true);
    try {
      final res = await E2bWorkspaceService.instance.pauseSandbox(
        item.sandboxId,
        config.e2bApiKey,
      );
      if (res.success) {
        if (config.activeSandboxId == item.sandboxId) {
          await Global.settings.updateCloudWorkspaceConfig(
            (curr) => curr.copyWith(activeSandboxStatus: 'paused'),
          );
          // 暂停当前沙盒后端点不可达,统一断开 keepalive / Sidecar / SSE
          E2bWorkspaceService.instance.stopKeepAlive();
          SidecarManager.instance.stop();
          if (Get.isRegistered<SessionController>()) {
            Get.find<SessionController>().disconnectSse();
          }
        }
        Snack.success(
          LocaleKeys.e2bSandboxPausedSuccess.trParams({'id': item.sandboxId}),
        );
        await _fetchSandboxList();
      } else {
        Snack.error(
          LocaleKeys.e2bSandboxPauseFailed.trParams({'error': res.error ?? ''}),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  /// 唤醒已休眠沙盒
  Future<void> _resumeSandbox(E2bSandboxInfo item) async {
    final config = Global.settings.cloudWorkspaceConfig;
    if (config.e2bApiKey.isEmpty) return;
    setState(() => _isActionInProgress = true);
    try {
      final res = await E2bWorkspaceService.instance.resumeSandbox(
        item.sandboxId,
        config.e2bApiKey,
      );
      if (res.success) {
        if (config.activeSandboxId == item.sandboxId) {
          await Global.settings.updateCloudWorkspaceConfig(
            (curr) => curr.copyWith(activeSandboxStatus: 'running'),
          );
        }
        Snack.success(
          LocaleKeys.e2bSandboxResumedSuccess.trParams({'id': item.sandboxId}),
        );
        await _fetchSandboxList();
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

  /// 销毁释放沙盒
  Future<void> _destroySandbox(E2bSandboxInfo item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.e2bConfirmDestroy.tr),
        content: Text(
          '${LocaleKeys.e2bSandboxLabel.trParams({'id': item.sandboxId})}\n${LocaleKeys.e2bConfirmDestroyDesc.tr}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(LocaleKeys.cancel.tr),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(LocaleKeys.e2bDestroySandbox.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final config = Global.settings.cloudWorkspaceConfig;
    setState(() => _isActionInProgress = true);
    try {
      final res = await E2bWorkspaceService.instance.destroySandbox(
        item.sandboxId,
        config.e2bApiKey,
      );
      if (res.success) {
        if (config.activeSandboxId == item.sandboxId) {
          await Global.settings.updateCloudWorkspaceConfig(
            (curr) => curr.copyWith(clearActiveSandbox: true),
          );
          // 销毁当前沙盒后全局仍指向已失效端点,必须统一 teardown
          E2bWorkspaceService.instance.stopKeepAlive();
          SidecarManager.instance.stop();
          if (Get.isRegistered<SessionController>()) {
            Get.find<SessionController>().disconnectSse();
          }
        }
        Snack.success(
          LocaleKeys.e2bSandboxDestroyedSuccess.trParams({
            'id': item.sandboxId,
          }),
        );
        await _fetchSandboxList();
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

  Future<void> _openCloudWorkspaceSheet({bool onlyConfig = false}) async {
    await CloudWorkspaceSheet.show(
      context,
      onlyConfig: onlyConfig,
      onLaunch: (cfg) => CloudWorkspaceLaunchDialog.show(context, config: cfg),
    );
    if (mounted) {
      setState(() {});
      _refreshCloudStatus();
      if (Global.settings.cloudWorkspaceConfig.e2bApiKey.trim().isNotEmpty) {
        _fetchSandboxList();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cloudConfig = Global.settings.cloudWorkspaceConfig;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.tabConnection.tr,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_selectedMode == 1) ...[
            IconButton(
              tooltip: LocaleKeys.e2bConfigWorkspace.tr,
              icon: const Icon(Icons.tune),
              onPressed: () => _openCloudWorkspaceSheet(onlyConfig: true),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 顶部模式切换 (自建 vs 云端)
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 0,
                icon: const Icon(Icons.dns_outlined),
                label: Text(LocaleKeys.connModeSelfHosted.tr),
              ),
              ButtonSegment(
                value: 1,
                icon: const Icon(Icons.cloud_outlined),
                label: Text(LocaleKeys.connModeCloud.tr),
              ),
            ],
            selected: {_selectedMode},
            onSelectionChanged: (vals) {
              if (vals.isNotEmpty) {
                setState(() => _selectedMode = vals.first);
                if (_selectedMode == 1) {
                  _refreshCloudStatus();
                } else {
                  _settings.checkHealth();
                }
              }
            },
          ),
          const SizedBox(height: 16),

          // 健康状态条
          _buildHealthStatus(theme),
          const Divider(height: 24),

          if (_selectedMode == 0) ...[
            // ── 自建服务器视图 ──
            _buildSelfHostedView(theme),
          ] else ...[
            // ── E2B 云端沙盒与列表管理视图 ──
            _buildCloudWorkspaceView(theme, cloudConfig),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthStatus(ThemeData theme) {
    // 云端模式显示云端自身的连接状态,与自建服务器健康无关
    if (_selectedMode == 1) {
      return _buildCloudHealthStatus(theme);
    }
    return Obx(() {
      final checking = _settings.healthChecking.value;
      final ok = _settings.healthOk.value;
      final version = _settings.healthVersion.value;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: checking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                ok == true
                    ? Icons.check_circle
                    : ok == false
                    ? Icons.error
                    : Icons.help_outline,
                color: ok == true
                    ? context.appColors.success
                    : ok == false
                    ? theme.colorScheme.error
                    : null,
              ),
        title: Text(
          ok == true
              ? LocaleKeys.mobileConnected.tr
              : ok == false
              ? LocaleKeys.mobileUnreachable.tr
              : LocaleKeys.mobileUnknown.tr,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          version.isEmpty ? LocaleKeys.mobileTapRefresh.tr : version,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _settings.checkHealth,
        ),
      );
    });
  }

  /// 云端模式专属状态条:基于是否配置 Key、活跃沙盒与实时探测结果
  Widget _buildCloudHealthStatus(ThemeData theme) {
    final cloudConfig = Global.settings.cloudWorkspaceConfig;
    final hasKey = cloudConfig.e2bApiKey.trim().isNotEmpty;
    final activeId = cloudConfig.activeSandboxId;
    // Global.serverUrl 仅在健康检查通过后写入,代表真实已建立的连接
    final connectedNow =
        E2bWorkspaceService.isCloudUrl(Global.serverUrl) &&
        activeId != null &&
        activeId.isNotEmpty &&
        Global.serverUrl.contains(activeId);

    final ({IconData icon, Color? iconColor, String title, String subtitle})
    state;

    if (!hasKey) {
      state = (
        icon: Icons.key_off_outlined,
        iconColor: null,
        title: LocaleKeys.e2bNoApiKey.tr,
        subtitle: LocaleKeys.e2bNoApiKeyDesc.tr,
      );
    } else if (_cloudChecking) {
      state = (
        icon: Icons.cloud_sync_outlined,
        iconColor: null,
        title: LocaleKeys.e2bCheckingStatus.tr,
        subtitle: activeId ?? '',
      );
    } else if (connectedNow) {
      final status = _activeProbeStatus;
      if (status == 200) {
        state = (
          icon: Icons.check_circle,
          iconColor: context.appColors.success,
          title: LocaleKeys.e2bSandboxConnected.tr,
          subtitle: activeId,
        );
      } else if (status == 401 || status == 403) {
        state = (
          icon: Icons.shield_outlined,
          iconColor: theme.colorScheme.tertiary,
          title: LocaleKeys.e2bAuthFailedTitle.tr,
          subtitle: LocaleKeys.e2bAuthFailedDesc.tr,
        );
      } else {
        state = (
          icon: Icons.warning_amber_rounded,
          iconColor: theme.colorScheme.error,
          title: LocaleKeys.e2bServiceNotReadyTitle.trParams({
            'status': status?.toString() ?? 'no_resp',
          }),
          subtitle: LocaleKeys.e2bServiceNotReadyDesc.tr,
        );
      }
    } else if (activeId != null && activeId.isNotEmpty) {
      state = (
        icon: Icons.cloud_off_outlined,
        iconColor: null,
        title: LocaleKeys.e2bSandboxDisconnected.tr,
        subtitle: LocaleKeys.e2bSandboxDisconnectedDesc.trParams({
          'id': activeId,
        }),
      );
    } else {
      state = (
        icon: Icons.cloud_queue_outlined,
        iconColor: null,
        title: LocaleKeys.e2bNoActiveSandbox.tr,
        subtitle: LocaleKeys.e2bNoActiveSandboxDesc.tr,
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _cloudChecking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(state.icon, color: state.iconColor),
      title: Text(state.title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        state.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: hasKey
          ? IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _cloudChecking ? null : _refreshCloudStatus,
            )
          : IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _openCloudWorkspaceSheet(onlyConfig: true),
            ),
    );
  }

  Widget _buildSelfHostedView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.mobileServerConnection.tr,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _urlCtrl,
          decoration: InputDecoration(
            labelText: LocaleKeys.mobileServerUrl.tr,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _userCtrl,
          decoration: InputDecoration(
            labelText: LocaleKeys.username.tr,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: LocaleKeys.mobilePassword.tr,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _saveAndReconnect,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_tethering),
          label: Text(
            _saving
                ? LocaleKeys.mobileReconnecting.tr
                : LocaleKeys.mobileSaveAndReconnect.tr,
          ),
        ),
      ],
    );
  }

  /// 渲染 E2B 云端沙盒管理仪表盘与沙盒列表
  Widget _buildCloudWorkspaceView(
    ThemeData theme,
    CloudWorkspaceConfig cloudConfig,
  ) {
    // 1. 若未配置 API Key，展示引导卡片
    if (cloudConfig.e2bApiKey.trim().isEmpty) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.vpn_key_outlined,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    LocaleKeys.e2bApiKeyRequired.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                LocaleKeys.e2bApiKeyRequiredDesc.tr,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openCloudWorkspaceSheet(onlyConfig: false),
                icon: const Icon(Icons.key),
                label: Text(LocaleKeys.e2bConfigApiKey.tr),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部操作栏（沙盒实例统计 + 刷新 + 新建）
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  LocaleKeys.e2bSandboxList.tr,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_sandboxes.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  tooltip: LocaleKeys.e2bRefreshList.tr,
                  icon: _loadingSandboxes
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  onPressed: _loadingSandboxes ? null : _fetchSandboxList,
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _isActionInProgress
                      ? null
                      : () => _openCloudWorkspaceSheet(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(LocaleKeys.e2bCreateSandbox.tr),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_loadingSandboxes && _sandboxes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(LocaleKeys.e2bFetchingSandboxes.tr),
                ],
              ),
            ),
          )
        else if (_sandboxesError != null && _sandboxes.isEmpty)
          Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(height: 8),
                  Text(
                    LocaleKeys.e2bFetchSandboxesFailed.trParams({
                      'error': _sandboxesError ?? '',
                    }),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _fetchSandboxList,
                    icon: const Icon(Icons.refresh),
                    label: Text(LocaleKeys.retry.tr),
                  ),
                ],
              ),
            ),
          )
        else if (_sandboxes.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LocaleKeys.e2bNoSandboxes.tr,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => _openCloudWorkspaceSheet(),
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(LocaleKeys.e2bNewSandbox.tr),
                  ),
                ],
              ),
            ),
          )
        else
          ..._sandboxes.map((sb) => _buildSandboxCard(theme, sb, cloudConfig)),
      ],
    );
  }

  /// 渲染单个沙盒实例卡片
  Widget _buildSandboxCard(
    ThemeData theme,
    E2bSandboxInfo sandbox,
    CloudWorkspaceConfig cloudConfig,
  ) {
    // Global.serverUrl 仅在健康检查通过后写入,才是真实已建立的连接
    final isCurrentConnected = Global.serverUrl.contains(sandbox.sandboxId);
    final isPaused = sandbox.isPaused;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCurrentConnected
              ? theme.colorScheme.primary
              : isPaused
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: isCurrentConnected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：ID、当前连接标识、状态 Badge
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.dns_rounded,
                        size: 18,
                        color: isPaused
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          sandbox.sandboxId,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        iconSize: 14,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: LocaleKeys.clipboardCopied.tr,
                        icon: const Icon(Icons.copy, size: 14),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: sandbox.sandboxId),
                          );
                          Snack.success(LocaleKeys.clipboardCopied.tr);
                        },
                      ),
                    ],
                  ),
                ),
                if (isCurrentConnected) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      LocaleKeys.e2bCurrentlyConnected.tr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: isPaused
                        ? theme.colorScheme.surfaceContainerHighest
                        : context.appColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPaused
                        ? LocaleKeys.e2bSandboxStatusPaused.tr
                        : LocaleKeys.e2bSandboxStatusRunning.tr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPaused
                          ? theme.colorScheme.onSurfaceVariant
                          : context.appColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 沙盒元数据
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _buildMetaItem(
                  theme,
                  Icons.layers_outlined,
                  sandbox.alias.isNotEmpty ? sandbox.alias : sandbox.templateId,
                ),
                if (sandbox.repoName.isNotEmpty)
                  _buildMetaItem(
                    theme,
                    Icons.folder_zip_outlined,
                    sandbox.repoName,
                  ),
                _buildMetaItem(
                  theme,
                  Icons.memory,
                  '${sandbox.cpuCount} vCPU · ${sandbox.memoryMB} MB',
                ),
                if (sandbox.startedAt != null)
                  _buildMetaItem(
                    theme,
                    Icons.access_time,
                    LocaleKeys.e2bStartedAt.trParams({
                      'time': _formatTime(sandbox.startedAt!),
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // 操作按钮栏
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isActionInProgress
                        ? null
                        : () => _connectToSandbox(sandbox),
                    icon: Icon(
                      isPaused ? Icons.play_arrow : Icons.login,
                      size: 16,
                    ),
                    label: Text(
                      isPaused
                          ? LocaleKeys.e2bResumeSandbox.tr
                          : LocaleKeys.e2bConnectSandbox.tr,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isPaused)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isActionInProgress
                        ? null
                        : () => _pauseSandbox(sandbox),
                    icon: const Icon(Icons.pause, size: 16),
                    label: Text(
                      LocaleKeys.e2bPauseSandbox.tr,
                      style: const TextStyle(fontSize: 12),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isActionInProgress
                        ? null
                        : () => _resumeSandbox(sandbox),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: Text(
                      LocaleKeys.e2bResumeSandbox.tr,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: LocaleKeys.e2bDestroySandbox.tr,
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: _isActionInProgress
                      ? null
                      : () => _destroySandbox(sandbox),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(ThemeData theme, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
