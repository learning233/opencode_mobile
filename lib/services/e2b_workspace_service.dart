import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import '../e2b/e2b.dart';
import '../models/cloud_workspace_config.dart';
import '../models/e2b_sandbox_info.dart';
import '../utils/app_logger.dart';
import 'git_repo_service.dart';

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

/// E2B 云端沙盒与工作区服务
class E2bWorkspaceService {
  static final E2bWorkspaceService instance = E2bWorkspaceService._internal();
  E2bWorkspaceService._internal();

  static const String e2bApiBase = 'https://api.e2b.app';
  static const Duration _defaultHttpTimeout = Duration(seconds: 15);

  /// 判定 URL 是否为 E2B 云端沙盒端点(全局统一判据)。
  /// 严格按 host 解析,覆盖官方支持域 e2b.app / e2b.dev / e2b.pro / e2b-staging.dev,
  /// 避免把自建服务器(如含 e2b.app 的任意文本)误判为云端。
  static const List<String> _cloudDomains = [
    'e2b.app',
    'e2b.dev',
    'e2b.pro',
    'e2b-staging.dev',
  ];

  static bool isCloudUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) return false;
    for (final d in _cloudDomains) {
      if (host == d || host.endsWith('.$d')) return true;
    }
    return false;
  }

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: e2bApiBase,
      connectTimeout: _defaultHttpTimeout,
      sendTimeout: _defaultHttpTimeout,
      receiveTimeout: _defaultHttpTimeout,
    ),
  );

  Dio _healthDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      sendTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  /// 测试专用:注入 mock 健康检查 HTTP 客户端
  // ignore: avoid_setters_without_getters
  set healthDioForTest(Dio dio) => _healthDio = dio;

  /// 沙盒内启动 OpenCode 的引导脚本。
  /// 密码通过进程环境变量 BOOTSTRAP_PASSWORD 传入(避免拼接注入)。
  ///
  /// 注意:脚本经 `bash -l -c '<全文>'` 执行,进程自身 cmdline 含脚本全文,
  /// 因此 pgrep 必须用 `[o]pencode` 正则技巧避免自匹配;
  /// 服务就绪判定一律用 curl 探测本机 4096,不依赖进程名。
  /// 退出码约定: 0 成功 / 42 opencode 安装失败 / 43 serve 启动失败。
  static const String bootstrapScript = r'''
export PATH="$HOME/.opencode/bin:/usr/local/bin:$PATH"
echo "=== OpenCode Bootstrap ==="
echo "USER: $(whoami), HOME: $HOME"

# 落盘密码供重连恢复(仅当前用户可读)
umask 077 && printf '%s' "$BOOTSTRAP_PASSWORD" > "$HOME/.opencode_pw"

# 探测本机 4096:200=健康;000=无监听;其他(如401)=有服务但密码不匹配
probe() {
  local code
  code="$(curl -s -o /dev/null -m 2 -w '%{http_code}' \
    -u "opencode:$BOOTSTRAP_PASSWORD" \
    http://127.0.0.1:4096/api/health 2>/dev/null)"
  [ -z "$code" ] && code="000"
  echo "$code"
}

code="$(probe)"
case "$code" in
  200)
    echo "opencode serve already healthy on 4096"
    exit 0
    ;;
  000)
    echo "no server listening on 4096 yet"
    ;;
  *)
    echo "port 4096 has a server with mismatched auth (HTTP $code), restarting..."
    pkill -f "[o]pencode serve" 2>/dev/null || true
    sleep 1
    ;;
esac

# opencode 缺失时自动安装:官方安装脚本优先,npm 兜底(base 模板自带 Node/curl)
if ! command -v opencode > /dev/null 2>&1; then
  echo "opencode not found, installing..."
  curl -fsSL https://opencode.ai/install | bash 2>&1 | tail -n 5
  export PATH="$HOME/.opencode/bin:/usr/local/bin:$PATH"
  if ! command -v opencode > /dev/null 2>&1; then
    echo "install script failed, trying npm..."
    npm install -g opencode-ai 2>&1 | tail -n 5
    export PATH="/usr/local/bin:$PATH"
  fi
  if ! command -v opencode > /dev/null 2>&1; then
    echo "ERROR: opencode install failed"
    exit 42
  fi
fi
echo "opencode version: $(opencode --version 2>&1 | head -n 1)"

# 克隆目录用 GitHub 项目名;未绑定仓库时回退到 ~/workspace
mkdir -p "$HOME/workspace"
REPO_DIR=""
if [ -n "$GIT_CLONE_URL" ]; then
  REPO_NAME="$(basename "$GIT_CLONE_URL" .git)"
  case "$REPO_NAME" in
    ""|"."|".."|*/*) REPO_NAME="" ;;
  esac
  if [ -n "$REPO_NAME" ]; then
    REPO_DIR="$HOME/$REPO_NAME"
  fi
fi

if [ -n "$REPO_DIR" ] && [ ! -d "$REPO_DIR/.git" ]; then
  echo "Cloning git repository into $REPO_DIR ..."
  rm -rf "$REPO_DIR"
  git clone "$GIT_CLONE_URL" "$REPO_DIR" 2>&1 | tail -n 3 || true
fi
cd "$REPO_DIR" 2>/dev/null || cd "$HOME/workspace" 2>/dev/null || cd "$HOME"
echo "Working directory: $(pwd)"
if [ -n "$GIT_BRANCH" ] && [ -d .git ]; then
  git checkout "$GIT_BRANCH" 2>&1 | tail -n 2 || true
fi

# 剥离 clone URL 中内嵌的 token,避免凭据持久化进 .git/config
if [ -d .git ]; then
  remote_url="$(git remote get-url origin 2>/dev/null || true)"
  if [ -n "$remote_url" ]; then
    stripped="$(printf '%s' "$remote_url" | sed -E 's#^(https?://)[^/@]+@#\1#')"
    if [ "$stripped" != "$remote_url" ]; then
      git remote set-url origin "$stripped" 2>/dev/null || true
    fi
  fi
fi

echo "Starting opencode serve on 0.0.0.0:4096..."
setsid nohup env OPENCODE_SERVER_PASSWORD="$BOOTSTRAP_PASSWORD" \
  opencode serve --hostname 0.0.0.0 --port 4096 \
  > /tmp/opencode.log 2>&1 < /dev/null &

# 轮询等待端口就绪(最多约 30 秒);进程若中途退出则提前失败并输出日志
for i in $(seq 1 15); do
  code="$(probe)"
  if [ "$code" = "200" ]; then
    echo "opencode serve is up (attempt $i)"
    exit 0
  fi
  if ! pgrep -f "[o]pencode serve" > /dev/null 2>&1; then
    echo "ERROR: opencode serve exited, log:"
    cat /tmp/opencode.log 2>/dev/null
    exit 43
  fi
  sleep 2
done

echo "ERROR: opencode serve not ready after 30s, log:"
cat /tmp/opencode.log 2>/dev/null
exit 43
''';

  /// 生成安全的随机密码用于 OpenCode Basic Auth
  String generateSecurePassword([int length = 16]) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  /// 一键启动或拉起 E2B 云端开发沙盒
  Future<E2bLaunchResult> launchWorkspace(
    CloudWorkspaceConfig config, {
    void Function(String stepMessage)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final apiKey = config.e2bApiKey.trim();
    if (apiKey.isEmpty) {
      return const E2bLaunchResult(
        success: false,
        error: 'E2B API Key 不能为空，请先在设置中填写',
      );
    }

    if (cancelToken?.isCancelled == true) {
      return const E2bLaunchResult(success: false, error: '操作已取消');
    }

    final password = config.activeSandboxPassword?.isNotEmpty == true
        ? config.activeSandboxPassword!
        : generateSecurePassword();

    Sandbox? sandbox;
    try {
      onProgress?.call('正在向 E2B 申请微型虚拟机沙盒...');
      AppLogger.i('Requesting E2B Sandbox with template: ${config.templateId}');

      // 组装注入的环境变量
      final envVars = <String, String>{
        'OPENCODE_SERVER_PASSWORD': password,
        'PORT': '4096',
      };

      // 注入 Git 提交者配置;Token 不再注入全局环境(GITHUB_TOKEN/GIT_TOKEN),
      // 仅以内嵌 clone URL 形式供 bootstrap 一次性使用,clone 后立即剥离
      if (config.gitUsername.trim().isNotEmpty) {
        envVars['GIT_AUTHOR_NAME'] = config.gitUsername.trim();
        envVars['GIT_COMMITTER_NAME'] = config.gitUsername.trim();
      }
      if (config.gitEmail.trim().isNotEmpty) {
        envVars['GIT_AUTHOR_EMAIL'] = config.gitEmail.trim();
        envVars['GIT_COMMITTER_EMAIL'] = config.gitEmail.trim();
      }
      if (config.gitRepoUrl.trim().isNotEmpty) {
        final authCloneUrl = GitRepoService.instance.buildAuthenticatedCloneUrl(
          repoUrl: config.gitRepoUrl,
          token: config.gitToken,
        );
        envVars['GIT_CLONE_URL'] = authCloneUrl;
        envVars['GIT_BRANCH'] = config.gitBranch;
      }

      // 计算 TTL 秒数（最低 10 分钟，默认 2 小时）
      final timeoutSeconds = max(600, config.ttlHours * 3600);

      final templateName = config.templateId.trim().isEmpty
          ? 'opencode'
          : config.templateId.trim();

      // 通过 Dart E2B SDK 创建沙盒
      sandbox = await Sandbox.create(
        opts: SandboxCreateOpts(
          apiKey: apiKey,
          template: templateName,
          timeout: timeoutSeconds,
          autoPause: config.autoPause,
          envVars: {
            ...envVars,
            if (config.toolchains.isNotEmpty)
              'TOOLCHAINS': config.toolchains.join(','),
          },
          metadata: {
            'source': 'opencode_mobile',
            'created_at': DateTime.now().toIso8601String(),
            if (config.gitRepoFullName.isNotEmpty)
              'repo': config.gitRepoFullName,
            if (config.toolchains.isNotEmpty)
              'toolchains': config.toolchains.join(','),
          },
        ),
        dio: _dio,
      );

      if (cancelToken?.isCancelled == true) {
        await sandbox.destroy();
        return const E2bLaunchResult(success: false, error: '操作已取消');
      }

      final sandboxId = sandbox.sandboxId;
      final endpointUrl = sandbox.getHostUrl(4096);
      AppLogger.i('E2B Sandbox created via SDK: $sandboxId -> $endpointUrl');

      onProgress?.call('沙盒已分配，正在沙盒内部署 OpenCode 服务（缺失时会自动安装）...');

      // 确保沙盒内常驻运行 opencode serve 服务(失败必须中止)
      final bootstrap = await ensureOpenCodeRunning(
        sandboxId: sandboxId,
        apiKey: apiKey,
        password: password,
        config: config,
        sandbox: sandbox,
        endpointUrl: endpointUrl,
      );

      if (!bootstrap.success) {
        final logPart = (bootstrap.logTail?.isNotEmpty == true)
            ? '\n\n沙盒内 /tmp/opencode.log 尾部:\n${bootstrap.logTail}'
            : '';
        return E2bLaunchResult(
          success: false,
          sandboxId: sandboxId,
          endpointUrl: endpointUrl,
          password: password,
          envdAccessToken: sandbox.envdAccessToken,
          error: _maskSecrets(
            'OpenCode 服务启动失败: ${bootstrap.error}$logPart',
            config,
          ),
        );
      }

      if (cancelToken?.isCancelled == true) {
        await sandbox.destroy();
        return const E2bLaunchResult(success: false, error: '操作已取消');
      }

      onProgress?.call(bootstrap.alreadyRunning
          ? 'OpenCode 已在运行，正在验证健康状态...'
          : 'OpenCode 已拉起，正在等待服务就绪...');

      // 轮询健康检查等待 OpenCode serve 启动就绪（默认最多约 120 秒）
      final health = await _waitForHealthy(
        endpointUrl: endpointUrl,
        password: password,
        onProgress: onProgress,
        maxRetries: 60,
        sandbox: sandbox,
        cancelToken: cancelToken,
      );

      if (!health.healthy) {
        return E2bLaunchResult(
          success: false,
          sandboxId: sandboxId,
          endpointUrl: endpointUrl,
          password: password,
          envdAccessToken: sandbox.envdAccessToken,
          error: health.failReason ?? '沙盒已拉起，但 OpenCode 服务未在预期时间内响应健康检查',
        );
      }

      onProgress?.call('OpenCode 握手成功，正在进入工作区...');
      return E2bLaunchResult(
        success: true,
        sandboxId: sandboxId,
        endpointUrl: endpointUrl,
        password: password,
        envdAccessToken: sandbox.envdAccessToken,
      );
    } on SandboxException catch (e) {
      AppLogger.e('E2B SDK SandboxException: ${e.message}', e);
      return E2bLaunchResult(success: false, error: 'E2B 沙盒异常: ${e.message}');
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? '$e';
      AppLogger.e('E2B launchWorkspace Dio error: $message', e);
      return E2bLaunchResult(success: false, error: 'E2B 请求异常: $message');
    } catch (e) {
      AppLogger.e('E2B launchWorkspace unexpected error', e);
      return E2bLaunchResult(success: false, error: '未知异常: $e');
    }
  }

  /// 连接并拉起已有沙盒的完整流程 (连接唤醒 → 密码恢复 → 服务常驻 → 健康验证)
  Future<E2bSandboxConnectResult> connectSandbox({
    required CloudWorkspaceConfig config,
    required String sandboxId,
    required String endpointUrl,
    void Function(String stepMessage)? onProgress,
    CancelToken? cancelToken,
    int maxRetries = 30,
    Sandbox? sandbox,
  }) async {
    final apiKey = config.e2bApiKey.trim();
    if (apiKey.isEmpty) {
      return const E2bSandboxConnectResult(
        success: false,
        error: 'E2B API Key 不能为空，请先在设置中填写',
      );
    }

    if (cancelToken?.isCancelled == true) {
      return const E2bSandboxConnectResult(success: false, error: '操作已取消');
    }

    try {
      // 1. 真实 connect: 校验存在性 + 自动唤醒 paused 沙盒(201) + 刷新 token
      onProgress?.call('正在连接沙盒并验证状态...');
      sandbox ??= await Sandbox.connect(
        SandboxConnectOpts(
          sandboxId: sandboxId,
          apiKey: apiKey,
          envdAccessToken: config.activeSandboxEnvdToken,
          timeout: max(600, config.ttlHours * 3600),
        ),
      );

      if (cancelToken?.isCancelled == true) {
        return const E2bSandboxConnectResult(success: false, error: '操作已取消');
      }

      // 2. 密码解析: 优先用该沙盒对应的存储密码, 缺失时从沙盒内 recover
      var password = (config.activeSandboxId == sandboxId
              ? config.activeSandboxPassword
              : null) ??
          '';
      if (password.isEmpty) {
        onProgress?.call('正在恢复沙盒访问凭据...');
        password = await recoverPassword(sandbox) ?? '';
      }
      if (password.isEmpty) {
        return const E2bSandboxConnectResult(
          success: false,
          error: '无法恢复该沙盒的 OpenCode 密码，请销毁后重新创建',
        );
      }

      if (cancelToken?.isCancelled == true) {
        return const E2bSandboxConnectResult(success: false, error: '操作已取消');
      }

      // 3. 确保沙盒内已安装并启动 opencode serve
      onProgress?.call('正在拉起沙盒内 OpenCode 服务...');
      final bootstrap = await ensureOpenCodeRunning(
        sandboxId: sandboxId,
        apiKey: apiKey,
        password: password,
        config: config,
        sandbox: sandbox,
        endpointUrl: endpointUrl,
      );

      if (!bootstrap.success) {
        final logPart = (bootstrap.logTail?.isNotEmpty == true)
            ? '\n\n沙盒内 /tmp/opencode.log 尾部:\n${bootstrap.logTail}'
            : '';
        return E2bSandboxConnectResult(
          success: false,
          error: _maskSecrets(
            'OpenCode 服务启动失败: ${bootstrap.error}$logPart',
            config,
          ),
        );
      }

      if (cancelToken?.isCancelled == true) {
        return const E2bSandboxConnectResult(success: false, error: '操作已取消');
      }

      // 4. 轮询健康检查等待就绪
      onProgress?.call('正在验证服务健康状态...');
      final health = await waitForHealthy(
        endpointUrl: endpointUrl,
        password: password,
        maxRetries: maxRetries,
        sandbox: sandbox,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );

      if (!health.healthy) {
        return E2bSandboxConnectResult(
          success: false,
          error: health.failReason ?? 'OpenCode 服务未能在预期时间内就绪',
        );
      }

      return E2bSandboxConnectResult(
        success: true,
        password: password,
        envdAccessToken: sandbox.envdAccessToken,
        domain: sandbox.connectionConfig.domain,
      );
    } on SandboxNotFoundException catch (e) {
      AppLogger.w('E2B SandboxNotFoundException: $e');
      return const E2bSandboxConnectResult(
        success: false,
        error: '沙盒不存在或已过期销毁，请新建沙盒',
      );
    } on SandboxAuthenticationException catch (e) {
      AppLogger.e('E2B SandboxAuthenticationException: $e');
      return E2bSandboxConnectResult(
        success: false,
        error: 'E2B API Key 认证失败: ${e.message}',
      );
    } on SandboxException catch (e) {
      AppLogger.e('E2B SandboxException: ${e.message}', e);
      return E2bSandboxConnectResult(
        success: false,
        error: 'E2B 沙盒连接异常: ${e.message}',
      );
    } catch (e) {
      AppLogger.e('E2B connectSandbox unexpected error', e);
      return E2bSandboxConnectResult(
        success: false,
        error: '连接沙盒遇到未知错误: $e',
      );
    }
  }

  /// 确保指定沙盒内已安装并常驻运行 opencode serve 服务。
  ///
  /// 只走 envd Connect-RPC 通道(直连域名路由);失败时返回结构化原因与日志尾部,
  /// 调用方必须检查 [E2bBootstrapResult.success] 并中止后续流程。
  Future<E2bBootstrapResult> ensureOpenCodeRunning({
    required String sandboxId,
    required String apiKey,
    required String password,
    required CloudWorkspaceConfig config,
    Sandbox? sandbox,
    String? endpointUrl,
  }) async {
    // 0. 服务已就绪则跳过 bootstrap
    if (endpointUrl != null && endpointUrl.isNotEmpty) {
      final code = await _probeHealth('$endpointUrl/api/health', password);
      if (code == 200) {
        AppLogger.i('OpenCode already healthy at $endpointUrl, skip bootstrap');
        return const E2bBootstrapResult(success: true, alreadyRunning: true);
      }
    }

    // 1. 获取 Sandbox 实例(真实 connect:校验存在性 + 自动唤醒 + 刷新 token)
    sandbox ??= await _connectSandbox(sandboxId, apiKey, config);

    // 2. 执行引导脚本(前台等待结束,含 opencode 自动安装兜底)
    try {
      final result = await sandbox.commands.run(
        bootstrapScript,
        opts: CommandOpts(
          timeoutMs: 180000,
          envs: {'BOOTSTRAP_PASSWORD': password},
          onStdout: (out) {
            final t = out.trim();
            if (t.isNotEmpty) AppLogger.i('[Sandbox VM] $t');
          },
          onStderr: (err) {
            final t = err.trim();
            if (t.isNotEmpty) AppLogger.w('[Sandbox VM stderr] $t');
          },
        ),
      );
      if (result.isSuccess) {
        AppLogger.i('OpenCode bootstrap finished OK via envd RPC');
        return const E2bBootstrapResult(success: true);
      }
      return E2bBootstrapResult(
        success: false,
        error: _mapBootstrapExitCode(result.exitCode, result.error),
        logTail: await readOpencodeLogTail(sandbox),
      );
    } on CommandExitException catch (e) {
      return E2bBootstrapResult(
        success: false,
        error: _mapBootstrapExitCode(e.exitCode, e.message),
        logTail: await readOpencodeLogTail(sandbox),
      );
    } catch (e) {
      AppLogger.e('OpenCode bootstrap failed with unexpected error', e);
      return E2bBootstrapResult(success: false, error: '执行引导脚本失败: $e');
    }
  }

  /// 从错误/日志文本中抹掉已配置的敏感值(Git Token、沙盒密码),防止
  /// clone 失败输出或日志尾部把凭据透出到 UI。
  String _maskSecrets(String input, CloudWorkspaceConfig config) {
    var out = input;
    final token = config.gitToken.trim();
    if (token.isNotEmpty && out.contains(token)) {
      out = out.replaceAll(token, '***');
    }
    final pw = config.activeSandboxPassword ?? '';
    if (pw.isNotEmpty && out.contains(pw)) {
      out = out.replaceAll(pw, '***');
    }
    return out;
  }

  String _mapBootstrapExitCode(int exitCode, String? detail) {
    switch (exitCode) {
      case 42:
        return '沙盒内未找到 opencode 且自动安装失败(curl 与 npm 均未成功),请检查模板网络或改用预装 opencode 的自定义模板';
      case 43:
        return 'opencode serve 启动后立即退出,请检查 /tmp/opencode.log';
      case -1:
        return '引导脚本执行超时(180s)';
      default:
        return '引导脚本退出码 $exitCode${detail == null ? '' : ': $detail'}';
    }
  }

  Future<Sandbox> _connectSandbox(
    String sandboxId,
    String apiKey,
    CloudWorkspaceConfig config,
  ) async {
    try {
      return await Sandbox.connect(
        SandboxConnectOpts(
          sandboxId: sandboxId,
          apiKey: apiKey,
          envdAccessToken: config.activeSandboxEnvdToken,
        ),
      );
    } catch (e) {
      throw SandboxException('无法连接沙盒 envd 数据面: $e');
    }
  }

  /// 读取沙盒内 /tmp/opencode.log 尾部(诊断用,失败返回空串)
  Future<String> readOpencodeLogTail(Sandbox sandbox) async {
    try {
      final log = await sandbox.files.read('/tmp/opencode.log');
      if (log.isEmpty) return '';
      return log.length > 800 ? log.substring(log.length - 800) : log;
    } catch (_) {
      return '';
    }
  }

  /// 通过 envd 从沙盒内恢复 OpenCode Basic Auth 密码。
  /// 优先读 bootstrap 落盘的 ~/.opencode_pw,回退到 serve 进程的环境变量。
  /// pgrep 用 [o]pencode 技巧避免匹配到执行命令的 bash 自身。
  Future<String?> recoverPassword(Sandbox sandbox) async {
    try {
      final result = await sandbox.commands.run(
        r'''
cat "$HOME/.opencode_pw" 2>/dev/null && exit 0
pid="$(pgrep -f '[o]pencode serve' | head -n 1)"
if [ -n "$pid" ] && [ -r "/proc/$pid/environ" ]; then
  tr '\0' '\n' < "/proc/$pid/environ" | grep '^OPENCODE_SERVER_PASSWORD=' | cut -d= -f2-
fi
''',
        opts: const CommandOpts(timeoutMs: 15000),
      );
      final pw = result.stdout.trim();
      return pw.isEmpty ? null : pw;
    } catch (e) {
      AppLogger.w('recoverPassword failed: $e');
      return null;
    }
  }

  /// 探测沙盒应用端口健康,返回 HTTP 状态码。
  /// 200=健康;401/403=服务存活但密码不匹配;502/其他/null=服务未就绪。
  /// 供云端模式状态条使用。
  Future<int?> probeSandboxHealth(
    String endpointUrl, {
    String? password,
    CancelToken? cancelToken,
  }) {
    return _probeHealth(
      '$endpointUrl/api/health',
      password ?? '',
      cancelToken: cancelToken,
    );
  }

  /// 探测健康端点,返回 HTTP 状态码(网络异常返回 null)
  Future<int?> _probeHealth(String healthUrl, String password,
      {CancelToken? cancelToken}) async {
    try {
      final token = base64Encode(utf8.encode('opencode:$password'));
      final res = await _healthDio.get(
        healthUrl,
        options: Options(
          headers: {'Authorization': 'Basic $token'},
          validateStatus: (status) => true,
        ),
        cancelToken: cancelToken,
      );
      return res.statusCode;
    } catch (e) {
      if (cancelToken?.isCancelled == true) return null;
      AppLogger.d('Health probe $healthUrl error: $e');
      return null;
    }
  }

  /// 公开暴露的轮询方法
  Future<E2bHealthResult> waitForHealthy({
    required String endpointUrl,
    required String password,
    void Function(String stepMessage)? onProgress,
    int maxRetries = 60,
    Sandbox? sandbox,
    CancelToken? cancelToken,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return _waitForHealthy(
      endpointUrl: endpointUrl,
      password: password,
      onProgress: onProgress,
      maxRetries: maxRetries,
      sandbox: sandbox,
      cancelToken: cancelToken,
      retryDelay: retryDelay,
    );
  }

  /// 轮询 OpenCode 端点健康检查。
  /// 502/网络异常 = 端口尚未就绪,继续重试;401/403 = 密码不匹配,立即失败。
  Future<E2bHealthResult> _waitForHealthy({
    required String endpointUrl,
    required String password,
    void Function(String stepMessage)? onProgress,
    int maxRetries = 60,
    Sandbox? sandbox,
    CancelToken? cancelToken,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    final healthUrl = '$endpointUrl/api/health';
    final globalHealthUrl = '$endpointUrl/global/health';
    final token = base64Encode(utf8.encode('opencode:$password'));
    final headers = {'Authorization': 'Basic $token'};

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      if (cancelToken?.isCancelled == true) {
        AppLogger.i('OpenCode health check cancelled by user');
        return const E2bHealthResult(healthy: false, failReason: '操作已取消');
      }

      int? code;
      try {
        final res = await _healthDio.get(
          healthUrl,
          options: Options(headers: headers, validateStatus: (status) => true),
          cancelToken: cancelToken,
        );
        code = res.statusCode;
        AppLogger.d(
          'Health check [$attempt/$maxRetries] $healthUrl -> HTTP ${res.statusCode}, data: ${res.data}',
        );
      } catch (e) {
        if (cancelToken?.isCancelled == true) {
          return const E2bHealthResult(healthy: false, failReason: '操作已取消');
        }
        AppLogger.d('Health check [$attempt/$maxRetries] $healthUrl error: $e');
      }

      if (code == 200) {
        AppLogger.i('OpenCode health check succeeded (HTTP 200) on $healthUrl');
        return const E2bHealthResult(healthy: true);
      }
      // 应用层认证失败:密码不匹配,重试无意义
      if (code == 401 || code == 403) {
        return E2bHealthResult(
          healthy: false,
          failReason: 'OpenCode 认证失败 (HTTP $code),Basic Auth 密码不匹配',
        );
      }

      if (cancelToken?.isCancelled == true) {
        return const E2bHealthResult(healthy: false, failReason: '操作已取消');
      }

      try {
        final resGlobal = await _healthDio.get(
          globalHealthUrl,
          options: Options(headers: headers, validateStatus: (status) => true),
          cancelToken: cancelToken,
        );
        AppLogger.d(
          'Health check (global) [$attempt/$maxRetries] $globalHealthUrl -> HTTP ${resGlobal.statusCode}, data: ${resGlobal.data}',
        );
        if (resGlobal.statusCode == 200) {
          AppLogger.i(
            'OpenCode health check succeeded (HTTP 200) on $globalHealthUrl',
          );
          return const E2bHealthResult(healthy: true);
        }
        if (resGlobal.statusCode == 401 || resGlobal.statusCode == 403) {
          return E2bHealthResult(
            healthy: false,
            failReason:
                'OpenCode 认证失败 (HTTP ${resGlobal.statusCode}),Basic Auth 密码不匹配',
          );
        }
      } catch (e) {
        if (cancelToken?.isCancelled == true) {
          return const E2bHealthResult(healthy: false, failReason: '操作已取消');
        }
        AppLogger.d(
          'Health check (global) [$attempt/$maxRetries] $globalHealthUrl error: $e',
        );
      }

      if (attempt % 5 == 0 && sandbox != null && cancelToken?.isCancelled != true) {
        final logTail = await readOpencodeLogTail(sandbox);
        if (logTail.isNotEmpty) {
          AppLogger.w('[VM /tmp/opencode.log]\n$logTail');
        }
      }

      onProgress?.call('正在握手 OpenCode 服务... ($attempt/$maxRetries)');
      await Future.delayed(retryDelay);
    }
    final waited = maxRetries * retryDelay.inSeconds;
    AppLogger.w(
      'OpenCode health check timed out after $maxRetries retries on $endpointUrl',
    );
    return E2bHealthResult(
      healthy: false,
      failReason: '健康检查超时:OpenCode 服务未在 $waited 秒内就绪(502 表示沙盒内 4096 端口无进程监听)',
    );
  }

  // ==========================
  // TTL keep-alive
  // ==========================

  Timer? _keepAliveTimer;
  String? _keepAliveSandboxId;

  /// 启动 keep-alive:每 5 分钟刷新一次沙盒 TTL,防止长会话中途被回收
  void startKeepAlive({
    required String sandboxId,
    required String apiKey,
    required int timeoutSeconds,
    String domain = 'e2b.app',
  }) {
    stopKeepAlive();
    _keepAliveSandboxId = sandboxId;
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        await Sandbox.setTimeout(
          sandboxId,
          apiKey: apiKey,
          timeoutSeconds: timeoutSeconds,
          domain: domain,
        );
        AppLogger.d(
          'E2B keep-alive: sandbox $sandboxId TTL renewed (+${timeoutSeconds}s)',
        );
      } catch (e) {
        AppLogger.w('E2B keep-alive failed for $sandboxId: $e');
      }
    });
    AppLogger.i(
      'E2B keep-alive started for $sandboxId (every 5 min, TTL ${timeoutSeconds}s)',
    );
  }

  /// 停止 keep-alive
  void stopKeepAlive() {
    if (_keepAliveTimer != null) {
      _keepAliveTimer!.cancel();
      _keepAliveTimer = null;
      AppLogger.i(
        'E2B keep-alive stopped${_keepAliveSandboxId != null ? ' (was $_keepAliveSandboxId)' : ''}',
      );
    }
    _keepAliveSandboxId = null;
  }

  // ==========================
  // 控制面操作
  // ==========================

  /// 暂停/休眠沙盒 (Pause)
  Future<({bool success, String? error})> pauseSandbox(
    String sandboxId,
    String apiKey,
  ) async {
    try {
      await Sandbox.pause(sandboxId, apiKey: apiKey, dio: _dio);
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: '$e');
    }
  }

  /// 恢复已暂停的沙盒 (Resume)
  Future<({bool success, String? error})> resumeSandbox(
    String sandboxId,
    String apiKey,
  ) async {
    try {
      await Sandbox.resume(sandboxId, apiKey: apiKey, dio: _dio);
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: '$e');
    }
  }

  /// 销毁沙盒 (Kill / Delete)
  Future<({bool success, String? error})> destroySandbox(
    String sandboxId,
    String apiKey,
  ) async {
    if (_keepAliveSandboxId == sandboxId) {
      stopKeepAlive();
    }
    try {
      await Sandbox.kill(sandboxId, apiKey: apiKey, dio: _dio);
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: '$e');
    }
  }

  /// 获取当前 E2B 账户下的所有沙盒实例列表
  Future<List<E2bSandboxInfo>> fetchSandboxes(String apiKey) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) return [];

    try {
      final list = await Sandbox.list(
        opts: SandboxListOpts(apiKey: cleanKey),
        dio: _dio,
      );
      final result =
          list.sandboxes.map((j) => E2bSandboxInfo.fromJson(j)).toList();
      AppLogger.i('Fetched ${result.length} E2B sandboxes via Sandbox.list');
      return result;
    } catch (e) {
      AppLogger.w('E2B fetchSandboxes failed via Sandbox.list: $e');
      return [];
    }
  }
}
