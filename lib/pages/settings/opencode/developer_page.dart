import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/settings_controller.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../../../widgets/settings/settings.dart';

class OpencodeDeveloperPage extends StatefulWidget {
  const OpencodeDeveloperPage({super.key});

  @override
  State<OpencodeDeveloperPage> createState() => _OpencodeDeveloperPageState();
}

class _OpencodeDeveloperPageState extends State<OpencodeDeveloperPage> {
  SettingsController get _settings => Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await Future.wait([
      _settings.fetchCommands(),
      _settings.fetchFormatters(),
      _settings.fetchReferences(),
      _settings.fetchGlobalConfig(),
    ]);
  }

  Future<void> _editCommand([Map<String, dynamic>? existing]) async {
    if (existing != null && !SettingsController.isCommandEditable(existing)) {
      Snack.error('Only config-sourced commands can be edited.');
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CommandEditorDialog(initial: existing),
    );
    if (result == null || !mounted) return;

    final cfg = Map<String, dynamic>.from(_settings.commandConfig ?? {});
    final name = result['name']?.toString() ?? '';
    if (name.isEmpty) return;
    final payload = Map<String, dynamic>.from(result)..remove('name');
    cfg[name] = payload;
    final ok = await _settings.setCommandConfig(cfg);
    if (!mounted) return;
    if (ok) {
      Snack.success(LocaleKeys.save.tr);
    } else {
      Snack.error(LocaleKeys.saveFailed.tr);
    }
  }

  Future<void> _deleteCommand(String name, Map<String, dynamic> cmd) async {
    if (!SettingsController.isCommandEditable(cmd)) {
      Snack.error('Only config-sourced commands can be deleted.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.delete.tr),
        content: Text(name),
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
    // 已知服务端限制：PATCH /global/config 为 mergeDeep 深合并且 command 条目
    // 无禁用字段，移除的 command 键会被保留，重进页面后可能重新出现。
    final cfg = Map<String, dynamic>.from(_settings.commandConfig ?? {});
    cfg.remove(name);
    final ok = await _settings.setCommandConfig(cfg);
    if (!mounted) return;
    if (ok) {
      Snack.success(LocaleKeys.delete.tr);
    } else {
      Snack.error(LocaleKeys.deleteFailed.tr);
    }
  }

  Future<void> _addReference() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ReferenceEditorSheet(),
    );
    if (result == null || !mounted) return;
    final name = result['name']?.toString().trim() ?? '';
    if (name.isEmpty) return;
    final next = Map<String, dynamic>.from(_settings.referenceConfig ?? {});
    if (next.containsKey(name)) {
      Snack.error(LocaleKeys.developerRefNameExists.tr);
      return;
    }
    final entry = Map<String, dynamic>.from(result)..remove('name');
    final type = entry['type']?.toString() ?? 'string';
    switch (type) {
      case 'git':
        next[name] = {
          'repository': entry['repository'] ?? entry['url'] ?? '',
          if ((entry['branch']?.toString() ?? '').isNotEmpty)
            'branch': entry['branch'],
        };
      case 'local':
      case 'path':
        next[name] = {'path': entry['path'] ?? ''};
      default:
        next[name] = entry['value']?.toString() ?? '';
    }
    final ok = await _settings.setReferenceConfig(next);
    if (!mounted) return;
    if (ok) {
      Snack.success(LocaleKeys.save.tr);
    } else {
      Snack.error(LocaleKeys.saveFailed.tr);
    }
  }

  Future<void> _deleteReference(int index) async {
    final current = _settings.references.toList();
    if (index < 0 || index >= current.length) return;
    current.removeAt(index);
    // 已知服务端限制：references 为 map，mergeDeep 深合并会保留被移除的键
    // （Entry 虽有 hidden 字段但客户端未接），删除后重进页面可能重新出现。
    final next = SettingsController.referenceConfigFromEntries(current);
    final ok = await _settings.setReferenceConfig(next);
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
          LocaleKeys.tabDeveloper.tr,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.add),
            tooltip: LocaleKeys.addCommand.tr,
            onPressed: () => _editCommand(),
          ),
        ],
      ),
      body: Obx(() {
        _settings.globalConfig.value;
        final list = _settings.commands;
        final formatters = _settings.formatters.toList();
        final refs = _settings.references.toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionHeader(title: LocaleKeys.mobileFormatters.tr),
            SettingsCard(
              children: [
                SettingsRow(
                  title: LocaleKeys.mobileEnableFormatters.tr,
                  desc: 'Master switch for code formatters.',
                  child: Switch(
                    value: _settings.formattersEnabled,
                    onChanged: (v) async {
                      final ok = await _settings.setFormattersEnabled(v);
                      if (!ok && mounted) {
                        Snack.error(LocaleKeys.saveFailed.tr);
                      }
                    },
                  ),
                ),
                if (_settings.formattersLoading.value && formatters.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (formatters.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _settings.formattersError.value.isNotEmpty
                          ? _settings.formattersError.value
                          : 'No formatters reported by server.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final f in formatters)
                    ListTile(
                      dense: true,
                      title: Text(
                        f['name']?.toString() ??
                            f['id']?.toString() ??
                            'formatter',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        [
                          if (f['status'] != null) f['status'].toString(),
                          if (f['extensions'] is List)
                            (f['extensions'] as List).join(', '),
                        ].where((e) => e.isNotEmpty).join(' · '),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SectionHeader(
                    title: LocaleKeys.mobileReferences.trParams({
                      'count': '${refs.length}',
                    }),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addReference,
                  icon: const Icon(CupertinoIcons.add, size: 18),
                  label: Text(LocaleKeys.add.tr),
                ),
              ],
            ),
            SettingsCard(
              children: refs.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _settings.referencesError.value.isNotEmpty
                              ? _settings.referencesError.value
                              : 'No references configured.',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ]
                  : [
                      for (var i = 0; i < refs.length; i++)
                        ListTile(
                          dense: true,
                          title: Text(
                            refs[i]['name']?.toString() ??
                                refs[i]['id']?.toString() ??
                                'reference',
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            [
                              refs[i]['type']?.toString() ?? 'string',
                              refs[i]['repository']?.toString() ??
                                  refs[i]['url']?.toString() ??
                                  refs[i]['path']?.toString() ??
                                  refs[i]['value']?.toString() ??
                                  '',
                              if (refs[i]['branch'] != null)
                                refs[i]['branch'].toString(),
                            ].where((e) => e.isNotEmpty).join(' · '),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _deleteReference(i),
                          ),
                        ),
                    ],
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: LocaleKeys.mobileCustomCommands.trParams({
                'count': '${list.length}',
              }),
            ),
            if (_settings.isLoadingCommands.value && list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (list.isEmpty)
              SettingsCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _settings.commandsError.value.isNotEmpty
                          ? _settings.commandsError.value
                          : 'No custom commands configured.',
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
                children: list.map((cmd) {
                  final name = cmd['name']?.toString() ?? '';
                  final template = cmd['template']?.toString() ?? '';
                  final desc = cmd['description']?.toString() ?? '';
                  final source = cmd['source']?.toString() ?? 'config';
                  final editable = SettingsController.isCommandEditable(cmd);
                  return ListTile(
                    dense: true,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            source,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      desc.isNotEmpty ? desc : template,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: editable
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _editCommand(cmd),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                onPressed: name.isEmpty
                                    ? null
                                    : () => _deleteCommand(name, cmd),
                              ),
                            ],
                          )
                        : Tooltip(
                            message: 'Read-only ($source)',
                            child: Icon(
                              Icons.lock_outline,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  );
                }).toList(),
              ),
          ],
        );
      }),
    );
  }
}

