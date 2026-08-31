import 'dart:async';

/// 命令执行配置选项
class CommandOpts {
  /// 是否在后台启动并立即返回 Handle
  final bool background;

  /// 工作目录 (默认 /home/user)
  final String? cwd;

  /// 执行用户 (默认当前用户)
  final String? user;

  /// 环境变量
  final Map<String, String> envs;

  /// 标准输出实时回调
  final void Function(String stdout)? onStdout;

  /// 标准错误实时回调
  final void Function(String stderr)? onStderr;

  /// 超时时间 (毫秒，默认 60,000)
  final int timeoutMs;

  const CommandOpts({
    this.background = false,
    this.cwd,
    this.user,
    this.envs = const {},
    this.onStdout,
    this.onStderr,
    this.timeoutMs = 60000,
  });
}

/// 命令执行结果 (同步完成)
class CommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final String? error;

  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.error,
  });

  bool get isSuccess => exitCode == 0;

  @override
  String toString() =>
      'CommandResult(exitCode: $exitCode, stdout: ${stdout.length} chars, stderr: ${stderr.length} chars)';
}

/// 正在运行的后台命令句柄
class CommandHandle {
  final int pid;
  final Future<CommandResult> Function() _waiter;
  final Future<void> Function() _killer;
  final Future<void> Function(String data) _stdinSender;
  final Future<void> Function() _stdinCloser;

  CommandHandle({
    required this.pid,
    required Future<CommandResult> Function() waiter,
    required Future<void> Function() killer,
    required Future<void> Function(String data) stdinSender,
    required Future<void> Function() stdinCloser,
  })  : _waiter = waiter,
        _killer = killer,
        _stdinSender = stdinSender,
        _stdinCloser = stdinCloser;

  /// 等待命令执行完成并返回结果
  Future<CommandResult> wait() => _waiter();

  /// 终止进程 (SIGTERM / SIGKILL)
  Future<void> kill() => _killer();

  /// 向进程标准输入发送数据
  Future<void> sendStdin(String data) => _stdinSender(data);

  /// 关闭标准输入 (EOF)
  Future<void> closeStdin() => _stdinCloser();
}
