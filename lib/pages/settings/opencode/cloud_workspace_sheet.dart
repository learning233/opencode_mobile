import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../init.dart';
import '../../../models/cloud_workspace_config.dart';
import '../../../services/git_repo_service.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import 'e2b_template_picker_sheet.dart';
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
    final cfg = Global.settings.cloudWorkspaceConfig;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => CloudWorkspaceSheet(
        initialConfig: cfg,
        onlyConfig: onlyConfig,
        onSave: (newCfg) async {
          await Global.settings.setCloudWorkspaceConfig(newCfg);
        },
        onLaunch: onLaunch,
      ),
    );
  }

  @override
  State<CloudWorkspaceSheet> createState() => _CloudWorkspaceSheetState();
}

class _CloudWorkspaceSheetState extends State<CloudWorkspaceSheet> {

  late TextEditingController _templateCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _repoCtrl;
  late TextEditingController _repoFullNameCtrl;
  late TextEditingController _tokenCtrl;

  String _branch = 'main';
  String _gitUsername = '';
  String _gitEmail = '';

  late int _ttlHours;
  late bool _autoPause;
  bool _isFetchingRepos = false;
  bool _isFetchingTemplates = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.initialConfig;

    _templateCtrl = TextEditingController(text: cfg.templateId);
    _passwordCtrl = TextEditingController(
      text: widget.onlyConfig ? cfg.sandboxPassword : '',
    );
    _repoCtrl = TextEditingController(text: cfg.gitRepoUrl);
    _repoFullNameCtrl = TextEditingController(text: cfg.gitRepoFullName);
    _tokenCtrl = TextEditingController(text: cfg.gitToken);

    _branch = cfg.gitBranch.isEmpty ? 'main' : cfg.gitBranch;
    _gitUsername = cfg.gitUsername;
    _gitEmail = cfg.gitEmail;

