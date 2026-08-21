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
