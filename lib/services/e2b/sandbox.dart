import 'dart:async';
import 'package:dio/dio.dart';
import '../../utils/app_logger.dart';
import 'models/errors.dart';
import 'models/sandbox_opts.dart';
import 'services/commands.dart';
import 'services/filesystem.dart';
import 'services/git.dart';
import 'services/pty.dart';
import 'transport/connect_transport.dart';
import 'transport/connection_config.dart';

/// 沙盒列表分页结果
class SandboxListResult {
  final List<Map<String, dynamic>> sandboxes;

  /// 下一页游标;为空表示没有更多
  final String? nextToken;

  const SandboxListResult({required this.sandboxes, this.nextToken});
}

/// E2B 沙盒实体类 (对应 JS/Python SDK 中的 Sandbox)
class Sandbox {
  final String sandboxId;
  final String templateId;
  final String? envdAccessToken;
  final ConnectionConfig connectionConfig;
  final ConnectTransport transport;

  late final Commands commands;
  late final Filesystem files;
  late final Pty pty;
  late final Git git;

  Sandbox._({
    required this.sandboxId,
    required this.templateId,
    this.envdAccessToken,
    required this.connectionConfig,
    required this.transport,
  }) {
    commands = Commands(sandboxId: sandboxId, transport: transport);
    files = Filesystem(
      sandboxId: sandboxId,
      transport: transport,
      dio: transport.dio,
    );
    pty = Pty(sandboxId: sandboxId, transport: transport);
    git = Git(commands: commands);
  }

  // ==========================
  // 控制面错误处理
  // ==========================

  /// Extract message from E2B control plane error response
  static String _parseServerMessage(dynamic body) {
    if (body is Map) {
      return (body['message'] ?? body['error'] ?? '').toString();
    }
    if (body == null) return '';
    return body.toString();
  }

  /// Throw typed exception based on control plane HTTP status code and server response body
  static Never _throwControlPlaneError(
    int? statusCode,
    dynamic body,
    String action,
  ) {
    final serverMsg = _parseServerMessage(body);
    final suffix = serverMsg.isEmpty ? '' : ', $serverMsg';

    if (statusCode == 401 || statusCode == 403) {
      throw SandboxAuthenticationException(
        'Failed to $action: invalid E2B API Key or unauthorized (HTTP $statusCode)$suffix',
      );
    }
    if (statusCode == 404) {
      throw SandboxNotFoundException(
        'Failed to $action: target not found (HTTP 404)$suffix',
      );
    }
    // Actionable guidance for template-related errors
    if (serverMsg.toLowerCase().contains('template')) {
      throw SandboxException(
        'Failed to $action: template not found or unavailable (HTTP $statusCode)$suffix\n'
        'Please check template ID in settings or view available templates in E2B Dashboard → Templates',
        statusCode: statusCode,
      );
    }
    throw SandboxException(
      'Failed to $action: HTTP ${statusCode ?? '?'}$suffix',
      statusCode: statusCode,
    );
  }

  /// Check whether control plane response is successful
  static bool _isSuccess(int? statusCode) =>
      statusCode != null && statusCode >= 200 && statusCode < 300;

  // ==========================
  // Lifecycle Factory Methods
  // ==========================

