import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../init.dart';
import '../../../models/cloud_workspace_config.dart';
import '../../../services/git_repo_service.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import 'git_repo_picker_sheet.dart';

class CloudWorkspaceSheet extends StatefulWidget {
  const CloudWorkspaceSheet({
    super.key,
    required this.initialConfig,
    required this.onSave,
    this.onLaunch,
    this.onlyConfig = false,
  });

  final CloudWorkspaceConfig initialConfig;
  final FutureOr<void> Function(CloudWorkspaceConfig config) onSave;
  final void Function(CloudWorkspaceConfig config)? onLaunch;
  final bool onlyConfig;

  static Future<bool?> show(
    BuildContext context, {
    bool onlyConfig = false,
    void Function(CloudWorkspaceConfig config)? onLaunch,
  }) {
    final current = Global.settings.cloudWorkspaceConfig;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => CloudWorkspaceSheet(
        initialConfig: current,
        onlyConfig: onlyConfig,
        onSave: (cfg) async {
          await Global.settings.setCloudWorkspaceConfig(cfg);
        },
        onLaunch: onLaunch,
      ),
    );
  }

  @override
  State<CloudWorkspaceSheet> createState() => _CloudWorkspaceSheetState();
}

class _CloudWorkspaceSheetState extends State<CloudWorkspaceSheet> {
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _templateCtrl;
  late TextEditingController _repoCtrl;
  late TextEditingController _repoFullNameCtrl;
  late TextEditingController _tokenCtrl;

  String _branch = 'main';
  String _gitUsername = '';
  String _gitEmail = '';

  late Set<String> _selectedToolchains;
  late int _ttlHours;
  late bool _autoPause;
  bool _isFetchingRepos = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.initialConfig;
    _apiKeyCtrl = TextEditingController(text: cfg.e2bApiKey);
    _templateCtrl = TextEditingController(text: cfg.templateId);
    _repoCtrl = TextEditingController(text: cfg.gitRepoUrl);
    _repoFullNameCtrl = TextEditingController(text: cfg.gitRepoFullName);
    _tokenCtrl = TextEditingController(text: cfg.gitToken);

    _branch = cfg.gitBranch.isEmpty ? 'main' : cfg.gitBranch;
    _gitUsername = cfg.gitUsername;
    _gitEmail = cfg.gitEmail;

    _selectedToolchains = Set<String>.from(cfg.toolchains);
    _ttlHours = cfg.ttlHours;
    _autoPause = cfg.autoPause;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _templateCtrl.dispose();
    _repoCtrl.dispose();
    _repoFullNameCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  CloudWorkspaceConfig _buildConfig() {
    return widget.initialConfig.copyWith(
      e2bApiKey: _apiKeyCtrl.text.trim(),
      templateId: _templateCtrl.text.trim().isEmpty
          ? 'opencode'
          : _templateCtrl.text.trim(),
      toolchains: _selectedToolchains.toList(),
      gitProvider: 'github',
      gitRepoUrl: _repoCtrl.text.trim(),
      gitRepoFullName: _repoFullNameCtrl.text.trim(),
      gitBranch: _branch,
      gitToken: _tokenCtrl.text.trim(),
      gitUsername: _gitUsername,
      gitEmail: _gitEmail,
      ttlHours: _ttlHours,
      autoPause: _autoPause,
    );
  }

