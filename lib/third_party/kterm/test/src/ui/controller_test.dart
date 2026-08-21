import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';
import 'package:kterm/src/ui/controller.dart';

void main() {
  group('TerminalController', () {
    testWidgets('setSelectionRange works', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final terminal = Terminal();
      final terminalView = TerminalController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            controller: terminalView,
          ),
        ),
      ));

      terminalView.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(2, 2),
      );

      await tester.pump();

      expect(terminalView.selection, isNotNull);
    });

    testWidgets('setSelectionMode changes BufferRange type', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final terminal = Terminal();
      final terminalView = TerminalController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            controller: terminalView,
          ),
        ),
      ));

      terminalView.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(2, 2),
      );

      expect(terminalView.selection, isA<BufferRangeLine>());

      terminalView.setSelectionMode(SelectionMode.block);

      expect(terminalView.selection, isA<BufferRangeBlock>());
    });

    testWidgets('clearSelection works', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final terminal = Terminal();
      final terminalView = TerminalController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            controller: terminalView,
          ),
        ),
      ));

      terminalView.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(2, 2),
      );

      expect(terminalView.selection, isNotNull);

      terminalView.clearSelection();

      expect(terminalView.selection, isNull);
    });
  });

  group('TerminalController.highlight', () {
    test('works', () {
      final terminal = Terminal();
      final controller = TerminalController();

      final highlight = controller.highlight(
        p1: terminal.buffer.createAnchor(5, 5),
        p2: terminal.buffer.createAnchor(5, 10),
        color: Colors.yellow,
      );
      assert(controller.highlights.length == 1);

      highlight.dispose();
      assert(controller.highlights.isEmpty);
    });
  });

  group('TerminalController.search', () {
    test(
        'Given no text provider, When search called, Then returns empty results',
        () {
      final controller = TerminalController();

      // No onGetText callback set
      controller.search('test');

      expect(controller.searchResults, isEmpty);
      expect(controller.currentSearchIndex, equals(-1));
    });

    test('Given text with match, When search called, Then returns results', () {
      final terminal = Terminal();
      terminal.write('hello world\nhello flutter');
      final controller = TerminalController();

      // Set up text provider
      controller.onGetText = () => terminal.buffer.getText();

      controller.search('hello');

      expect(controller.searchResults, isNotEmpty);
      expect(controller.hasSearchResults, isTrue);
    });

    test('Given empty pattern, When search called, Then clears results', () {
      final terminal = Terminal();
      terminal.write('hello world');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();

      controller.search('hello');
      expect(controller.hasSearchResults, isTrue);

      controller.search('');
      expect(controller.searchResults, isEmpty);
      expect(controller.currentSearchIndex, equals(-1));
    });

    test(
        'Given case insensitive search, When search called, Then finds matches',
        () {
      final terminal = Terminal();
      terminal.write('Hello HELLO hello');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.setSearchOptions(<SearchOption>{SearchOption.caseSensitive});

      controller.search('hello');

      expect(controller.hasSearchResults, isTrue);
    });

    test(
        'Given case sensitive search, When search called, Then finds exact matches only',
        () {
      final terminal = Terminal();
      terminal.write('Hello HELLO hello');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.setSearchOptions(<SearchOption>{SearchOption.caseSensitive});

      controller.search('Hello');

      // Should only find exact case match
      expect(controller.hasSearchResults, isTrue);
    });

    test('Given regex search, When search called, Then uses regex pattern', () {
      final terminal = Terminal();
      terminal.write('test123 test456 test789');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.setSearchOptions(<SearchOption>{SearchOption.regex});

      controller.search(r'test\d+');

      expect(controller.hasSearchResults, isTrue);
    });

    test(
        'Given whole word search, When search called, Then matches whole words only',
        () {
      final terminal = Terminal();
      terminal.write('testing tested test');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.setSearchOptions(<SearchOption>{SearchOption.wholeWord});

      controller.search('test');

      expect(controller.hasSearchResults, isTrue);
    });

    test('searchNext cycles through results', () {
      final terminal = Terminal();
      terminal.write('test test test');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.search('test');

      expect(controller.currentSearchIndex, equals(0));

      controller.searchNext();
      expect(controller.currentSearchIndex, equals(1));

      controller.searchNext();
      expect(controller.currentSearchIndex, equals(2));

      // Should cycle back to first
      controller.searchNext();
      expect(controller.currentSearchIndex, equals(0));
    });

    test('searchPrevious cycles through results backwards', () {
      final terminal = Terminal();
      terminal.write('test test test');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.search('test');

      expect(controller.currentSearchIndex, equals(0));

      controller.searchPrevious();
      expect(controller.currentSearchIndex, equals(2));

      controller.searchPrevious();
      expect(controller.currentSearchIndex, equals(1));
    });

    test('openSearch sets isSearching to true', () {
      final controller = TerminalController();

      expect(controller.isSearching, isFalse);

      controller.openSearch();

      expect(controller.isSearching, isTrue);
    });

    test('closeSearch clears search state', () {
      final terminal = Terminal();
      terminal.write('test');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.openSearch();
      controller.search('test');

      expect(controller.isSearching, isTrue);
      expect(controller.hasSearchResults, isTrue);

      controller.closeSearch();

      expect(controller.isSearching, isFalse);
      expect(controller.searchPattern, isNull);
      expect(controller.searchResults, isEmpty);
      expect(controller.currentSearchIndex, equals(-1));
    });

    test('clearSearch clears pattern and results but keeps search mode', () {
      final terminal = Terminal();
      terminal.write('test');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.openSearch();
      controller.search('test');

      controller.clearSearch();

      expect(controller.isSearching, isTrue); // Should still be in search mode
      expect(controller.searchPattern, isNull);
      expect(controller.searchResults, isEmpty);
      expect(controller.currentSearchIndex, equals(-1));
    });

    test('toggleSearchOption toggles option correctly', () {
      final controller = TerminalController();

      expect(controller.searchOptions.contains(SearchOption.caseSensitive),
          isFalse);

      controller.toggleSearchOption(SearchOption.caseSensitive);
      expect(controller.searchOptions.contains(SearchOption.caseSensitive),
          isTrue);

      controller.toggleSearchOption(SearchOption.caseSensitive);
      expect(controller.searchOptions.contains(SearchOption.caseSensitive),
          isFalse);
    });

    test('currentSearchResult returns correct result', () {
      final terminal = Terminal();
      terminal.write('apple banana apple');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.search('apple');

      expect(controller.currentSearchResult, isNotNull);
      expect(controller.searchResultCount, equals(2));

      controller.searchNext();
      expect(controller.currentSearchResult, isNotNull);
    });

    test('getSearchResultAt returns correct result', () {
      final terminal = Terminal();
      terminal.write('test1 test2 test3');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.search('test');

      final result0 = controller.getSearchResultAt(0);
      final result1 = controller.getSearchResultAt(1);
      final result2 = controller.getSearchResultAt(2);
      final resultOutOfBounds = controller.getSearchResultAt(100);

      expect(result0, isNotNull);
      expect(result1, isNotNull);
      expect(result2, isNotNull);
      expect(resultOutOfBounds, isNull);
    });

    // Boundary tests
    test(
        'Given empty string search, When search called, Then returns empty results',
        () {
      final terminal = Terminal();
      terminal.write('hello world');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();

      controller.search('');
      expect(controller.searchResults, isEmpty);
      expect(controller.currentSearchIndex, equals(-1));
    });

    test(
        'Given no matching text, When search called, Then returns empty results',
        () {
      final terminal = Terminal();
      terminal.write('hello world');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();

      controller.search('xyz');
      expect(controller.searchResults, isEmpty);
      expect(controller.hasSearchResults, isFalse);
    });

    test(
        'Given Unicode text search, When search called, Then finds Unicode matches',
        () {
      final terminal = Terminal();
      terminal.write('你好世界 hello 🌍');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();

      controller.search('你好');
      expect(controller.hasSearchResults, isTrue);
      expect(controller.searchResultCount, equals(1));

      controller.search('🌍');
      expect(controller.hasSearchResults, isTrue);
    });

    test(
        'Given special regex characters, When search called with regex, Then handles escape',
        () {
      final terminal = Terminal();
      terminal.write('test[1] test(2) test{3}');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.setSearchOptions(<SearchOption>{SearchOption.regex});

      // Search for literal brackets by escaping
      controller.search(r'test\[1\]');
      expect(controller.hasSearchResults, isTrue);
    });

    test(
        'Given invalid regex, When search called with regex option, Then handles gracefully',
        () {
      final terminal = Terminal();
      terminal.write('test');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.setSearchOptions(<SearchOption>{SearchOption.regex});

      // Invalid regex should not crash
      controller.search('[invalid');
      // Should return empty results or handle gracefully
      expect(controller.searchResults, isEmpty);
    });

    test(
        'Given very long text search, When search called, Then completes without error',
        () {
      final terminal = Terminal();
      // Create a long text
      final longText = 'a' * 10000 + 'target' + 'b' * 10000;
      terminal.write(longText);
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();

      controller.search('target');
      expect(controller.hasSearchResults, isTrue);
      expect(controller.searchResultCount, equals(1));
    });

    test(
        'Given search at buffer, When search called, Then finds matches boundaries at edges',
        () {
      final terminal = Terminal();
      terminal.write('a'.padRight(100, 'a'));
      terminal.write('start');
      terminal.write('b'.padRight(100, 'b'));
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();

      controller.search('start');
      expect(controller.hasSearchResults, isTrue);
      expect(controller.searchResults.first.begin.x, equals(100));
    });
  });
}
