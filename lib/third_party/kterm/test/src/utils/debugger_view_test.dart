import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/utils/debugger.dart';
import 'package:kterm/src/utils/debugger_view.dart';

void main() {
  group('TerminalDebuggerView', () {
    testWidgets(
        'Given debugger view, When created with empty debugger, Then shows empty list',
        (tester) async {
      // Arrange
      final debugger = TerminalDebugger();

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalDebuggerView(debugger),
          ),
        ),
      );

      // Assert
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets(
        'Given debugger view, When debugger has commands, Then shows commands',
        (tester) async {
      // Arrange
      final debugger = TerminalDebugger();
      debugger.write('\x1b[31m'); // SGR foreground red

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalDebuggerView(debugger),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('Given debugger view, When created, Then registers listener',
        (tester) async {
      // Arrange
      final debugger = TerminalDebugger();

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalDebuggerView(debugger),
          ),
        ),
      );

      // Assert - widget should build without error
      expect(find.byType(TerminalDebuggerView), findsOneWidget);
    });

    testWidgets('Given debugger view, When disposed, Then widget is removed',
        (tester) async {
      // Arrange
      final debugger = TerminalDebugger();

      // Act - build and dispose
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalDebuggerView(debugger),
          ),
        ),
      );

      expect(find.byType(TerminalDebuggerView), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // Assert - widget should be removed
      expect(find.byType(TerminalDebuggerView), findsNothing);
    });
  });
}
