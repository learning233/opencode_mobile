class QuickPhraseItem {
  final String name;
  final String template;
  final String description;
  final String agent;
  final String model;
  final bool isSystem;

  QuickPhraseItem({
    required this.name,
    required this.template,
    this.description = '',
    this.agent = '',
    this.model = '',
    this.isSystem = false,
  });

  factory QuickPhraseItem.fromRaw(dynamic raw) {
    if (raw is Map) {
      return QuickPhraseItem(
        name: raw['name']?.toString() ?? '',
        template: raw['template']?.toString() ?? '',
        description: raw['description']?.toString() ?? '',
        agent: raw['agent']?.toString() ?? '',
        model: raw['model']?.toString() ?? '',
        isSystem: raw['isSystem'] == true,
      );
    }
    return QuickPhraseItem(name: '', template: raw?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'template': template,
    if (description.isNotEmpty) 'description': description,
    if (agent.isNotEmpty) 'agent': agent,
    if (model.isNotEmpty) 'model': model,
    if (isSystem) 'isSystem': true,
  };

  static List<QuickPhraseItem> listFromRaw(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => QuickPhraseItem.fromRaw(e)).toList();
    }
    return [];
  }
}
