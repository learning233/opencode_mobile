/// Prepends `https://` to a URL input when it has no scheme, and trims.
/// Returns an empty string when [urlInput] is blank.
String normalizeWebUrl(String urlInput) {
  String input = urlInput.trim();
  if (input.isEmpty) return '';
  if (!input.startsWith('http://') && !input.startsWith('https://')) {
    input = 'https://$input';
  }
  return input;
}

/// 规范化 opencode 服务器地址输入：trim、无 scheme 时补 `http://`（本地服务
/// 不会是 https）、剥离路径/查询/锚点——opencode serve 挂载在根路径，误填
/// `http://host:4096/api/health` 之类的整路径会导致健康检查 404。
/// 返回 null 表示无法解析出有效 host（如 `http://` 单独存在）。
String? normalizeServerUrl(String urlInput) {
  var input = urlInput.trim();
  if (input.isEmpty) return null;
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(input)) {
    input = 'http://$input';
  }
  final uri = Uri.tryParse(input);
  if (uri == null || uri.host.isEmpty) return null;
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme.toLowerCase()}://${uri.host}$port';
}

/// Slash-insensitive comparison key for URL dedup: same as [normalizeWebUrl]
/// but with a single trailing `/` stripped, so `http://host:port` and
/// `http://host:port/` (e.g. a preview page that redirects with a trailing
/// slash) are treated as the same tab. Returns empty when [urlInput] is blank.
String webUrlDedupKey(String urlInput) {
  var normalized = normalizeWebUrl(urlInput);
  if (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

/// Builds a preview URL from a connected server URL and a bound port.
///
/// Extracts `scheme://host` from [serverUrl] (e.g. `http://192.168.1.100:4096`)
/// and returns `http://192.168.1.100:<port>`. Returns null when the server URL
/// cannot be parsed, [port] is blank, or [port] is not a valid integer in the
/// range 1–65535.
String? buildPreviewUrl(String serverUrl, String port) {
  final cleaned = port.trim();
  if (cleaned.isEmpty) return null;
  final portNum = int.tryParse(cleaned);
  if (portNum == null || portNum < 1 || portNum > 65535) return null;

  final uri = Uri.tryParse(normalizeWebUrl(serverUrl));
  if (uri == null || uri.host.isEmpty) return null;

  final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme;
  return '$scheme://${uri.host}:$portNum';
}

/// Masks IPv4 addresses in a URL (each octet's first char → `*`), keeping
/// localhost and domain names intact. Returns [url] unchanged when it cannot
/// be parsed.
String maskUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final host = uri.host;
  final octets = host.split('.');
  if (octets.length == 4 && octets.every((o) => int.tryParse(o) != null)) {
    final masked = octets
        .map((o) => o.length > 1 ? '*${o.substring(1)}' : '*')
        .join('.');
    return uri.replace(host: masked).toString();
  }
  return url;
}

final _ipv4RegExp = RegExp(r'\b(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\b');

/// Masks every IPv4 address found inside arbitrary text (each octet's first
/// char → `*`). Used for log/error strings that may embed full URLs.
/// Non-IP text is returned unchanged.
String maskIpsInText(String text) {
  return text.replaceAllMapped(_ipv4RegExp, (m) {
    final octets = m.group(0)!.split('.');
    return octets
        .map((o) => o.length > 1 ? '*${o.substring(1)}' : '*')
        .join('.');
  });
}