  Future<void> _saveOnly() async {
    final cfg = _buildConfig();
    await widget.onSave(cfg);
    if (mounted) {
      Snack.success(LocaleKeys.save.tr);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _saveAndLaunch() async {
    final cfg = _buildConfig();
    if (cfg.e2bApiKey.isEmpty) {
      Snack.error(LocaleKeys.e2bApiKeyHint.tr);
      return;
    }
    await widget.onSave(cfg);
    if (mounted) {
      Navigator.of(context).pop(true);
      widget.onLaunch?.call(cfg);
    }
  }

  Future<void> _fetchAndSelectRepo() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      Snack.error(LocaleKeys.e2bGitTokenRequiredForRepos.tr);
      return;
    }

    setState(() => _isFetchingRepos = true);
    try {
      // 1. 静默获取 GitHub 用户信息（用于提交记录归属）
      if (_gitUsername.isEmpty || _gitEmail.isEmpty) {
        final userInfo = await GitRepoService.instance.fetchUserInfo(token);
        if (userInfo != null) {
          if (_gitUsername.isEmpty && userInfo.name.isNotEmpty) {
            _gitUsername = userInfo.name;
          }
          if (_gitEmail.isEmpty && userInfo.email.isNotEmpty) {
            _gitEmail = userInfo.email;
          }
        }
      }

      if (!mounted) return;

      // 2. 弹出 GitHub 仓库选择列表
      final selected = await GitRepoPickerSheet.show(context, token: token);

      if (selected != null && mounted) {
        setState(() {
          _repoCtrl.text = selected.cloneUrl;
          _repoFullNameCtrl.text = selected.fullName;
          _branch = selected.defaultBranch.isEmpty
              ? 'main'
              : selected.defaultBranch;
        });
        Snack.success(
          LocaleKeys.e2bRepoSelected.trParams({'repo': selected.fullName}),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingRepos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.cloud_queue, size: 20),
            const SizedBox(width: 8),
            Text(
              LocaleKeys.e2bTitle.tr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: _saveOnly, child: Text(LocaleKeys.save.tr)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 简述卡片
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LocaleKeys.e2bDesc.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. E2B 核心凭据
          _buildSectionHeader(Icons.vpn_key, LocaleKeys.e2bApiKey.tr, theme),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyCtrl,
            keyboardType: TextInputType.text,
            enableSuggestions: true,
            autocorrect: false,
            obscureText: true,
            decoration: InputDecoration(
              labelText: LocaleKeys.e2bApiKey.tr,
              hintText: LocaleKeys.e2bApiKeyHint.tr,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.key),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _templateCtrl,
            keyboardType: TextInputType.text,
            enableSuggestions: true,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: LocaleKeys.e2bTemplate.tr,
              hintText: LocaleKeys.e2bTemplateHint.tr,
              helperText: LocaleKeys.e2bTemplateHelper.tr,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.layers_outlined),
            ),
          ),
          const SizedBox(height: 20),

          // 2. 工具链选配
          _buildSectionHeader(
            Icons.construction,
            LocaleKeys.e2bToolchains.tr,
            theme,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildToolchainChip(
                id: 'dart',
                label: LocaleKeys.e2bToolchainDart.tr,
                theme: theme,
              ),
              _buildToolchainChip(
                id: 'rust',
                label: LocaleKeys.e2bToolchainRust.tr,
                theme: theme,
              ),
              _buildToolchainChip(
                id: 'c_cpp',
                label: LocaleKeys.e2bToolchainCpp.tr,
                theme: theme,
              ),
              _buildToolchainChip(
                id: 'python',
                label: LocaleKeys.e2bToolchainPython.tr,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. GitHub 仓库绑定与授权选择
          _buildSectionHeader(
            Icons.merge_type,
            LocaleKeys.e2bGitProjectAndAuth.tr,
            theme,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenCtrl,
            keyboardType: TextInputType.text,
            enableSuggestions: true,
            autocorrect: false,
            obscureText: true,
            decoration: InputDecoration(
              labelText: LocaleKeys.e2bGitPatLabel.tr,
              hintText: LocaleKeys.e2bGitPatHint.tr,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.token),
            ),
          ),
          const SizedBox(height: 10),
          // 获取并选择项目按钮
          FilledButton.tonalIcon(
            onPressed: _isFetchingRepos ? null : _fetchAndSelectRepo,
            icon: _isFetchingRepos
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.account_tree),
            label: Text(
              _isFetchingRepos
                  ? LocaleKeys.e2bFetchingRepos.tr
                  : LocaleKeys.e2bFetchAndSelectRepo.tr,
            ),
          ),
          const SizedBox(height: 10),
          if (_repoFullNameCtrl.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      LocaleKeys.e2bSelectedRepoWithBranch.trParams({
                        'repo': _repoFullNameCtrl.text,
                        'branch': _branch,
                      }),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        _repoCtrl.clear();
                        _repoFullNameCtrl.clear();
                        _branch = 'main';
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            TextField(
              controller: _repoCtrl,
              decoration: InputDecoration(
                labelText: LocaleKeys.e2bGitRepo.tr,
                hintText: LocaleKeys.e2bGitRepoUrlOptionalHint.tr,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),

          // 4. 云端保活与长任务配置
          _buildSectionHeader(
            Icons.timer_outlined,
            LocaleKeys.e2bTtlHours.tr,
            theme,
          ),
          const SizedBox(height: 4),
          Text(
            LocaleKeys.e2bTtlDesc.tr,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 1, label: Text('1h')),
              ButtonSegment(value: 2, label: Text('2h')),
              ButtonSegment(value: 4, label: Text('4h')),
              ButtonSegment(value: 8, label: Text('8h')),
              ButtonSegment(value: 24, label: Text('24h')),
            ],
            selected: {_ttlHours},
            onSelectionChanged: (vals) {
              if (vals.isNotEmpty) setState(() => _ttlHours = vals.first);
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _autoPause,
            onChanged: (val) => setState(() => _autoPause = val),
            title: Text(
              LocaleKeys.e2bAutoPause.tr,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              LocaleKeys.e2bAutoPauseDesc.tr,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 底部操作按钮
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: widget.onlyConfig ? _saveOnly : _saveAndLaunch,
            icon: Icon(widget.onlyConfig ? Icons.save : Icons.rocket_launch),
            label: Text(
              widget.onlyConfig
                  ? LocaleKeys.save.tr
                  : LocaleKeys.e2bLaunchWorkspace.tr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildToolchainChip({
    required String id,
    required String label,
    required ThemeData theme,
  }) {
    final isSelected = _selectedToolchains.contains(id);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedToolchains.add(id);
          } else {
            _selectedToolchains.remove(id);
          }
        });
      },
    );
  }
}
