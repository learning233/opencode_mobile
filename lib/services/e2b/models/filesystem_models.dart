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
    final typeStr = (json['type'] ?? json['file_type'] ?? '').toString().toLowerCase();
    final type = typeStr.contains('dir')
        ? EntryType.directory
        : (typeStr.contains('sym') ? EntryType.symlink : EntryType.file);

    return EntryInfo(
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      type: type,
      size: (json['size'] as num?)?.toInt() ?? 0,
      modifiedAt: json['modified_at'] != null
          ? DateTime.tryParse(json['modified_at'].toString())
          : null,
    );
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
