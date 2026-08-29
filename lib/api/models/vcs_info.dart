/// Data models for VCS (Git) branch info and status.
library;

/// Represents branch and basic repository metadata from `GET /vcs`.
class VcsInfo {
  final String branch;
  final String defaultBranch;
  final bool isClean;
  final List<String> branches;

  const VcsInfo({
    this.branch = '',
    this.defaultBranch = '',
    this.isClean = true,
    this.branches = const [],
  });

  factory VcsInfo.fromJson(Map<String, dynamic> json) {
    final rawBranches = json['branches'];
    final branchList = <String>[];
    if (rawBranches is List) {
      for (final b in rawBranches) {
        if (b != null) branchList.add(b.toString());
      }
    }

    return VcsInfo(
      branch: json['branch']?.toString() ?? '',
      defaultBranch:
          json['defaultBranch']?.toString() ??
          json['default_branch']?.toString() ??
          '',
      isClean: json['isClean'] as bool? ?? json['is_clean'] as bool? ?? true,
      branches: branchList,
    );
  }

  Map<String, dynamic> toJson() => {
    'branch': branch,
    'defaultBranch': defaultBranch,
    'isClean': isClean,
    'branches': branches,
  };
}

/// Represents a single changed file in `GET /vcs/status`.
class VcsStatusFile {
  final String file;
  final String status;
  final int additions;
  final int deletions;
  final bool staged;

  const VcsStatusFile({
    required this.file,
    this.status = 'modified',
    this.additions = 0,
    this.deletions = 0,
    this.staged = false,
  });

  factory VcsStatusFile.fromJson(Map<String, dynamic> json) {
    final filePath = json['file']?.toString() ?? json['path']?.toString() ?? '';
    return VcsStatusFile(
      file: filePath,
      status: json['status']?.toString().toLowerCase() ?? 'modified',
      additions: (json['additions'] as num?)?.toInt() ?? 0,
      deletions: (json['deletions'] as num?)?.toInt() ?? 0,
      staged: json['staged'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'file': file,
    'status': status,
    'additions': additions,
    'deletions': deletions,
    'staged': staged,
  };

  /// Returns true if status indicates addition / untracked file.
  bool get isAdded =>
      status == 'added' ||
      status == 'untracked' ||
      status == 'new' ||
      status == '?';

  /// Returns true if status indicates deleted file.
  bool get isDeleted =>
      status == 'deleted' || status == 'removed' || status == 'd';

  /// Returns true if status indicates modified file.
  bool get isModified => !isAdded && !isDeleted;
}
