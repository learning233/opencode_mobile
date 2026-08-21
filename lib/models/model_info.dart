class ModelInfo {
  final String id;
  final String name;
  final String providerId;
  final String family;
  final String releaseDate;
  final bool supportsReasoning;
  final bool supportsImage;
  final List<String> variants;
  final int contextLimit;

  ModelInfo({
    required this.id,
    required this.name,
    this.providerId = '',
    this.family = '',
    this.releaseDate = '',
    this.supportsReasoning = false,
    this.supportsImage = false,
    this.variants = const [],
    this.contextLimit = 0,
  });

  String get key => '$providerId:$id';

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    final caps = json['capabilities'];
    final vars = json['variants'];
    final limit = json['limit'];
    final time = json['time'];
    final contextLimitVal = limit is Map ? (limit['context'] ?? 0) : 0;
    final released = time is Map ? time['released'] : null;
    final releaseDate =
        json['release_date'] as String? ??
        (released is num
            ? DateTime.fromMillisecondsSinceEpoch(
                released.toInt(),
              ).toIso8601String().substring(0, 10)
            : '');
    return ModelInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '',
      providerId: json['providerID'] as String? ?? '',
      family: json['family'] as String? ?? '',
      releaseDate: releaseDate,
      supportsReasoning: caps is Map
          ? (caps['reasoning'] as bool? ??
                (caps['input'] is List &&
                    (caps['input'] as List).contains('reasoning')))
          : false,
      supportsImage: _supportsInput(caps, 'image'),
      variants: _parseVariants(vars),
      contextLimit: (contextLimitVal as num).toInt(),
    );
  }

  /// 判断 capabilities 是否支持某输入类型。服务端返回两种形状：
  /// - models.dev 模型：`input` 为对象（如 `{text: true, image: true}`）
  /// - opencode/自定义 provider：`input` 为数组（如 `['text', 'image']`）
  static bool _supportsInput(dynamic caps, String type) {
    if (caps is! Map) return false;
    final input = caps['input'];
    if (input is List) return input.contains(type);
    if (input is Map) return input[type] == true;
    return false;
  }

  static List<String> _parseVariants(dynamic value) {
    if (value is Map) return value.keys.map((e) => e.toString()).toList();
    if (value is List) {
      return value
          .map((item) {
            if (item is Map) return item['id']?.toString() ?? '';
            return item.toString();
          })
          .where((id) => id.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
