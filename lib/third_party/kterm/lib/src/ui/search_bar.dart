import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kterm/src/ui/controller.dart';

/// A search bar widget for terminal search functionality.
class TerminalSearchBar extends StatefulWidget {
  const TerminalSearchBar({
    super.key,
    required this.controller,
    this.onClose,
    this.autoFocus = true,
    this.searchBackgroundColor,
    this.searchBorderColor,
  });

  final TerminalController controller;
  final VoidCallback? onClose;
  final bool autoFocus;

  /// Custom background color for the search bar.
  /// If not provided, defaults to theme-dependent colors.
  final Color? searchBackgroundColor;

  /// Custom border color for the search bar.
  /// If not provided, defaults to theme-dependent colors.
  final Color? searchBorderColor;

  @override
  State<TerminalSearchBar> createState() => _TerminalSearchBarState();
}

class _TerminalSearchBarState extends State<TerminalSearchBar> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController =
        TextEditingController(text: widget.controller.searchPattern ?? '');
    _focusNode = FocusNode();

    _textController.addListener(_onTextChanged);

    widget.controller.addListener(_onControllerChanged);

    // Auto focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.autoFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onTextChanged() {
    widget.controller.search(_textController.text);
  }

  void _onControllerChanged() {
    // Sync text if changed externally
    if (_textController.text != (widget.controller.searchPattern ?? '')) {
      _textController.text = widget.controller.searchPattern ?? '';
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onClose?.call();
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        // Enter - search next
        if (HardwareKeyboard.instance.isShiftPressed) {
          widget.controller.searchPrevious();
        } else {
          widget.controller.searchNext();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        widget.controller.searchPrevious();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        widget.controller.searchNext();
      }
    }
  }

  Widget _buildInlineOptionButton(SearchOption option, String label) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isSelected = widget.controller.searchOptions.contains(option);
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        final color = isSelected
            ? theme.colorScheme.primary
            : (isDark ? Colors.white54 : Colors.black54);

        final bgColor = isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : Colors.transparent;

        return Material(
          color: Colors.transparent,
          child: Tooltip(
            message: option == SearchOption.caseSensitive
                ? '区分大小写 (Aa)'
                : option == SearchOption.wholeWord
                    ? '全字匹配 (ab)'
                    : '使用正则表达式 (.*)',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () {
                widget.controller.toggleSearchOption(option);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use custom colors or fall back to theme-dependent defaults
    final backgroundColor = widget.searchBackgroundColor ??
        (isDark ? const Color(0xFF252526) : Colors.white);
    final borderColor = widget.searchBorderColor ??
        (isDark ? const Color(0xFF3C3C3C) : Colors.grey.shade300);
    final inputTextColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white70 : Colors.black54;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Search input
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                style: TextStyle(
                  fontSize: 13,
                  color: inputTextColor,
                ),
                decoration: InputDecoration(
                  hintText: '查找',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInlineOptionButton(
                          SearchOption.caseSensitive, 'Aa'),
                      _buildInlineOptionButton(SearchOption.wholeWord, 'ab'),
                      _buildInlineOptionButton(SearchOption.regex, '.*'),
                      const SizedBox(width: 4),
                    ],
                  ),
                  suffixIconConstraints: const BoxConstraints(
                    maxHeight: 24,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Result count
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final hasResults = widget.controller.hasSearchResults;
                final current = widget.controller.currentSearchIndex;
                final total = widget.controller.searchResultCount;

                if (!widget.controller.isSearching ||
                    _textController.text.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    hasResults ? '${current + 1}/$total' : '无结果',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasResults
                          ? (isDark ? Colors.white70 : Colors.black87)
                          : (isDark ? Colors.orange : Colors.orange.shade700),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(width: 4),

            // Previous button
            IconButton(
              icon: Icon(
                Icons.arrow_upward,
                size: 16,
                color: iconColor,
              ),
              onPressed: widget.controller.searchPrevious,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              splashRadius: 14,
              tooltip: '上一个匹配 (Shift+F3)',
            ),

            // Next button
            IconButton(
              icon: Icon(
                Icons.arrow_downward,
                size: 16,
                color: iconColor,
              ),
              onPressed: widget.controller.searchNext,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              splashRadius: 14,
              tooltip: '下一个匹配 (F3)',
            ),

            const SizedBox(width: 2),

            // Close button
            IconButton(
              icon: Icon(
                Icons.close,
                size: 16,
                color: iconColor,
              ),
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              splashRadius: 14,
              tooltip: '关闭 (Escape)',
            ),
          ],
        ),
      ),
    );
  }
}
