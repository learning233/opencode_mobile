import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../init.dart';
import '../../models/quick_phrase.dart';
import '../../utils/translations.dart';

class QuickPhrasesPage extends StatefulWidget {
  const QuickPhrasesPage({super.key});

  @override
  State<QuickPhrasesPage> createState() => _QuickPhrasesPageState();
}

class _QuickPhrasesPageState extends State<QuickPhrasesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = Get.find<SettingsController>();
      if (s.commands.isEmpty) s.fetchCommands();
    });
  }

  String _modelDisplayName(String key) {
    if (key.isEmpty) return 'Default';
    final m = Get.find<SessionController>().availableModels.firstWhereOrNull(
      (m) => m.key == key,
    );
    return m?.name ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.csQuickPhrases.tr,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.add, size: 20),
            onPressed: () => _showAddSheet(context),
          ),
        ],
      ),
      body: Obx(() {
        final userItems = Global.quickPhrasesRx;

        if (userItems.isEmpty) {
          return Center(
            child: Text(
              LocaleKeys.csNoQuickPhrases.tr,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: userItems.length,
          itemBuilder: (_, i) {
            final p = userItems[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  p.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.colorScheme.secondary),
                ),
                subtitle: Text(
                  p.template,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _showAddSheet(context, editItem: p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _deleteItem(p),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Future<void> _deleteItem(QuickPhraseItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.quickPhrasesDeleteTitle.tr),
        content: Text(
          LocaleKeys.quickPhrasesDeleteConfirm.trParams({
            'name': item.name.isNotEmpty ? item.name : item.template,
          }),
        ),
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
    if (confirm != true) return;

    final next = [...Global.quickPhrasesRx];
    // Match by object identity, not name: legacy raw-string items share the
    // empty name '', so name matching would delete every empty-named item.
    next.removeWhere((x) => identical(x, item));
    await Global.saveQuickPhrases(next);
  }

  Future<void> _showAddSheet(
    BuildContext context, {
    QuickPhraseItem? editItem,
  }) async {
    final allModels = Get.find<SessionController>().availableModels;
    final modelIds = ['', ...allModels.map((m) => m.key)];
    final result = await showModalBottomSheet<QuickPhraseItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PhraseSheet(
        editItem: editItem,
        modelIds: modelIds,
        modelDisplay: _modelDisplayName,
      ),
    );
    if (result == null) return;

    if (editItem != null) {
      final next = [...Global.quickPhrasesRx];
      final idx = next.indexWhere((x) => identical(x, editItem));
      if (idx >= 0) {
        next[idx] = result;
      } else {
        next.add(result);
      }
      await Global.saveQuickPhrases(next);
    } else {
      await Global.saveQuickPhrases([...Global.quickPhrasesRx, result]);
    }
  }
}

class _PhraseSheet extends StatefulWidget {
  final QuickPhraseItem? editItem;
  final List<String> modelIds;
  final String Function(String) modelDisplay;

  const _PhraseSheet({
    this.editItem,
    required this.modelIds,
    required this.modelDisplay,
  });

  @override
  State<_PhraseSheet> createState() => _PhraseSheetState();
}

class _PhraseSheetState extends State<_PhraseSheet> {
  late final TextEditingController _templateCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _nameCtrl;
  late String _agent;
  late String _modelId;
  String? _nameErrorText;
  String? _templateErrorText;

  @override
  void initState() {
    super.initState();
    _templateCtrl = TextEditingController(
      text: widget.editItem?.template ?? '',
    );
    _descCtrl = TextEditingController(text: widget.editItem?.description ?? '');
    _nameCtrl = TextEditingController(text: widget.editItem?.name ?? '');
    final rawAgent = widget.editItem?.agent ?? '';
    _agent = (rawAgent == 'build' || rawAgent == 'plan') ? rawAgent : 'build';
    _modelId = widget.editItem?.model ?? '';

    _templateCtrl.addListener(() {
      if (_templateErrorText != null && _templateCtrl.text.trim().isNotEmpty) {
        setState(() => _templateErrorText = null);
      }
    });
    _nameCtrl.addListener(() {
      if (_nameErrorText != null && _nameCtrl.text.trim().isNotEmpty) {
        setState(() => _nameErrorText = null);
      }
    });
  }

  @override
  void dispose() {
    _templateCtrl.dispose();
    _descCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    readOnly: widget.editItem != null,
                    decoration: InputDecoration(
                      labelText: 'Name *',
                      errorText: _nameErrorText,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                      fillColor: widget.editItem != null
                          ? theme.colorScheme.surfaceContainerHighest
                          : null,
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _templateCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Template *',
                      errorText: _templateErrorText,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          'Agent',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: 'build',
                              label: Text(
                                'build',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            ButtonSegment(
                              value: 'plan',
                              label: Text(
                                'plan',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                          selected: {_agent},
                          onSelectionChanged: (sel) =>
                              setState(() => _agent = sel.first),
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          'Model',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: widget.modelIds.contains(_modelId)
                              ? _modelId
                              : null,
                          isDense: true,
                          items: widget.modelIds.map((id) {
                            return DropdownMenuItem(
                              value: id,
                              child: Text(
                                widget.modelDisplay(id),
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _modelId = v ?? ''),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                onPressed: () {
                  final template = _templateCtrl.text.trim();
                  final name = _nameCtrl.text.trim();
                  String? nameErr;
                  String? templateErr;

                  if (name.isEmpty) {
                    nameErr = LocaleKeys.quickPhrasesEnterName.tr;
                  } else {
                    final inLocal = Global.quickPhrasesRx.any(
                      (x) => x.name == name && x != widget.editItem,
                    );
                    final inSystem = Get.find<SettingsController>()
                        .commandPhrases
                        .any((x) => x.name == name);
                    if (inLocal || inSystem) {
                      nameErr = LocaleKeys.quickPhrasesNameExists.tr;
                    }
                  }

                  if (template.isEmpty) {
                    templateErr = LocaleKeys.quickPhrasesEnterTemplate.tr;
                  }

                  if (nameErr != null || templateErr != null) {
                    setState(() {
                      _nameErrorText = nameErr;
                      _templateErrorText = templateErr;
                    });
                    return;
                  }

                  Navigator.pop(
                    context,
                    QuickPhraseItem(
                      name: name,
                      template: template,
                      description: _descCtrl.text.trim(),
                      agent: _agent,
                      model: _modelId,
                    ),
                  );
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
