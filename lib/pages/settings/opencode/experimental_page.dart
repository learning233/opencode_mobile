import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../controllers/settings_controller.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../widgets/settings.dart';

class OpencodeExperimentalPage extends StatefulWidget {
  const OpencodeExperimentalPage({super.key});

  @override
  State<OpencodeExperimentalPage> createState() =>
      _OpencodeExperimentalPageState();
}

class _OpencodeExperimentalPageState extends State<OpencodeExperimentalPage> {
  final _timeoutCtrl = TextEditingController();
  final _toolCtrl = TextEditingController();
  List<String> _primaryTools = [];
  bool _toolsDirty = false;
  bool _timeoutDirty = false;

  SettingsController get _settings => Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _settings.fetchGlobalConfig();
      if (mounted) _syncFromConfig();
    });
  }

  @override
  void dispose() {
    _timeoutCtrl.dispose();
    _toolCtrl.dispose();
    super.dispose();
  }

  void _syncFromConfig() {
    if (_toolsDirty || _timeoutDirty) return;
    final experimental = _settings.experimental ?? {};
    final timeout = experimental['mcp_timeout'];
    _timeoutCtrl.text = timeout == null ? '' : timeout.toString();
    final tools = experimental['primary_tools'];
    setState(() {
      _primaryTools = tools is List
          ? tools.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : <String>[];
    });
  }

  Future<void> _toggle(String key, bool value) async {
    final ok = await _settings.setExperimental({key: value});
    if (!mounted) return;
    if (!ok) {
      Snack.error(LocaleKeys.saveFailed.tr);
    }
  }

  Future<void> _saveTimeout() async {
    final raw = _timeoutCtrl.text.trim();
    final value = raw.isEmpty ? null : int.tryParse(raw);
    if (raw.isNotEmpty && value == null) {
      Snack.error(LocaleKeys.mobileMcpTimeoutInvalid.tr);
      return;
    }
    final ok = await _settings.setExperimental({'mcp_timeout': value});
    if (!mounted) return;
    if (ok) {
      setState(() => _timeoutDirty = false);
      Snack.success(LocaleKeys.save.tr);
    } else {
      Snack.error(LocaleKeys.saveFailed.tr);
    }
  }

  Future<void> _savePrimaryTools() async {
    final ok = await _settings.setExperimental({
      'primary_tools': List<String>.from(_primaryTools),
    });
    if (!mounted) return;
    if (ok) {
      setState(() => _toolsDirty = false);
      Snack.success(LocaleKeys.save.tr);
    } else {
      Snack.error(LocaleKeys.saveFailed.tr);
    }
  }

  void _addTool() {
    final value = _toolCtrl.text.trim();
    if (value.isEmpty) return;
    setState(() {
      if (!_primaryTools.contains(value)) {
        _primaryTools.add(value);
        _toolsDirty = true;
      }
    });
    _toolCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.tabExperimental.tr,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // 有未保存编辑时不刷新覆盖，避免静默丢弃用户输入。
              if (_toolsDirty || _timeoutDirty) {
                Snack.warning(LocaleKeys.edUnsavedChanges.tr);
                return;
              }
              await _settings.fetchGlobalConfig();
              if (mounted) _syncFromConfig();
            },
          ),
        ],
      ),
      body: Obx(() {
        _settings.globalConfig.value;
        final experimental = _settings.experimental ?? {};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionHeader(title: LocaleKeys.experimental.tr),
            SettingsCard(
              children: [
                SettingsRow(
                  title: LocaleKeys.batchTool.tr,
                  desc: LocaleKeys.mobileBatchToolDesc.tr,
                  child: Switch(
                    value: experimental['batch_tool'] == true,
                    onChanged: (v) => _toggle('batch_tool', v),
                  ),
                ),
                SettingsRow(
                  title: LocaleKeys.disablePasteSummary.tr,
                  desc: LocaleKeys.mobileDisablePasteDesc.tr,
                  child: Switch(
                    value: experimental['disable_paste_summary'] == true,
                    onChanged: (v) => _toggle('disable_paste_summary', v),
                  ),
                ),
                SettingsRow(
                  title: LocaleKeys.continueLoopOnDeny.tr,
                  desc: LocaleKeys.mobileContinueLoopDesc.tr,
                  child: Switch(
                    value: experimental['continue_loop_on_deny'] == true,
                    onChanged: (v) => _toggle('continue_loop_on_deny', v),
                  ),
                ),
                SettingsRow(
                  title: LocaleKeys.openTelemetry.tr,
                  desc: LocaleKeys.mobileOtelDesc.tr,
                  child: Switch(
                    value: experimental['openTelemetry'] == true,
                    onChanged: (v) => _toggle('openTelemetry', v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionHeader(title: LocaleKeys.mcpTimeout.tr),
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        LocaleKeys.mcpTimeout.tr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _timeoutCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          hintText: LocaleKeys.mobileMcpTimeoutHint.tr,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() => _timeoutDirty = true),
                      ),
                      if (_timeoutDirty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _saveTimeout,
                            child: Text(LocaleKeys.save.tr),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionHeader(title: LocaleKeys.primaryTools.tr),
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        LocaleKeys.primaryTools.tr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LocaleKeys.mobilePrimaryToolsHint.tr,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _toolCtrl,
                              decoration: InputDecoration(
                                hintText: LocaleKeys.mobileToolNameHint.tr,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              onSubmitted: (_) => _addTool(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.add),
                            onPressed: _addTool,
                          ),
                        ],
                      ),
                      if (_primaryTools.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tool in _primaryTools)
                                InputChip(
                                  label: Text(
                                    tool,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onDeleted: () {
                                    setState(() {
                                      _primaryTools.remove(tool);
                                      _toolsDirty = true;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      if (_toolsDirty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _savePrimaryTools,
                            child: Text(LocaleKeys.save.tr),
                          ),
                        ),
                    ],
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
