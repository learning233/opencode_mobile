import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/errors.dart';
import '../models/process_models.dart';
import '../transport/connect_transport.dart';

/// E2B 进程命令执行服务 (对应 JS SDK Commands)
class Commands {
  final String sandboxId;
  final ConnectTransport transport;

  Commands({required this.sandboxId, required this.transport});

  /// 启动命令并等待执行结束，返回 CommandResult
  Future<CommandResult> run(
    String command, {
    CommandOpts opts = const CommandOpts(),
  }) async {
    final handle = await start(command, opts: opts);
    final result = await handle.wait();
    if (!result.isSuccess) {
      throw CommandExitException(
        exitCode: result.exitCode,
        stdout: result.stdout,
        stderr: result.stderr,
        message: result.error,
      );
    }
    return result;
  }

  /// 解析 end 事件的退出码。当前 envd 在 `status` 字符串里返回
  /// (如 "exit status 3"),`exit_code` 已废弃且服务端不保证填充。
  static int _parseExitCode(Map<dynamic, dynamic> end) {
    final explicit = end['exit_code'] ?? end['exitCode'];
    if (explicit is num) return explicit.toInt();
    if (explicit is String) {
      final parsed = int.tryParse(explicit);
      if (parsed != null) return parsed;
    }
    final status = end['status']?.toString();
    if (status != null) {
      final match = RegExp(r'exit status (\d+)').firstMatch(status);
      if (match != null) {
        return int.tryParse(match.group(1)!) ?? 0;
      }
    }
    return 0;
  }

