/// E2B 沙盒模板信息模型
class E2bTemplateInfo {
  const E2bTemplateInfo({
    required this.templateId,
    this.buildId = '',
    this.cpuCount = 2,
    this.memoryMB = 2048,
    this.diskSizeMB = 0,
    this.isPublic = false,
    this.aliases = const [],
    this.names = const [],
    this.buildStatus = 'ready',
    this.createdAt,
    this.updatedAt,
  });

  final String templateId;
  final String buildId;
  final int cpuCount;
  final int memoryMB;
  final int diskSizeMB;
  final bool isPublic;
  final List<String> aliases;
  final List<String> names;
  final String buildStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 模板优先展示名称 (优先取 alias/name，否则取 templateId)
  String get displayName {
    if (aliases.isNotEmpty && aliases.first.trim().isNotEmpty) {
      return aliases.first.trim();
    }
    if (names.isNotEmpty && names.first.trim().isNotEmpty) {
      return names.first.trim();
    }
    return templateId;
  }

  factory E2bTemplateInfo.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return const [];
    }

    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      try {
        return DateTime.tryParse(raw.toString());
      } catch (_) {
        return null;
      }
    }

    return E2bTemplateInfo(
      templateId: (json['templateID'] ?? json['templateId'] ?? json['id'] ?? '')
          .toString(),
      buildId: (json['buildID'] ?? json['buildId'] ?? '').toString(),
      cpuCount: (json['cpuCount'] as num?)?.toInt() ?? 2,
      memoryMB: (json['memoryMB'] as num?)?.toInt() ?? 2048,
      diskSizeMB: (json['diskSizeMB'] as num?)?.toInt() ?? 0,
      isPublic: json['public'] == true,
      aliases: parseStringList(json['aliases']),
      names: parseStringList(json['names']),
      buildStatus: (json['buildStatus'] ?? 'ready').toString(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'templateID': templateId,
    'buildID': buildId,
    'cpuCount': cpuCount,
    'memoryMB': memoryMB,
    'diskSizeMB': diskSizeMB,
    'public': isPublic,
    'aliases': aliases,
    'names': names,
    'buildStatus': buildStatus,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}
