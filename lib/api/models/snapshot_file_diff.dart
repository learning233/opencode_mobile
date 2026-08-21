/// Per-file change summary from OpenCode session snapshot diff.
///
/// Returned by `GET /session/{id}/diff?messageID=...` and stored on
/// user message `summary.diffs`.
class SnapshotFileDiff {
  final String file;
  final int additions;
  final int deletions;
  final String status;
  final String patch;

  SnapshotFileDiff({
    required this.file,
    this.additions = 0,
    this.deletions = 0,
    this.status = 'modified',
    this.patch = '',
  });

  static SnapshotFileDiff merge(SnapshotFileDiff prev, SnapshotFileDiff next) {
    var status = next.status;
    if (prev.status == 'added' && next.status != 'deleted') {
      status = 'added';
    } else if (next.status.isEmpty) {
      status = prev.status;
    }
    final patch = next.patch.isNotEmpty ? next.patch : prev.patch;
    // 无 patch 可展示时保留累加统计（无同源数据可比对）。
    if (patch.isEmpty) {
      return SnapshotFileDiff(
        file: next.file,
        additions: prev.additions + next.additions,
        deletions: prev.deletions + next.deletions,
        status: status.isNotEmpty ? status : 'modified',
        patch: patch,
      );
    }
    // 统计与展示的 patch 同源：patch 只保留最后一次，直接累加会在
    // "先 add 再 modify"时重复计数，且与展示的 hunk 不一致。改为从
    // 保留的 patch 重新计数。
    final (adds, dels) = _countPatchLines(patch);
    return SnapshotFileDiff(
      file: next.file,
      additions: adds,
      deletions: dels,
      status: status.isNotEmpty ? status : 'modified',
      patch: patch,
    );
  }

  /// 统计 patch 中的 +/- 行数（排除 `+++`/`---` 文件头），与 UI diff 渲染同源。
  static (int, int) _countPatchLines(String patch) {
    var adds = 0;
    var dels = 0;
    for (final line in patch.replaceAll('\r\n', '\n').split('\n')) {
      if (line.startsWith('+') && !line.startsWith('+++ ')) adds++;
      if (line.startsWith('-') && !line.startsWith('--- ')) dels++;
    }
    return (adds, dels);
  }

  factory SnapshotFileDiff.fromJson(Map<String, dynamic> json) {
    return SnapshotFileDiff(
      file: json['file']?.toString() ?? '',
      additions: (json['additions'] as num?)?.toInt() ?? 0,
      deletions: (json['deletions'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'modified',
      patch: json['patch']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'file': file,
    'additions': additions,
    'deletions': deletions,
    'status': status,
    if (patch.isNotEmpty) 'patch': patch,
  };

  String get displayName {
    final normalized = file.replaceAll('\\', '/');
    final parts = normalized.split('/');
    if (parts.length > 2) {
      return '${parts[parts.length - 2]}/${parts.last}';
    }
    return parts.isNotEmpty ? parts.last : file;
  }
}
