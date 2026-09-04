class LspServerInfo {
  final String id;
  final String name;
  final String root;
  final String status;
  final List<String> extensions;
  final String? command;
  final String? error;
  final bool disabled;

  LspServerInfo({
    required this.id,
    required this.name,
    this.root = '',
    this.status = 'unknown',
    this.extensions = const [],
    this.command,
    this.error,
    this.disabled = false,
  });

  factory LspServerInfo.fromJson(Map<String, dynamic> json) {
    final rawExt = json['extensions'];
    final extensions = rawExt is List
        ? rawExt.map((e) => e.toString()).toList()
        : const <String>[];

    return LspServerInfo(
      id: json['id']?.toString() ?? '',
      name:
          json['name']?.toString() ??
          json['id']?.toString() ??
          json['language']?.toString() ??
          'lsp',
      root: json['root']?.toString() ?? '',
      status:
          json['status']?.toString() ?? json['state']?.toString() ?? 'unknown',
      extensions: extensions,
      command: json['command']?.toString() ?? json['executable']?.toString(),
      error: json['error']?.toString(),
      disabled: json['disabled'] == true,
    );
  }

  bool get isInstalled =>
      status == 'installed' || status == 'running' || status == 'connected';
}
