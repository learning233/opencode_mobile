class McpServerStatus {
  final String name;
  final String status;
  final String? error;
  final String type;
  final String? command;
  final String? url;
  final List<String> tools;
  final Map<String, String> env;
  final Map<String, String> headers;

  McpServerStatus({
    required this.name,
    required this.status,
    this.error,
    this.type = '',
    this.command,
    this.url,
    this.tools = const [],
    this.env = const {},
    this.headers = const {},
  });

  factory McpServerStatus.fromEntry(String name, dynamic raw) {
    if (raw is Map) {
      final statusField = raw['status'];
      String status;
      String? error;
      if (statusField is Map) {
        status = statusField['status']?.toString() ?? 'unknown';
        error = statusField['error']?.toString() ?? raw['error']?.toString();
      } else {
        status =
            statusField?.toString() ?? raw['state']?.toString() ?? 'unknown';
        error = raw['error']?.toString();
      }

      final cmdRaw = raw['command'];
      String? command;
      if (cmdRaw is List) {
        command = cmdRaw.map((e) => e.toString()).join(' ');
      } else if (cmdRaw != null) {
        command = cmdRaw.toString();
      }

      final toolsRaw = raw['tools'];
      final tools = <String>[];
      if (toolsRaw is List) {
        for (final t in toolsRaw) {
          if (t is Map) {
            final n = t['name']?.toString() ?? t['id']?.toString();
            if (n != null && n.isNotEmpty) tools.add(n);
          } else if (t != null) {
            tools.add(t.toString());
          }
        }
      }

      final envRaw = raw['env'] ?? raw['environment'];
      final env = <String, String>{};
      if (envRaw is Map) {
        envRaw.forEach((k, v) {
          if (v != null) env[k.toString()] = v.toString();
        });
      }

      final headersRaw = raw['headers'];
      final headers = <String, String>{};
      if (headersRaw is Map) {
        headersRaw.forEach((k, v) {
          if (v != null) headers[k.toString()] = v.toString();
        });
      }

      return McpServerStatus(
        name: raw['name']?.toString() ?? name,
        status: status,
        error: error,
        type: raw['type']?.toString() ?? raw['transport']?.toString() ?? '',
        command: command,
        url: raw['url']?.toString(),
        tools: tools,
        env: env,
        headers: headers,
      );
    }
    return McpServerStatus(name: name, status: raw?.toString() ?? 'unknown');
  }

  bool get isConnected =>
      status == 'connected' || status == 'enabled' || status == 'running';
}
