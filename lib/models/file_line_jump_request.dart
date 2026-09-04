class FileLineJumpRequest {
  final String path;
  final String? worktree;
  final int line;
  final int timestamp;

  const FileLineJumpRequest({
    required this.path,
    this.worktree,
    required this.line,
    required this.timestamp,
  });
}