  /// Create and launch a new E2B Sandbox
  static Future<Sandbox> create({
    SandboxCreateOpts opts = const SandboxCreateOpts(),
    Dio? dio,
  }) async {
    final effectiveApiKey = opts.apiKey ?? '';
    if (effectiveApiKey.isEmpty) {
      throw const SandboxAuthenticationException('E2B API Key cannot be empty');
    }

    final client = dio ?? Dio();
    final config = ConnectionConfig(
      apiKey: effectiveApiKey,
      domain: opts.domain,
    );

    final payload = {
      'templateID': opts.template,
      'timeout': opts.timeout,
      'autoPause': opts.autoPause,
      if (opts.envVars.isNotEmpty) 'envVars': opts.envVars,
      if (opts.metadata.isNotEmpty) 'metadata': opts.metadata,
    };

    try {
      var res = await client.post(
        '${config.apiUrl}/sandboxes',
        options: Options(
          headers: config.getApiHeaders(),
          validateStatus: (status) => true,
        ),
        data: payload,
      );

      // 若因套餐限制 (如 Hobby 限制单次 <= 1h) 导致超长 timeout 被 400 拒绝，自动以 3600s 降级重试
      if (res.statusCode == 400 && opts.timeout > 3600) {
        final serverMsg = _parseServerMessage(res.data).toLowerCase();
        if (serverMsg.contains('timeout')) {
          AppLogger.w(
            'E2B timeout ${opts.timeout}s rejected by plan limit, automatically retrying with 3600s',
          );
          final fallbackPayload = Map<String, dynamic>.from(payload);
          fallbackPayload['timeout'] = 3600;
          res = await client.post(
            '${config.apiUrl}/sandboxes',
            options: Options(
              headers: config.getApiHeaders(),
              validateStatus: (status) => true,
            ),
            data: fallbackPayload,
          );
        }
      }

      if (!_isSuccess(res.statusCode)) {
        _throwControlPlaneError(res.statusCode, res.data, 'create sandbox');
      }

      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : const <String, dynamic>{};
      final sandboxId =
          (data['sandboxID'] ?? data['sandboxId'] ?? data['id'])?.toString() ??
          '';
      if (sandboxId.isEmpty) {
        throw const SandboxException(
          'Failed to create sandbox: missing sandboxID in server response',
        );
      }
      final templateId = data['templateID']?.toString() ?? opts.template;
      final envdAccessToken = data['envdAccessToken']?.toString();

      final fullConfig = ConnectionConfig(
        apiKey: effectiveApiKey,
        domain: opts.domain,
        envdAccessToken: envdAccessToken,
        sandboxId: sandboxId,
      );

      final transport = ConnectTransport(config: fullConfig, dio: client);

      return Sandbox._(
        sandboxId: sandboxId,
        templateId: templateId,
        envdAccessToken: envdAccessToken,
        connectionConfig: fullConfig,
        transport: transport,
      );
    } on DioException catch (e) {
      throw SandboxException(
        'Failed to create sandbox: ${e.message}',
        cause: e,
      );
    }
  }

  /// 连接到一个已存在的 E2B 沙盒。
  ///
  /// 真实调用控制面 `POST /sandboxes/{id}/connect`:校验沙盒存在性,
  /// 已休眠(paused)的沙盒会被自动唤醒(响应 201),
  /// 并返回服务端新签发的 envdAccessToken 与 domain。
  static Future<Sandbox> connect(SandboxConnectOpts opts, {Dio? dio}) async {
    final effectiveApiKey = opts.apiKey ?? '';
    if (effectiveApiKey.isEmpty) {
      throw const SandboxAuthenticationException('E2B API Key cannot be empty');
    }

    final client =
        dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

    final baseConfig = ConnectionConfig(
      apiKey: effectiveApiKey,
      domain: opts.domain,
    );

    try {
      var res = await client.post(
        '${baseConfig.apiUrl}/sandboxes/${opts.sandboxId}/connect',
        options: Options(
          headers: baseConfig.getApiHeaders(),
          validateStatus: (status) => true,
        ),
        data: {'timeout': opts.timeout},
      );

      // 若因套餐限制导致超长 timeout 被 400 拒绝，自动以 3600s 降级重试
      if (res.statusCode == 400 && opts.timeout > 3600) {
        final serverMsg = _parseServerMessage(res.data).toLowerCase();
        if (serverMsg.contains('timeout')) {
          AppLogger.w(
            'E2B connect timeout ${opts.timeout}s rejected by plan limit, automatically retrying with 3600s',
          );
          res = await client.post(
            '${baseConfig.apiUrl}/sandboxes/${opts.sandboxId}/connect',
            options: Options(
              headers: baseConfig.getApiHeaders(),
              validateStatus: (status) => true,
            ),
            data: {'timeout': 3600},
          );
        }
      }

      if (!_isSuccess(res.statusCode)) {
        _throwControlPlaneError(res.statusCode, res.data, 'connect sandbox');
      }

      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : const <String, dynamic>{};
      final envdAccessToken = (data['envdAccessToken'] ?? opts.envdAccessToken)
          ?.toString();
      final respDomain = data['domain']?.toString();
      final domain = (respDomain == null || respDomain.isEmpty)
          ? opts.domain
          : respDomain;

      final config = ConnectionConfig(
        apiKey: effectiveApiKey,
        domain: domain,
        envdAccessToken: envdAccessToken,
        sandboxId: opts.sandboxId,
      );

      final transport = ConnectTransport(config: config, dio: client);

      return Sandbox._(
        sandboxId: opts.sandboxId,
        templateId: data['templateID']?.toString() ?? 'unknown',
        envdAccessToken: envdAccessToken,
        connectionConfig: config,
        transport: transport,
      );
    } on DioException catch (e) {
      throw SandboxException(
        'Failed to connect sandbox: ${e.message}',
        cause: e,
      );
    }
  }

