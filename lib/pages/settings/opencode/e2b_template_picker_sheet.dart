import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../models/e2b_template_info.dart';
import '../../../services/e2b_workspace_service.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';

/// E2B 沙盒模板选择 BottomSheet
class E2bTemplatePickerSheet extends StatefulWidget {
  const E2bTemplatePickerSheet({super.key, required this.apiKey});

  final String apiKey;

  static Future<E2bTemplateInfo?> show(
    BuildContext context, {
    required String apiKey,
  }) {
    return showModalBottomSheet<E2bTemplateInfo>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => E2bTemplatePickerSheet(apiKey: apiKey),
    );
  }

  @override
  State<E2bTemplatePickerSheet> createState() => _E2bTemplatePickerSheetState();
}

class _E2bTemplatePickerSheetState extends State<E2bTemplatePickerSheet> {
  final _searchCtrl = TextEditingController();
  List<E2bTemplateInfo> _allTemplates = [];
  List<E2bTemplateInfo> _filteredTemplates = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final templates = await E2bWorkspaceService.instance.fetchTemplates(
        widget.apiKey,
      );

      // 确保列表包含官方推荐的 opencode 与 base 默认模板
      final list = List<E2bTemplateInfo>.from(templates);
      if (!list.any((t) => t.templateId == 'opencode' || t.displayName == 'opencode')) {
        list.insert(
          0,
          const E2bTemplateInfo(
            templateId: 'opencode',
            aliases: ['opencode'],
            cpuCount: 2,
            memoryMB: 4096,
            isPublic: true,
            buildStatus: 'ready',
          ),
        );
      }
      if (!list.any((t) => t.templateId == 'base' || t.displayName == 'base')) {
        list.add(
          const E2bTemplateInfo(
            templateId: 'base',
            aliases: ['base'],
            cpuCount: 2,
            memoryMB: 2048,
            isPublic: true,
            buildStatus: 'ready',
          ),
        );
      }

      if (mounted) {
        setState(() {
          _allTemplates = list;
          _filteredTemplates = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = LocaleKeys.e2bFetchTemplatesFailed.trParams({
            'error': e.toString(),
          });
        });
        Snack.error(LocaleKeys.e2bFetchTemplatesFailed.trParams({
          'error': e.toString(),
        }));
      }
    }
  }

  void _filterTemplates(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredTemplates = _allTemplates;
      } else {
        _filteredTemplates = _allTemplates.where((t) {
          return t.displayName.toLowerCase().contains(q) ||
              t.templateId.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // 顶端拖动手柄
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.layers_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    LocaleKeys.e2bSelectTemplate.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadTemplates,
                  ),
                ],
              ),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _filterTemplates,
                decoration: InputDecoration(
                  hintText: LocaleKeys.e2bSearchTemplates.tr,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _filterTemplates('');
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(LocaleKeys.e2bFetchingTemplates.tr),
                        ],
                      ),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 40,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 10),
                            Text(_errorMessage!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: _loadTemplates,
                              child: Text(LocaleKeys.retry.tr),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _filteredTemplates.isEmpty
                  ? Center(
                      child: Text(LocaleKeys.e2bNoTemplatesFound.tr),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: _filteredTemplates.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final t = _filteredTemplates[index];
                        final isOfficial =
                            t.templateId == 'opencode' || t.templateId == 'base';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isOfficial
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.secondaryContainer,
                            child: Icon(
                              isOfficial
                                  ? Icons.verified
                                  : Icons.memory,
                              size: 20,
                              color: isOfficial
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.secondary,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOfficial)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    LocaleKeys.e2bOfficialTemplate.tr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    LocaleKeys.e2bCustomTemplate.tr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (t.templateId != t.displayName)
                                Text(
                                  'ID: ${t.templateId}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.developer_board,
                                    size: 14,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${t.cpuCount} vCPU / ${t.memoryMB} MB RAM',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).pop(t);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
