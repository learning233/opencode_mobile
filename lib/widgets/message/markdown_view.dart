import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:re_highlight/languages/bash.dart' show langBash;
import 'package:re_highlight/languages/cpp.dart' show langCpp;
import 'package:re_highlight/languages/css.dart' show langCss;
import 'package:re_highlight/languages/csharp.dart' show langCsharp;
import 'package:re_highlight/languages/dart.dart' show langDart;
import 'package:re_highlight/languages/diff.dart' show langDiff;
import 'package:re_highlight/languages/go.dart' show langGo;
import 'package:re_highlight/languages/graphql.dart' show langGraphql;
import 'package:re_highlight/languages/java.dart' show langJava;
import 'package:re_highlight/languages/javascript.dart' show langJavascript;
import 'package:re_highlight/languages/json.dart' show langJson;
import 'package:re_highlight/languages/kotlin.dart' show langKotlin;
import 'package:re_highlight/languages/markdown.dart' show langMarkdown;
import 'package:re_highlight/languages/php.dart' show langPhp;
import 'package:re_highlight/languages/python.dart' show langPython;
import 'package:re_highlight/languages/ruby.dart' show langRuby;
import 'package:re_highlight/languages/rust.dart' show langRust;
import 'package:re_highlight/languages/shell.dart' show langShell;
import 'package:re_highlight/languages/sql.dart' show langSql;
import 'package:re_highlight/languages/swift.dart' show langSwift;
import 'package:re_highlight/languages/typescript.dart' show langTypescript;
import 'package:re_highlight/languages/xml.dart' show langXml;
import 'package:re_highlight/languages/yaml.dart' show langYaml;
import 'package:re_highlight/re_highlight.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_logger.dart';

class MarkdownView extends StatelessWidget {
  final String content;
  final bool isStreaming;

  const MarkdownView({
    super.key,
    required this.content,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (content.isEmpty && !isStreaming) return const SizedBox.shrink();

    if (isStreaming && content.isEmpty) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    Widget body(String data) => MarkdownBody(
      data: data,
      // 列表层已为每条消息包 SelectionArea（chat_view._buildMessageItem），
      // 这里不再开 selectable，避免同一段文本维护两套选择系统（长消息开销
      // 明显且交互易冲突）。链接点击仍由 onTapLink 处理。
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: _styleSheetFor(theme, isDark),
      builders: {
        'pre': CodeBlockBuilder(isDark: isDark, isStreaming: isStreaming),
      },
      onTapLink: (text, href, title) {
        if (href != null) {
          try {
            launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
          } catch (e) {
            AppLogger.e('Failed to open link: $href', e);
          }
        }
      },
    );

    // 流式期间按围栏感知的空行切点分为「稳定前缀 + 活跃尾部」：前缀数据
    // 不变 → flutter_markdown_plus 因 data 相等跳过重 parse（styleSheet 已
    // 记忆化），每次 flush 只重 parse 尾部小段，把流式渲染成本从 O(全文)
    // 降到 O(尾部)。找不到安全切点时整体渲染。
    if (isStreaming) {
      final split = _splitStablePrefix(content);
      if (split != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [body(split.$1), body(split.$2)],
        );
      }
    }
    return body(content);
  }
}

/// [_styleSheetFor] 的记忆化缓存。flutter_markdown_plus 在 didUpdateWidget 中
/// 对 data 与 styleSheet 均按实例比较，任一变化即全量重 parse markdown——
/// 若每次 build 都新建 styleSheet，内容没变的重建也会触发重 parse。该 sheet
/// 只依赖主题亮度与个别主题色/字体，命中时复用同一实例。
MarkdownStyleSheet? _cachedStyleSheet;
bool? _cachedSheetIsDark;
Color? _cachedSheetPrimary;
Color? _cachedSheetDivider;
TextStyle? _cachedSheetBodyText;

/// 流式分块的围栏行匹配（与 ToolCallDetector._stripCode 同语义：围栏行切换
/// 进出代码块状态，不区分 ``` 与 ~~~ 的配对）。
final RegExp _fenceLinePattern = RegExp(r'^\s*(`{3,}|~{3,})');

/// 流式内容低于该长度时不分块（整体渲染的成本可忽略）。
const int _streamingSplitMinLength = 1200;

/// 超过该字符数的代码块，高亮延后一帧执行（避免流式结束瞬间同帧多块高亮卡顿）。
const int _largeHighlightThreshold = 8192;

