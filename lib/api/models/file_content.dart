/// Parsed `GET /file/content` response body.
///
/// Backend returns either:
/// - text: `{type:"text", content: text.value.trim()}`
/// - binary: `{type:"binary", content: <base64>, encoding:"base64", mimeType}`
class FileContent {
  final String type; // "text" | "binary"
  final String content;
  final String? encoding;
  final String? mimeType;

  const FileContent({
    required this.type,
    required this.content,
    this.encoding,
    this.mimeType,
  });

  bool get isBinary => type == 'binary';

  factory FileContent.parse(dynamic data) {
    if (data is Map) {
      final type = (data['type'] as String?) ?? 'text';
      final content = (data['content'] ?? data['data'] ?? '').toString();
      return FileContent(
        type: type,
        content: content,
        encoding: data['encoding']?.toString(),
        mimeType: data['mimeType']?.toString(),
      );
    }
    if (data is String) {
      return FileContent(type: 'text', content: data);
    }
    return const FileContent(type: 'text', content: '');
  }
}
