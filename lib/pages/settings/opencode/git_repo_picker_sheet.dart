import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/git_repo_service.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';

class GitRepoPickerSheet extends StatefulWidget {
  const GitRepoPickerSheet({super.key, required this.token});

  final String token;

  static Future<GitRepoItem?> show(
    BuildContext context, {
    required String token,
  }) {
    return showModalBottomSheet<GitRepoItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => GitRepoPickerSheet(token: token),
    );
  }

  @override
  State<GitRepoPickerSheet> createState() => _GitRepoPickerSheetState();
}

class _GitRepoPickerSheetState extends State<GitRepoPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<GitRepoItem> _allRepos = [];
  List<GitRepoItem> _filteredRepos = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRepos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repos = await GitRepoService.instance.fetchRepositories(
        widget.token,
      );
      if (mounted) {
        setState(() {
          _allRepos = repos;
          _filteredRepos = repos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = LocaleKeys.e2bFetchReposFailed.trParams({
            'error': e.toString(),
          });
        });
        Snack.error(LocaleKeys.e2bFetchReposTokenError.tr);
      }
    }
  }

  void _filterRepos(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredRepos = _allRepos;
      } else {
        _filteredRepos = _allRepos.where((r) {
          return r.fullName.toLowerCase().contains(q) ||
              r.name.toLowerCase().contains(q) ||
              r.description.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
                  Icon(Icons.folder_open, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    LocaleKeys.e2bSelectGitHubRepo.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadRepos,
                  ),
                ],
              ),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _filterRepos,
                decoration: InputDecoration(
                  hintText: LocaleKeys.e2bSearchRepos.tr,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _filterRepos('');
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
                          Text(LocaleKeys.e2bFetchingRepoList.tr),
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
                              onPressed: _loadRepos,
                              child: Text(LocaleKeys.retry.tr),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _filteredRepos.isEmpty
                  ? Center(
                      child: Text(
                        LocaleKeys.e2bNoReposFound.tr,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: _filteredRepos.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (ctx, index) {
                        final repo = _filteredRepos[index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: repo.isPrivate
                                ? theme.colorScheme.tertiaryContainer
                                : theme.colorScheme.primaryContainer,
                            child: Icon(
                              repo.isPrivate
                                  ? Icons.lock_outline
                                  : Icons.public,
                              size: 18,
                              color: repo.isPrivate
                                  ? theme.colorScheme.onTertiaryContainer
                                  : theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  repo.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  repo.defaultBranch,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: repo.description.isNotEmpty
                              ? Text(
                                  repo.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.of(context).pop(repo);
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
