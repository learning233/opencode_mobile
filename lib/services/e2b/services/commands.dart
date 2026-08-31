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
    int exitCode = 0;
    String? exitError;

    final payload = {
      'process': {
        'cmd': '/bin/bash',
        'args': ['-l', '-c', command],
        if (opts.cwd != null) 'cwd': opts.cwd,
        if (opts.user != null) 'user': opts.user,
        if (opts.envs.isNotEmpty) 'envs': opts.envs,
      },
      'stdin': false,
    };

    final stream = transport.serverStreamCall(
      sandboxId: sandboxId,
      path: '/process.Process/Start',
      request: payload,
      cancelToken: cancelToken,
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
              String text;
              try {
                text = utf8.decode(base64Decode(outBase64));
              } catch (_) {
                text = outBase64;
              }
              stdoutBuffer.write(text);
              opts.onStdout?.call(text);
            }

            if (errBase64 != null) {
              String text;
              try {
                text = utf8.decode(base64Decode(errBase64));
              } catch (_) {
                text = errBase64;
              }
              stderrBuffer.write(text);
              opts.onStderr?.call(text);
            }
          }

          // 3. end 事件 (proto 字段为 exit_code,JSON codec 下兼容 exitCode)
          if (event['end'] is Map) {
            final end = event['end'];
            exitCode = ((end['exit_code'] ?? end['exitCode']) as num?)
                    ?.toInt() ??
                0;
            exitError = end['error']?.toString();
          }
        }
      },
      onDone: completeResult,
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
