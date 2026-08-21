import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:kterm/src/base/disposable.dart';
import 'package:kterm/src/core/buffer/cell_offset.dart';
import 'package:kterm/src/core/buffer/line.dart';
import 'package:kterm/src/core/buffer/range.dart';
import 'package:kterm/src/core/buffer/range_block.dart';
import 'package:kterm/src/core/buffer/range_line.dart';
import 'package:kterm/src/ui/pointer_input.dart';
import 'package:kterm/src/ui/selection_mode.dart';

/// Options for search behavior.
enum SearchOption {
  /// Case-sensitive search.
  caseSensitive,

  /// Treat pattern as regular expression.
  regex,

  /// Match whole words only.
  wholeWord,
}

/// Callback type for searching text in the terminal buffer.
typedef SearchCallback = String Function();

/// Callback type for creating a cell anchor from a position.
typedef CreateAnchorCallback = CellAnchor Function(CellOffset offset);

class TerminalController with ChangeNotifier {
  TerminalController({
    SelectionMode selectionMode = SelectionMode.line,
    PointerInputs pointerInputs = const PointerInputs({PointerInput.tap}),
    bool suspendPointerInput = false,
  })  : _selectionMode = selectionMode,
        _pointerInputs = pointerInputs,
        _suspendPointerInputs = suspendPointerInput;

  /// Callback to get the terminal buffer text for searching.
  SearchCallback? onGetText;

  /// Callback to create a cell anchor from a buffer offset.
  CreateAnchorCallback? onCreateAnchor;

  /// Callback when Ctrl+L is triggered to send selected text to prompt input.
  void Function(String text)? onSendSelectionToPrompt;

  CellAnchor? _selectionBase;
  CellAnchor? _selectionExtent;

  SelectionMode get selectionMode => _selectionMode;
  SelectionMode _selectionMode;

  /// The set of pointer events which will be used as mouse input for the terminal.
  PointerInputs get pointerInput => _pointerInputs;
  PointerInputs _pointerInputs;

  /// True if sending pointer events to the terminal is suspended.
  bool get suspendedPointerInputs => _suspendPointerInputs;
  bool _suspendPointerInputs;

  List<TerminalHighlight> get highlights => _highlights;
  final _highlights = <TerminalHighlight>[];

  // Search state
  String? _searchPattern;
  bool _isSearching = false;
  Set<SearchOption> _searchOptions = {};
  List<BufferRange> _searchResults = [];
  int _currentSearchIndex = -1;

  /// The current search pattern.
  String? get searchPattern => _searchPattern;

  /// Whether a search is currently active.
  bool get isSearching => _isSearching;

  /// Current search options.
  Set<SearchOption> get searchOptions => _searchOptions;

  /// All search results matching the current pattern.
  List<BufferRange> get searchResults => _searchResults;

  /// The index of the current search result (0-based).
  /// -1 if no result is selected.
  int get currentSearchIndex => _currentSearchIndex;

  /// The current search result, or null if no result is selected.
  BufferRange? get currentSearchResult {
    if (_currentSearchIndex >= 0 &&
        _currentSearchIndex < _searchResults.length) {
      return _searchResults[_currentSearchIndex];
    }
    return null;
  }

  /// Number of search results.
  int get searchResultCount => _searchResults.length;

  /// Whether there are any search results.
  bool get hasSearchResults => _searchResults.isNotEmpty;

  BufferRange? get selection {
    final base = _selectionBase;
    final extent = _selectionExtent;

    if (base == null || extent == null) {
      return null;
    }

    if (!base.attached || !extent.attached) {
      return null;
    }

    return _createRange(base.offset, extent.offset);
  }

  /// Set selection on the terminal from [base] to [extent]. This method takes
  /// the ownership of [base] and [extent] and will dispose them when the
  /// selection is cleared or changed.
  void setSelection(CellAnchor base, CellAnchor extent, {SelectionMode? mode}) {
    _selectionBase?.dispose();
    _selectionBase = base;

    _selectionExtent?.dispose();
    _selectionExtent = extent;

    if (mode != null) {
      _selectionMode = mode;
    }

    notifyListeners();
  }

  BufferRange _createRange(CellOffset begin, CellOffset end) {
    switch (selectionMode) {
      case SelectionMode.line:
        return BufferRangeLine(begin, end);
      case SelectionMode.block:
        return BufferRangeBlock(begin, end);
    }
  }

  /// Controls how the terminal behaves when the user selects a range of text.
  /// The default is [SelectionMode.line]. Setting this to [SelectionMode.block]
  /// enables block selection mode.
  void setSelectionMode(SelectionMode newSelectionMode) {
    // If the new mode is the same as the old mode,
    // nothing has to be changed.
    if (_selectionMode == newSelectionMode) {
      return;
    }
    // Set the new mode.
    _selectionMode = newSelectionMode;
    notifyListeners();
  }

  /// Clears the current selection.
  void clearSelection() {
    _selectionBase?.dispose();
    _selectionBase = null;
    _selectionExtent?.dispose();
    _selectionExtent = null;
    notifyListeners();
  }

  // Select which type of pointer events are send to the terminal.
  void setPointerInputs(PointerInputs pointerInput) {
    _pointerInputs = pointerInput;
    notifyListeners();
  }

  // Toggle sending pointer events to the terminal.
  void setSuspendPointerInput(bool suspend) {
    _suspendPointerInputs = suspend;
    notifyListeners();
  }

  // Returns true if this type of PointerInput should be send to the Terminal.
  @internal
  bool shouldSendPointerInput(PointerInput pointerInput) {
    // Always return false if pointer input is suspended.
    return _suspendPointerInputs
        ? false
        : _pointerInputs.inputs.contains(pointerInput);
  }

