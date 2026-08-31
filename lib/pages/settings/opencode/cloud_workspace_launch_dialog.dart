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
  const CloudWorkspaceLaunchDialog({
    super.key,
    required this.config,
  });

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
  String _currentStatus = '正在准备启动 E2B 云端沙盒...';
  bool _isError = false;
  String? _errorMessage;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _startLaunch();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Dialog disposed');
    super.dispose();
  }

  Future<void> _startLaunch() async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    setState(() {
      _isError = false;
      _errorMessage = null;
      _currentStatus = '正在向 E2B 申请微型虚拟机沙盒...';
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
        _errorMessage = result.error ?? '启动云端沙盒失败';
      });
      return;
    }

    final sandboxId = result.sandboxId!;
    final endpointUrl = result.endpointUrl!;
    final password = result.password!;

    setState(() => _currentStatus = '沙盒就绪，正在与本地建立安全连接...');

    // 1. 保存当前沙盒状态到设置(含 envd 访问令牌,供下次直连恢复)
    await Global.settings.updateCloudWorkspaceConfig((curr) {
      return curr.copyWith(
        activeSandboxId: sandboxId,
        activeSandboxUrl: endpointUrl,
        activeSandboxPassword: password,
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
        _errorMessage = connectResult.error ?? 'OpenCode 连接握手失败';
      });
      return;
    }

    // 3. 握手成功:启动 TTL keep-alive,初始化控制器并进入主页
    E2bWorkspaceService.instance.startKeepAlive(
      sandboxId: sandboxId,
      apiKey: widget.config.e2bApiKey.trim(),
      timeoutSeconds: widget.config.ttlHours * 3600 < 600
          ? 600
          : widget.config.ttlHours * 3600,
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
      Snack.success('E2B 云端工作区已连接并就绪');
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
            color: _isError ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Text(
            _isError ? '启动遇到问题' : 'E2B 云端工作区',
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
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.15),
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
                      _errorMessage ?? '未知错误',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '沙盒实例已保留，可在连接页沙盒列表中销毁或重新连接。',
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