class _CommandEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;

  const _CommandEditorDialog({this.initial});

  @override
  State<_CommandEditorDialog> createState() => _CommandEditorDialogState();
}

class _CommandEditorDialogState extends State<_CommandEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _templateCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _agentCtrl;
  late final TextEditingController _modelCtrl;
  late bool _subtask;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _nameCtrl = TextEditingController(text: i?['name']?.toString() ?? '');
    _templateCtrl = TextEditingController(
      text: i?['template']?.toString() ?? '',
    );
    _descCtrl = TextEditingController(
      text: i?['description']?.toString() ?? '',
    );
    _agentCtrl = TextEditingController(text: i?['agent']?.toString() ?? '');
    _modelCtrl = TextEditingController(
      text: SettingsController.modelRefToString(i?['model']),
    );
    _subtask = i?['subtask'] == true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _templateCtrl.dispose();
    _descCtrl.dispose();
    _agentCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(
        editing
            ? LocaleKeys.developerEditCommand.tr
            : LocaleKeys.developerNewCommand.tr,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              enabled: !editing,
              decoration: InputDecoration(
                labelText: LocaleKeys.mobileNameRequired.tr,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _templateCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: LocaleKeys.mobileTemplateRequired.tr,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: LocaleKeys.mobileDescription.tr,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _agentCtrl,
              decoration: InputDecoration(
                labelText: LocaleKeys.mobileAgent.tr,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelCtrl,
              decoration: InputDecoration(
                labelText: LocaleKeys.mobileModel.tr,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                LocaleKeys.mobileSubtask.tr,
                style: const TextStyle(fontSize: 13),
              ),
              value: _subtask,
              onChanged: (v) => setState(() => _subtask = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LocaleKeys.cancel.tr),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            final template = _templateCtrl.text.trim();
            if (name.isEmpty || template.isEmpty) return;
            final payload = <String, dynamic>{
              'name': name,
              'template': template,
              if (_descCtrl.text.trim().isNotEmpty)
                'description': _descCtrl.text.trim(),
              if (_agentCtrl.text.trim().isNotEmpty)
                'agent': _agentCtrl.text.trim(),
              if (_modelCtrl.text.trim().isNotEmpty)
                'model': _modelCtrl.text.trim(),
              if (_subtask) 'subtask': true,
            };
            Navigator.pop(context, payload);
          },
          child: Text(LocaleKeys.save.tr),
        ),
      ],
    );
  }
}

