import 'dart:convert';

/// E2B 云端开发工作区配置模型
class CloudWorkspaceConfig {
  CloudWorkspaceConfig({
    this.e2bApiKey = '',
    this.templateId = 'opencode',
    this.sandboxPassword = '',
    this.gitProvider = 'github',
    this.gitRepoUrl = '',
    this.gitRepoFullName = '',
    this.gitBranch = 'main',
    this.gitToken = '',
    this.gitUsername = '',
    this.gitEmail = '',
    this.ttlHours = 2,
    this.autoPause = true,
    this.activeSandboxId,
    this.activeSandboxUrl,
    this.activeSandboxPassword,
    this.activeSandboxEnvdToken,
    this.activeSandboxStatus,
    this.lastConnectedAt,
  });

  /// E2B 官方用户 API Key
  final String e2bApiKey;

  /// 沙盒模板 ID（默认使用 E2B 官方 opencode 预建模板）
  final String templateId;

  /// 自定义/预设的 OpenCode 访问密码（用于 Web/多设备登录）
  final String sandboxPassword;

  /// Git 平台类型: 默认 'github'
  final String gitProvider;

  /// Git 仓库 URL (e.g. https://github.com/org/repo.git)
  final String gitRepoUrl;

  /// Git 仓库完整名称 (e.g. org/repo)
  final String gitRepoFullName;

  /// Git 目标分支
  final String gitBranch;

  /// Git 访问 Token (Personal Access Token)
  final String gitToken;

  /// Git 提交者用户名
  final String gitUsername;

  /// Git 提交者邮箱
  final String gitEmail;

  /// 云端独立运行周期（小时，默认 2 小时，即使手机离线/锁屏也不中断）
  final int ttlHours;

  /// 任务全部完成且空闲时，是否自动进入快照休眠
  final bool autoPause;

  /// 当前活跃的 E2B 沙盒实例 ID
  final String? activeSandboxId;

  /// 当前活跃的沙盒直连 URL (https://4096-{id}.e2b.app)
  final String? activeSandboxUrl;

  /// 当前沙盒自动生成的 Basic Auth 密码
  final String? activeSandboxPassword;

  /// 当前沙盒的 envd 数据面访问令牌(创建/连接时由服务端签发)
  final String? activeSandboxEnvdToken;

  /// 当前沙盒状态: 'running', 'paused', 'stopped'
  final String? activeSandboxStatus;

  /// 上次连接时间戳
  final DateTime? lastConnectedAt;

  bool get hasActiveSandbox =>
      activeSandboxId != null && activeSandboxId!.isNotEmpty;

  CloudWorkspaceConfig copyWith({
    String? e2bApiKey,
    String? templateId,
    String? sandboxPassword,
    String? gitProvider,
    String? gitRepoUrl,
    String? gitRepoFullName,
    String? gitBranch,
    String? gitToken,
    String? gitUsername,
    String? gitEmail,
    int? ttlHours,
    bool? autoPause,
    String? activeSandboxId,
    String? activeSandboxUrl,
    String? activeSandboxPassword,
    String? activeSandboxEnvdToken,
    String? activeSandboxStatus,
    DateTime? lastConnectedAt,
    bool clearActiveSandbox = false,
  }) {
    return CloudWorkspaceConfig(
      e2bApiKey: e2bApiKey ?? this.e2bApiKey,
      templateId: templateId ?? this.templateId,
      sandboxPassword: sandboxPassword ?? this.sandboxPassword,
      gitProvider: gitProvider ?? this.gitProvider,
      gitRepoUrl: gitRepoUrl ?? this.gitRepoUrl,
      gitRepoFullName: gitRepoFullName ?? this.gitRepoFullName,
      gitBranch: gitBranch ?? this.gitBranch,
      gitToken: gitToken ?? this.gitToken,
      gitUsername: gitUsername ?? this.gitUsername,
      gitEmail: gitEmail ?? this.gitEmail,
      ttlHours: ttlHours ?? this.ttlHours,
      autoPause: autoPause ?? this.autoPause,
      activeSandboxId: clearActiveSandbox
          ? null
          : (activeSandboxId ?? this.activeSandboxId),
      activeSandboxUrl: clearActiveSandbox
          ? null
          : (activeSandboxUrl ?? this.activeSandboxUrl),
      activeSandboxPassword: clearActiveSandbox
          ? null
          : (activeSandboxPassword ?? this.activeSandboxPassword),
      activeSandboxEnvdToken: clearActiveSandbox
          ? null
          : (activeSandboxEnvdToken ?? this.activeSandboxEnvdToken),
      activeSandboxStatus: clearActiveSandbox
          ? null
          : (activeSandboxStatus ?? this.activeSandboxStatus),
      lastConnectedAt: clearActiveSandbox
          ? null
          : (lastConnectedAt ?? this.lastConnectedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'e2b_api_key': e2bApiKey,
      'template_id': templateId,
      'sandbox_password': sandboxPassword,
      'git_provider': gitProvider,
      'git_repo_url': gitRepoUrl,
      'git_repo_full_name': gitRepoFullName,
      'git_branch': gitBranch,
      'git_token': gitToken,
      'git_username': gitUsername,
      'git_email': gitEmail,
      'ttl_hours': ttlHours,
      'auto_pause': autoPause,
      'active_sandbox_id': activeSandboxId,
      'active_sandbox_url': activeSandboxUrl,
      'active_sandbox_password': activeSandboxPassword,
      'active_sandbox_envd_token': activeSandboxEnvdToken,
      'active_sandbox_status': activeSandboxStatus,
      'last_connected_at': lastConnectedAt?.toIso8601String(),
    };
  }

  factory CloudWorkspaceConfig.fromJson(Map<String, dynamic> json) {
    return CloudWorkspaceConfig(
      e2bApiKey: json['e2b_api_key'] as String? ?? '',
      templateId: json['template_id'] as String? ?? 'opencode',
      sandboxPassword: json['sandbox_password'] as String? ?? '',
      gitProvider: json['git_provider'] as String? ?? 'github',
      gitRepoUrl: json['git_repo_url'] as String? ?? '',
      gitRepoFullName: json['git_repo_full_name'] as String? ?? '',
      gitBranch: json['git_branch'] as String? ?? 'main',
      gitToken: json['git_token'] as String? ?? '',
      gitUsername: json['git_username'] as String? ?? '',
      gitEmail: json['git_email'] as String? ?? '',
      ttlHours: (json['ttl_hours'] as num?)?.toInt() ?? 2,
      autoPause: json['auto_pause'] as bool? ?? true,
      activeSandboxId: json['active_sandbox_id'] as String?,
      activeSandboxUrl: json['active_sandbox_url'] as String?,
      activeSandboxPassword: json['active_sandbox_password'] as String?,
      activeSandboxEnvdToken: json['active_sandbox_envd_token'] as String?,
      activeSandboxStatus: json['active_sandbox_status'] as String?,
      lastConnectedAt: json['last_connected_at'] != null
          ? DateTime.tryParse(json['last_connected_at'] as String)
          : null,
    );
  }

  String serialize() => jsonEncode(toJson());

  static CloudWorkspaceConfig deserialize(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return CloudWorkspaceConfig();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CloudWorkspaceConfig.fromJson(decoded);
      }
    } catch (_) {}
    return CloudWorkspaceConfig();
  }
}
