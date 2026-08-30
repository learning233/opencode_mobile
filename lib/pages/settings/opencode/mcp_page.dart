import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../controllers/settings_controller.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../../../utils/url_utils.dart';
import '../../../widgets/settings/settings.dart';

class OpencodeMcpPage extends StatefulWidget {
  const OpencodeMcpPage({super.key});

  @override
  State<OpencodeMcpPage> createState() => _OpencodeMcpPageState();
}

class _OpencodeMcpPageState extends State<OpencodeMcpPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  final _expanded = <String>{};

  SettingsController get _settings => Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settings.fetchMcpServers();
      _settings.fetchGlobalConfig();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<McpServerStatus> _filterServers(List<McpServerStatus> list) {
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.status.toLowerCase().contains(q) ||
              (s.command?.toLowerCase().contains(q) ?? false) ||
              (s.url?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  Future<void> _toggleConnection(McpServerStatus server) async {
    if (server.status == 'needs_auth') {
      await _startAuth(server);
      return;
    }
    final key = server.isConnected
        ? 'disconnect_${server.name}'
        : 'connect_${server.name}';
    if (_settings.mcpActionInProgress.contains(key)) return;
    try {
      if (server.isConnected) {
        await _settings.disconnectMcp(server.name);
      } else {
        await _settings.connectMcp(server.name);
      }
    } catch (e) {
      if (mounted) {
        Snack.error('MCP ${server.name}: ${maskIpsInText('$e')}');
      }
    }
  }

  Future<void> _confirmRemove(McpServerStatus server) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              LocaleKeys.mcpRemoveTitle.tr,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(LocaleKeys.mcpRemoveConfirm.trParams({'name': server.name})),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(LocaleKeys.cancel.tr),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(LocaleKeys.delete.tr),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final success = await _settings.removeMcpServer(server.name);
    if (!success && mounted) {
      Snack.error('Failed to remove ${server.name}');
    }
  }

  Future<void> _startAuth(McpServerStatus server) async {
    if (_settings.mcpActionInProgress.contains('auth_${server.name}')) return;
    _settings.mcpActionInProgress.add('auth_${server.name}');
    try {
      final res = await _settings.startMcpAuth(server.name);
      final authUrl = res['authorizationUrl'] as String?;
      if (authUrl == null || authUrl.isEmpty) {
        throw Exception('No authorization URL returned');
      }
      final uri = Uri.tryParse(authUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      final codeCtrl = TextEditingController();
      if (!mounted) return;
      final code = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                LocaleKeys.mcpAuthTitle.tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                LocaleKeys.mcpAuthDesc.tr,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: InputDecoration(
                  labelText: LocaleKeys.mcpAuthCodeLabel.tr,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(LocaleKeys.cancel.tr),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, codeCtrl.text.trim()),
                    child: Text(LocaleKeys.save.tr),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      codeCtrl.dispose();
      if (code == null || code.isEmpty) return;
      await _settings.completeMcpAuth(server.name, code);
      await _settings.fetchMcpServers();
      if (mounted) {
        Snack.success(
          LocaleKeys.mcpAuthSuccess.trParams({'name': server.name}),
        );
      }
    } catch (e) {
      if (mounted) {
        Snack.error(
          '${LocaleKeys.mcpAuthFailed.trParams({'name': server.name})}: '
          '${maskIpsInText('$e')}',
        );
      }
    } finally {
      _settings.mcpActionInProgress.remove('auth_${server.name}');
    }
  }

  Future<void> _removeAuth(McpServerStatus server) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              LocaleKeys.mcpRemoveAuthTitle.tr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              LocaleKeys.mcpRemoveAuthConfirm.trParams({'name': server.name}),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(LocaleKeys.cancel.tr),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(LocaleKeys.delete.tr),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _settings.removeMcpAuth(server.name);
      await _settings.fetchMcpServers();
      if (mounted) {
        Snack.success(
          LocaleKeys.mcpRemoveAuthSuccess.trParams({'name': server.name}),
        );
      }
    } catch (e) {
      if (mounted) Snack.error(maskIpsInText('$e'));
    }
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final commandCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final oauthClientIdCtrl = TextEditingController();
    final oauthClientSecretCtrl = TextEditingController();
    final envEntries = <({TextEditingController k, TextEditingController v})>[];
    var isRemote = false;
    var useOAuth = false;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                32 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      LocaleKeys.addMcpServer.tr,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.serverNamePlaceholder.tr,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      LocaleKeys.connectionType.tr,
                      style: Theme.of(ctx).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: 'local',
                          label: Text(LocaleKeys.mcpLocal.tr),
                        ),
                        ButtonSegment(
                          value: 'remote',
                          label: Text(LocaleKeys.mcpRemote.tr),
                        ),
                      ],
                      selected: {isRemote ? 'remote' : 'local'},
                      onSelectionChanged: (sel) {
                        setDialogState(() => isRemote = sel.first == 'remote');
                      },
                    ),
                    const SizedBox(height: 12),
                    if (isRemote) ...[
                      TextField(
                        controller: urlCtrl,
                        decoration: InputDecoration(
                          labelText: LocaleKeys.serverUrlPlaceholder.tr,
                          border: const OutlineInputBorder(),
                          hintText: 'https://example.com/mcp',
                        ),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: useOAuth,
                        onChanged: (v) {
                          setDialogState(() => useOAuth = v ?? false);
                        },
                        title: const Text(
                          'OAuth',
                          style: TextStyle(fontSize: 13),
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      if (useOAuth) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: oauthClientIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Client ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: oauthClientSecretCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Client Secret',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ] else ...[
                      TextField(
                        controller: commandCtrl,
                        decoration: InputDecoration(
                          labelText: LocaleKeys.commandPlaceholder.tr,
                          border: const OutlineInputBorder(),
                          hintText:
                              'npx -y @modelcontextprotocol/server-filesystem /path',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          isRemote ? 'Headers' : 'Environment',
                          style: Theme.of(ctx).textTheme.labelMedium,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              envEntries.add((
                                k: TextEditingController(),
                                v: TextEditingController(),
                              ));
                            });
                          },
                          icon: const Icon(CupertinoIcons.add, size: 16),
                          label: Text(LocaleKeys.add.tr),
                        ),
                      ],
                    ),
                    for (var i = 0; i < envEntries.length; i++) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: envEntries[i].k,
                              decoration: InputDecoration(
                                labelText: LocaleKeys.mobileHeaderKey.tr,
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: envEntries[i].v,
                              decoration: InputDecoration(
                                labelText: LocaleKeys.mobileHeaderValue.tr,
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setDialogState(() {
                                envEntries[i].k.dispose();
                                envEntries[i].v.dispose();
                                envEntries.removeAt(i);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          child: Text(LocaleKeys.cancel.tr),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  // 名称规范化（将拼入 /mcp/$name/... URL 路径），
                                  // 并拒绝重名：服务端 PATCH 深合并会在重名时
                                  // 把新旧配置融合成 hybrid 条目。
                                  final sanitized = SettingsController
                                      .sanitizeServerName(nameCtrl.text);
                                  if (sanitized.isEmpty) {
                                    Snack.error(LocaleKeys.mcpNameRequired.tr);
                                    return;
                                  }
                                  final configMcp =
                                      _settings.globalConfig.value?['mcp'];
                                  // 已被「删除」（enabled:false）的同名条目不算
                                  // 重名，允许重新添加（createMcpServer 会带上
                                  // enabled:true 重新启用）。
                                  final existing = <String>{
                                    ..._settings.mcpServers.map(
                                      (s) => s.name,
                                    ),
                                    if (configMcp is Map)
                                      ...configMcp.keys
                                          .map((k) => k.toString())
                                          .where(
                                            (k) =>
                                                !(configMcp[k] is Map &&
                                                    (configMcp[k]
                                                            as Map)['enabled'] ==
                                                        false),
                                          ),
                                  };
                                  if (existing.contains(sanitized)) {
                                    Snack.error(
                                      LocaleKeys.mcpNameExists.trParams({
                                        'name': sanitized,
                                      }),
                                    );
                                    return;
                                  }
                                  if (isRemote) {
                                    if (urlCtrl.text.trim().isEmpty) {
                                      Snack.error(LocaleKeys.mcpUrlRequired.tr);
                                      return;
                                    }
                                  } else {
                                    if (commandCtrl.text.trim().isEmpty) {
                                      Snack.error(
                                        LocaleKeys.mcpCommandRequired.tr,
                                      );
                                      return;
                                    }
                                  }

                                  setDialogState(() => saving = true);
                                  try {
                                    final env = <String, String>{};
                                    for (final e in envEntries) {
                                      final k = e.k.text.trim();
                                      if (k.isNotEmpty) env[k] = e.v.text;
                                    }
                                    await _settings.createMcpServer(
                                      name: sanitized,
                                      transport: isRemote ? 'remote' : 'local',
                                      command: isRemote
                                          ? null
                                          : commandCtrl.text.trim(),
                                      url: isRemote
                                          ? urlCtrl.text.trim()
                                          : null,
                                      env: env.isEmpty ? null : env,
                                      oauthClientId: isRemote
                                          ? oauthClientIdCtrl.text.trim()
                                          : null,
                                      oauthClientSecret: isRemote
                                          ? oauthClientSecretCtrl.text.trim()
                                          : null,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    Snack.error(
                                      '${LocaleKeys.mcpAddFailed.tr}: '
                                      '${maskIpsInText('$e')}',
                                    );
                                  } finally {
                                    if (ctx.mounted) {
                                      setDialogState(() => saving = false);
                                    }
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(LocaleKeys.addMcpServer.tr),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    commandCtrl.dispose();
    urlCtrl.dispose();
    oauthClientIdCtrl.dispose();
    oauthClientSecretCtrl.dispose();
    for (final e in envEntries) {
      e.k.dispose();
      e.v.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.tabMcp.tr, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.add),
            tooltip: LocaleKeys.addMcpServer.tr,
            onPressed: _showAddDialog,
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: _settings.fetchMcpServers,
          ),
        ],
      ),
      body: _buildInstalled(context),
    );
  }

  Widget _buildInstalled(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final loading = _settings.mcpLoading.value;
      final servers = _filterServers(_settings.mcpServers.toList());
      final busy = _settings.mcpActionInProgress.toSet();

      if (loading && _settings.mcpServers.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_settings.mcpError.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _settings.mcpError.value,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
          SettingsSearchField(
            controller: _searchCtrl,
            hint: LocaleKeys.searchProvidersPlaceholder.tr,
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          SettingsCard(
            children: servers.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        loading ? 'Loading...' : 'No MCP servers configured.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ]
                : servers
                      .map(
                        (server) => _McpServerTile(
                          server: server,
                          expanded: _expanded.contains(server.name),
                          busy: busy.any((k) => k.endsWith('_${server.name}')),
                          onExpand: () {
                            setState(() {
                              if (_expanded.contains(server.name)) {
                                _expanded.remove(server.name);
                              } else {
                                _expanded.add(server.name);
                              }
                            });
                          },
                          onToggle: () => _toggleConnection(server),
                          onRemove: () => _confirmRemove(server),
                          onRemoveAuth: server.type == 'remote'
                              ? () => _removeAuth(server)
                              : null,
                        ),
                      )
                      .toList(),
          ),
        ],
      );
    });
  }
}