class _ReferenceEditorSheet extends StatefulWidget {
  const _ReferenceEditorSheet();

  @override
  State<_ReferenceEditorSheet> createState() => _ReferenceEditorSheetState();
}

class _ReferenceEditorSheetState extends State<_ReferenceEditorSheet> {
  final _nameCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  String _type = 'string';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + botPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LocaleKeys.mobileAddReference.tr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.mobileNameRequired.tr,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 'string',
                        label: Text(LocaleKeys.mobileRefText.tr),
                      ),
                      ButtonSegment(
                        value: 'git',
                        label: Text(LocaleKeys.mobileRefGit.tr),
                      ),
                      ButtonSegment(
                        value: 'local',
                        label: Text(LocaleKeys.mobileRefPath.tr),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (sel) =>
                        setState(() => _type = sel.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _valueCtrl,
                    decoration: InputDecoration(
                      labelText: _type == 'git'
                          ? 'Repository URL *'
                          : _type == 'local'
                          ? 'Path *'
                          : 'Value *',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (_type == 'git') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _branchCtrl,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.mobileBranchOptional.tr,
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
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
                onPressed: () {
                  final name = _nameCtrl.text.trim();
                  final value = _valueCtrl.text.trim();
                  if (name.isEmpty || value.isEmpty) return;
                  if (_type == 'string') {
                    Navigator.pop(context, {
                      'name': name,
                      'type': 'string',
                      'value': value,
                    });
                  } else if (_type == 'git') {
                    Navigator.pop(context, {
                      'name': name,
                      'type': 'git',
                      'repository': value,
                      if (_branchCtrl.text.trim().isNotEmpty)
                        'branch': _branchCtrl.text.trim(),
                    });
                  } else {
                    Navigator.pop(context, {
                      'name': name,
                      'type': 'local',
                      'path': value,
                    });
                  }
                },
                child: Text(LocaleKeys.save.tr),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