  /// 异步在沙盒内启动新进程，返回 CommandHandle。
  ///
  /// [CommandOpts.background] 为 true 时(对齐官方 JS SDK 语义):
  /// 收到 start 事件拿到 pid 后立即脱离事件流并返回,进程由 envd 托管继续运行,
  /// 断开监听不会终止进程。
  Future<CommandHandle> start(
    String command, {
    CommandOpts opts = const CommandOpts(),
  }) async {
    final cancelToken = CancelToken();
    final completer = Completer<CommandResult>();

    int? processPid;
    final pidCompleter = Completer<int>();

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    // 增量 UTF-8 解码：使用自定义 _StreamingTextSink 保证实时吐出每个解码分块，
    // 同时跨帧的不完整多字节 UTF-8 序列由 Utf8Decoder 内部缓冲，避免产生 U+FFFD。
    final stdoutByteSink = utf8.decoder.startChunkedConversion(
      _StreamingTextSink((text) {
        stdoutBuffer.write(text);
        opts.onStdout?.call(text);
      }),
    );

    final stderrByteSink = utf8.decoder.startChunkedConversion(
      _StreamingTextSink((text) {
        stderrBuffer.write(text);
        opts.onStderr?.call(text);
      }),
    );
    int exitCode = 0;
    String? exitError;
    bool sawEndEvent = false;
    bool sawEndStream = false;

    final payload = {
      'process': {
        'cmd': '/bin/bash',
        'args': ['-l', '-c', command],
        if (opts.cwd != null) 'cwd': opts.cwd,
        if (opts.envs.isNotEmpty) 'envs': opts.envs,
      },
      'stdin': false,
    };

    final stream = transport.serverStreamCall(
      sandboxId: sandboxId,
      path: '/process.Process/Start',
      request: payload,
      cancelToken: cancelToken,
      user: opts.user,
    );

    void completeResult() {
      if (!pidCompleter.isCompleted) {
        pidCompleter.complete(processPid ?? 0);
      }
      if (!completer.isCompleted) {
        completer.complete(
          CommandResult(
            exitCode: exitCode,
            stdout: stdoutBuffer.toString(),
            stderr: stderrBuffer.toString(),
            error: exitError,
          ),
        );
      }
    }

    final sub = stream.listen(
      (frame) {
        // 0x02 尾帧:Connect trailer,可能携带服务端错误 {code,message}/{error}
        if (frame.flag == ConnectFrameFlag.endOfStream) {
          sawEndStream = true;
          final trailer = frame.jsonMap;
          final trailerError = trailer?['error'] ?? trailer?['message'];
          if (trailerError != null && trailerError.toString().trim().isNotEmpty) {
            exitError = 'envd 流式调用错误: $trailerError';
          }
          return;
        }

        final map = frame.jsonMap;
        if (map == null) return;

        final event = map['event'];
        if (event is Map) {
          // 1. start 事件
          if (event['start'] is Map) {
            final pid = (event['start']['pid'] as num?)?.toInt() ?? 0;
            processPid = pid;
            if (!pidCompleter.isCompleted) pidCompleter.complete(pid);
          }

          // 2. data 事件 (stdout / stderr / pty)
          if (event['data'] is Map) {
            final data = event['data'];
            final outBase64 = data['stdout'] as String?;
            final errBase64 = data['stderr'] as String?;

            if (outBase64 != null) {
              try {
                final bytes = base64Decode(outBase64);
                stdoutByteSink.add(bytes);
              } catch (_) {
                stdoutBuffer.write(outBase64);
                opts.onStdout?.call(outBase64);
              }
            }

            if (errBase64 != null) {
              try {
                final bytes = base64Decode(errBase64);
                stderrByteSink.add(bytes);
              } catch (_) {
                stderrBuffer.write(errBase64);
                opts.onStderr?.call(errBase64);
              }
            }
          }

          // 3. end 事件:优先解析当前规范的 status 字符串,兼容旧 exit_code/exitCode
          if (event['end'] is Map) {
            final end = event['end'];
            sawEndEvent = true;
            exitCode = _parseExitCode(end);
            exitError = end['error']?.toString();
          }
        }
      },
      onDone: () {
        // 冲刷残留的多字节 UTF-8 序列
        try {
          stdoutByteSink.close();
        } catch (_) {}
        try {
          stderrByteSink.close();
        } catch (_) {}
        // 流结束但从未收到 end 事件 = 命令未正常完成,不能静默按成功处理
        if (exitError == null && !sawEndEvent) {
          exitError = sawEndStream
              ? '进程流在收到 end 事件前被服务端关闭'
              : '进程流异常结束,未收到 end 事件';
        }
        completeResult();
      },
      onError: (Object e) {
        if (!pidCompleter.isCompleted) pidCompleter.completeError(e);
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    // 等待分配 PID 或超时
    final pid = await pidCompleter.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => 0,
    );

    if (opts.background) {
      // 后台模式:拿到 PID 后脱离事件流,进程不会被终止
      await sub.cancel();
      completeResult();
    }

    Future<CommandResult> waiter() {
      var fut = completer.future;
      if (!opts.background && opts.timeoutMs > 0) {
        fut = fut.timeout(
          Duration(milliseconds: opts.timeoutMs),
          onTimeout: () {
            // 超时终止远端进程并返回已收集的输出
            kill(pid, cancelToken: cancelToken).catchError((_) {});
            return CommandResult(
              exitCode: -1,
              stdout: stdoutBuffer.toString(),
              stderr: stderrBuffer.toString(),
              error: '命令执行超时 (${opts.timeoutMs}ms)',
            );
          },
        );
      }
      return fut;
    }

    return CommandHandle(
      pid: pid,
      waiter: waiter,
      killer: () => kill(pid, cancelToken: cancelToken),
      stdinSender: (data) => sendStdin(pid, data),
      stdinCloser: () => closeStdin(pid),
    );
  }

  /// 发送终止信号 (SIGTERM=15 / SIGKILL=9)
  Future<void> kill(int pid, {int signal = 15, CancelToken? cancelToken}) async {
    cancelToken?.cancel();
    if (pid <= 0) return;

    await transport.unaryCall(
      sandboxId: sandboxId,
      path: '/process.Process/SendSignal',
      request: {
        'process': {'pid': pid},
        'signal': signal,
      },
    );
  }

  /// 向进程输入 stdin 数据
  Future<void> sendStdin(int pid, String data) async {
    final base64Data = base64Encode(utf8.encode(data));
    await transport.unaryCall(
      sandboxId: sandboxId,
      path: '/process.Process/SendInput',
      request: {
        'process': {'pid': pid},
        'input': {'stdin': base64Data},
      },
    );
  }

  /// 关闭标准输入 (EOF)
  Future<void> closeStdin(int pid) async {
    await transport.unaryCall(
      sandboxId: sandboxId,
      path: '/process.Process/CloseStdin',
      request: {
        'process': {'pid': pid},
      },
    );
  }
}

/// 增量流式文本解码接收器，对每个就绪的文本分块实时触发回调
class _StreamingTextSink implements Sink<String> {
  final void Function(String chunk) onChunk;
  _StreamingTextSink(this.onChunk);

  @override
  void add(String data) {
    if (data.isNotEmpty) {
      onChunk(data);
    }
  }

  @override
  void close() {}
}