/// 把流式 markdown 在最后一个「围栏外的空行」处切成稳定前缀 + 活跃尾部，
/// 前缀随 flush 保持数据不变从而跳过重 parse。找不到安全切点返回 null。
/// 已知取舍：跨空行的松散列表会被切成两段（有序列表编号从头显示），属
/// 流式期间的临时观感，流结束整体渲染自动恢复正确。
(String, String)? _splitStablePrefix(String content) {
  if (content.length < _streamingSplitMinLength) return null;
  var inFence = false;
  var lastBoundary = -1;
  var offset = 0;
  for (final line in content.split('\n')) {
    final lineStart = offset;
    offset += line.length + 1; // +1 为换行符（末行多算的 1 无碍，仅用于比较）
    if (_fenceLinePattern.hasMatch(line)) {
      inFence = !inFence;
      continue;
    }
    if (!inFence && line.trim().isEmpty) {
      lastBoundary = lineStart;
    }
  }
  if (lastBoundary <= 0 || lastBoundary >= content.length) return null;
  return (content.substring(0, lastBoundary), content.substring(lastBoundary));
}

MarkdownStyleSheet _styleSheetFor(ThemeData theme, bool isDark) {
  final primary = theme.colorScheme.primary;
  final divider = theme.dividerColor;
  final bodyText = theme.textTheme.bodyMedium;
  final cached = _cachedStyleSheet;
  if (cached != null &&
      _cachedSheetIsDark == isDark &&
      _cachedSheetPrimary == primary &&
      _cachedSheetDivider == divider &&
      _cachedSheetBodyText == bodyText) {
    return cached;
  }
  final sheet = MarkdownStyleSheet(
    p: const TextStyle(fontSize: 14, height: 1.5),
    h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    h3: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    code: TextStyle(
      fontSize: 12,
      backgroundColor: isDark
          ? const Color(0xFF242630)
          : const Color(0xFFF1F3F5),
      fontFamily: 'monospace',
      color: isDark ? const Color(0xFFE2E4E9) : const Color(0xFF2A2B36),
    ),
    codeblockDecoration: const BoxDecoration(),
    codeblockPadding: const EdgeInsets.all(0),
    blockquoteDecoration: BoxDecoration(
      color: isDark ? const Color(0xFF181A22) : const Color(0xFFF6F8FA),
      border: Border(
        left: BorderSide(color: primary.withValues(alpha: 0.6), width: 3),
      ),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
    listIndent: 22,
    tableBorder: TableBorder.symmetric(
      inside: BorderSide(color: divider.withValues(alpha: 0.2), width: 0.5),
      outside: BorderSide(color: divider.withValues(alpha: 0.35), width: 0.5),
    ),
    tableHead: bodyText?.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
    tableBody: bodyText?.copyWith(fontSize: 12),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: divider.withValues(alpha: 0.5), width: 0.5),
      ),
    ),
  );
  _cachedStyleSheet = sheet;
  _cachedSheetIsDark = isDark;
  _cachedSheetPrimary = primary;
  _cachedSheetDivider = divider;
  _cachedSheetBodyText = bodyText;
  return sheet;
}

/// Custom code block builder that extracts language info and adds an
/// interactive copy-enabled header.
class CodeBlockBuilder extends MarkdownElementBuilder {
  final bool isDark;
  final bool isStreaming;

  CodeBlockBuilder({required this.isDark, required this.isStreaming});

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    var code = element.textContent;

    // Skip custom block rendering for inline code (no newlines)
    if (!code.contains('\n')) {
      return null;
    }

    // Strip the last trailing newline standard in Markdown block elements
    if (code.endsWith('\n')) {
      code = code.substring(0, code.length - 1);
    }

    // flutter_markdown_plus routes fenced code through the `pre` element; the
    // language class lives on the inner `<code>` element.
    final infoString =
        element.children
            ?.whereType<md.Element>()
            .firstOrNull
            ?.attributes['class'] ??
        element.attributes['class'] ??
        '';

    return _MarkdownCodeBlock(
      code: code,
      infoString: infoString,
      highlightEnabled: !isStreaming,
    );
  }
}

class _MarkdownCodeBlock extends StatefulWidget {
  final String code;
  final String infoString;
  final bool highlightEnabled;

  const _MarkdownCodeBlock({
    required this.code,
    required this.infoString,
    required this.highlightEnabled,
  });

  @override
  State<_MarkdownCodeBlock> createState() => _MarkdownCodeBlockState();
}

final Highlight _globalHighlight = Highlight();
final Set<String> _registeredLanguages = {};

/// Sub-language grammars referenced by a registered top-level grammar.
/// re_highlight resolves these by name at highlight time, so they must be
/// registered before use or that region degrades to plain text.
const _languageDeps = <String, List<String>>{
  'dart': ['markdown'],
  'javascript': ['css', 'graphql', 'xml'],
  'typescript': ['css', 'graphql', 'xml'],
  'shell': ['bash'],
  'yaml': ['ruby'],
  'markdown': ['xml'],
  'xml': ['css', 'javascript'],
};