  /// 刷新沙盒 TTL (keep-alive,从当前时刻重新计时)
  static Future<void> setTimeout(
    String sandboxId, {
    required String apiKey,
    required int timeoutSeconds,
    String domain = 'e2b.app',
    Dio? dio,
  }) async {
    final client = dio ?? Dio();
    final config = ConnectionConfig(apiKey: apiKey, domain: domain);
    try {
      var res = await client.post(
        '${config.apiUrl}/sandboxes/$sandboxId/timeout',
        options: Options(
          headers: config.getApiHeaders(),
          validateStatus: (status) => true,
        ),
        data: {'timeout': timeoutSeconds},
      );

      // 若因套餐限制导致超长 timeout 被 400 拒绝，自动以 3600s 降级重试
      if (res.statusCode == 400 && timeoutSeconds > 3600) {
        final serverMsg = _parseServerMessage(res.data).toLowerCase();
        if (serverMsg.contains('timeout')) {
          AppLogger.w(
            'E2B setTimeout ${timeoutSeconds}s rejected by plan limit, automatically retrying with 3600s',
          );
          res = await client.post(
            '${config.apiUrl}/sandboxes/$sandboxId/timeout',
            options: Options(
              headers: config.getApiHeaders(),
              validateStatus: (status) => true,
            ),
            data: {'timeout': 3600},
          );
        }
      }

      if (!_isSuccess(res.statusCode)) {
        _throwControlPlaneError(
          res.statusCode,
          res.data,
          'set sandbox timeout',
        );
      }
    } on DioException catch (e) {
      throw SandboxException(
        'Failed to set sandbox timeout: ${e.message}',
        cause: e,
      );
    }
  }

