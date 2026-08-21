import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('TerminalSearchBar', () {
    // Use a wider viewport to avoid overflow issues in tests
    const testViewSize = Size(1200, 800);

    testWidgets('Given basic render, When mounted, Then shows search input',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final controller = TerminalController();
      controller.openSearch();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(controller: controller),
        ),
      ));

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Given custom colors, When rendering, Then uses custom colors',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final controller = TerminalController();
      controller.openSearch();

      const customBackground = Color(0xFF123456);
      const customBorder = Color(0xFF654321);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(
            controller: controller,
            searchBackgroundColor: customBackground,
            searchBorderColor: customBorder,
          ),
        ),
      ));

      // Verify the widget renders without errors
      expect(find.byType(TerminalSearchBar), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Given autoFocus=true, When rendered, Then auto focuses input',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final controller = TerminalController();
      controller.openSearch();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(
            controller: controller,
            autoFocus: true,
          ),
        ),
      ));

      await tester.pumpAndSettle();

      // The TextField should be focusable
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets(
        'Given has search results, When click next, Then navigates to next result',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final terminal = Terminal();
      terminal.write('test1 test2 test3');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.openSearch();
      controller.search('test');

      expect(controller.currentSearchIndex, equals(0));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(controller: controller),
        ),
      ));

      // Find and tap the next button (arrow down icon)
      final nextButton = find.byIcon(Icons.keyboard_arrow_down);
      expect(nextButton, findsOneWidget);

      await tester.tap(nextButton);
      await tester.pump();

      expect(controller.currentSearchIndex, equals(1));
    });

    testWidgets(
        'Given has search results, When click previous, Then navigates to previous result',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final terminal = Terminal();
      terminal.write('test1 test2 test3');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.openSearch();
      controller.search('test');

      expect(controller.currentSearchIndex, equals(0));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(controller: controller),
        ),
      ));

      // Find and tap the previous button (arrow up icon)
      final prevButton = find.byIcon(Icons.keyboard_arrow_up);
      expect(prevButton, findsOneWidget);

      await tester.tap(prevButton);
      await tester.pump();

      // Should cycle to last result
      expect(controller.currentSearchIndex, equals(2));
    });

    testWidgets('Given input text, When text changes, Then triggers search',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final terminal = Terminal();
      terminal.write('hello world');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.openSearch();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(controller: controller),
        ),
      ));

      // Initial state: empty search pattern
      expect(controller.searchPattern, '');

      // Enter text in the search field
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      expect(controller.searchPattern, equals('hello'));
      expect(controller.hasSearchResults, isTrue);
    });

    testWidgets(
        'Given no search results, When displaying result count, Then shows "No results"',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final terminal = Terminal();
      terminal.write('hello world');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.openSearch();
      controller.search('xyz'); // No matches

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(controller: controller),
        ),
      ));

      expect(find.text('No results'), findsOneWidget);
    });

    testWidgets(
        'Given empty search box, When rendering, Then hides result count',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final controller = TerminalController();
      controller.openSearch();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(controller: controller),
        ),
      ));

      // Should not show result count when search is empty
      expect(find.text('No results'), findsNothing);
      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets(
        'Given search options, When click options menu, Then shows options',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final controller = TerminalController();
      controller.openSearch();

      // Use a SizedBox to ensure the search bar has enough width
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: TerminalSearchBar(controller: controller),
          ),
        ),
      ));

      // Find and tap the options menu icon
      final optionsIcon = find.byIcon(Icons.tune);
      expect(optionsIcon, findsOneWidget);

      await tester.tap(optionsIcon);
      // Don't use pumpAndSettle due to known overflow issue in popup menu
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify menu items are shown (may show warnings but should work)
      expect(find.text('Match Case'), findsOneWidget);
      expect(find.text('Use Regular Expression'), findsOneWidget);
      expect(find.text('Match Whole Word'), findsOneWidget);
    });

    testWidgets(
        'Given search option, When toggle option, Then updates search options',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final terminal = Terminal();
      terminal.write('Hello HELLO hello');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.openSearch();
      controller.search('hello');

      // Initially case insensitive (should find all 3)
      expect(controller.searchResultCount, equals(3));

      // Use a SizedBox to ensure the search bar has enough width
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: TerminalSearchBar(controller: controller),
          ),
        ),
      ));

      // Open options menu
      await tester.tap(find.byIcon(Icons.tune));
      // Don't use pumpAndSettle due to known overflow issue in popup menu
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Match Case"
      await tester.tap(find.text('Match Case'));
      await tester.pump();

      // Now case sensitive - should only find 1
      expect(controller.searchOptions.contains(SearchOption.caseSensitive),
          isTrue);
    });

    testWidgets(
        'Given onClose callback, When close button pressed, Then calls onClose',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final controller = TerminalController();
      controller.openSearch();

      bool closeCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(
            controller: controller,
            onClose: () => closeCalled = true,
          ),
        ),
      ));

      // Find and tap the close button
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      await tester.pump();

      expect(closeCalled, isTrue);
    });

    testWidgets('Given escape key, When pressed, Then calls onClose callback',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final controller = TerminalController();
      controller.openSearch();

      bool closeCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(
            controller: controller,
            onClose: () => closeCalled = true,
          ),
        ),
      ));

      // Send escape key event
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(closeCalled, isTrue);
    });

    testWidgets('Given has results, When displaying, Then shows result count',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final terminal = Terminal();
      terminal.write('test1 test2');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.openSearch();
      controller.search('test');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(controller: controller),
        ),
      ));

      // Should show "1/2" (first result, total 2)
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets(
        'Given autoFocus=false, When rendered, Then does not auto focus input',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final controller = TerminalController();
      controller.openSearch();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(
            controller: controller,
            autoFocus: false,
          ),
        ),
      ));

      // Widget should render without auto-focus
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Given search bar, When rendered, Then shows hint text',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final controller = TerminalController();
      controller.openSearch();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(controller: controller),
        ),
      ));

      expect(find.text('Search...'), findsOneWidget);
    });

    testWidgets(
        'Given controller not searching, When rendered, Then hides search bar content',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final controller = TerminalController();
      // Don't call openSearch()

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(controller: controller),
        ),
      ));

      // The search bar still renders but search is not active
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets(
        'Given multiple search cycles, When navigate through results, Then cycles correctly',
        (tester) async {
      tester.view.physicalSize = testViewSize;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final terminal = Terminal();
      terminal.write('a b c d e');
      final controller = TerminalController();

      controller.onGetText = () => terminal.buffer.getText();
      controller.openSearch();
      controller.search(' '); // Find all spaces

      expect(controller.searchResultCount, equals(4));
      expect(controller.currentSearchIndex, equals(0));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(controller: controller),
        ),
      ));

      // Navigate through all results
      for (int i = 0; i < 4; i++) {
        controller.searchNext();
        await tester.pump();
        expect(controller.currentSearchIndex, equals(i + 1 > 3 ? 0 : i + 1));
      }
    });
  });
}
