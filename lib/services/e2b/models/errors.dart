/// E2B SDK 异常体系
class SandboxException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic cause;

  const SandboxException(this.message, {this.statusCode, this.cause});

  @override
  String toString() =>
      'SandboxException: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

class SandboxTimeoutException extends SandboxException {
  const SandboxTimeoutException(super.message, {super.statusCode, super.cause});
}

class SandboxAuthenticationException extends SandboxException {
  const SandboxAuthenticationException(
    super.message, {
    super.statusCode,
    super.cause,
  });
}

class SandboxNotFoundException extends SandboxException {
  const SandboxNotFoundException(
    super.message, {
    super.statusCode,
    super.cause,
  });
}

class CommandExitException extends SandboxException {
  final int exitCode;
  final String stdout;
  final String stderr;

  const CommandExitException({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    String? message,
  }) : super(
         message ?? 'Command exited with non-zero code $exitCode:\n$stderr',
       );
}