  /// 查询用户当前所有沙盒 (v2 端点,支持分页)
  static Future<SandboxListResult> list({
    SandboxListOpts opts = const SandboxListOpts(),
    Dio? dio,
  }) async {
    final effectiveApiKey = opts.apiKey ?? '';
    final client = dio ?? Dio();
    final config = ConnectionConfig(
      apiKey: effectiveApiKey,
      domain: opts.domain,
    );

    try {
      final res = await client.get(
        '${config.apiUrl}/v2/sandboxes',
        options: Options(
          headers: config.getApiHeaders(),
          validateStatus: (status) => true,
        ),
        queryParameters: {
          // v2 接口的 state 参数要求逗号分隔(style: form, explode: false)
          if (opts.states != null) 'state': opts.states!.join(','),
          'limit': opts.limit,
          if (opts.nextToken != null) 'nextToken': opts.nextToken,
        },
      );

      if (!_isSuccess(res.statusCode)) {
        _throwControlPlaneError(res.statusCode, res.data, 'list sandboxes');
      }

      List<Map<String, dynamic>> sandboxes;
      final data = res.data;
      if (data is List) {
        sandboxes = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (data is Map && data['sandboxes'] is List) {
        sandboxes = (data['sandboxes'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        sandboxes = [];
      }

      final nextToken = res.headers.value('x-next-token');
      return SandboxListResult(
        sandboxes: sandboxes,
        nextToken: (nextToken == null || nextToken.isEmpty) ? null : nextToken,
      );
    } on DioException catch (e) {
      throw SandboxException(
        'Failed to list sandboxes: ${e.message}',
        cause: e,
      );
    }
  }

  /// 查询用户账户下的所有沙盒模板 (GET /templates)
  static Future<List<Map<String, dynamic>>> listTemplates({
    required String apiKey,
    String domain = 'e2b.app',
    Dio? dio,
  }) async {
    final client = dio ?? Dio();
    final config = ConnectionConfig(apiKey: apiKey, domain: domain);
    try {
      final res = await client.get(
        '${config.apiUrl}/templates',
        options: Options(
          headers: config.getApiHeaders(),
          validateStatus: (status) => true,
        ),
      );

      if (!_isSuccess(res.statusCode)) {
        _throwControlPlaneError(
          res.statusCode,
          res.data,
          'list sandbox templates',
        );
      }

      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (data is Map && data['templates'] is List) {
        return (data['templates'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw SandboxException(
        'Failed to list sandbox templates: ${e.message}',
        cause: e,
      );
    }
  }

  /// 休眠沙盒 (Pause)
  static Future<void> pause(
    String sandboxId, {
    required String apiKey,
    String domain = 'e2b.app',
    Dio? dio,
  }) async {
    final client = dio ?? Dio();
    final config = ConnectionConfig(apiKey: apiKey, domain: domain);
    try {
      final res = await client.post(
        '${config.apiUrl}/sandboxes/$sandboxId/pause',
        options: Options(
          headers: config.getApiHeaders(),
          validateStatus: (status) => true,
        ),
      );
      if (!_isSuccess(res.statusCode)) {
        _throwControlPlaneError(res.statusCode, res.data, 'pause sandbox');
      }
    } on DioException catch (e) {
      throw SandboxException('Failed to pause sandbox: ${e.message}', cause: e);
    }
  }

  /// 唤醒沙盒 (Resume)
  static Future<void> resume(
    String sandboxId, {
    required String apiKey,
    String domain = 'e2b.app',
    Dio? dio,
  }) async {
    final client = dio ?? Dio();
    final config = ConnectionConfig(apiKey: apiKey, domain: domain);
    try {
      final res = await client.post(
        '${config.apiUrl}/sandboxes/$sandboxId/resume',
        options: Options(
          headers: config.getApiHeaders(),
          validateStatus: (status) => true,
        ),
      );
      if (!_isSuccess(res.statusCode)) {
        _throwControlPlaneError(res.statusCode, res.data, 'resume sandbox');
      }
    } on DioException catch (e) {
      throw SandboxException(
        'Failed to resume sandbox: ${e.message}',
        cause: e,
      );
    }
  }

  /// 销毁沙盒 (Kill / Delete)
  static Future<void> kill(
    String sandboxId, {
    required String apiKey,
    String domain = 'e2b.app',
    Dio? dio,
  }) async {
    final client = dio ?? Dio();
    final config = ConnectionConfig(apiKey: apiKey, domain: domain);
    try {
      final res = await client.delete(
        '${config.apiUrl}/sandboxes/$sandboxId',
        options: Options(
          headers: config.getApiHeaders(),
          validateStatus: (status) => true,
        ),
      );
      if (!_isSuccess(res.statusCode)) {
        _throwControlPlaneError(res.statusCode, res.data, 'kill sandbox');
      }
    } on DioException catch (e) {
      throw SandboxException('Failed to kill sandbox: ${e.message}', cause: e);
    }
  }

  // ==========================
  // 实例方法
  // ==========================

  /// 获取指定暴露端口的主机名
  String getHost(int port) => connectionConfig.getHost(sandboxId, port);

  /// 获取指定暴露端口的完整 HTTPS URL
  String getHostUrl(int port) => connectionConfig.getHostUrl(sandboxId, port);

  /// 销毁当前沙盒
  Future<void> destroy({Dio? dio}) => Sandbox.kill(
    sandboxId,
    apiKey: connectionConfig.apiKey,
    domain: connectionConfig.domain,
    dio: dio,
  );

  /// 休眠当前沙盒
  Future<void> pauseSandbox({Dio? dio}) => Sandbox.pause(
    sandboxId,
    apiKey: connectionConfig.apiKey,
    domain: connectionConfig.domain,
    dio: dio,
  );

  /// 唤醒当前沙盒
  Future<void> resumeSandbox({Dio? dio}) => Sandbox.resume(
    sandboxId,
    apiKey: connectionConfig.apiKey,
    domain: connectionConfig.domain,
    dio: dio,
  );

  /// 刷新当前沙盒 TTL (keep-alive)
  Future<void> extendTimeout(int timeoutSeconds, {Dio? dio}) =>
      Sandbox.setTimeout(
        sandboxId,
        apiKey: connectionConfig.apiKey,
        timeoutSeconds: timeoutSeconds,
        domain: connectionConfig.domain,
        dio: dio,
      );
}
