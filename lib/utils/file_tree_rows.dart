import '../api/models/file_entry.dart';

/// 文件树行类型，与扁平化结果一一对应。
enum FileTreeRowKind { folder, file, loading, error }

/// 文件树的一行（扁平时生成，供 ListView.builder 虚拟化渲染）。
class FileTreeRow {
  const FileTreeRow({
    required this.kind,
    this.entry,
    this.dir,
    this.depth = 0,
    this.error,
  });

  final FileTreeRowKind kind;

  /// folder / file 行的条目。
  final FileEntry? entry;

  /// loading / error 行所属的目录路径。
  final String? dir;

  final int depth;

  /// error 行的错误信息。
  final String? error;
}

/// 展开深度上限：超过后目录不再递归展开（防御极端深目录）。
const int kFileTreeMaxDepth = 8;

/// 把目录缓存 + 展开态拍平成行列表。
///
/// 语义与原递归渲染一致：
/// - 目录/文件按 `dirCache` 内顺序逐行产出，不做重排序；
/// - 目录展开时递归插入其子行，深度不超过 `maxDepth`；
/// - 目录未缓存 / 加载中 / 出错且无缓存子项时，产出一行 loading / error。
List<FileTreeRow> flattenFileTree({
  required String root,
  required Map<String, List<FileEntry>> dirCache,
  required Map<String, bool> expanded,
  required Map<String, bool> loading,
  required Map<String, String?> errors,
  int maxDepth = kFileTreeMaxDepth,
}) {
  final rows = <FileTreeRow>[];

  void visit(String dirPath, int depth) {
    if (depth > maxDepth) return;
    final isLoading = loading[dirPath] ?? false;
    final error = errors[dirPath];
    final children = dirCache[dirPath];

    if (isLoading && (children == null || children.isEmpty)) {
      rows.add(
        FileTreeRow(kind: FileTreeRowKind.loading, dir: dirPath, depth: depth),
      );
      return;
    }
    if (error != null && (children == null || children.isEmpty)) {
      rows.add(
        FileTreeRow(
          kind: FileTreeRowKind.error,
          dir: dirPath,
          depth: depth,
          error: error,
        ),
      );
      return;
    }
    if (children == null) return;

    for (final entry in children) {
      if (entry.isDirectory) {
        rows.add(
          FileTreeRow(kind: FileTreeRowKind.folder, entry: entry, depth: depth),
        );
        if (expanded[entry.path] ?? false) {
          visit(entry.path, depth + 1);
        }
      } else {
        rows.add(
          FileTreeRow(kind: FileTreeRowKind.file, entry: entry, depth: depth),
        );
      }
    }
  }

  visit(root, 0);
  return rows;
}
