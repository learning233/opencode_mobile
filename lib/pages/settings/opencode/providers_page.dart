import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/models/settings.dart';
import '../../../controllers/settings_controller.dart';
import '../../../utils/translations.dart';
import '../../../widgets/integration_sheet.dart';
import '../../../widgets/settings/settings.dart';
import 'custom_provider_page.dart';

class OpencodeProvidersPage extends StatefulWidget {
  const OpencodeProvidersPage({super.key});

  @override
  State<OpencodeProvidersPage> createState() => _OpencodeProvidersPageState();
}

class _OpencodeProvidersPageState extends State<OpencodeProvidersPage> {
  final _searchCtrl = TextEditingController();
  final _disconnecting = <String>{};
  String _query = '';
  bool _showAllProviders = false;

  SettingsController get _settings => Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool force = false}) async {
    await Future.wait([
      _settings.fetchProviders(force: force),
      _settings.fetchGlobalConfig(),
    ]);
  }

  Future<void> _openProviderAuth(ProviderInfo provider) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProviderAuthSheet(providerId: provider.id),
    );
    if (result == true) {
      await _refresh(force: true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });
  }

  bool _isProviderConnected(ProviderInfo provider) {
    return provider.connected;
  }

  bool _isConfigCustom(String providerId) {
    final providerMap = _settings.globalConfig.value?['provider'];
    if (providerMap is! Map) return false;
    final entry = providerMap[providerId];
    if (entry is! Map) return false;
    final npm = entry['npm']?.toString() ?? '';
    if (npm != '@ai-sdk/openai-compatible') return false;
    final models = entry['models'];
    if (models is Map && models.isNotEmpty) return true;
    return true;
  }

  String _sourceTag(ProviderInfo provider) {
    final source = provider.type;
    if (source == 'env') return 'Env';
    if (source == 'api') return 'API';
    if (source == 'config') {
      if (_isConfigCustom(provider.id)) return LocaleKeys.customProviderTag.tr;
      return 'Config';
    }
    if (source == 'custom') return LocaleKeys.customProviderTag.tr;
    return '';
  }

  Future<void> _disconnectProvider(ProviderInfo provider) async {
    setState(() => _disconnecting.add(provider.id));
    try {
      await _settings.disconnectProvider(provider.id);
      await _refresh(force: true);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _disconnecting.remove(provider.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.providers.tr,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(force: true),
          ),
        ],
      ),
      body: Obx(() {
        final loading = _settings.isLoadingProviders.value;
        final allProviders = _settings.providers.toList();

        final connected = <ProviderInfo>[];
        for (final p in allProviders) {
          if (_isProviderConnected(p)) {
            connected.add(p);
          }
        }

        final connectedIds = connected.map((p) => p.id).toSet();
        final unconnected = <ProviderInfo>[];
        for (final p in allProviders) {
          if (!connectedIds.contains(p.id)) unconnected.add(p);
        }

        unconnected.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

        final q = _query.toLowerCase();
        final filteredAll = q.isEmpty
            ? unconnected
            : unconnected
                  .where(
                    (p) =>
                        p.name.toLowerCase().contains(q) ||
                        p.id.toLowerCase().contains(q),
                  )
                  .toList();

        final hasMoreThanFive = filteredAll.length > 3;
        final visibleAll = (_showAllProviders || _query.isNotEmpty)
            ? filteredAll
            : filteredAll.take(3).toList();

        if (loading && allProviders.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionHeader(title: LocaleKeys.secConnectedProviders.tr),
            SettingsCard(
              children: connected.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          LocaleKeys.noConnectedProviders.tr,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ]
                  : connected.map((provider) {
                      final isCustom = _isConfigCustom(provider.id);
                      final tag = _sourceTag(provider);
                      return _ProviderTile(
                        provider: provider,
                        isConnected: true,
                        isDisconnecting: _disconnecting.contains(provider.id),
                        sourceTag: tag,
                        isCustom: isCustom,
                        onTap: isCustom
                            ? () => Get.to(
                                () => CustomProviderPage(
                                  ctrl: _settings,
                                  editProviderId: provider.id,
                                ),
                              )
                            : () => _openProviderAuth(provider),
                        onDisconnect: () => _disconnectProvider(provider),
                        onEdit: isCustom
                            ? () => Get.to(
                                () => CustomProviderPage(
                                  ctrl: _settings,
                                  editProviderId: provider.id,
                                ),
                              )
                            : null,
                      );
                    }).toList(),
            ),
            const SizedBox(height: 16),

            SectionHeader(title: LocaleKeys.secAllProviders.tr),
            SettingsSearchField(
              controller: _searchCtrl,
              hint: LocaleKeys.searchProvidersPlaceholder.tr,
              onChanged: (value) => setState(() {
                _query = value.trim();
                if (_query.isNotEmpty) {
                  _showAllProviders = true;
                } else {
                  _showAllProviders = false;
                }
              }),
            ),
            SettingsCard(
              children: [
                if (filteredAll.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      LocaleKeys.noMatchingProviders.tr,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...[
                  ...visibleAll.map((provider) {
                    final isCustom = _isConfigCustom(provider.id);
                    return _ProviderTile(
                      provider: provider,
                      isConnected: false,
                      isCustom: isCustom,
                      onTap: isCustom
                          ? () => Get.to(
                              () => CustomProviderPage(
                                ctrl: _settings,
                                editProviderId: provider.id,
                              ),
                            )
                          : () => _openProviderAuth(provider),
                      onEdit: isCustom
                          ? () => Get.to(
                              () => CustomProviderPage(
                                ctrl: _settings,
                                editProviderId: provider.id,
                              ),
                            )
                          : null,
                    );
                  }),
                  if (hasMoreThanFive && !_showAllProviders && _query.isEmpty)
                    ListTile(
                      dense: true,
                      title: Text(
                        LocaleKeys.providersShowAll.trParams({
                          'totalCount': filteredAll.length.toString(),
                        }),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      onTap: () => setState(() => _showAllProviders = true),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            SectionHeader(title: LocaleKeys.secCustomProvider.tr),
            const SizedBox(height: 4),
            SettingsCard(
              children: [
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  leading: const Icon(CupertinoIcons.cloud, size: 20),
                  title: Text(
                    LocaleKeys.customProvider.tr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    LocaleKeys.customProviderDesc.tr,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () =>
                      Get.to(() => CustomProviderPage(ctrl: _settings)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SectionHeader(title: LocaleKeys.secBlockedProviders.tr),
            const SizedBox(height: 4),
            SettingsCard(
              children: [
                if (_settings.disabledProviders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      LocaleKeys.noBlockedProviders.tr,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ..._settings.disabledProviders.map(
                    (id) => ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      title: Text(
                        id,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: SizedBox(
                        height: 28,
                        child: TextButton(
                          onPressed: () async {
                            try {
                              await _settings.enableProvider(id);
                            } catch (_) {}
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(
                            LocaleKeys.restore.tr,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final ProviderInfo provider;
  final VoidCallback onTap;
  final VoidCallback? onDisconnect;
  final VoidCallback? onEdit;
  final bool isCustom;
  final bool isConnected;
  final bool isDisconnecting;
  final String sourceTag;

  const _ProviderTile({
    required this.provider,
    required this.onTap,
    required this.isConnected,
    this.isDisconnecting = false,
    this.onDisconnect,
    this.onEdit,
    this.isCustom = false,
    this.sourceTag = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tags = isConnected && sourceTag.isNotEmpty ? [sourceTag] : <String>[];

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              provider.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final tag in tags) ...[
            const SizedBox(width: 6),
            _Badge(text: tag, theme: theme),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: LocaleKeys.providersConfigEdit.tr,
              onPressed: onEdit,
            ),
          ],
          if (onDisconnect != null) ...[
            const SizedBox(width: 4),
            SizedBox(
              width: 36,
              height: 36,
              child: isDisconnecting
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: LocaleKeys.providersDeleteKey.tr,
                      onPressed: onDisconnect,
                    ),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final ThemeData theme;

  const _Badge({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.6,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
