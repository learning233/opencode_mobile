import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/models/settings.dart';
import '../../../controllers/session_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../widgets/settings.dart';

class OpencodeAgentPage extends StatefulWidget {
  const OpencodeAgentPage({super.key});

  @override
  State<OpencodeAgentPage> createState() => _OpencodeAgentPageState();
}

class _OpencodeAgentPageState extends State<OpencodeAgentPage> {
  SettingsController get _settings => Get.find<SettingsController>();
  SessionController get _session => Get.find<SessionController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  List<String> _allModelIds() {
    final ids = <String>[];
    for (final p in _settings.providers) {
      if (!p.connected) continue;
      for (final m in p.models) {
        ids.add('${p.id}/${m.id}');
      }
    }
    return ids;
  }

  String _modelDisplayName(String id) {
    if (id.isEmpty) {
      final defaultModel =
          _settings.globalConfig.value?['model']?.toString() ?? '';
      if (defaultModel.isNotEmpty) {
        return 'Default (${_modelDisplayName(defaultModel)})';
      }
      return LocaleKeys.default_.tr;
    }
    for (final p in _settings.providers) {
      if (!p.connected) continue;
      for (final m in p.models) {
        if ('${p.id}/${m.id}' == id || m.id == id) {
          return '${p.name} / ${m.name}';
        }
      }
    }
    return id;
  }

  List<String> _variantsForModel(String modelId) {
    if (modelId.isEmpty) return const ['low', 'medium', 'high'];
    final match = _session.allModels
        .where((m) => m.id == modelId || '${m.providerId}/${m.id}' == modelId)
        .firstOrNull;
    if (match != null && match.variants.isNotEmpty) return match.variants;
    return const ['low', 'medium', 'high'];
  }

  Future<void> _refresh({bool force = false}) async {
    await Future.wait([
      _settings.fetchAgents(),
      _settings.fetchProviders(force: force),
      _settings.fetchGlobalConfig(),
      _session.fetchModels(),
    ]);
  }

  Future<void> _showNewAgentDialog() async {
    final modelIds = ['', ..._allModelIds()];
    final existing = _settings.availableAgents.map((a) => a.name).toSet();
    final result = await showModalBottomSheet<AgentDetailInfo>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NewAgentSheet(
        modelIds: modelIds,
        modes: SettingsController.agentModes,
        modelDisplay: _modelDisplayName,
        variantsForModel: _variantsForModel,
        existingNames: existing,
      ),
    );
    if (result == null || !mounted) return;

