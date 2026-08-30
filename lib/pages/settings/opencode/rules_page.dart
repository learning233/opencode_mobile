import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/settings_controller.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../../../widgets/settings/settings.dart';

class OpencodeRulesPage extends StatefulWidget {
  const OpencodeRulesPage({super.key});

  @override
  State<OpencodeRulesPage> createState() => _OpencodeRulesPageState();
}

class _OpencodeRulesPageState extends State<OpencodeRulesPage> {
  final _globalCtrl = TextEditingController();
  Worker? _globalRulesWorker;

  SettingsController get _settings => Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    _globalRulesWorker = ever(
      _settings.globalRulesContent,
      (_) => _syncGlobalField(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        _settings.fetchGlobalConfig(),
        _settings.fetchGlobalRules(),
      ]);
      if (mounted) _syncGlobalField();
    });
  }

  @override
  void dispose() {
    _globalRulesWorker?.dispose();
    _globalCtrl.dispose();
    super.dispose();
  }

  void _syncGlobalField() {
    _globalCtrl.text = _settings.globalRulesContent.value;
  }

  Future<void> _reloadGlobalRules() async {
    await _settings.fetchGlobalRules();
    if (!mounted) return;
    setState(() {
      _globalCtrl.text = _settings.globalRulesContent.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.tabRules.tr,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Obx(() {
        final loading = _settings.isLoadingGlobalRules.value;
        final error = _settings.globalRulesError.value;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (error.isNotEmpty && !loading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SettingsCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        error,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SectionHeader(title: LocaleKeys.globalAgentsMd.tr),
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocaleKeys.globalAgentsDesc.tr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _settings.globalAgentsPath.value,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                LocaleKeys.globalAgentsReadOnlyBanner.tr,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (loading && _globalCtrl.text.isEmpty)
                        const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        SizedBox(
                          height: 200,
                          child: TextField(
                            controller: _globalCtrl,
                            readOnly: true,
                            maxLines: null,
                            expands: true,
                            enableInteractiveSelection: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                            decoration: InputDecoration(
                              hintText: LocaleKeys.enterGlobalRules.tr,
                              contentPadding: const EdgeInsets.all(10),
                              filled: true,
                              fillColor: theme
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _StatusBadge(
                            active: _settings.hasGlobalRules.value,
                            activeLabel: LocaleKeys.active.tr,
                            inactiveLabel: LocaleKeys.notSet.tr,
                          ),
                          const SizedBox(width: 12),
                          TextButton.icon(
                            onPressed: loading ? null : _reloadGlobalRules,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: Text(LocaleKeys.reload.tr),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionHeader(title: LocaleKeys.instructions.tr),
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocaleKeys.instructionsDesc.tr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._settings.instructionPaths.map(
                        (p) => _InstructionPathRow(
                          path: p,
                          onRemove: () async {
                            final paths = List<String>.from(
                              _settings.instructionPaths,
                            )..remove(p);
                            final ok = await _settings.setInstructionPaths(
                              paths,
                            );
                            if (!ok && mounted) {
                              Snack.error(LocaleKeys.save.tr);
                            }
                          },
                        ),
                      ),
                      if (_settings.instructionPaths.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            LocaleKeys.noCustomInstructions.tr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      _AddInstructionPath(
                        onAdd: (path) async {
                          final current = List<String>.from(
                            _settings.instructionPaths,
                          );
                          if (current.contains(path)) return;
                          current.add(path);
                          final ok = await _settings.setInstructionPaths(
                            current,
                          );
                          if (!ok && mounted) {
                            Snack.error(LocaleKeys.save.tr);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionHeader(title: LocaleKeys.rulesClaudeCompatTitle.tr),
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocaleKeys.rulesClaudeCompatDesc.tr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LocaleKeys.rulesClaudeCompatEnv.tr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
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

class _StatusBadge extends StatelessWidget {
  final bool active;
  final String activeLabel;
  final String inactiveLabel;

  const _StatusBadge({
    required this.active,
    required this.activeLabel,
    required this.inactiveLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withValues(alpha: 0.1)
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        active ? activeLabel : inactiveLabel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: active ? Colors.green : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _InstructionPathRow extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;

  const _InstructionPathRow({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              path,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.cancel_outlined,
              size: 18,
              color: theme.colorScheme.error,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AddInstructionPath extends StatefulWidget {
  final ValueChanged<String> onAdd;

  const _AddInstructionPath({required this.onAdd});

  @override
  State<_AddInstructionPath> createState() => _AddInstructionPathState();
}

class _AddInstructionPathState extends State<_AddInstructionPath> {
  final _ctrl = TextEditingController();
  bool _showInput = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _ctrl.text.trim();
    if (trimmed.isNotEmpty) {
      widget.onAdd(trimmed);
      _ctrl.clear();
    }
    setState(() => _showInput = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_showInput) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _showInput = true),
        icon: const Icon(CupertinoIcons.add, size: 16),
        label: Text(
          LocaleKeys.rulesAddInstructionPath.tr,
          style: const TextStyle(fontSize: 12),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              hintText: LocaleKeys.rulesInstructionPathPlaceholder.tr,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            Icons.cancel_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: () => setState(() => _showInput = false),
        ),
      ],
    );
  }
}
