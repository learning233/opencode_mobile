import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../utils/app_logger.dart';
import '../utils/url_utils.dart';
import 'models/event.dart';
import 'opencode_client.dart';

/// Callback type for receiving parsed SSE events.
typedef SseEventHandler = void Function(SseEvent event);

/// Callback type for connection status changes (connected/disconnected).
typedef SseStatusCallback = void Function(bool connected);

/// Callback type for SSE connection errors.
typedef SseErrorCallback = void Function(dynamic error);

/// Server-Sent Events (SSE) client for receiving real-time events from the
/// OpenCode sidecar server.
///
/// Maintains a persistent HTTP connection using chunked transfer encoding.
/// On connection loss, automatically reconnects with exponential backoff
/// (1s, 2s, 4s, 8s, 16s) for the first [_maxReconnectAttempts] failures, then
/// keeps retrying every [_slowRetryIntervalSeconds] seconds until the
/// connection is restored or [dispose] is called — a network drop never kills
/// the stream permanently.
///
/// - 401/403 (credential) failures stop reconnection immediately; check
///   [isCredentialFailed]. Once set on an instance it never auto-recovers —
///   consumers must create a new [SseClient] (e.g. via `_connectSse`) after
///   the user fixes credentials.
/// - [disconnect] is a graceful stop: it cancels the request and any pending
///   reconnect timer. Call [connect] again to resume.
/// - [dispose] permanently stops reconnection and closes the stream.
class SseClient {
  final OpenCodeClient _client;
  final String _path;
  final StreamController<SseEvent> _controller = StreamController.broadcast();
  CancelToken? _cancelToken;
  bool _connected = false;
  bool _connecting = false;
  bool _disposed = false;
  bool _manuallyDisconnected = false;
  bool _credentialFailed = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  /// Fast exponential-backoff attempts before falling back to slow retry.
  /// Derived from [_fastDelays] so the two can never drift apart.
  static final int _maxReconnectAttempts = _fastDelays.length;

  /// Interval (seconds) between retries after fast backoff is exhausted.
  static const int _slowRetryIntervalSeconds = 30;

  /// Fast backoff delays (seconds), indexed by attempt number (1-based).
  static const List<int> _fastDelays = [1, 2, 4, 8, 16];

  /// Called when connection status changes.
  SseStatusCallback? onStatusChange;

  /// Called when a connection error occurs.
  SseErrorCallback? onError;

  /// Optional query params added to SSE URL (e.g. directory, workspace).
  Map<String, dynamic> queryParams = {};

  /// Creates an SSE client bound to the given HTTP client and endpoint path.
  SseClient(this._client, this._path);

  /// A broadcast stream of parsed [SseEvent] objects received from the server.
  Stream<SseEvent> get stream => _controller.stream;

  /// Whether the SSE connection is currently established.
  bool get isConnected => _connected;

  /// Whether a connection attempt is currently in flight.
  bool get isConnecting => _connecting;

  /// Number of consecutive failed attempts since the last successful connect.
  int get reconnectAttempts => _reconnectAttempts;

  /// True after a credential failure (401/403); reconnection has been stopped.
  bool get isCredentialFailed => _credentialFailed;

