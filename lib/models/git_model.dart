/// GitHub 仓库条目数据模型
class GitRepoItem {
  const GitRepoItem({
    required this.name,
    required this.fullName,
    required this.cloneUrl,
    required this.defaultBranch,
    required this.isPrivate,
    this.description = '',
    this.owner = '',
    this.htmlUrl = '',
  });

  final String name;
  final String fullName;
  final String cloneUrl;
  final String defaultBranch;
  final bool isPrivate;
  final String description;
  final String owner;
  final String htmlUrl;

  factory GitRepoItem.fromGitHubJson(Map<String, dynamic> json) {
    return GitRepoItem(
      name: json['name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      cloneUrl: json['clone_url'] as String? ?? '',
      defaultBranch: json['default_branch'] as String? ?? 'main',
      isPrivate: json['private'] as bool? ?? false,
      description: json['description'] as String? ?? '',
      owner: (json['owner'] is Map)
          ? ((json['owner'] as Map)['login'] as String? ?? '')
          : '',
      htmlUrl: json['html_url'] as String? ?? '',
    );
  }
}

/// GitHub 平台用户信息
class GitUserInfo {
  const GitUserInfo({required this.login, this.name = '', this.email = ''});

  final String login;
  final String name;
  final String email;
}
