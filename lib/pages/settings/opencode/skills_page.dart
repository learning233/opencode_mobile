import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:get/get.dart';

import '../../../controllers/settings_controller.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../../../widgets/settings/settings.dart';

class OpencodeSkillsPage extends StatefulWidget {
  const OpencodeSkillsPage({super.key});

  @override
  State<OpencodeSkillsPage> createState() => _OpencodeSkillsPageState();
}

class _OpencodeSkillsPageState extends State<OpencodeSkillsPage> {
  final _pathCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _paths = <String>[];
  final _urls = <String>[];
  bool _dirty = false;

  SettingsController get _settings => Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        _settings.fetchSkills(),
        _settings.fetchGlobalConfig(),
      ]);
      if (mounted) _syncSourcesFromConfig();
    });
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _syncSourcesFromConfig() {
    if (_dirty) return;
    setState(() {
      _paths
        ..clear()
        ..addAll(_settings.skillsPaths);
      _urls
        ..clear()
        ..addAll(_settings.skillsUrls);
    });
  }

  void _addPath() {
    final value = _pathCtrl.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _paths.add(value);
      _dirty = true;
    });
    _pathCtrl.clear();
  }

  void _addUrl() {
    final value = _urlCtrl.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _urls.add(value);
      _dirty = true;
    });
    _urlCtrl.clear();
  }

  void _removePath(int index) {
    setState(() {
      _paths.removeAt(index);
      _dirty = true;
    });
  }

  void _removeUrl(int index) {
    setState(() {
      _urls.removeAt(index);
      _dirty = true;
    });
  }

  void _resetSources() {
    setState(() {
      _dirty = false;
    });
    _syncSourcesFromConfig();
  }

  Future<void> _saveSources() async {
    try {
      await _settings.setSkillsConfig({
        'paths': List<String>.from(_paths),
        'urls': List<String>.from(_urls),
      });
      if (mounted) {
        setState(() => _dirty = false);
        Snack.success(LocaleKeys.skillsSaveSources.tr);
        await _settings.fetchSkills();
      }
    } catch (e) {
      if (mounted) {
        Snack.error('${LocaleKeys.skillSaveFailed.tr}: $e');
      }
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_settings.fetchSkills(), _settings.fetchGlobalConfig()]);
    if (mounted) _syncSourcesFromConfig();
  }

  void _showSkillDetail(Map<String, dynamic> skill) {
    final name = skill['name']?.toString() ?? '';
    final desc = skill['description']?.toString() ?? '';
    final location = skill['location']?.toString() ?? '';
    final content =
        skill['content']?.toString() ??
        skill['body']?.toString() ??
        skill['prompt']?.toString() ??
        '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final height = MediaQuery.sizeOf(ctx).height * 0.75;
        return SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(desc, style: const TextStyle(fontSize: 13)),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    location,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: content.isEmpty
                      ? Center(
                          child: Text(
                            'No content preview available.',
                            style: TextStyle(
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Markdown(data: content, selectable: true),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.tabSkills.tr,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(title: LocaleKeys.tabSkills.tr),
          SettingsCard(
            children: [
              _SourceInputRow(
                title: LocaleKeys.skillsAdditionalPaths.tr,
                tooltip: LocaleKeys.skillsPathsTooltip.tr,
                icon: Icons.folder_outlined,
                controller: _pathCtrl,
                placeholder: './team-skills',
                items: _paths,
                onAdd: _addPath,
                onRemove: _removePath,
              ),
              _SourceInputRow(
                title: LocaleKeys.skillsRemoteUrls.tr,
                icon: Icons.language_outlined,
                controller: _urlCtrl,
                placeholder: 'https://example.com/skills/',
                items: _urls,
                onAdd: _addUrl,
                onRemove: _removeUrl,
              ),
            ],
          ),
          if (_dirty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _resetSources,
                    child: Text(LocaleKeys.edReset.tr),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saveSources,
                    child: Text(LocaleKeys.skillsSaveSources.tr),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SectionHeader(title: LocaleKeys.skillsLoadedSkills.tr),
          Obx(() {
            final loading = _settings.skillsLoading.value;
            final skillList = _settings.skills.toList();
            final error = _settings.skillsError.value;

            if (loading && skillList.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (skillList.isEmpty) {
              return SettingsCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      error.isNotEmpty
                          ? '${LocaleKeys.skillsFailedLoad.tr}: $error'
                          : LocaleKeys.skillsNoLoaded.tr,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SettingsCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '${LocaleKeys.skillsFailedLoad.tr}: $error',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                SettingsCard(
                  children: skillList
                      .map(
                        (skill) => _SkillTile(
                          skill: skill,
                          onTap: () => _showSkillDetail(skill),
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _SourceInputRow extends StatelessWidget {
  final String title;
  final String? tooltip;
  final IconData icon;
  final TextEditingController controller;
  final String placeholder;
  final List<String> items;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _SourceInputRow({
    required this.title,
    this.tooltip,
    required this.icon,
    required this.controller,
    required this.placeholder,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleWidget = Text(
      title,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: tooltip != null
                    ? Tooltip(message: tooltip, child: titleWidget)
                    : titleWidget,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: placeholder,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(CupertinoIcons.add, size: 20),
                tooltip: LocaleKeys.add.tr,
                onPressed: onAdd,
              ),
            ],
          ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: items.indexed.map((entry) {
                  final index = entry.$1;
                  final item = entry.$2;
                  return InputChip(
                    label: Text(
                      item,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: () => onRemove(index),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  final Map<String, dynamic> skill;
  final VoidCallback onTap;

  const _SkillTile({required this.skill, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = skill['name']?.toString() ?? '';
    final desc = skill['description']?.toString() ?? '';
    final location = skill['location']?.toString() ?? '';
    final isBuiltIn = location == '<built-in>' || location.isEmpty;

    return ListTile(
      dense: true,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isBuiltIn ? Colors.orange : theme.colorScheme.primary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isBuiltIn ? 'BUILT-IN' : 'LOCAL',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isBuiltIn ? Colors.orange : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (!isBuiltIn && location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                location,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
    );
  }
}
