/// Holds information about a detected tool call found in text content.
class ToolCallInfo {
  /// The name of the detected tool (e.g. 'bash', 'read', 'edit').
  final String toolName;

  /// Extracted parameters from the tool call XML, keyed by parameter name.
  final Map<String, String> params;

  /// The raw XML string that matched the tool call pattern.
  final String rawXml;

  /// Creates a [ToolCallInfo] with the given detection results.
  ToolCallInfo({
    required this.toolName,
    required this.params,
    required this.rawXml,
  });
}

/// Detects tool call XML patterns in text content, matching known tool tags
/// (bash, read, write, edit, glob, grep, etc.) and extracting their parameters.
class ToolCallDetector {
  static const _toolTags = [
    'read_file',
    'read',
    'write',
    'edit',
    'bash',
    'shell',
    'glob',
    'grep',
    'list',
    'webfetch',
    'websearch',
    'question',
    'task',
    'apply_patch',
    'todo_write',
    'subtask',
    'skill',
    'lsp',
  ];

  /// 预编译工具标签正则，避免每次 detect() 重新编译
  static final _toolPatterns = <RegExp>[
    for (final tag in _toolTags)
      RegExp(
        '<(${RegExp.escape(tag)})\\b[^>]*>([\\s\\S]*?)<\\/${RegExp.escape(tag)}>',
        caseSensitive: false,
      ),
  ];

  /// 预编译参数提取正则
  static final _paramRegex = RegExp(r'<(\w+)>([\s\S]*?)</\1>');

  /// Matches a fenced code block opener/closer (``` or ~~~, 3+ chars).
  static final _fenceRegex = RegExp(r'^\s*(`{3,}|~{3,})');

  /// Matches an inline code span (`` `code` ``, ```` ``code`` ````, …).
  static final _inlineCodeRegex = RegExp(r'`+[^`\n]+`+');

  /// Removes fenced code blocks and inline code spans from [text] so that
  /// XML tool-call examples inside code are not mistaken for real tool calls.
  static String _stripCode(String text) {
    final lines = text.split('\n');
    final buf = <String>[];
    var inFence = false;
    for (final line in lines) {
      if (_fenceRegex.hasMatch(line)) {
        inFence = !inFence;
        continue;
      }
      if (inFence) continue;
      buf.add(line);
    }
    return buf.join('\n').replaceAll(_inlineCodeRegex, '');
  }

  /// detect 结果缓存：已完成消息的文本不再变化，滚动/重建反复进入时避免
  /// 对全文重复跑 _stripCode + 逐个正则扫描。key 为 trim 后全文，负结果
  /// （null）同样缓存；按插入序 FIFO 淘汰，超长文本不缓存防内存放大。
  static final Map<String, ToolCallInfo?> _resultCache = {};
  static const int _resultCacheLimit = 256;
  static const int _resultCacheMaxTextLength = 20000;

  /// Scans [text] for a tool call XML pattern and returns a [ToolCallInfo] if
  /// one is found, or null if no recognized tool tag is present.
  static ToolCallInfo? detect(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > _resultCacheMaxTextLength) {
      return _detectUncached(trimmed);
    }
    if (_resultCache.containsKey(trimmed)) return _resultCache[trimmed];
    final info = _detectUncached(trimmed);
    if (_resultCache.length >= _resultCacheLimit) {
      _resultCache.remove(_resultCache.keys.first);
    }
    _resultCache[trimmed] = info;
    return info;
  }

  static ToolCallInfo? _detectUncached(String trimmed) {
    final plain = _stripCode(trimmed);

    for (var i = 0; i < _toolTags.length; i++) {
      final tag = _toolTags[i];
      final match = _toolPatterns[i].firstMatch(plain);
      if (match != null) {
        final params = <String, String>{};
        for (final pm in _paramRegex.allMatches(match.group(0)!)) {
          final key = pm.group(1)!.toLowerCase();
          if (key != tag.toLowerCase()) {
            params[key] = pm.group(2)!.trim();
          }
        }
        return ToolCallInfo(
          toolName: tag,
          params: params,
          rawXml: match.group(0)!,
        );
      }
    }
    return null;
  }
}
