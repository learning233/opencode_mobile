/// E2B 沙盒实例数据模型
class E2bSandboxInfo {
  const E2bSandboxInfo({
    required this.sandboxId,
    required this.templateId,
    this.alias = '',
    required this.state,
    this.startedAt,
    this.endAt,
    this.cpuCount = 2,
    this.memoryMB = 2048,
    this.metadata = const {},
  });

  final String sandboxId;
  final String templateId;
  final String alias;
  final String state; // 'running', 'paused', 'stopped'
  final DateTime? startedAt;
  final DateTime? endAt;
  final int cpuCount;
  final int memoryMB;
  final Map<String, dynamic> metadata;

  bool get isRunning => state.toLowerCase() == 'running';
  bool get isPaused => state.toLowerCase() == 'paused';

  String get repoName => metadata['repo']?.toString() ?? '';
  String get endpointUrl => 'https://4096-$sandboxId.e2b.app';

  factory E2bSandboxInfo.fromJson(Map<String, dynamic> json) {
    return E2bSandboxInfo(
      sandboxId: (json['sandboxID'] ?? json['sandboxId'] ?? json['id'] ?? '')
          .toString(),
      templateId: (json['templateID'] ?? json['templateId'] ?? json['template'] ?? '')
          .toString(),
      alias: json['alias']?.toString() ?? '',
      state: (json['state'] ?? json['status'] ?? 'running').toString(),
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      endAt: json['endAt'] != null
          ? DateTime.tryParse(json['endAt'].toString())
          : null,
      cpuCount: (json['cpuCount'] as num?)?.toInt() ?? 2,
      memoryMB: (json['memoryMB'] as num?)?.toInt() ?? 2048,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sandboxID': sandboxId,
      'templateID': templateId,
      'alias': alias,
      'state': state,
      'startedAt': startedAt?.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'cpuCount': cpuCount,
      'memoryMB': memoryMB,
      'metadata': metadata,
    };
  }
}
