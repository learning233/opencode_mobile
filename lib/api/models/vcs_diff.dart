/// Represents a diff for a single file in a version control system (e.g. git).
///
/// Contains the file path, unified diff patch content, and line statistics
/// returned by the backend for display in the diff editor view.
class VcsFileDiff {
  /// Relative file path within the repository.
  final String file;

  /// Unified diff patch content (additions prefixed with `+`, deletions with `-`).
  final String patch;

  /// Number of lines added in this diff.
  final int additions;

  /// Number of lines deleted in this diff.
  final int deletions;

  /// Git status of the file: "modified", "added", "deleted", "renamed", etc.
  final String status;

  VcsFileDiff({
    required this.file,
    this.patch = '',
    this.additions = 0,
    this.deletions = 0,
    this.status = 'modified',
  });

  /// Creates a [VcsFileDiff] from a JSON map returned by the backend API.
  factory VcsFileDiff.fromJson(Map<String, dynamic> json) {
    return VcsFileDiff(
      file: json['file'] as String? ?? '',
      patch: json['patch'] as String? ?? '',
      additions: (json['additions'] as num?)?.toInt() ?? 0,
      deletions: (json['deletions'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'modified',
    );
  }

  /// Serializes this diff to a JSON map for the backend API.
  Map<String, dynamic> toJson() => {
    'file': file,
    'patch': patch,
    'additions': additions,
    'deletions': deletions,
    'status': status,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VcsFileDiff &&
          file == other.file &&
          status == other.status &&
          additions == other.additions &&
          deletions == other.deletions;

  @override
  int get hashCode => Object.hash(file, status, additions, deletions);
}
