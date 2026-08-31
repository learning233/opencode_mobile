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

  /// 兼容 proto3 JSON 枚举名（FILE_TYPE_DIRECTORY 等）、数值枚举（1/2/3）与旧 HTTP 简写（dir/file/symlink）
  static EntryType _parseType(dynamic raw) {
    if (raw == null) return EntryType.unknown;
    final str = raw.toString().toLowerCase();
    if (str == '2' || str.contains('dir')) return EntryType.directory;
    if (str == '3' || str.contains('sym')) return EntryType.symlink;
    if (str == '1' || str.contains('file')) return EntryType.file;
    if (str == '0' || str.contains('unspecified')) return EntryType.unknown;
    return str.isEmpty ? EntryType.unknown : EntryType.file;
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