  /// Opens an SSE connection to the server.
  /// Parses incoming text/event-stream data into [SseEvent] objects and adds
  /// them to [stream]. Automatically reconnects on failure unless [dispose]
  /// has been called or the failure is a credential error.
  Future<void> connect() async {
    if (_connected || _connecting || _disposed || _credentialFailed) return;
    _connecting = true;
    _manuallyDisconnected = false;
    _cancelToken = CancelToken();

    // 响应流是否无异常自然结束（服务端优雅关闭）。异常路径会置 false，
    // 正常结束（无 catch 计入失败）时用于补计一次失败，走快速退避。
    var hadCleanClose = true;

    try {
      final response = await _client.dio.get(
        _path,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
          receiveTimeout: const Duration(days: 1),
        ),
        cancelToken: _cancelToken,
      );

      // 在途 connect 与 disconnect/dispose 竞争：请求虽已返回，但若已被取消
      // 或已销毁，不能再宣称已连接，否则消费端会误触发重连刷新（如切项目时
      // 对旧连接 _refreshAfterReconnect）。此时直接放弃本连接，交给 finally 清理。
      if (_disposed || (_cancelToken?.isCancelled ?? false)) return;

      _connected = true;
      _reconnectAttempts = 0;
      _credentialFailed = false;
      onStatusChange?.call(true);

      final stream = response.data.stream as Stream<Uint8List>;
      final lines = utf8.decoder.bind(stream).transform(const LineSplitter());

      final buffer = StringBuffer();
      await for (final line in lines) {
        if (_cancelToken?.isCancelled ?? false) break;

        if (line.startsWith('id:') ||
            line.startsWith('event:') ||
            line.startsWith('data:') ||
            line.startsWith('retry:')) {
          buffer.writeln(line);
        } else if (line.trim().isEmpty && buffer.isNotEmpty) {
          final raw = buffer.toString();
          buffer.clear();
          try {
            final event = SseEvent.parse(raw);
            _controller.add(event);
          } catch (e) {
            AppLogger.e('SSE parse error', e);
          }
        }
      }
    } catch (e) {
      // 主动取消（disconnect/dispose 触发）不计入失败次数。
      if (e is DioException && CancelToken.isCancel(e)) return;
      // 凭据失效（401/403）无法靠重连恢复，停止重连并交由消费端提示。
      if (_isCredentialError(e)) {
        _credentialFailed = true;
        AppLogger.e(
          'SSE credential failed (401/403), reconnection stopped: ${maskIpsInText('$e')}',
        );
        onError?.call(e);
        return;
      }
      // 异常断开：失败计数已在 catch 中自增，无需重复计入，标记非干净关闭。
      hadCleanClose = false;
      _reconnectAttempts++;
      if (_reconnectAttempts <= 3) {
        AppLogger.e(
          'SSE connection error (attempt $_reconnectAttempts): ${maskIpsInText('$e')}',
        );
      }
      onError?.call(e);
    } finally {
      // 捕获断开前的连接状态，仅在"已连接→断开"跳变时回调 false：
      // 重试失败（本就未连上）与手动断开都不再重复通知，避免消费端
      // 在慢重试阶段每 30s 弹一次断线提示。
      final wasConnected = _connected;
      _connecting = false;
      _connected = false;
      // dispose() 已经把 _disposed 置 true，这里不要在 dispose 后再回调，
      // 否则监听器可能在 widget 已卸载后触发 setState。
      if (!_disposed && wasConnected) onStatusChange?.call(false);
      // 未手动断开、未凭据失败时才继续重连；超过快速退避次数后进入低频慢重试。
      if (!_disposed && !_manuallyDisconnected && !_credentialFailed) {
        // 响应流无异常自然结束（服务端优雅关闭）也算一次失败，走 1s 快速退避，
        // 否则 `_reconnectAttempts` 保持 0，会直接取 30s 慢重试。
        if (hadCleanClose) {
          _reconnectAttempts++;
        }
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    // 快速退避档位与 _maxReconnectAttempts 对齐（由 _fastDelays 派生，不会漂移），
    // 超出则转慢重试。
    final seconds =
        _reconnectAttempts > 0 && _reconnectAttempts <= _maxReconnectAttempts
        ? _fastDelays[_reconnectAttempts - 1]
        : _slowRetryIntervalSeconds;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (!_disposed && !_manuallyDisconnected && !_credentialFailed) {
        connect();
      }
    });
  }

  static bool _isCredentialError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      return code == 401 || code == 403;
    }
    return false;
  }

  /// Gracefully disconnects the SSE connection.
  /// Cancels the pending request, stops the reconnect timer, and marks the
  /// client as manually disconnected so no further auto-reconnect happens
  /// until [connect] is called again.
  ///
  /// Note: during [dispose] this won't fire [onStatusChange(false)] (guarded
  /// by [_disposed]), so teardown paths like project switch / connection
  /// re-init don't emit a misleading "disconnected" toast. Standalone manual
  /// disconnect still notifies once.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _cancelToken?.cancel();
    _connected = false;
    _connecting = false;
    _manuallyDisconnected = true;
    if (!_disposed) onStatusChange?.call(false);
  }

  /// Permanently disposes the SSE client.
  /// Sets the disposed flag to prevent future reconnection, closes the stream
  /// controller, and disconnects any active connection.
  void dispose() {
    _disposed = true;
    disconnect();
    _controller.close();
  }
}