    // 服务端 PATCH 为 mergeDeep 深合并，按 agent 单键提交即可新增，
    // 无需整 map 重建（整 map 也无法真正删除条目）。
    // 同名重建时旧配置残留 hidden:true，需显式置 false 才能重新可见。
    final ok = await _settings.setAgentConfig({
      result.name: {...result.toJson(), 'hidden': false},
    });
    if (!mounted) return;
    if (ok) {
      Snack.success(LocaleKeys.agentCreate.tr);
    } else {
      Snack.error(LocaleKeys.failedToLoadAgents.tr);
    }
  }

  Future<void> _confirmDelete(AgentDetailInfo agent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.delete.tr),
        content: Text(agent.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocaleKeys.cancel.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(LocaleKeys.delete.tr),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await _settings.deleteAgent(agent.name);
    if (!mounted) return;
    if (ok) {
      Snack.success(LocaleKeys.delete.tr);
    } else {
      Snack.error(LocaleKeys.deleteFailed.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.tabAgent.tr,
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
        if (_settings.isLoadingAgents.value &&
            _settings.availableAgents.isEmpty) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final agents = _settings.availableAgents.toList();
        final modelIds = _allModelIds();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: SectionHeader(
                    title: '${LocaleKeys.agentConfigs.tr} (${agents.length})',
                  ),
                ),
                TextButton.icon(
                  onPressed: _showNewAgentDialog,
                  icon: const Icon(CupertinoIcons.add, size: 18),
                  label: Text(LocaleKeys.newAgent.tr),
                ),
              ],
            ),
            if (agents.isEmpty)
              SettingsCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _settings.agentsError.value.isNotEmpty
                          ? '${LocaleKeys.failedToLoadAgents.tr}: ${_settings.agentsError.value}'
                          : LocaleKeys.noAgentsConfigured.tr,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              )
            else
              SettingsCard(
                children: agents
                    .map(
                      (agent) => _AgentExpansionTile(
                        key: ValueKey('agent_${agent.name}'),
                        agent: agent,
                        modelIds: modelIds,
                        variantsForModel: _variantsForModel,
                        modes: SettingsController.agentModes,
                        modelDisplay: _modelDisplayName,
                        onSave: (updated) async {
                          // 单键深合并提交；重命名时旧名置 hidden（服务端
                          // 无法删键，fetchAgents 过滤 hidden）。新名显式
                          // hidden:false，防止撞上历史软删除的同名条目。
                          return _settings.setAgentConfig({
                            if (updated.name != agent.name)
                              agent.name: {'hidden': true},
                            updated.name: {
                              ...updated.toJson(),
                              'hidden': false,
                            },
                          });
                        },
                        onDelete: () => _confirmDelete(agent),
                        isSaving: _settings.savingStates.containsKey('agent'),
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

class _AgentExpansionTile extends StatefulWidget {
  final AgentDetailInfo agent;
  final List<String> modelIds;
  final List<String> Function(String modelId) variantsForModel;
  final List<String> modes;
  final String Function(String) modelDisplay;
  final Future<bool> Function(AgentDetailInfo updated) onSave;
  final VoidCallback onDelete;
  final bool isSaving;

  const _AgentExpansionTile({
    super.key,
    required this.agent,
    required this.modelIds,
    required this.variantsForModel,
    required this.modes,
    required this.modelDisplay,
    required this.onSave,
    required this.onDelete,
    required this.isSaving,
  });

  @override
  State<_AgentExpansionTile> createState() => _AgentExpansionTileState();
}

class _AgentExpansionTileState extends State<_AgentExpansionTile> {
  late String _model;
  late String _variant;
  late String _mode;
  late bool _disable;
  late double _temperature;
  late double _topP;
  late int _steps;
  late TextEditingController _descCtrl;
  late TextEditingController _promptCtrl;
  late TextEditingController _stepsCtrl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController();
    _promptCtrl = TextEditingController();
    _stepsCtrl = TextEditingController();
    _syncFromAgent();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _promptCtrl.dispose();
    _stepsCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AgentExpansionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty && oldWidget.agent.name == widget.agent.name) {
      _syncFromAgent();
    }
  }

  List<String> get _variantItems {
    final items = widget.variantsForModel(_model);
    if (items.isNotEmpty) return items;
    if (_variant.isNotEmpty) return [_variant];
    return const [];
  }

  void _syncFromAgent() {
    _model = widget.agent.model;
    final variants = widget.variantsForModel(_model);
    _variant =
        widget.agent.variant.isNotEmpty &&
            (variants.isEmpty || variants.contains(widget.agent.variant))
        ? widget.agent.variant
        : (variants.isNotEmpty ? variants.first : '');
    _mode = widget.agent.mode;
    _disable = widget.agent.disable;
    _temperature = widget.agent.temperature;
    _topP = widget.agent.topP;
    _steps = widget.agent.steps;
    _descCtrl.text = widget.agent.description;
    _promptCtrl.text = widget.agent.prompt;
    _stepsCtrl.text = _steps > 0 ? '$_steps' : '';
    _dirty = false;
  }

  void _onModelChanged(String modelId) {
    final variants = widget.variantsForModel(modelId);
    setState(() {
      _model = modelId;
      _variant = variants.contains(_variant)
          ? _variant
          : (variants.isNotEmpty ? variants.first : '');
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final variants = _variantItems;
    final variant = variants.contains(_variant)
        ? _variant
        : (variants.isNotEmpty ? variants.first : '');
    final steps = int.tryParse(_stepsCtrl.text.trim()) ?? 0;
    final updated = widget.agent.copyWith(
      model: _model,
      variant: variant,
      mode: _mode,
      disable: _disable,
      temperature: _temperature,
      topP: _topP,
      steps: steps,
      description: _descCtrl.text.trim(),
      prompt: _promptCtrl.text,
    );
    final ok = await widget.onSave(updated);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _variant = variant;
        _steps = steps;
        _dirty = false;
      });
      Snack.success(LocaleKeys.save.tr);
    } else {
      Snack.error(LocaleKeys.saveFailed.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      widget.modelDisplay(_model),
      if (_mode.isNotEmpty) _mode,
      if (_disable) LocaleKeys.disabled.tr,
    ].join(' · ');

    final modelItems = [
      '',
      ...widget.modelIds.isNotEmpty
          ? widget.modelIds
          : [if (_model.isNotEmpty) _model],
    ];
    final variantItems = _variantItems;
    final variantValue = variantItems.contains(_variant)
        ? _variant
        : (variantItems.isNotEmpty ? variantItems.first : '');

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      title: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _disable ? theme.disabledColor : Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.agent.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _descCtrl,
                decoration: InputDecoration(
                  labelText: LocaleKeys.mobileDescription.tr,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 8),
              DropdownSetting(
                title: LocaleKeys.mobileModel.tr,
                desc: 'AI model for this agent.',
                value: _model,
                items: modelItems,
                onChanged: _onModelChanged,
                display: widget.modelDisplay,
              ),
              DropdownSetting(
                title: LocaleKeys.mobileMode.tr,
                desc: 'Agent execution mode.',
                value: _mode,
                items: widget.modes,
                onChanged: (v) {
                  setState(() {
                    _mode = v;
                    _dirty = true;
                  });
                },
                display: (v) => v,
              ),
              if (variantItems.isNotEmpty)
                DropdownSetting(
                  title: LocaleKeys.mobileVariant.tr,
                  desc: 'Thinking / reasoning effort.',
                  value: variantValue,
                  items: variantItems,
                  onChanged: (v) {
                    setState(() {
                      _variant = v;
                      _dirty = true;
                    });
                  },
                  display: (v) => v,
                ),
              SettingsRow(
                title: LocaleKeys.mobileTemperature.tr,
                desc: _temperature.toStringAsFixed(2),
                child: SizedBox(
                  width: 140,
                  child: Slider(
                    value: _temperature.clamp(0.0, 2.0),
                    min: 0,
                    max: 2,
                    divisions: 40,
                    onChanged: (v) {
                      setState(() {
                        _temperature = v;
                        _dirty = true;
                      });
                    },
                  ),
                ),
              ),
              SettingsRow(
                title: LocaleKeys.mobileTopP.tr,
                desc: _topP.toStringAsFixed(2),
                child: SizedBox(
                  width: 140,
                  child: Slider(
                    value: _topP.clamp(0.0, 1.0),
                    min: 0,
                    max: 1,
                    divisions: 20,
                    onChanged: (v) {
                      setState(() {
                        _topP = v;
                        _dirty = true;
                      });
                    },
                  ),
                ),
              ),
              TextField(
                controller: _stepsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: LocaleKeys.mobileMaxSteps.tr,
                  border: OutlineInputBorder(),
                  isDense: true,
                  helperText: '0 = unlimited / default',
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _promptCtrl,
                decoration: InputDecoration(
                  labelText: LocaleKeys.mobileSystemPrompt.tr,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
                maxLines: 4,
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 8),
              SettingsRow(
                title: LocaleKeys.disabled.tr,
                desc: 'Disable this agent globally.',
                child: Switch(
                  value: _disable,
                  onChanged: (v) {
                    setState(() {
                      _disable = v;
                      _dirty = true;
                    });
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: LocaleKeys.delete.tr,
                    onPressed: widget.isSaving ? null : widget.onDelete,
                  ),
                  if (_dirty) ...[
                    TextButton(
                      onPressed: () => setState(_syncFromAgent),
                      child: Text(LocaleKeys.edReset.tr),
                    ),
                    FilledButton(
                      onPressed: widget.isSaving ? null : _save,
                      child: widget.isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(LocaleKeys.save.tr),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NewAgentSheet extends StatefulWidget {
  final List<String> modelIds;
  final List<String> modes;
  final String Function(String) modelDisplay;
  final List<String> Function(String modelId) variantsForModel;
  final Set<String> existingNames;

  const _NewAgentSheet({
    required this.modelIds,
    required this.modes,
    required this.modelDisplay,
    required this.variantsForModel,
    required this.existingNames,
  });

  @override
  State<_NewAgentSheet> createState() => _NewAgentSheetState();
}

class _NewAgentSheetState extends State<_NewAgentSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();
  String _model = '';
  String _mode = 'primary';
  String _variant = '';
  double _temperature = 0;
  double _topP = 1;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _promptCtrl.dispose();
    _stepsCtrl.dispose();
    super.dispose();
  }

  List<String> get _variantItems {
    final items = widget.variantsForModel(_model);
    if (items.isNotEmpty) return items;
    if (_variant.isNotEmpty) return [_variant];
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameCtrl.text.trim();
    final duplicate = name.isNotEmpty && widget.existingNames.contains(name);
    final variants = _variantItems;
    final variantValue = variants.contains(_variant)
        ? _variant
        : (variants.isNotEmpty ? variants.first : '');
    final botPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + botPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LocaleKeys.agentNewTitle.tr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.mobileAgentNameRequired.tr,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      errorText: duplicate ? 'Name already exists' : null,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.mobileDescription.tr,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  DropdownSetting(
                    title: LocaleKeys.mobileModel.tr,
                    value: _model,
                    items: widget.modelIds,
                    onChanged: (v) {
                      final next = widget.variantsForModel(v);
                      setState(() {
                        _model = v;
                        _variant = next.isNotEmpty ? next.first : '';
                      });
                    },
                    display: widget.modelDisplay,
                  ),
                  const SizedBox(height: 8),
                  DropdownSetting(
                    title: LocaleKeys.mobileMode.tr,
                    value: _mode,
                    items: widget.modes,
                    onChanged: (v) => setState(() => _mode = v),
                    display: (v) => v,
                  ),
                  if (variants.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DropdownSetting(
                      title: LocaleKeys.mobileVariant.tr,
                      value: variantValue,
                      items: variants,
                      onChanged: (v) => setState(() => _variant = v),
                      display: (v) => v,
                    ),
                  ],
                  SettingsRow(
                    title: LocaleKeys.mobileTemperature.tr,
                    desc: _temperature.toStringAsFixed(2),
                    child: SizedBox(
                      width: 140,
                      child: Slider(
                        value: _temperature.clamp(0.0, 2.0),
                        min: 0,
                        max: 2,
                        divisions: 40,
                        onChanged: (v) => setState(() => _temperature = v),
                      ),
                    ),
                  ),
                  SettingsRow(
                    title: LocaleKeys.mobileTopP.tr,
                    desc: _topP.toStringAsFixed(2),
                    child: SizedBox(
                      width: 140,
                      child: Slider(
                        value: _topP.clamp(0.0, 1.0),
                        min: 0,
                        max: 1,
                        divisions: 20,
                        onChanged: (v) => setState(() => _topP = v),
                      ),
                    ),
                  ),
                  TextField(
                    controller: _stepsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.mobileMaxSteps.tr,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _promptCtrl,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.mobileSystemPrompt.tr,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(LocaleKeys.cancel.tr),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: name.isEmpty || duplicate
                    ? null
                    : () {
                        Navigator.pop(
                          context,
                          AgentDetailInfo(
                            name: name,
                            model: _model,
                            mode: _mode,
                            variant: variantValue,
                            temperature: _temperature,
                            topP: _topP,
                            steps: int.tryParse(_stepsCtrl.text.trim()) ?? 0,
                            description: _descCtrl.text.trim(),
                            prompt: _promptCtrl.text,
                          ),
                        );
                      },
                child: Text(LocaleKeys.agentCreate.tr),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
