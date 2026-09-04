/// Data models representing search results from `/find` and `/find/file`.
library;

class TextSubmatch {
  final String text;
  final int start;
  final int end;

  const TextSubmatch({
    required this.text,
    required this.start,
    required this.end,
  });

  factory TextSubmatch.fromJson(Map<String, dynamic> json) {
    String subText = '';
    final match = json['match'];
    if (match is Map) {
      subText = match['text']?.toString() ?? '';
    } else if (match is String) {
      subText = match;
    }

    return TextSubmatch(
      text: subText,
      start: (json['start'] as num?)?.toInt() ?? 0,
      end: (json['end'] as num?)?.toInt() ?? 0,
    );
  }
}

class TextSearchMatch {
  final String path;
  final String lineText;
  final int lineNumber;
  final int absoluteOffset;
  final List<TextSubmatch> submatches;

  const TextSearchMatch({
    required this.path,
    required this.lineText,
    required this.lineNumber,
    required this.absoluteOffset,
    this.submatches = const [],
  });

  factory TextSearchMatch.fromJson(Map<String, dynamic> json) {
    String filePath = '';
    final pathObj = json['path'];
    if (pathObj is Map) {
      filePath = pathObj['text']?.toString() ?? '';
    } else if (pathObj is String) {
      filePath = pathObj;
    }

    String linesText = '';
    final linesObj = json['lines'];
    if (linesObj is Map) {
      linesText = linesObj['text']?.toString() ?? '';
    } else if (linesObj is String) {
      linesText = linesObj;
    }

    final rawSubmatches = json['submatches'];
    final submatchesList = <TextSubmatch>[];
    if (rawSubmatches is List) {
      for (final item in rawSubmatches) {
        if (item is Map) {
          submatchesList.add(
            TextSubmatch.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return TextSearchMatch(
      path: filePath,
      lineText: linesText.replaceAll(RegExp(r'[\r\n]+$'), ''),
      lineNumber: (json['line_number'] as num?)?.toInt() ?? 1,
      absoluteOffset: (json['absolute_offset'] as num?)?.toInt() ?? 0,
      submatches: submatchesList,
    );
  }
}

/// A group of text matches clustered under a single file path for UI rendering.
class FileSearchGroup {
  final String path;
  final List<TextSearchMatch> matches;
  bool isExpanded;

  FileSearchGroup({
    required this.path,
    required this.matches,
    this.isExpanded = true,
  });

  String get fileName => path.contains('/') ? path.split('/').last : path;
}
