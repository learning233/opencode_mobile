import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/settings_controller.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../../../widgets/settings/settings.dart';

class OpencodePermissionsPage extends StatefulWidget {
  const OpencodePermissionsPage({super.key});

  @override
  State<OpencodePermissionsPage> createState() =>
      _OpencodePermissionsPageState();
}

IconData _permissionIcon(String tool) {
  switch (tool) {
    case 'read':
      return CupertinoIcons.doc_text;
    case 'edit':
      return CupertinoIcons.pencil;
    case 'bash':
      return Icons.terminal;
    case 'glob':
      return Icons.find_in_page_outlined;
    case 'grep':
      return CupertinoIcons.search;
    case 'list':
      return CupertinoIcons.folder;
    case 'task':
      return CupertinoIcons.flowchart;
    case 'webfetch':
      return CupertinoIcons.globe;
    case 'websearch':
      return CupertinoIcons.compass;
    case 'todowrite':
      return CupertinoIcons.checkmark_square;
    case 'question':
      return CupertinoIcons.question_circle;
    case 'external_directory':
      return CupertinoIcons.folder;
    case 'lsp':
      return CupertinoIcons.chevron_left_slash_chevron_right;
    case 'skill':
      return CupertinoIcons.square_grid_2x2;
    case 'doom_loop':
      return CupertinoIcons.repeat;
    default:
      return CupertinoIcons.wrench;
  }
}

class _OpencodePermissionsPageState extends State<OpencodePermissionsPage> {
  SettingsController get _settings => Get.find<SettingsController>();

  /// Guards concurrent permission PATCHes from rapid taps (each `setPermission`
  /// is a read-modify-write against the same config).
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        _settings.fetchGlobalConfig(),
        _settings.fetchSavedPermissions(),
      ]);
    });
  }

  Future<void> _setAll(String value) async {
    if (_saving) return;
    _saving = true;
    try {
      final updated = <String, dynamic>{};
      for (final t in _settings.knownPermissions) {
        updated[t] = value;
      }
      await _settings.setPermission(updated);
    } catch (e) {
      if (mounted) Snack.error('$e');
    } finally {
      _saving = false;
    }
  }

  Future<void> _setTool(String tool, String value) async {
    if (_saving) return;
    _saving = true;
    try {
      final existing = _settings.permission?[tool];
      if (existing is Map) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(LocaleKeys.tabPermissions.tr),
            content: Text(
              LocaleKeys.permissionsReplaceConfirm.trParams({
                'tool': tool,
                'value': value,
              }),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(LocaleKeys.cancel.tr),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(LocaleKeys.save.tr),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      final updated = Map<String, dynamic>.from(_settings.permission ?? {});
      updated[tool] = value;
      await _settings.setPermission(updated);
    } catch (e) {
      if (mounted) Snack.error('$e');
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.tabPermissions.tr,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await Future.wait([
                _settings.fetchGlobalConfig(),
                _settings.fetchSavedPermissions(),
              ]);
            },
          ),
        ],
      ),
      body: Obx(() {
        _settings.globalConfig.value;
        final perm = _settings.permission ?? {};
        final tools = _settings.knownPermissions;
        final saved = _settings.savedPermissions;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionHeader(title: LocaleKeys.secBulkActions.tr),
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Apply to all tools',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ),
                      _PermChip(
                        label: LocaleKeys.ask.tr,
                        color: Colors.orange,
                        onPressed: () => _setAll('ask'),
                      ),
                      const SizedBox(width: 4),
                      _PermChip(
                        label: LocaleKeys.allow.tr,
                        color: Colors.green,
                        onPressed: () => _setAll('allow'),
                      ),
                      const SizedBox(width: 4),
                      _PermChip(
                        label: LocaleKeys.deny.tr,
                        color: theme.colorScheme.error,
                        onPressed: () => _setAll('deny'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: '${LocaleKeys.toolPermissions.tr} (${tools.length})',
            ),
            SettingsCard(
              children: tools.map((tool) {
                final current = SettingsController.permissionFor(perm, tool);
                final desc = SettingsController.permissionDescription(tool);
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _permissionIcon(tool),
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tool,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              current == SettingsController.permissionCustom
                                  ? 'Path-based rules (custom)'
                                  : desc,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (current == SettingsController.permissionCustom) ...[
                        _PermChip(
                          label: 'Custom',
                          color: theme.colorScheme.tertiary,
                          selected: true,
                          onPressed: () {},
                        ),
                        const SizedBox(width: 4),
                      ],
                      _PermChip(
                        label: LocaleKeys.ask.tr,
                        color: Colors.orange,
                        selected: current == 'ask',
                        onPressed: () => _setTool(tool, 'ask'),
                      ),
                      const SizedBox(width: 4),
                      _PermChip(
                        label: LocaleKeys.allow.tr,
                        color: Colors.green,
                        selected: current == 'allow',
                        onPressed: () => _setTool(tool, 'allow'),
                      ),
                      const SizedBox(width: 4),
                      _PermChip(
                        label: LocaleKeys.deny.tr,
                        color: theme.colorScheme.error,
                        selected: current == 'deny',
                        onPressed: () => _setTool(tool, 'deny'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SectionHeader(title: LocaleKeys.mobileSavedPermissions.tr),
            if (_settings.savedPermissionsLoading.value)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (saved.isEmpty)
              SettingsCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No saved permission rules.',
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
                children: saved.map((item) {
                  final id = item['id']?.toString() ?? '';
                  final title =
                      item['permission']?.toString() ??
                      item['action']?.toString() ??
                      id;
                  final subtitle = [
                    if (item['resource'] != null)
                      item['resource'].toString()
                    else if (item['pattern'] != null)
                      item['pattern'].toString(),
                    if (item['projectID'] != null)
                      'project: ${item['projectID']}',
                  ].where((e) => e.isNotEmpty).join(' · ');
                  return ListTile(
                    dense: true,
                    title: Text(title, style: const TextStyle(fontSize: 13)),
                    subtitle: subtitle.isEmpty
                        ? null
                        : Text(subtitle, style: const TextStyle(fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: id.isEmpty
                          ? null
                          : () async {
                              final ok = await _settings.deleteSavedPermission(
                                id,
                              );
                              if (!ok && mounted) {
                                Snack.error(LocaleKeys.delete.tr);
                              }
                            },
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

class _PermChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  const _PermChip({
    required this.label,
    required this.color,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final grey = Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? color : grey.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? color : grey,
            ),
          ),
        ),
      ),
    );
  }
}