  /// Creates a new highlight on the terminal from [p1] to [p2] with the given
  /// [color]. The highlight will be removed when the returned object is
  /// disposed.
  TerminalHighlight highlight({
    required CellAnchor p1,
    required CellAnchor p2,
    required Color color,
  }) {
    final highlight = TerminalHighlight(
      this,
      p1: p1,
      p2: p2,
      color: color,
    );

    _highlights.add(highlight);
    notifyListeners();

    highlight.registerCallback(() {
      _highlights.remove(highlight);
      notifyListeners();
    });

    return highlight;
  }

  // Search methods

  /// Opens the search UI (called when user activates search mode).
  void openSearch() {
    _isSearching = true;
    notifyListeners();
  }

  /// Closes the search UI and clears the search state.
  void closeSearch() {
    _isSearching = false;
    _searchPattern = null;
    _searchResults = [];
    _currentSearchIndex = -1;
    notifyListeners();
  }

  /// Sets the search options.
  void setSearchOptions(Set<SearchOption> options) {
    _searchOptions = options;
    // Re-run search if pattern exists
    if (_searchPattern != null && _searchPattern!.isNotEmpty) {
      search(_searchPattern!);
    } else {
      notifyListeners();
    }
  }

  /// Toggles a search option.
  void toggleSearchOption(SearchOption option) {
    if (_searchOptions.contains(option)) {
      _searchOptions = Set.from(_searchOptions)..remove(option);
    } else {
      _searchOptions = Set.from(_searchOptions)..add(option);
    }
    // Re-run search if pattern exists
    if (_searchPattern != null && _searchPattern!.isNotEmpty) {
      search(_searchPattern!);
    } else {
      notifyListeners();
    }
  }

  /// Performs a search for [pattern] in the terminal buffer.
  void search(String pattern) {
    _searchPattern = pattern;

    if (pattern.isEmpty) {
      _searchResults = [];
      _currentSearchIndex = -1;
      notifyListeners();
      return;
    }

    // Get text from buffer using callback
    final text = onGetText?.call() ?? '';
    if (text.isEmpty) {
      _searchResults = [];
      _currentSearchIndex = -1;
      notifyListeners();
      return;
    }

    _searchResults = _performSearch(text, pattern);
    _currentSearchIndex = _searchResults.isNotEmpty ? 0 : -1;
    notifyListeners();
  }

  /// Performs the actual search logic.
  List<BufferRange> _performSearch(String text, String pattern) {
    final results = <BufferRange>[];
    final isCaseSensitive = _searchOptions.contains(SearchOption.caseSensitive);
    final isRegex = _searchOptions.contains(SearchOption.regex);
    final isWholeWord = _searchOptions.contains(SearchOption.wholeWord);

    try {
      late RegExp regex;
      if (isRegex) {
        regex = RegExp(pattern, caseSensitive: isCaseSensitive);
      } else {
        // Escape special regex characters for literal search
        final escaped = RegExp.escape(pattern);
        final patternStr = isWholeWord ? '\\b$escaped\\b' : escaped;
        regex = RegExp(patternStr, caseSensitive: isCaseSensitive);
      }

      for (final match in regex.allMatches(text)) {
        final start = match.start;
        final end = match.end;

        // Convert text offset to cell offset
        final startOffset = _textOffsetToCellOffset(text, start);
        final endOffset = _textOffsetToCellOffset(text, end);

        if (startOffset != null && endOffset != null) {
          results.add(BufferRangeLine(startOffset, endOffset));
        }
      }
    } catch (e) {
      // Invalid regex, ignore
    }

    return results;
  }

  /// Converts a text offset to a cell offset.
  /// This is a simplified implementation that assumes monospace cells.
  CellOffset? _textOffsetToCellOffset(String text, int offset) {
    // Get line information from buffer
    // This is a simplified implementation
    // In reality, we need to track line breaks in the buffer
    final onGetText = this.onGetText;
    if (onGetText == null) return null;

    // Calculate line and column from offset
    final bufferText = onGetText();
    if (offset > bufferText.length) return null;

    // Find the line number and column
    int lineNumber = 0;
    int col = 0;

    for (int i = 0; i < offset; i++) {
      if (bufferText[i] == '\n') {
        lineNumber++;
        col = 0;
      } else {
        col++;
      }
    }

    return CellOffset(col, lineNumber);
  }

  /// Moves to the next search result.
  void searchNext() {
    if (_searchResults.isEmpty) return;

    _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    notifyListeners();
  }

  /// Moves to the previous search result.
  void searchPrevious() {
    if (_searchResults.isEmpty) return;

    _currentSearchIndex = (_currentSearchIndex - 1 + _searchResults.length) %
        _searchResults.length;
    notifyListeners();
  }

  /// Clears the current search but keeps search mode active.
  void clearSearch() {
    _searchPattern = null;
    _searchResults = [];
    _currentSearchIndex = -1;
    notifyListeners();
  }

  /// Gets the search result at [index].
  BufferRange? getSearchResultAt(int index) {
    if (index >= 0 && index < _searchResults.length) {
      return _searchResults[index];
    }
    return null;
  }
}

class TerminalHighlight with Disposable {
  final TerminalController owner;

  final CellAnchor p1;

  final CellAnchor p2;

  final Color color;

  TerminalHighlight(
    this.owner, {
    required this.p1,
    required this.p2,
    required this.color,
  });

  /// Returns the range of the highlight. May be null if the anchors that
  /// define the highlight are not attached to the terminal.
  BufferRange? get range {
    if (!p1.attached || !p2.attached) {
      return null;
    }
    return BufferRangeLine(p1.offset, p2.offset);
  }
}