class _McpServerTile extends StatelessWidget {
  final McpServerStatus server;
  final bool expanded;
  final bool busy;
  final VoidCallback onExpand;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final VoidCallback? onRemoveAuth;

  const _McpServerTile({
    required this.server,
    required this.expanded,
    required this.busy,
    required this.onExpand,
    required this.onToggle,
    required this.onRemove,
    this.onRemoveAuth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = server.isConnected;
    final needsAuth = server.status == 'needs_auth';
    final statusColor = connected
        ? context.appColors.success
        : needsAuth
        ? Colors.orange
        : theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
          onTap: onExpand,
          leading: Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
          ),
          title: Text(server.name, style: const TextStyle(fontSize: 13)),
          subtitle: Text(
            server.status,
            style: TextStyle(fontSize: 11, color: statusColor),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                TextButton(
                  onPressed: busy ? null : onToggle,
                  child: Text(
                    connected
                        ? LocaleKeys.disconnect.tr
                        : LocaleKeys.providersConnect.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: connected
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: busy ? null : onRemove,
                  tooltip: LocaleKeys.mcpRemoveTitle.tr,
                ),
              ],
            ],
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (server.type.isNotEmpty)
                  _detailLine(theme, 'Type', server.type),
                if (server.command != null && server.command!.isNotEmpty)
                  _detailLine(theme, 'Command', server.command!),
                if (server.url != null && server.url!.isNotEmpty)
                  _detailLine(theme, 'URL', server.url!),
                if (server.error != null && server.error!.isNotEmpty)
                  _detailLine(
                    theme,
                    'Error',
                    server.error!,
                    color: theme.colorScheme.error,
                  ),
                if (server.env.isNotEmpty)
                  _detailLine(theme, 'Env', server.env.keys.join(', ')),
                if (server.headers.isNotEmpty)
                  _detailLine(theme, 'Headers', server.headers.keys.join(', ')),
                if (server.tools.isNotEmpty)
                  _detailLine(theme, 'Tools', server.tools.join(', ')),
                if (onRemoveAuth != null)
                  TextButton.icon(
                    onPressed: onRemoveAuth,
                    icon: const Icon(Icons.logout, size: 14),
                    label: Text(
                      LocaleKeys.mcpRemoveAuthTitle.tr,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _detailLine(
    ThemeData theme,
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 11,
                color: color ?? theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
