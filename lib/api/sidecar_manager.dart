import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../init.dart';
import '../utils/app_logger.dart';
import '../utils/url_utils.dart';
import 'endpoints.dart';

class SidecarManager {
  static final SidecarManager instance = SidecarManager._internal();
  SidecarManager._internal();

  /// 健康检查连接超时：目标不可达时快速失败，避免 Splash 长时间阻塞。
  static const Duration healthConnectTimeout = Duration(seconds: 5);

  final Dio _healthDio = Dio();
  CancelToken? _healthCancelToken;
  int _generation = 0;

  String _baseUrl = ApiEndpoints.baseLocalUrl;
  String _username = 'opencode';
  String _password = '';
  bool _isInitialized = false;
  String _phase = 'disconnected';

  String get baseUrl => _baseUrl;
  String get username => _username;
  String get password => _password;
  bool get isInitialized => _isInitialized;
  String get phase => _phase;

  Future<({bool success, String? error})> updateConnection(
    String url,
    String username,
    String password,
  ) async {
    final generation = ++_generation;
    _healthCancelToken?.cancel();
    final cancelToken = CancelToken();
    _healthCancelToken = cancelToken;

    // 规范化服务器 URL：去掉尾斜杠，避免拼出 //api/health 之类的路径。
    var newUrl = url.trim();
    while (newUrl.endsWith('/') && newUrl.length > 1) {
      newUrl = newUrl.substring(0, newUrl.length - 1);
    }
    final newUser = username.trim();
    final newPass = password.trim();

    _setPhase('connecting');
    AppLogger.i(
      'Connecting to remote Sidecar at [${maskIpsInText(newUrl)}] as $newUser',
    );
    final result = await _pollHealthCheck(
      newUrl,
      newUser,
      newPass,
      cancelToken,
    );
    if (generation != _generation) {
      AppLogger.w(
        'updateConnection superseded by a newer connect/stop, discarding result',
      );
      return (success: false, error: null);
    }
    if (result.healthy) {
      AppLogger.i('Remote Sidecar server connection established successfully');
      // 只在健康检查通过后才提交内存态与持久化，失败保留 last-known-good。
      _baseUrl = newUrl;
      _username = newUser;
      _password = newPass;
      _isInitialized = true;
      await Global.persistServerConnection(
        url: newUrl,
        username: newUser,
        password: newPass,
      );
      _setPhase('connected');
      return (success: true, error: null);
    }
    AppLogger.e('Remote Sidecar server health check failed.');
    _setPhase('failed');
    return (success: false, error: result.error);
  }

  Future<void> stop() async {
    _generation++;
    _healthCancelToken?.cancel();
    _healthCancelToken = null;
    _isInitialized = false;
    _setPhase('disconnected');
  }

  void _setPhase(String newPhase) {
    _phase = newPhase;
  }

  /// 健康检查结果：healthy 之外带回最后一次失败的错误描述，供连接表单展示。
  /// 错误随返回值传递而非写入共享字段，避免旧一代连接的迟到响应覆盖新连接的
  /// 错误信息（跨 generation 竞态）。
  Future<({bool healthy, String? error})> _pollHealthCheck(
    String url,
    String username,
    String password,
    CancelToken cancelToken,
  ) async {
    final healthUrl = '$url/api/health';
    AppLogger.d(
      '_pollHealthCheck healthUrl=[${maskIpsInText(healthUrl)}] password.isEmpty=[${password.isEmpty}]',
    );
    final headers = <String, String>{};
    if (password.isNotEmpty) {
      final token = base64Encode(utf8.encode('$username:$password'));
      headers['Authorization'] = 'Basic $token';
    }

    String? lastError;
    int attempts = 0;
    const maxAttempts = 3;

    try {
      while (attempts < maxAttempts) {
        if (cancelToken.isCancelled) {
          return (healthy: false, error: lastError);
        }
        try {
          final response = await _healthDio.get(
            healthUrl,
            options: Options(
              headers: headers,
              validateStatus: (status) => true,
              connectTimeout: healthConnectTimeout,
              sendTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
            cancelToken: cancelToken,
          );
          if (response.statusCode == 200) {
            return (healthy: true, error: null);
          }
          if (response.statusCode == 401) {
            return (
              healthy: false,
              error: 'Authentication failed (401). Check username/password.',
            );
          }
          lastError = 'Server returned status ${response.statusCode}.';
        } catch (e) {
          if (e is DioException && CancelToken.isCancel(e)) {
            return (healthy: false, error: lastError);
          }
          final msg = e.toString();
          AppLogger.w(
            'Health check attempt $attempts failed: ${maskIpsInText(msg)}',
          );
          lastError = maskIpsInText(msg);
        }
        attempts++;
        // 最后一次尝试后不再 sleep，避免每次失败连接无谓多等 0.5s。
        if (attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      return (healthy: false, error: lastError);
    } finally {
      if (identical(cancelToken, _healthCancelToken)) {
        _healthCancelToken = null;
      }
    }
  }
}
