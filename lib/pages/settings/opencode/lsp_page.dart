import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/settings_controller.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../../../widgets/settings/settings.dart';

String _lspStatusLabel(String status) {
  switch (status) {
    case 'connected':
      return LocaleKeys.lspInstalled.tr;
    case 'error':
      return 'Error';
    case 'installed':
      return LocaleKeys.lspInstalled.tr;
    case 'missing':
      return LocaleKeys.lspMissing.tr;
    default:
      return status;
  }
}

class OpencodeLspPage extends StatefulWidget {
  const OpencodeLspPage({super.key});

  @override
  State<OpencodeLspPage> createState() => _OpencodeLspPageState();
}

class _OpencodeLspPageState extends State<OpencodeLspPage> {
  SettingsController get _settings => Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([_settings.fetchLsp(), _settings.fetchGlobalConfig()]);
    });
  }

  Future<void> _refresh() async {
    await Future.wait([_settings.fetchLsp(), _settings.fetchGlobalConfig()]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.tabLsp.tr, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Obx(() {
        _settings.globalConfig.value;
        final loading = _settings.lspLoading.value;
        final servers = _settings.lspServers.toList();
        final overall = _settings.lspStatus.value;
        final enabled = _settings.lspEnabled;

        if (loading && servers.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionHeader(title: LocaleKeys.tabLsp.tr),
            SettingsCard(
              children: [
                SettingsRow(
                  title: LocaleKeys.mobileEnableLsp.tr,
                  desc: overall.isNotEmpty
                      ? LocaleKeys.mobileStatus.trParams({'status': overall})
                      : LocaleKeys.mobileEnableLspDesc.tr,
                  child: Switch(
                    value: enabled,
                    onChanged: (v) async {
                      final ok = await _settings.setLspEnabled(v);
                      if (!ok && mounted) {
                        Snack.error(LocaleKeys.save.tr);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionHeader(title: LocaleKeys.lspAvailableServers.tr),
            const SizedBox(height: 8),
            SettingsCard(
              children: servers.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          loading ? 'Loading...' : LocaleKeys.edNoLspServers.tr,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ]
                  : servers
                        .map(
                          (server) => _LspServerTile(
                            server: server,
                            disabled:
                                _settings.isLspServerDisabled(server.name) ||
                                server.disabled,
                            enabledMaster: enabled,
                            onDisabledChanged: (disabled) async {
                              final ok = await _settings.setLspServerDisabled(
                                server.name,
                                disabled,
                              );
                              if (!ok && mounted) {
                                Snack.error(LocaleKeys.save.tr);
                              }
                            },
                          ),
                        )
                        .toList(),
            ),
          ],
        );
      }),
    );
  }
}

class _LspServerTile extends StatelessWidget {
  final LspServerInfo server;
  final bool disabled;
  final bool enabledMaster;
  final ValueChanged<bool> onDisabledChanged;

  const _LspServerTile({
    required this.server,
    required this.disabled,
    required this.enabledMaster,
    required this.onDisabledChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = server.isInstalled
        ? context.appColors.success
        : theme.colorScheme.onSurfaceVariant;

    final subtitles = <String>[
      _lspStatusLabel(server.status),
      if (disabled) 'Disabled in config',
      if (server.extensions.isNotEmpty)
        server.extensions.map((e) => e.startsWith('.') ? e : '.$e').join(', '),
      if (server.command != null && server.command!.isNotEmpty)
        LocaleKeys.lspExecutable.tr.replaceFirst('@cmd', server.command!),
    ];

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      title: Text(server.name, style: const TextStyle(fontSize: 13)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < subtitles.length; i++)
            Text(
              subtitles[i],
              style: TextStyle(
                fontSize: 11,
                color: i == 0
                    ? statusColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (server.error != null && server.error!.isNotEmpty)
            Text(
              server.error!,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
            ),
        ],
      ),
      trailing: Switch(
        value: enabledMaster && !disabled,
        onChanged: enabledMaster ? (v) => onDisabledChanged(!v) : null,
      ),
    );
  }
}
