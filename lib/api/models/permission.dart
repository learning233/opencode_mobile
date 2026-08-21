/// A pending permission request from the AI agent, awaiting user approval.
class PendingPermission {
  final String id;
  final String sessionID;

  /// Permission type: 'read', 'write', 'edit', 'bash', 'web', or 'webfetch'.
  final String type;

  /// File patterns or paths this permission applies to.
  final List<String> patterns;

  final Map<String, dynamic> metadata;

  /// Patterns the user has chosen to always allow for the current session.
  final List<String> always;

  PendingPermission({
    required this.id,
    required this.sessionID,
    required this.type,
    required this.patterns,
    this.metadata = const {},
    this.always = const [],
  });

  /// Creates a [PendingPermission] from an SSE event properties map.
  factory PendingPermission.fromEvent(Map<String, dynamic> props) {
    final rawPatterns = props['patterns'];
    final rawAlways = props['always'];
    return PendingPermission(
      id: props['id']?.toString() ?? '',
      sessionID: props['sessionID']?.toString() ?? '',
      type: props['permission']?.toString() ?? props['type']?.toString() ?? '',
      patterns: rawPatterns is List
          ? rawPatterns.map((e) => e.toString()).toList()
          : rawPatterns is String
          ? [rawPatterns]
          : [],
      metadata: props['metadata'] is Map
          ? Map<String, dynamic>.from(props['metadata'] as Map)
          : const {},
      always: rawAlways is List
          ? rawAlways.map((e) => e.toString()).toList()
          : const [],
    );
  }

  String get displayPattern => patterns.isNotEmpty ? patterns.join(', ') : '';

  String get displayType => type.isNotEmpty ? type : 'permission';
}
