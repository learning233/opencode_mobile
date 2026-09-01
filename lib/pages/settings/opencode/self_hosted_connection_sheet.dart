import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../api/sidecar_manager.dart';
import '../../../controllers/project_controller.dart';
import '../../../controllers/session_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../init.dart';
import '../../../services/e2b_workspace_service.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../../../utils/url_utils.dart';

/// 自建服务器连接与配置 BottomSheet
class SelfHostedConnectionSheet extends StatefulWidget {
  const SelfHostedConnectionSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const SelfHostedConnectionSheet(),
    );
  }

  @override
  State<SelfHostedConnectionSheet> createState() =>
      _SelfHostedConnectionSheetState();
}

class _SelfHostedConnectionSheetState extends State<SelfHostedConnectionSheet> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;

  bool _obscurePassword = true;
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(
      text: Global.settings.selfHostedServerUrl ?? '',
    );
    _userCtrl = TextEditingController(
      text:
          (Global.settings.selfHostedServerUsername?.trim().isNotEmpty == true)
          ? Global.settings.selfHostedServerUsername!
          : 'opencode',
    );
    _passCtrl = TextEditingController(
      text: Global.settings.selfHostedServerPassword ?? '',
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectAndSave() async {
    final rawUrl = _urlCtrl.text.trim();
    final url = normalizeServerUrl(rawUrl);
    if (url == null) {
      setState(() {
        _errorMessage = LocaleKeys.connectionValidUrlRequired.tr;
      });
      Snack.error(LocaleKeys.connectionValidUrlRequired.tr);
      return;
    }

    _urlCtrl.text = url;
    final user = _userCtrl.text.trim().isEmpty
        ? 'opencode'
        : _userCtrl.text.trim();
    final pass = _passCtrl.text;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      // 切回自建服务器时停止云端沙盒的 TTL keep-alive
      E2bWorkspaceService.instance.stopKeepAlive();

      final res = await SidecarManager.instance.updateConnection(
        url,
        user,
        pass,
      );

      if (!res.success) {
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _errorMessage = res.error ?? LocaleKeys.mobileConnectionFailed.tr;
          });
          Snack.error(_errorMessage!);
        }
        return;
      }

      // 保存持久化凭据
      await Global.settings.setSelfHostedServerUrl(url);
      await Global.settings.setSelfHostedServerUsername(user);
      await Global.settings.setSelfHostedServerPassword(pass);

      // 刷新项目和会话
      final projectCtrl = Get.find<ProjectController>();
      await projectCtrl.refreshAfterConnect();

      if (Get.isRegistered<SessionController>()) {
        Get.find<SessionController>().initializeAfterConnect();
      }
      if (Get.isRegistered<SettingsController>()) {
        Get.find<SettingsController>().checkHealth();
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = '$e';
        });
        Snack.error('$e');
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: bottomInset + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.dns_outlined,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                '${LocaleKeys.drawerSelfHostedSection.tr} ${LocaleKeys.mobileServerConnection.tr}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtrl,
            autofocus: _urlCtrl.text.isEmpty,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: LocaleKeys.mobileServerUrl.tr,
              hintText: 'http://192.168.1.100:4096',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _userCtrl,
            decoration: InputDecoration(
              labelText: LocaleKeys.username.tr,
              hintText: 'opencode',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: LocaleKeys.mobilePassword.tr,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isConnecting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(LocaleKeys.cancel.tr),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _isConnecting ? null : _connectAndSave,
                  icon: _isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.link, size: 18),
                  label: Text(
                    _isConnecting
                        ? LocaleKeys.mobileConnecting.tr
                        : LocaleKeys.mobileSaveAndReconnect.tr,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
