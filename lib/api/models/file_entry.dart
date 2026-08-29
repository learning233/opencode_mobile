/// Backend `GET /file` returns `{name, path, absolute, type, ignored}` (no
/// `size`). Directory `path` values carry a trailing `path.sep` appended by the
/// backend (Windows `\` / POSIX `/`); the client normalizes them away so the
/// same directory is always keyed as `src` regardless of backend platform.
class FileEntry {
  final String name;
  final String path;
  final String type; // "file" | "directory"
  final String? absolute;
  final bool ignored; // gitignore / .ignore 过滤结果

  FileEntry({
    required this.name,
    required this.path,
    required this.type,
    this.absolute,
    this.ignored = false,
  });

  bool get isDirectory => type == 'directory';

  factory FileEntry.fromJson(Map<String, dynamic> json) {
    final rawPath = (json['path'] ?? json['filePath'] ?? json['file'] ?? '')
        .toString();
    // Normalize backslashes to forward slashes, then strip a single trailing
    // separator added by the backend for directories (`src/` -> `src`).
    final normalized = rawPath
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'/$'), '');
    var rawName = (json['name'] ?? json['filename'] ?? '').toString();
    if (rawName.isEmpty && normalized.isNotEmpty) {
      final parts = normalized.split('/');
      for (var i = parts.length - 1; i >= 0; i--) {
        if (parts[i].isNotEmpty) {
          rawName = parts[i];
          break;
        }
      }
    }
    return FileEntry(
      name: rawName.isNotEmpty ? rawName : normalized,
      path: normalized,
      type: (json['type'] ?? 'file').toString(),
      absolute: json['absolute']?.toString(),
      ignored: json['ignored'] == true,
    );
  }
}
