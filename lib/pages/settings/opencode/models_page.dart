import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/session_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../models/model_info.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../../../widgets/settings/settings.dart';

class OpencodeModelsPage extends StatefulWidget {
  const OpencodeModelsPage({super.key});

  @override
  State<OpencodeModelsPage> createState() => _OpencodeModelsPageState();
}

class _OpencodeModelsPageState extends State<OpencodeModelsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  SessionController get _session => Get.find<SessionController>();
  SettingsController get _settings => Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        _settings.fetchGlobalConfig(),
        _settings.fetchProviders(),
        _session.fetchModels(),
      ]);
      _session.updateAvailableModels();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _configModelId(ModelInfo model) => '${model.providerId}/${model.id}';

  static String _providerName(
    Map<String, String> providerNames,
    String providerId,
  ) {
    return providerNames[providerId] ?? providerId;
  }

  String _modelDisplayName(
    String configId,
    List<ModelInfo> models,
    Map<String, String> providerNames,
  ) {
    if (configId.isEmpty) return LocaleKeys.default_.tr;
    final match = models
        .where((m) => _configModelId(m) == configId)
        .firstOrNull;
    if (match == null) return configId;
    return '${_providerName(providerNames, match.providerId)} / ${match.name}';
  }

  Future<void> _setVisibility(ModelInfo model, bool visible) async {
    try {
      await _settings.setModelVisible(model, visible);
      _session.updateAvailableModels();
    } catch (e) {
      Snack.error('${LocaleKeys.modelsUpdateVisibilityFailed.tr}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.models.tr, style: const TextStyle(fontSize: 16)),
      ),
      body: Obx(() {
        // Local visibility prefs (desktop parity).
        _settings.shownModelsRx.length;
        _settings.hiddenModelsRx.length;
        final models = _session.allModels;
        final providerNames = <String, String>{
          for (final p in _settings.providers) p.id: p.name,
        };
        final query = _query.toLowerCase();
        final filtered = models.where((model) {
          if (query.isEmpty) return true;
          final providerName = _providerName(providerNames, model.providerId);
          return model.name.toLowerCase().contains(query) ||
              model.id.toLowerCase().contains(query) ||
              providerName.toLowerCase().contains(query);
        }).toList();

        final grouped = <String, List<ModelInfo>>{};
        for (final model in filtered) {
          grouped.putIfAbsent(model.providerId, () => []).add(model);
        }
        for (final items in grouped.values) {
          items.sort((a, b) => a.name.compareTo(b.name));
        }

        final modelConfigIds = ['', ...models.map(_configModelId)];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SettingsCard(
              children: [
                DropdownSetting(
                  key: const ValueKey('smallModel'),
                  title: LocaleKeys.smallModel.tr,
                  desc: LocaleKeys.smallModelDesc.tr,
                  value: _settings.smallModel ?? '',
                  items: modelConfigIds,
                  isLoading: _session.isLoadingModels.value,
                  onChanged: (v) async {
                    final ok = await _settings.setSmallModel(v);
                    if (!ok) Snack.error(LocaleKeys.saveFailed.tr);
                  },
                  display: (v) => _modelDisplayName(v, models, providerNames),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsSearchField(
              controller: _searchCtrl,
              hint: LocaleKeys.searchModelsPlaceholder.tr,
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            if (_session.isLoadingModels.value && models.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  _query.isEmpty
                      ? LocaleKeys.noModelsLoaded.tr
                      : LocaleKeys.noMatchingModels.tr,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ...grouped.entries.map((entry) {
                final providerName = _providerName(providerNames, entry.key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeader(title: providerName),
                      const SizedBox(height: 4),
                      SettingsCard(
                        children: entry.value.map((model) {
                          final visible = _settings.isModelVisible(
                            model,
                            models,
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        model.name,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        _configModelId(model),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: 11,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: visible,
                                  onChanged: (value) =>
                                      _setVisibility(model, value),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      }),
    );
  }
}