class _MarkdownCodeBlockState extends State<_MarkdownCodeBlock> {
  bool _copied = false;
  late String _langName;
  late String? _langId;
  TextSpan? _cachedCodeSpan;
  String? _cachedCode;
  String? _cachedLangId;
  bool? _cachedIsDark;
  bool? _cachedHighlightEnabled;
  bool _largeHighlightDeferred = false;

  @override
  void initState() {
    super.initState();
    _configureLanguage();
  }

  @override
  void didUpdateWidget(covariant _MarkdownCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.highlightEnabled) {
      _largeHighlightDeferred = false;
    }
    if (oldWidget.infoString != widget.infoString) {
      _configureLanguage();
      _clearHighlightCache();
    } else if (oldWidget.code != widget.code ||
        oldWidget.highlightEnabled != widget.highlightEnabled) {
      _clearHighlightCache();
    }
  }

  void _configureLanguage() {
    var lang = widget.infoString.toLowerCase().replaceAll('language-', '');
    if (lang.isEmpty) {
      _langName = 'CODE';
      _langId = null;
      return;
    }

    _langName = lang.toUpperCase();

    try {
      if (_getMode(lang) != null) {
        _langId = lang;
        _ensureLanguageRegistered(lang);
      } else {
        _langId = null;
      }
    } catch (_) {
      _langId = null;
    }
  }

  /// Registers [lang] and, recursively, every grammar it references via
  /// `subLanguage`, so embedded regions (e.g. bash inside shell, markdown
  /// inside dart doc comments) are highlighted too. Registration order does
  /// not matter: subLanguage resolution happens lazily at highlight time.
  void _ensureLanguageRegistered(String lang) {
    if (_registeredLanguages.contains(lang)) return;
    _registeredLanguages.add(lang);
    final mode = _getMode(lang);
    if (mode == null) return;
    _globalHighlight.registerLanguage(lang, mode);
    for (final dep in _languageDeps[lang] ?? const <String>[]) {
      _ensureLanguageRegistered(dep);
    }
  }

  void _clearHighlightCache() {
    _cachedCodeSpan = null;
    _cachedCode = null;
    _cachedLangId = null;
    _cachedIsDark = null;
    _cachedHighlightEnabled = null;
  }

  Mode? _getMode(String lang) {
    switch (lang) {
      case 'dart':
        return langDart;
      case 'python':
      case 'py':
        return langPython;
      case 'javascript':
      case 'js':
      case 'jsx':
        return langJavascript;
      case 'typescript':
      case 'ts':
      case 'tsx':
        return langTypescript;
      case 'go':
        return langGo;
      case 'rust':
      case 'rs':
        return langRust;
      case 'java':
        return langJava;
      case 'kotlin':
      case 'kt':
        return langKotlin;
      case 'swift':
        return langSwift;
      case 'cpp':
      case 'c':
        return langCpp;
      case 'csharp':
      case 'cs':
        return langCsharp;
      case 'ruby':
      case 'rb':
        return langRuby;
      case 'php':
        return langPhp;
      case 'sql':
        return langSql;
      case 'shell':
        return langShell;
      case 'bash':
      case 'sh':
        return langBash;
      case 'graphql':
      case 'gql':
        return langGraphql;
      case 'json':
        return langJson;
      case 'yaml':
      case 'yml':
        return langYaml;
      case 'xml':
      case 'html':
        return langXml;
      case 'css':
        return langCss;
      case 'markdown':
      case 'md':
        return langMarkdown;
      case 'diff':
        return langDiff;
      default:
        return null;
    }
  }

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final codeSpan = _resolveCodeSpan(isDark);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16171E) : const Color(0xFFE5E7EB),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.code,
                      size: 11,
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _langName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.5,
                          ),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _handleCopy,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check : Icons.copy_outlined,
                          size: 11,
                          color: _copied
                              ? Colors.green
                              : theme.textTheme.bodySmall?.color?.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'Copied' : 'Copy',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: _copied
                                ? Colors.green
                                : theme.textTheme.bodySmall?.color?.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text.rich(
              codeSpan,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
                color: isDark
                    ? const Color(0xFFE6EDF3)
                    : const Color(0xFF24292E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _resolveCodeSpan(bool isDark) {
    final langId = _langId;
    final canHighlight = widget.highlightEnabled && langId != null;
    // 大代码块的高亮是同步重活；流式结束瞬间整条消息的所有代码块同时翻转
    // highlightEnabled，会在同一帧内全部执行。超过阈值的块先渲染纯文本、
    // 延后一帧再高亮，把最重的一帧拆成两帧。
    if (canHighlight &&
        !_largeHighlightDeferred &&
        widget.code.length > _largeHighlightThreshold) {
      _largeHighlightDeferred = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _clearHighlightCache();
        setState(() {});
      });
      return TextSpan(text: widget.code);
    }

    if (_cachedCodeSpan != null &&
        _cachedCode == widget.code &&
        _cachedLangId == _langId &&
        _cachedIsDark == isDark &&
        _cachedHighlightEnabled == widget.highlightEnabled) {
      return _cachedCodeSpan!;
    }

    TextSpan codeSpan;
    if (canHighlight) {
      try {
        final result = _globalHighlight.highlight(
          code: widget.code,
          language: langId,
        );
        final resolvedTheme = isDark ? _darkCodeTheme : _lightCodeTheme;
        final renderer = TextSpanRenderer(
          TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.5,
            color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF24292E),
          ),
          resolvedTheme,
        );
        result.render(renderer);
        codeSpan = renderer.span ?? TextSpan(text: widget.code);
      } catch (_) {
        codeSpan = TextSpan(text: widget.code);
      }
    } else {
      codeSpan = TextSpan(text: widget.code);
    }

    _cachedCodeSpan = codeSpan;
    _cachedCode = widget.code;
    _cachedLangId = _langId;
    _cachedIsDark = isDark;
    _cachedHighlightEnabled = widget.highlightEnabled;
    return codeSpan;
  }
}

