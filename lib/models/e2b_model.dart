/// E2B 沙盒操作结果
class E2bLaunchResult {
  const E2bLaunchResult({
    required this.success,
    this.sandboxId,
    this.endpointUrl,
    this.password,
    this.envdAccessToken,
    this.error,
  });

  final bool success;
  final String? sandboxId;
  final String? endpointUrl;
  final String? password;
  final String? envdAccessToken;
  final String? error;
}

/// 沙盒内 OpenCode 启动引导(bootstrap)结果
class E2bBootstrapResult {
  const E2bBootstrapResult({
    required this.success,
    this.alreadyRunning = false,
    this.error,
    this.logTail,
  });

  final bool success;

  /// OpenCode 服务此前已在运行,跳过了 bootstrap
  final bool alreadyRunning;

  final String? error;

  /// 失败时附带 /tmp/opencode.log 尾部,便于诊断
  final String? logTail;
}

/// 健康检查轮询结果
class E2bHealthResult {
  const E2bHealthResult({required this.healthy, this.failReason});

  final bool healthy;

  /// 失败原因(如认证失败/超时/取消),成功时为 null
  final String? failReason;
}

/// 连接已有沙盒的完整流程结果(连接→凭据→部署→健康)
class E2bSandboxConnectResult {
  const E2bSandboxConnectResult({
    required this.success,
    this.password,
    this.envdAccessToken,
    this.domain = 'e2b.app',
    this.error,
  });

  final bool success;
  final String? password;
  final String? envdAccessToken;
  final String domain;
  final String? error;
}
