import 'message.dart';
import 'snapshot_file_diff.dart';

/// Abstract parser model for converting tool call parts into [SnapshotFileDiff] objects.
abstract class ToolDiffParser {
  /// Parses a tool [part] based on its tool type and returns extracted file diffs.
  static List<SnapshotFileDiff> parse(Part part) {
    if (part.type != PartType.tool) return const [];
    if (part.toolStatus == ToolStateStatus.error) return const [];

    final tool = part.toolName.toLowerCase();
    switch (tool) {
      case 'edit':
      case 'write':
        return SingleFileToolDiffParser().parsePart(part);
      case 'apply_patch':
      case 'patch':
        return BatchPatchToolDiffParser().parsePart(part);
      default:
        return const [];
    }
  }

  /// Parses the specified tool [part] and extracts file diff models.
  List<SnapshotFileDiff> parsePart(Part part);
}

/// Parser model for single-file tools (`edit`, `write`).
class SingleFileToolDiffParser extends ToolDiffParser {
  @override
  List<SnapshotFileDiff> parsePart(Part part) {
    final tool = part.toolName.toLowerCase();
    final metadata = part.toolMetadata ?? const <String, dynamic>{};
    final input = part.toolInput;

    final filediff = metadata['filediff'] is Map
        ? metadata['filediff'] as Map
        : const {};
    final file =
        (filediff['file'] ??
                input['filePath'] ??
                input['file'] ??
                input['uri'] ??
                input['path'])
            ?.toString() ??
        '';

    if (file.isEmpty) return const [];

    var adds = (filediff['additions'] as num?)?.toInt() ?? 0;
    var dels = (filediff['deletions'] as num?)?.toInt() ?? 0;
    final patch =
        (filediff['patch'] ??
                metadata['diff'] ??
                input['patchText'] ??
                input['patch'])
            ?.toString() ??
        '';

    if (adds == 0 && dels == 0) {
      if (patch.isNotEmpty) {
        for (final line in patch.replaceAll('\r\n', '\n').split('\n')) {
          if (line.startsWith('+') && !line.startsWith('+++ ')) adds++;
          if (line.startsWith('-') && !line.startsWith('--- ')) dels++;
        }
      } else {
        final newStr =
            (filediff['after'] ?? input['newString'] ?? input['content'])
                ?.toString() ??
            '';
        final oldStr =
            (filediff['before'] ?? input['oldString'])?.toString() ?? '';
        if (tool == 'write' || oldStr.isEmpty) {
          if (newStr.isNotEmpty) adds = newStr.split('\n').length;
        } else {
          if (oldStr.isNotEmpty) dels = oldStr.split('\n').length;
          if (newStr.isNotEmpty) adds = newStr.split('\n').length;
        }
      }
    }

    final status =
        filediff['status']?.toString() ??
        (tool == 'write' ? 'added' : 'modified');

    return [
      SnapshotFileDiff(
        file: file,
        additions: adds,
        deletions: dels,
        status: status,
        patch: patch,
      ),
    ];
  }
}

/// Parser model for batch patch tools (`apply_patch`, `patch`).
class BatchPatchToolDiffParser extends ToolDiffParser {
  @override
  List<SnapshotFileDiff> parsePart(Part part) {
    final metadata = part.toolMetadata ?? const <String, dynamic>{};
    final input = part.toolInput;

    final files = metadata['files'] is List
        ? metadata['files'] as List
        : (input['files'] is List ? input['files'] as List : const []);

    final result = <SnapshotFileDiff>[];
    for (final raw in files) {
      if (raw is! Map) continue;
      final movePath = raw['movePath']?.toString() ?? '';
      final relativePath = raw['relativePath']?.toString() ?? '';
      final filePath = raw['filePath']?.toString() ?? '';
      // Prefer the absolute filePath (matches edit's `filediff.file` key) so
      // edit + apply_patch on the same file merge into one diff entry.
      final file = movePath.isNotEmpty
          ? movePath
          : filePath.isNotEmpty
          ? filePath
          : relativePath;
      if (file.isEmpty) continue;

      final patch = (raw['patch'] ?? raw['diff'])?.toString() ?? '';
      var adds = (raw['additions'] as num?)?.toInt() ?? 0;
      var dels = (raw['deletions'] as num?)?.toInt() ?? 0;
      if (adds == 0 && dels == 0 && patch.isNotEmpty) {
        for (final line in patch.replaceAll('\r\n', '\n').split('\n')) {
          if (line.startsWith('+') && !line.startsWith('+++ ')) adds++;
          if (line.startsWith('-') && !line.startsWith('--- ')) dels++;
        }
      }

      final status =
          raw['status']?.toString() ?? (raw['type']?.toString() ?? 'modified');

      result.add(
        SnapshotFileDiff(
          file: file,
          additions: adds,
          deletions: dels,
          status: status,
          patch: patch,
        ),
      );
    }
    return result;
  }
}
