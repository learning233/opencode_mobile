import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../../../api/sidecar_manager.dart';
import '../../../controllers/project_controller.dart';
import '../../../controllers/session_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../init.dart';
import '../../../routes.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/url_utils.dart';

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

  SettingsController get _settings => Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = Global.serverUrl;
    _userCtrl.text = Global.serverUsername;
    _passCtrl.text = Global.serverPassword;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settings.checkHealth();
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndReconnect() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty ||
        !(url.startsWith('http://') || url.startsWith('https://'))) {
      Snack.error(LocaleKeys.connectionValidUrlRequired.tr);
      return;
    }
    setState(() => _saving = true);
    try {
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
      await Get.find<ProjectController>().refreshAfterConnect();
      Get.find<SessionController>().initializeAfterConnect();
      await _settings.checkHealth();
      if (mounted) {
        Snack.success(LocaleKeys.connectionReconnected.tr);
        _navigatedAway = true;
        Get.offNamed(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        Snack.error('${LocaleKeys.connectionReconnectFailed.tr}: ${maskIpsInText('$e')}');
      }
    } finally {
      if (mounted && !_navigatedAway) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.tabConnection.tr,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(LocaleKeys.mobileHealth.tr, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Obx(() {
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
          }),
          const Divider(height: 24),
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
      ),
    );
  }
}
