enum EntryType {
  file,
  directory,
  symlink,
  unknown,
}

class EntryInfo {
  final String name;
  final String path;
  final EntryType type;
  final int size;
  final DateTime? modifiedAt;

  const EntryInfo({
    required this.name,
    required this.path,
    required this.type,
    this.size = 0,
    this.modifiedAt,
  });

  factory EntryInfo.fromJson(Map<String, dynamic> json) {
    final raw = (json['type'] ?? json['file_type'] ?? '').toString();
    final typeStr = raw.toLowerCase();
    final type = _parseType(typeStr);

    final sizeRaw = json['size'];
    final size = sizeRaw is String
        ? (int.tryParse(sizeRaw) ?? 0)
        : ((sizeRaw as num?)?.toInt() ?? 0);

    final modifiedRaw = json['modifiedTime'] ?? json['modified_time'] ?? json['modified_at'];
    return EntryInfo(
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      type: type,
      size: size,
      modifiedAt: modifiedRaw != null
          ? DateTime.tryParse(modifiedRaw.toString())
          : null,
    );
  }

  /// 兼容 proto3 JSON 枚举名（FILE_TYPE_DIRECTORY 等）与旧 HTTP 简写（dir/file/symlink）
  static EntryType _parseType(String typeStr) {
    if (typeStr.contains('dir')) return EntryType.directory;
    if (typeStr.contains('sym')) return EntryType.symlink;
    if (typeStr.contains('file')) return EntryType.file;
    if (typeStr.contains('unspecified')) return EntryType.unknown;
    return typeStr.isEmpty ? EntryType.unknown : EntryType.file;
  }
}

enum FilesystemEventType {
  create,
  write,
  remove,
  rename,
}

class FilesystemEvent {
  final String path;
  final FilesystemEventType type;

  const FilesystemEvent({required this.path, required this.type});
}
