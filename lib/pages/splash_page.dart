import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../api/sidecar_manager.dart';
import '../controllers/project_controller.dart';
import '../controllers/session_controller.dart';
import '../init.dart';
import '../models/e2b_sandbox_info.dart';
import '../routes.dart';
import '../services/e2b_workspace_service.dart';
import '../utils/app_logger.dart';
import '../utils/translations.dart';
import '../utils/url_utils.dart';
import 'settings/connect/cloud_workspace_launch_dialog.dart';
import 'settings/connect/cloud_workspace_sheet.dart';
import 'settings/connect/e2b_api_key_dialog.dart';
import 'settings/connect/e2b_sandbox_picker_sheet.dart';
import 'splash/splash_auto_connecting_view.dart';
import 'splash/splash_cloud_view.dart';
import 'splash/splash_self_hosted_view.dart';

/// page 根目录启动页结构文件：负责自动连接引导、自建服务器与 E2B 云端沙盒模式分发，
/// 具体的表单和视图放入 lib/pages/splash/ 文件夹中。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // 0: 自建服务器, 1: E2B 云端沙盒
  int _selectedMode = 0;

  bool _isConnecting = false;
  bool _autoConnecting = true;
  bool _navigatedAway = false;
  String? _errorText;
  String? _cloudHint;
  String _cloudStepMessage = '';
  CancelToken? _cancelToken;

  /// 连接运行代号：Edit settings 取消或发起新连接时递增。
  int _connectSeq = 0;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _initMode();
    _tryAutoConnect();
  }

  void _loadSaved() {
    _urlController.text = Global.selfHostedServerUrl;
    _usernameController.text = Global.selfHostedServerUsername;
    _passwordController.text = Global.selfHostedServerPassword;
  }

  void _initMode() {
    final cloudConfig = Global.settings.cloudWorkspaceConfig;
    if (E2bWorkspaceService.isCloudUrl(Global.serverUrl) ||
        (Global.serverUrl.isEmpty && cloudConfig.hasActiveSandbox)) {
      _selectedMode = 1;
    } else {
      _selectedMode = 0;
    }
  }

  Future<void> _tryAutoConnect() async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final seq = _connectSeq;

    if (_selectedMode == 1) {
      // ── 云端模式冷启动恢复流 ──
      final cloudConfig = Global.settings.cloudWorkspaceConfig;
      if (!cloudConfig.hasActiveSandbox ||
          cloudConfig.e2bApiKey.trim().isEmpty) {
        setState(() => _autoConnecting = false);
        return;
      }

      setState(() {
        _autoConnecting = true;
        _errorText = null;
        _cloudHint = null;
      });

      try {
        AppLogger.i(
          'Splash cloud cold-start probing ${cloudConfig.activeSandboxUrl}',
        );
        final probeCode = await E2bWorkspaceService.instance.probeSandboxHealth(
          cloudConfig.activeSandboxUrl!,
          password: cloudConfig.activeSandboxPassword,
          cancelToken: _cancelToken,
        );

        if (!mounted || !_autoConnecting || seq != _connectSeq) return;

        if (probeCode == 200) {
          // 沙盒健康活跃，直接连接进主页
          final result = await SidecarManager.instance.updateConnection(
            cloudConfig.activeSandboxUrl!,
            'opencode',
            cloudConfig.activeSandboxPassword ?? '',
          );

          if (!mounted || !_autoConnecting || seq != _connectSeq) return;

          if (result.success) {
            E2bWorkspaceService.instance.startKeepAlive(
              sandboxId: cloudConfig.activeSandboxId!,
              apiKey: cloudConfig.e2bApiKey,
              timeoutSeconds: E2bWorkspaceService.sanitizeTimeoutSeconds(
                cloudConfig.ttlHours,
              ),
            );
            await _onConnected(seq);
            return;
          }
        }

        // 未就绪(502/暂停/超时/401等) -> 停在云端面板提示可唤醒，不产生新沙盒
        setState(() {
          _autoConnecting = false;
          _cloudHint = LocaleKeys.e2bSandboxNotReadyWakeHint.tr;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _autoConnecting = false;
          _cloudHint = LocaleKeys.e2bSandboxNotReadyWakeHint.tr;
        });
      } finally {
        if (mounted && !_navigatedAway) {
          setState(() => _autoConnecting = false);
        }
      }
      return;
    }

    // ── 自建服务器自动连接 ──
    if (!Global.hasSelfHostedSettings ||
        E2bWorkspaceService.isCloudUrl(Global.serverUrl)) {
      setState(() => _autoConnecting = false);
      return;
    }

    final url = Global.selfHostedServerUrl;
    final username = Global.selfHostedServerUsername;
    final password = Global.selfHostedServerPassword;
    setState(() {
      _autoConnecting = true;
      _errorText = null;
    });

    try {
      final result = await SidecarManager.instance.updateConnection(
        url,
        username,
        password,
      );
      // 用户已点击 Edit settings 取消自动连接时，忽略在途结果，不得跳转主页。
      if (!mounted || !_autoConnecting || seq != _connectSeq) return;
      if (result.success) {
        await _onConnected(seq);
      } else {
        setState(() {
          _autoConnecting = false;
          _errorText = result.error;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _autoConnecting = false;
        _errorText = maskIpsInText(e.toString());
      });
    } finally {
      if (mounted && !_navigatedAway) {
        setState(() => _autoConnecting = false);
      }
    }
  }

  Future<void> _onConnectSelfHosted() async {
    if (!_formKey.currentState!.validate()) return;
    final url = normalizeServerUrl(_urlController.text);
    if (url == null) {
      setState(() {
        _isConnecting = false;
        _errorText = LocaleKeys.connectionValidUrlRequired.tr;
      });
      return;
    }
    _urlController.text = url;
    final seq = ++_connectSeq;
    setState(() {
      _isConnecting = true;
      _errorText = null;
    });
    try {
      final result = await SidecarManager.instance.updateConnection(
        url,
        _usernameController.text,
        _passwordController.text,
      );
      if (!mounted || seq != _connectSeq) return;
      if (result.success) {
        await _onConnected(seq);
      } else {
        setState(() {
          _isConnecting = false;
          _errorText = result.error;
        });
      }
    } catch (e) {
      if (!mounted || seq != _connectSeq) return;
      setState(() {
        _isConnecting = false;
        _errorText = maskIpsInText(e.toString());
      });
    } finally {
      if (mounted && !_navigatedAway) setState(() => _isConnecting = false);
    }
  }

  Future<void> _onConnectCloud() async {
    final config = Global.settings.cloudWorkspaceConfig;
    if (!config.hasActiveSandbox) return;
    final seq = ++_connectSeq;
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    setState(() {
      _isConnecting = true;
      _errorText = null;
      _cloudStepMessage = LocaleKeys.mobileConnectSidecar.tr;
    });

    try {
      final res = await E2bWorkspaceService.instance.connectSandbox(
        config: config,
        sandboxId: config.activeSandboxId!,
        endpointUrl: config.activeSandboxUrl!,
        onProgress: (msg) {
          if (mounted && seq == _connectSeq) {
            setState(() => _cloudStepMessage = msg);
          }
        },
        cancelToken: _cancelToken,
      );

      if (!mounted || seq != _connectSeq) return;

      if (!res.success) {
        setState(() {
          _isConnecting = false;
          _errorText = res.error;
        });
        return;
      }

      final password = res.password!;
      final connectResult = await SidecarManager.instance.updateConnection(
        config.activeSandboxUrl!,
        'opencode',
        password,
      );

      if (!mounted || seq != _connectSeq) return;

      if (!connectResult.success) {
        setState(() {
          _isConnecting = false;
          _errorText = connectResult.error;
        });
        return;
      }

      // 回写更新持久化配置(保存恢复出的密码与最新 envd token)
      await Global.settings.updateCloudWorkspaceConfig((curr) {
        return curr.copyWith(
          activeSandboxPassword: password,
          activeSandboxEnvdToken: res.envdAccessToken,
          activeSandboxStatus: 'running',
          lastConnectedAt: DateTime.now(),
        );
      });

      E2bWorkspaceService.instance.startKeepAlive(
        sandboxId: config.activeSandboxId!,
        apiKey: config.e2bApiKey,
        timeoutSeconds: E2bWorkspaceService.sanitizeTimeoutSeconds(
          config.ttlHours,
        ),
        domain: res.domain,
      );

      await _onConnected(seq);
    } catch (e) {
      if (!mounted || seq != _connectSeq) return;
      setState(() {
        _isConnecting = false;
        _errorText = maskIpsInText(e.toString());
      });
    } finally {
      if (mounted && !_navigatedAway) setState(() => _isConnecting = false);
    }
  }

  Future<void> _onSelectAndSwitchSandbox(E2bSandboxInfo sb) async {
    await Global.settings.updateCloudWorkspaceConfig((curr) {
      return curr.copyWith(
        activeSandboxId: sb.sandboxId,
        activeSandboxUrl: sb.endpointUrl,
        activeSandboxStatus: sb.state,
      );
    });
    if (mounted) {
      setState(() {
        _errorText = null;
        _cloudHint = null;
      });
    }
  }

  Future<void> _onConnected(int seq) async {
    if (seq != _connectSeq) return;
    try {
      await Get.find<ProjectController>().refreshAfterConnect();
    } catch (_) {}
    if (seq != _connectSeq) return;
    try {
      Get.find<SessionController>().initializeAfterConnect();
    } catch (_) {}
    if (!mounted || seq != _connectSeq) return;
    _navigatedAway = true;
    Get.offNamed(AppRoutes.home);
  }

  @override
  void dispose() {
    _cancelToken?.cancel('SplashPage disposed');
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_autoConnecting) {
      return SplashAutoConnectingView(
        selectedMode: _selectedMode,
        onCancel: () {
          _connectSeq++;
          _cancelToken?.cancel();
          SidecarManager.instance.stop();
          if (Get.isRegistered<SessionController>()) {
            Get.find<SessionController>().disconnectSse();
          }
          setState(() => _autoConnecting = false);
        },
      );
    }

    final theme = Theme.of(context);
    final cloudConfig = Global.settings.cloudWorkspaceConfig;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'OpenCode',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  LocaleKeys.mobileConnectSidecar.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // ── 顶部模式切换 (自建服务器 vs E2B 云端) ──
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 0,
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: Text(LocaleKeys.connModeSelfHosted.tr),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: const Icon(Icons.cloud_outlined, size: 18),
                      label: Text(LocaleKeys.connModeCloud.tr),
                    ),
                  ],
                  selected: {_selectedMode},
                  onSelectionChanged: (vals) {
                    if (vals.isNotEmpty && !_isConnecting) {
                      setState(() {
                        _selectedMode = vals.first;
                        _errorText = null;
                        _cloudHint = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),

                if (_selectedMode == 0)
                  SplashSelfHostedView(
                    formKey: _formKey,
                    urlController: _urlController,
                    usernameController: _usernameController,
                    passwordController: _passwordController,
                    isBusy: _isConnecting,
                    errorText: _errorText,
                    onConnect: _onConnectSelfHosted,
                  )
                else
                  SplashCloudView(
                    config: cloudConfig,
                    isBusy: _isConnecting,
                    cloudHint: _cloudHint,
                    errorText: _errorText,
                    cloudStepMessage: _cloudStepMessage,
                    onConfigApiKey: () async {
                      await E2bApiKeyDialog.show(context);
                      if (mounted) setState(() {});
                    },
                    onNewSandbox: () async {
                      await CloudWorkspaceSheet.show(
                        context,
                        onLaunch: (cfg) => CloudWorkspaceLaunchDialog.show(
                          context,
                          config: cfg,
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                    onSelectSandbox: () async {
                      final selected = await E2bSandboxPickerSheet.show(
                        context,
                      );
                      if (selected != null && mounted) {
                        await _onSelectAndSwitchSandbox(selected);
                      }
                    },
                    onConnectCloud: _onConnectCloud,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
