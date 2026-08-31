import 'package:dio/dio.dart';
import '../utils/app_logger.dart';

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
  const GitUserInfo({
    required this.login,
    this.name = '',
    this.email = '',
  });

  final String login;
  final String name;
  final String email;
}

/// GitHub 仓库获取与凭据服务
class GitRepoService {
  static final GitRepoService instance = GitRepoService._internal();
  GitRepoService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// 获取 GitHub 用户信息（自动补全提交者姓名与邮箱）
  Future<GitUserInfo?> fetchUserInfo(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return null;

    try {
      final res = await _dio.get(
        'https://api.github.com/user',
        options: Options(
          headers: {
            'Authorization': 'Bearer $cleanToken',
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        return GitUserInfo(
          login: data['login'] as String? ?? '',
          name: data['name'] as String? ?? data['login'] as String? ?? '',
          email: data['email'] as String? ?? '',
        );
      }
    } catch (e) {
      AppLogger.w('GitHub fetchUserInfo failed: $e');
    }
    return null;
  }

  /// 获取用户在 GitHub 上所有有权限的仓库（包含自己拥有的、协作的、组织内的）
  Future<List<GitRepoItem>> fetchRepositories(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return [];

    try {
      final res = await _dio.get(
        'https://api.github.com/user/repos',
        queryParameters: {
          'per_page': 100,
          'sort': 'updated',
          'affiliation': 'owner,collaborator,organization_member',
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $cleanToken',
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List)
            .whereType<Map<String, dynamic>>()
            .map((j) => GitRepoItem.fromGitHubJson(j))
            .toList();
      }
    } catch (e) {
      AppLogger.e('GitHub fetchRepositories failed: $e');
      rethrow;
    }
    return [];
  }

  /// 构造带 Token 的 Authenticated Clone URL (确保在沙盒中 git push 无需密码认证)
  String buildAuthenticatedCloneUrl({
    required String repoUrl,
    required String token,
  }) {
    final cleanUrl = repoUrl.trim();
    final cleanToken = token.trim();
    if (cleanToken.isEmpty || !cleanUrl.startsWith('http')) {
      return cleanUrl;
    }

    try {
      final uri = Uri.parse(cleanUrl);
      final host = uri.host;
      // 用 Uri.replace(userInfo: ...) 构造,自动对 token 做 URL 编码
      final isGithubLike = host.contains('github.com') || host.contains('gitlab');
      final userInfo = isGithubLike ? 'oauth2:$cleanToken' : cleanToken;
      final updated = uri.replace(
        userInfo: userInfo,
      );
      return updated.toString();
    } catch (_) {
      return cleanUrl;
    }
  }
}
