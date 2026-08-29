class OpenedFile {
  final String path;
  final String name;
  final String? worktree;
  final String? initialContent;
  int? targetLine;

  OpenedFile({
    required this.path,
    required this.name,
    this.worktree,
    this.initialContent,
    this.targetLine,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenedFile &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          worktree == other.worktree;

  @override
  int get hashCode => path.hashCode ^ (worktree?.hashCode ?? 0);
}
