/// E2B 沙盒创建与连接选项
class SandboxCreateOpts {
  /// 模板 ID (如 'opencode', 'base', 'code-interpreter')
  final String template;

  /// 沙盒生命周期超时（秒，默认 300）
  final int timeout;

  /// 是否在空闲时自动休眠（节省资源）
  final bool autoPause;

  /// 注入到沙盒 MicroVM 的环境变量
  final Map<String, String> envVars;

  /// 沙盒元数据
  final Map<String, String> metadata;

  /// E2B API Key (可选，若不填则取全局配置)
  final String? apiKey;

  /// E2B 域名 (默认 e2b.app)
  final String domain;

  const SandboxCreateOpts({
    this.template = 'base',
    this.timeout = 300,
    this.autoPause = true,
    this.envVars = const {},
    this.metadata = const {},
    this.apiKey,
    this.domain = 'e2b.app',
  });
}

class SandboxConnectOpts {
  final String sandboxId;

  /// 连接/唤醒后沙盒的 TTL 秒数(从当前时刻重新计时,默认 300)
  final int timeout;
  final String? apiKey;
  final String? envdAccessToken;
  final String domain;

  const SandboxConnectOpts({
    required this.sandboxId,
    this.timeout = 300,
    this.apiKey,
    this.envdAccessToken,
    this.domain = 'e2b.app',
  });
}

class SandboxListOpts {
  final List<String>? states; // 'running', 'paused'
  final int limit;
  final String? nextToken;
  final String? apiKey;
  final String domain;

  const SandboxListOpts({
    this.states,
    this.limit = 50,
    this.nextToken,
    this.apiKey,
    this.domain = 'e2b.app',
  });
}
