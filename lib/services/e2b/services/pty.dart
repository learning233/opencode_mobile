import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
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
        'args': ['-l'],
        if (opts.cwd != null) 'cwd': opts.cwd,
        if (opts.user != null) 'user': opts.user,
        'envs': {
          'TERM': 'xterm-256color',
          'COLORTERM': 'truecolor',
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
    );

    stream.listen(
      (frame) {
        final map = frame.jsonMap;
        if (map == null) return;

        final event = map['event'];
        if (event is Map) {
          if (event['start'] is Map) {
            final pid = (event['start']['pid'] as num?)?.toInt() ?? 0;
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
    );

    final pid = await pidCompleter.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => 0,
    );

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
