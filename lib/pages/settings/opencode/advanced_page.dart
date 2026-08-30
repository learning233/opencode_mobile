import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/settings_controller.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../../../widgets/settings/settings.dart';

class OpencodeAdvancedPage extends StatefulWidget {
  const OpencodeAdvancedPage({super.key});

  @override
  State<OpencodeAdvancedPage> createState() => _OpencodeAdvancedPageState();
}

class _OpencodeAdvancedPageState extends State<OpencodeAdvancedPage> {
  SettingsController get _settings => Get.find<SettingsController>();

  final _watcherIgnoreList = <String>[];
  final _watcherInputCtrl = TextEditingController();
  final _pluginList = <String>[];
  final _pluginInputCtrl = TextEditingController();
  final _instructionList = <String>[];
  final _instructionInputCtrl = TextEditingController();

  bool _autoResize = true;
  final _maxWidthCtrl = TextEditingController();
  final _maxHeightCtrl = TextEditingController();
  final _maxBytesCtrl = TextEditingController();

  bool _watcherDirty = false;
  bool _pluginDirty = false;
  bool _instructionDirty = false;
  bool _attachmentDirty = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([_settings.fetchGlobalConfig()]);
      if (!mounted) return;
      _load();
      setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _watcherInputCtrl.dispose();
    _pluginInputCtrl.dispose();
    _instructionInputCtrl.dispose();
    _maxWidthCtrl.dispose();
    _maxHeightCtrl.dispose();
    _maxBytesCtrl.dispose();
    super.dispose();
  }

  void _load() {
    _watcherIgnoreList
      ..clear()
      ..addAll(
        ((_settings.watcherConfig?['ignore'] as List?) ?? const []).map(
          (e) => e.toString(),
        ),
      );

    _pluginList.clear();
    for (final p in _settings.pluginConfig) {
      if (p is String) {
        _pluginList.add(p);
      } else if (p is List && p.isNotEmpty) {
        _pluginList.add(p[0].toString());
      }
    }

    _instructionList
      ..clear()
      ..addAll(_settings.instructionPaths);

    final attachment = _settings.attachmentConfig;
    final image = attachment?['image'];
    if (image is Map) {
      _autoResize = image['auto_resize'] != false;
      _maxWidthCtrl.text = image['max_width']?.toString() ?? '';
      _maxHeightCtrl.text = image['max_height']?.toString() ?? '';
      _maxBytesCtrl.text = image['max_base64_bytes']?.toString() ?? '';
    } else {
      _autoResize = true;
      _maxWidthCtrl.clear();
      _maxHeightCtrl.clear();
      _maxBytesCtrl.clear();
    }

    _watcherDirty = false;
    _pluginDirty = false;
    _instructionDirty = false;
    _attachmentDirty = false;
  }

  Future<void> _saveWatcher() async {
    final ok = await _settings.setWatcherConfig({
      'ignore': _watcherIgnoreList.toList(),
    });
    if (!mounted) return;
    if (ok) setState(() => _watcherDirty = false);
    if (ok) {
      Snack.success(LocaleKeys.save.tr);
    } else {
      Snack.error(LocaleKeys.saveFailed.tr);
    }
  }

  Future<void> _savePlugin() async {
    final ok = await _settings.setPluginConfig(_pluginList.toList());
    if (!mounted) return;
    if (ok) setState(() => _pluginDirty = false);
    if (ok) {
      Snack.success(LocaleKeys.save.tr);
    } else {
      Snack.error(LocaleKeys.saveFailed.tr);
    }
  }

  Future<void> _saveInstructions() async {
    final ok = await _settings.setInstructionPaths(_instructionList.toList());
    if (!mounted) return;
    if (ok) setState(() => _instructionDirty = false);
    if (ok) {
      Snack.success(LocaleKeys.save.tr);
    } else {
      Snack.error(LocaleKeys.saveFailed.tr);
    }
  }

  Future<void> _saveAttachment() async {
    int? parsePositive(String text) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) return null;
      final v = int.tryParse(trimmed);
      return (v != null && v > 0) ? v : -1;
    }

    final width = parsePositive(_maxWidthCtrl.text);
    final height = parsePositive(_maxHeightCtrl.text);
    final bytes = parsePositive(_maxBytesCtrl.text);
    if (width == -1 || height == -1 || bytes == -1) {
      Snack.error(LocaleKeys.mobileInvalidNumber.tr);
      return;
    }
    final image = <String, dynamic>{'auto_resize': _autoResize};
    if (width != null) image['max_width'] = width;
    if (height != null) image['max_height'] = height;
    if (bytes != null) image['max_base64_bytes'] = bytes;
    final ok = await _settings.setAttachmentConfig({'image': image});
    if (!mounted) return;
    if (ok) setState(() => _attachmentDirty = false);
    if (ok) {
      Snack.success(LocaleKeys.save.tr);
    } else {
      Snack.error(LocaleKeys.saveFailed.tr);
    }
  }

  Widget _chipList({
    required List<String> items,
    required ValueChanged<String> onRemove,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'None',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: items
            .map(
              (item) => InputChip(
                label: Text(item, style: const TextStyle(fontSize: 11)),
                onDeleted: () => onRemove(item),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _listEditor({
    required String title,
    required String desc,
    required List<String> items,
    required TextEditingController inputCtrl,
    required VoidCallback onAdd,
    required ValueChanged<String> onRemove,
    required bool dirty,
    required VoidCallback onSave,
  }) {
    return SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: inputCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        hintText: LocaleKeys.mobileAddItem.tr,
                      ),
                      onSubmitted: (_) => onAdd(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(CupertinoIcons.add),
                    onPressed: onAdd,
                  ),
                ],
              ),
              _chipList(items: items, onRemove: onRemove),
              if (dirty)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: onSave,
                    child: Text(LocaleKeys.save.tr),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.tabAdvanced.tr,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // 有未保存编辑时不刷新覆盖，避免静默丢弃用户输入。
              if (_watcherDirty ||
                  _pluginDirty ||
                  _instructionDirty ||
                  _attachmentDirty) {
                Snack.warning(LocaleKeys.edUnsavedChanges.tr);
                return;
              }
              await _settings.fetchGlobalConfig();
              if (!mounted) return;
              setState(_load);
            },
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionHeader(title: LocaleKeys.fileWatcher.tr),
                _listEditor(
                  title: LocaleKeys.mobileIgnorePatterns.tr,
                  desc: 'Directories or patterns excluded from watching.',
                  items: _watcherIgnoreList,
                  inputCtrl: _watcherInputCtrl,
                  onAdd: () {
                    final v = _watcherInputCtrl.text.trim();
                    if (v.isEmpty) return;
                    setState(() {
                      _watcherIgnoreList.add(v);
                      _watcherInputCtrl.clear();
                      _watcherDirty = true;
                    });
                  },
                  onRemove: (v) {
                    setState(() {
                      _watcherIgnoreList.remove(v);
                      _watcherDirty = true;
                    });
                  },
                  dirty: _watcherDirty,
                  onSave: _saveWatcher,
                ),
                const SizedBox(height: 16),
                SectionHeader(title: LocaleKeys.mobilePlugins.tr),
                _listEditor(
                  title: LocaleKeys.mobilePluginEntries.tr,
                  desc: 'Plugin package names or paths.',
                  items: _pluginList,
                  inputCtrl: _pluginInputCtrl,
                  onAdd: () {
                    final v = _pluginInputCtrl.text.trim();
                    if (v.isEmpty) return;
                    setState(() {
                      _pluginList.add(v);
                      _pluginInputCtrl.clear();
                      _pluginDirty = true;
                    });
                  },
                  onRemove: (v) {
                    setState(() {
                      _pluginList.remove(v);
                      _pluginDirty = true;
                    });
                  },
                  dirty: _pluginDirty,
                  onSave: _savePlugin,
                ),
                const SizedBox(height: 16),
                SectionHeader(title: LocaleKeys.instructions.tr),
                _listEditor(
                  title: LocaleKeys.mobileInstructionPaths.tr,
                  desc: 'Extra instruction files loaded into context.',
                  items: _instructionList,
                  inputCtrl: _instructionInputCtrl,
                  onAdd: () {
                    final v = _instructionInputCtrl.text.trim();
                    if (v.isEmpty) return;
                    setState(() {
                      _instructionList.add(v);
                      _instructionInputCtrl.clear();
                      _instructionDirty = true;
                    });
                  },
                  onRemove: (v) {
                    setState(() {
                      _instructionList.remove(v);
                      _instructionDirty = true;
                    });
                  },
                  dirty: _instructionDirty,
                  onSave: _saveInstructions,
                ),
                const SizedBox(height: 16),
                SectionHeader(title: LocaleKeys.mobileAttachments.tr),
                SettingsCard(
                  children: [
                    SettingsRow(
                      title: LocaleKeys.mobileAutoResizeImages.tr,
                      desc: 'Downscale large images before upload.',
                      child: Switch(
                        value: _autoResize,
                        onChanged: (v) {
                          setState(() {
                            _autoResize = v;
                            _attachmentDirty = true;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        children: [
                          TextField(
                            controller: _maxWidthCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: LocaleKeys.mobileMaxWidth.tr,
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) =>
                                setState(() => _attachmentDirty = true),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _maxHeightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: LocaleKeys.mobileMaxHeight.tr,
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) =>
                                setState(() => _attachmentDirty = true),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _maxBytesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: LocaleKeys.mobileMaxBase64Bytes.tr,
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) =>
                                setState(() => _attachmentDirty = true),
                          ),
                          if (_attachmentDirty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: _saveAttachment,
                                child: Text(LocaleKeys.save.tr),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
