import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/errors.dart';
import '../models/pty_models.dart';
import '../transport/connect_transport.dart';

/// E2B 伪终端服务 (对应 JS SDK Pty)
class Pty {
  final String sandboxId;
  final ConnectTransport transport;

  Pty({required this.sandboxId, required this.transport});

  /// 创建交互式 PTY 会话
  Future<PtyHandle> create({PtyOpts opts = const PtyOpts()}) async {
    final cancelToken = CancelToken();
    final pidCompleter = Completer<int>();

    final payload = {
      'process': {
        'cmd': '/bin/bash',
        'args': ['-i', '-l'],
        if (opts.cwd != null) 'cwd': opts.cwd,
        'envs': {
          'TERM': 'xterm-256color',
          'COLORTERM': 'truecolor',
          'LANG': 'C.UTF-8',
          'LC_ALL': 'C.UTF-8',
          ...opts.envs,
        },
      },
      'pty': {'size': opts.size.toJson()},
    };

    final stream = transport.serverStreamCall(
      sandboxId: sandboxId,
      path: '/process.Process/Start',
      request: payload,
      cancelToken: cancelToken,
      user: opts.user,
    );

    // 保存订阅,超时/失败/回调退出时取消,避免悬空监听占用连接
    late final StreamSubscription<ConnectFrame> sub;
    var pidReceived = false;
    sub = stream.listen(
      (frame) {
        final map = frame.jsonMap;
        if (map == null) return;

        final event = map['event'];
        if (event is Map) {
          if (event['start'] is Map) {
            final pid = (event['start']['pid'] as num?)?.toInt() ?? 0;
            pidReceived = true;
            if (!pidCompleter.isCompleted) pidCompleter.complete(pid);
          }

          if (event['data'] is Map) {
            final data = event['data'];
            final ptyBase64 = data['pty'] as String?;
            if (ptyBase64 != null) {
              final bytes = base64Decode(ptyBase64);
              opts.onData?.call(Uint8List.fromList(bytes));
            }
          }
        }
      },
      onError: (e) {
        if (!pidCompleter.isCompleted) pidCompleter.completeError(e);
      },
      onDone: () {
        // 流结束但未收到 start 事件 = PTY 启动失败
        if (!pidReceived && !pidCompleter.isCompleted) {
          pidCompleter.completeError(
            const SandboxException('PTY 创建失败: 未收到 start 事件,流已结束'),
          );
        }
      },
    );

    int pid;
    try {
      pid = await pidCompleter.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          unawaited(sub.cancel());
          throw const SandboxException('PTY 创建超时: 15 秒内未收到 start 事件');
        },
      );
    } catch (e) {
      unawaited(sub.cancel());
      rethrow;
    }

    return PtyHandle(
      pid: pid,
      inputSender: (data) => sendInput(pid, data),
      resizer: (size) => resize(pid, size),
      killer: () => kill(pid, cancelToken: cancelToken),
    );
  }

  /// 发送按键数据给 PTY
  Future<void> sendInput(int pid, Uint8List data) async {
    final base64Data = base64Encode(data);
    await transport.unaryCall(
      sandboxId: sandboxId,
      path: '/process.Process/SendInput',
      request: {
        'process': {'pid': pid},
        'input': {'pty': base64Data},
      },
    );
  }

  /// 调整终端窗口尺寸
  Future<void> resize(int pid, PtySize size) async {
    await transport.unaryCall(
      sandboxId: sandboxId,
      path: '/process.Process/Update',
      request: {
        'process': {'pid': pid},
        'pty': {'size': size.toJson()},
      },
    );
  }

  /// 终止 PTY 会话
  Future<void> kill(int pid, {CancelToken? cancelToken}) async {
    cancelToken?.cancel();
    if (pid <= 0) return;
    await transport.unaryCall(
      sandboxId: sandboxId,
      path: '/process.Process/SendSignal',
      request: {
        'process': {'pid': pid},
        'signal': 9, // SIGKILL
      },
    );
  }
}
