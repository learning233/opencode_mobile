import '../utils/file_kind.dart';

class OpenedFile {
  final String path;
  final String name;
  final String? worktree;
  final FileKind kind;
  final String? initialContent;
  int? targetLine;

  OpenedFile({
    required this.path,
    required this.name,
    this.worktree,
    FileKind? kind,
    this.initialContent,
    this.targetLine,
  }) : kind = kind ?? detectFileKind(path);

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