// ── Syntax Highlighting Themes ──────────────────────────────

final _darkCodeTheme = {
  'keyword': const TextStyle(
    color: Color(0xFFFF79C6),
    fontWeight: FontWeight.bold,
  ),
  'string': const TextStyle(color: Color(0xFF50FA7B)),
  'number': const TextStyle(color: Color(0xFFBD93F9)),
  'literal': const TextStyle(color: Color(0xFFBD93F9)),
  'comment': const TextStyle(
    color: Color(0xFF6272A4),
    fontStyle: FontStyle.italic,
  ),
  'function': const TextStyle(color: Color(0xFF8BE9FD)),
  'class': const TextStyle(color: Color(0xFF50FA7B)),
  'title': const TextStyle(color: Color(0xFF50FA7B)),
  'params': const TextStyle(color: Color(0xFFF8F8F2)),
  'meta': const TextStyle(color: Color(0xFFFF79C6)),
  'built_in': const TextStyle(color: Color(0xFF8BE9FD)),
  'type': const TextStyle(
    color: Color(0xFF8BE9FD),
    fontStyle: FontStyle.italic,
  ),
  'attr': const TextStyle(color: Color(0xFF50FA7B)),
  'symbol': const TextStyle(color: Color(0xFFBD93F9)),
  'bullet': const TextStyle(color: Color(0xFFBD93F9)),
  'section': const TextStyle(
    color: Color(0xFF8BE9FD),
    fontWeight: FontWeight.bold,
  ),
  'addition': const TextStyle(color: Color(0xFF50FA7B)),
  'deletion': const TextStyle(color: Color(0xFFFF5555)),
};

final _lightCodeTheme = {
  'keyword': const TextStyle(
    color: Color(0xFFD73A49),
    fontWeight: FontWeight.bold,
  ),
  'string': const TextStyle(color: Color(0xFF032F62)),
  'number': const TextStyle(color: Color(0xFF005CC5)),
  'literal': const TextStyle(color: Color(0xFF005CC5)),
  'comment': const TextStyle(
    color: Color(0xFF6A737D),
    fontStyle: FontStyle.italic,
  ),
  'function': const TextStyle(color: Color(0xFF6F42C1)),
  'class': const TextStyle(color: Color(0xFFE36209)),
  'title': const TextStyle(color: Color(0xFF6F42C1)),
  'params': const TextStyle(color: Color(0xFF24292E)),
  'meta': const TextStyle(color: Color(0xFF005CC5)),
  'built_in': const TextStyle(color: Color(0xFFE36209)),
  'type': const TextStyle(color: Color(0xFF6F42C1)),
  'attr': const TextStyle(color: Color(0xFF005CC5)),
  'symbol': const TextStyle(color: Color(0xFF005CC5)),
  'bullet': const TextStyle(color: Color(0xFF005CC5)),
  'section': const TextStyle(
    color: Color(0xFF005CC5),
    fontWeight: FontWeight.bold,
  ),
  'addition': const TextStyle(color: Color(0xFF22863A)),
  'deletion': const TextStyle(color: Color(0xFFCB2431)),
};
