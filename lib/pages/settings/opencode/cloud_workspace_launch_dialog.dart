import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../api/sidecar_manager.dart';
import '../../../controllers/project_controller.dart';
import '../../../controllers/session_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../init.dart';
import '../../../models/cloud_workspace_config.dart';
import '../../../routes.dart';
import '../../../services/e2b_workspace_service.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';

class CloudWorkspaceLaunchDialog extends StatefulWidget {
  const CloudWorkspaceLaunchDialog({super.key, required this.config});

  final CloudWorkspaceConfig config;

  static Future<void> show(
    BuildContext context, {
    required CloudWorkspaceConfig config,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CloudWorkspaceLaunchDialog(config: config),
    );
  }

  @override
  State<CloudWorkspaceLaunchDialog> createState() =>
      _CloudWorkspaceLaunchDialogState();
}

class _CloudWorkspaceLaunchDialogState
    extends State<CloudWorkspaceLaunchDialog> {
  late String _currentStatus;
  bool _isError = false;
  String? _errorMessage;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _currentStatus = LocaleKeys.e2bLaunchPreparing.tr;
    _startLaunch();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Dialog disposed');
    super.dispose();
  }

  Future<void> _startLaunch() async {
    // 双保险:未配置 Key 直接报错,不发起任何请求
    if (widget.config.e2bApiKey.trim().isEmpty) {
      setState(() {
        _isError = true;
        _errorMessage = LocaleKeys.e2bApiKeyEmptyError.tr;
      });
      return;
    }

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    setState(() {
      _isError = false;
      _errorMessage = null;
      _currentStatus = LocaleKeys.e2bLaunchRequestingVm.tr;
    });

    final service = E2bWorkspaceService.instance;
    final result = await service.launchWorkspace(
      widget.config,
      cancelToken: _cancelToken,
      onProgress: (msg) {
        if (mounted) setState(() => _currentStatus = msg);
      },
    );

    if (!mounted || _cancelToken?.isCancelled == true) return;

    if (!result.success) {
      setState(() {
        _isError = true;
        _errorMessage = result.error ?? LocaleKeys.e2bLaunchFailed.tr;
      });
      return;
    }

    final sandboxId = result.sandboxId!;
    final endpointUrl = result.endpointUrl!;
    final password = result.password!;

    setState(() => _currentStatus = LocaleKeys.e2bLaunchConnecting.tr);

    // 1. 保存当前沙盒状态到设置(含 envd 访问令牌,供下次直连恢复)
    await Global.settings.updateCloudWorkspaceConfig((curr) {
      return curr.copyWith(
        activeSandboxId: sandboxId,
        activeSandboxUrl: endpointUrl,
        activeSandboxPassword: password,
        sandboxPassword: widget.config.sandboxPassword,
        activeSandboxEnvdToken: result.envdAccessToken,
        activeSandboxStatus: 'running',
        lastConnectedAt: DateTime.now(),
      );
    });

    // 2. 通过 SidecarManager 接入握手
    final connectResult = await SidecarManager.instance.updateConnection(
      endpointUrl,
      'opencode',
      password,
    );

    if (!mounted) return;

    if (!connectResult.success) {
      setState(() {
        _isError = true;
        _errorMessage = connectResult.error ?? LocaleKeys.e2bHandshakeFailed.tr;
      });
      return;
    }

    // 3. 握手成功:启动 TTL keep-alive,初始化控制器并进入主页
    E2bWorkspaceService.instance.startKeepAlive(
      sandboxId: sandboxId,
      apiKey: widget.config.e2bApiKey.trim(),
      timeoutSeconds: E2bWorkspaceService.sanitizeTimeoutSeconds(
        widget.config.ttlHours,
      ),
    );

    try {
      final projectCtrl = Get.find<ProjectController>();
      await projectCtrl.refreshAfterConnect();
    } catch (_) {}

    try {
      Get.find<SessionController>().initializeAfterConnect();
      Get.find<SettingsController>().checkHealth();
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop();
      Get.offNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _isError ? Icons.error_outline : Icons.cloud_sync,
            color: _isError
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Text(
            _isError
                ? LocaleKeys.e2bLaunchErrorTitle.tr
                : LocaleKeys.e2bTitle.tr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isError) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.15,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _currentStatus,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      _errorMessage ?? LocaleKeys.snackError.tr,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      LocaleKeys.e2bSandboxPreservedHint.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_isError) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LocaleKeys.close.tr),
          ),
          FilledButton(
            onPressed: _startLaunch,
            child: Text(LocaleKeys.retry.tr),
          ),
        ] else ...[
          TextButton(
            onPressed: () {
              _cancelToken?.cancel('User clicked cancel');
              Navigator.of(context).pop();
            },
            child: Text(LocaleKeys.cancel.tr),
          ),
        ],
      ],
    );
  }
}
