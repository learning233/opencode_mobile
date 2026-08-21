import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/translations.dart';
import '../api/sidecar_manager.dart';
import '../controllers/project_controller.dart';
import '../controllers/session_controller.dart';
import '../init.dart';
import '../routes.dart';
import '../utils/url_utils.dart';

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
  bool _isConnecting = false;
  bool _autoConnecting = true;
  bool _navigatedAway = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _tryAutoConnect();
  }

  void _loadSaved() {
    _urlController.text = Global.serverUrl;
    _usernameController.text = Global.serverUsername;
    _passwordController.text = Global.serverPassword;
  }

  /// 连接状态展示时对 URL 做脱敏：IPv4 每段隐藏首位，localhost/域名保持不变。
  String _maskedUrl(String url) => maskUrl(url);

  Future<void> _tryAutoConnect() async {
    if (!Global.hasServerSettings) {
      setState(() => _autoConnecting = false);
      return;
    }
    final url = Global.serverUrl;
    final username = Global.serverUsername;
    final password = Global.serverPassword;
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
      if (!mounted || !_autoConnecting) return;
      if (result.success) {
        await _onConnected();
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

  Future<void> _onConnect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isConnecting = true;
      _errorText = null;
    });
    try {
      final result = await SidecarManager.instance.updateConnection(
        _urlController.text,
        _usernameController.text,
        _passwordController.text,
      );
      if (!mounted) return;
      if (result.success) {
        await _onConnected();
      } else {
        setState(() {
          _isConnecting = false;
          _errorText = result.error;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _errorText = maskIpsInText(e.toString());
      });
    } finally {
      if (mounted && !_navigatedAway) setState(() => _isConnecting = false);
    }
  }

  Future<void> _onConnected() async {
    await Get.find<ProjectController>().refreshAfterConnect();
    Get.find<SessionController>().initializeAfterConnect();
    if (!mounted) return;
    _navigatedAway = true;
    Get.offNamed(AppRoutes.home);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_autoConnecting) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                LocaleKeys.mobileAutoConnecting.trParams({
                  'url': _maskedUrl(Global.serverUrl),
                }),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  SidecarManager.instance.stop();
                  setState(() => _autoConnecting = false);
                },
                child: Text(LocaleKeys.mobileEditSettings.tr),
              ),
            ],
          ),
        ),
      );
    }

    final isBusy = _isConnecting;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.mobileServerUrl.tr,
                    hintText: 'http://192.168.1.100:4096',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(CupertinoIcons.link),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? LocaleKeys.mobileServerUrlRequired.tr
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.username.tr,
                    hintText: 'opencode',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(CupertinoIcons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.mobilePassword.tr,
                    hintText: 'your-password-here',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(CupertinoIcons.lock),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: isBusy ? null : _onConnect,
                  icon: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.radiowaves_right),
                  label: Text(isBusy ? 'Connecting...' : 'Connect'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