    _ttlHours = cfg.ttlHours;
    _autoPause = cfg.autoPause;
  }

  @override
  void dispose() {

    _templateCtrl.dispose();
    _passwordCtrl.dispose();
    _repoCtrl.dispose();
    _repoFullNameCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  CloudWorkspaceConfig _buildConfig() {
    return widget.initialConfig.copyWith(
      templateId: _templateCtrl.text.trim().isEmpty
          ? 'opencode'
          : _templateCtrl.text.trim(),
      sandboxPassword: _passwordCtrl.text.trim(),
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
    if (Global.settings.cloudWorkspaceConfig.e2bApiKey.trim().isEmpty) {
      Snack.error(LocaleKeys.e2bApiKeyEmptyError.tr);
      return;
    }
    final cfg = _buildConfig();
    await widget.onSave(cfg);
    if (mounted) {
      Navigator.of(context).pop(true);
      widget.onLaunch?.call(cfg);
    }
  }

  Future<void> _fetchAndSelectTemplate() async {
    final apiKey = Global.settings.cloudWorkspaceConfig.e2bApiKey.trim();
    if (apiKey.isEmpty) {
      Snack.error(LocaleKeys.e2bApiKeyRequired.tr);
      return;
    }

    setState(() => _isFetchingTemplates = true);
    try {
      final selected = await E2bTemplatePickerSheet.show(
        context,
        apiKey: apiKey,
      );
      if (selected != null && mounted) {
        setState(() {
          _templateCtrl.text = selected.templateId;
        });
      }
    } finally {
      if (mounted) setState(() => _isFetchingTemplates = false);
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

      // picker 关闭后移除焦点,防止 token 输入框自动获焦弹出键盘
      FocusManager.instance.primaryFocus?.unfocus();

      if (selected != null && mounted) {
        setState(() {
          _repoCtrl.text = selected.cloneUrl;
          _repoFullNameCtrl.text = selected.fullName;
          _branch = selected.defaultBranch.isEmpty
              ? 'main'
              : selected.defaultBranch;
        });
      }
    } finally {
      if (mounted) setState(() => _isFetchingRepos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintStyle = TextStyle(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          widget.onlyConfig
              ? LocaleKeys.e2bConfigWorkspace.tr
              : LocaleKeys.e2bNewSandbox.tr,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: _saveOnly, child: Text(LocaleKeys.save.tr)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── 1. 沙盒模板与密码 ──
          _buildSectionHeader(
            Icons.cloud_outlined,
            LocaleKeys.e2bTemplate.tr,
            theme,
          ),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _templateCtrl,
                    keyboardType: TextInputType.text,
                    enableSuggestions: true,
                    autocorrect: false,
                    decoration: InputDecoration(
                      isDense: true,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      labelText: LocaleKeys.e2bTemplate.tr,
                      hintText: LocaleKeys.e2bTemplateHint.tr,
                      hintStyle: hintStyle,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: _isFetchingTemplates
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.list_alt, size: 20),
                        tooltip: LocaleKeys.e2bFetchTemplates.tr,
                        onPressed: _isFetchingTemplates
                            ? null
                            : _fetchAndSelectTemplate,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtrl,
                    keyboardType: TextInputType.text,
                    enableSuggestions: true,
                    autocorrect: false,
                    decoration: InputDecoration(
                      isDense: true,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      labelText: LocaleKeys.e2bSandboxPassword.tr,
                      hintText: LocaleKeys.e2bSandboxPasswordHint.tr,
                      hintStyle: hintStyle,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 2. GitHub 项目与授权 ──
          _buildSectionHeader(
            Icons.account_tree_outlined,
            LocaleKeys.e2bGitProjectAndAuth.tr,
            theme,
          ),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _tokenCtrl,
                    keyboardType: TextInputType.text,
                    enableSuggestions: true,
                    autocorrect: false,
                    decoration: InputDecoration(
                      isDense: true,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      labelText: LocaleKeys.e2bGitPatLabel.tr,
                      hintText: LocaleKeys.e2bGitPatHint.tr,
                      hintStyle: hintStyle,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_repoFullNameCtrl.text.isNotEmpty) ...[
                    // 选中仓库的紧凑展示卡片
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _repoFullNameCtrl.text,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  LocaleKeys.e2bBranchPrefix.trParams({
                                    'branch': _branch,
                                  }),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            tooltip: LocaleKeys.e2bFetchAndSelectRepo.tr,
                            onPressed: _isFetchingRepos
                                ? null
                                : _fetchAndSelectRepo,
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
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
                  ] else ...[
                    // 未选择仓库时：提供选择按钮与手动输入
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isFetchingRepos ? null : _fetchAndSelectRepo,
                      icon: _isFetchingRepos
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search, size: 18),
                      label: Text(
                        _isFetchingRepos
                            ? LocaleKeys.e2bFetchingRepos.tr
                            : LocaleKeys.e2bFetchAndSelectRepo.tr,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _repoCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        labelText: LocaleKeys.e2bGitRepo.tr,
                        hintText: LocaleKeys.e2bGitRepoUrlOptionalHint.tr,
                        hintStyle: hintStyle,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 3. 保活与自动化 ──
          _buildSectionHeader(
            Icons.timer_outlined,
            LocaleKeys.e2bKeepAliveConfig.tr,
            theme,
          ),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                      if (vals.isNotEmpty) {
                        setState(() => _ttlHours = vals.first);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _autoPause,
                    onChanged: (val) => setState(() => _autoPause = val),
                    title: Text(
                      LocaleKeys.e2bAutoPause.tr,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      LocaleKeys.e2bAutoPauseDesc.tr,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── 底部操作按钮 ──
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: widget.onlyConfig ? _saveOnly : _saveAndLaunch,
            icon: Icon(
              widget.onlyConfig ? Icons.save : Icons.add_circle_outline,
              size: 20,
            ),
            label: Text(
              widget.onlyConfig
                  ? LocaleKeys.save.tr
                  : LocaleKeys.e2bCreateAndLaunch.tr,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
