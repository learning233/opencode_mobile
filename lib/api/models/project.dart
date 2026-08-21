// ── Matches SDK type: Project ──

/// Represents a project worktree registered with the OpenCode server.
///
/// Each project has a unique [id], a file-system [worktree] path,
/// optional VCS metadata, and timestamp information.
class ProjectModel {
  /// Unique project identifier assigned by the server.
  final String id;

  /// Absolute file path to the project root directory.
  final String worktree;

  /// Optional path to the VCS directory (e.g. `.git`).
  final String? vcsDir;

  /// Optional VCS type string (e.g. `"git"`).
  final String? vcs;

  /// Project creation and initialization timestamps.
  final ProjectTimeInfo time;

  ProjectModel({
    required this.id,
    required this.worktree,
    this.vcsDir,
    this.vcs,
    ProjectTimeInfo? time,
  }) : time = time ?? ProjectTimeInfo();

  /// Creates a [ProjectModel] from a JSON map returned by the server.
  ///
  /// Accepts both legacy `worktree` and current-protocol `directory`.
  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String? ?? '',
      worktree: json['worktree'] as String? ?? '',
      vcsDir: json['vcsDir'] as String?,
      vcs: json['vcs'] as String?,
      time: json['time'] != null
          ? ProjectTimeInfo.fromJson(json['time'] as Map<String, dynamic>)
          : ProjectTimeInfo(),
    );
  }

  /// Serializes this project to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'worktree': worktree,
    if (vcsDir != null) 'vcsDir': vcsDir,
    if (vcs != null) 'vcs': vcs,
    'time': time.toJson(),
  };

  /// Returns the first character (uppercased) of the last directory
  /// segment of [worktree], or `'P'` if the path is empty.
  String get initials {
    final segs = worktree
        .split(RegExp(r'[\\/]'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (segs.isNotEmpty) return segs.last[0].toUpperCase();
    return 'P';
  }

  /// Returns the last directory segment of [worktree] as a human-readable
  /// project name, or `'Project'` if the path is empty.
  String get displayName {
    final segs = worktree
        .split(RegExp(r'[\\/]'))
        .where((s) => s.isNotEmpty)
        .toList();
    return segs.isNotEmpty ? segs.last : 'Project';
  }
}

/// Timestamps for when a project was created and (optionally) first
/// initialized by the OpenCode server.
class ProjectTimeInfo {
  /// Unix timestamp (milliseconds) when the project was created.
  final int created;

  /// Unix timestamp (milliseconds) when the project was first
  /// initialized, or `null` if not yet initialized.
  final int? initialized;

  ProjectTimeInfo({this.created = 0, this.initialized});

  /// Creates [ProjectTimeInfo] from a JSON map.
  factory ProjectTimeInfo.fromJson(Map<String, dynamic> json) =>
      ProjectTimeInfo(
        created: json['created'] as int? ?? 0,
        initialized: json['initialized'] as int?,
      );

  /// Serializes this time info to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'created': created,
    if (initialized != null) 'initialized': initialized,
  };
}
