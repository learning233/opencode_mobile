import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/scroll_handler.dart';
import 'package:kterm/src/core/buffer/cell_offset.dart';
import 'package:kterm/core.dart';

void main() {
  group('TerminalScrollGestureHandler', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal();
    });

    testWidgets(
        'Given terminal not in alt buffer, When widget built, Then renders child',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalScrollGestureHandler(
            terminal: terminal,
            getCellOffset: (offset) => CellOffset(0, 0),
            getLineHeight: () => 20.0,
            simulateScroll: true,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      // When not in alt buffer, it should just render the child
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets(
        'Given simulateScroll false, When widget built, Then widget builds successfully',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalScrollGestureHandler(
            terminal: terminal,
            getCellOffset: (offset) => CellOffset(0, 0),
            getLineHeight: () => 20.0,
            simulateScroll: false,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets(
        'Given custom getCellOffset, When widget built, Then widget builds successfully',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalScrollGestureHandler(
            terminal: terminal,
            getCellOffset: (offset) => CellOffset(5, 10),
            getLineHeight: () => 20.0,
            simulateScroll: true,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
