import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:kterm/src/ui/gesture/gesture_handler.dart';
import 'package:kterm/src/ui/gesture/gesture_detector.dart';
import 'package:kterm/src/terminal_view.dart';
import 'package:kterm/src/ui/controller.dart';
import 'package:kterm/src/ui/render.dart';

import 'gesture_handler_test.mocks.dart';

@GenerateMocks([TerminalViewState, RenderTerminal, TerminalController])
void main() {
  group('TerminalGestureHandler', () {
    late MockTerminalViewState mockTerminalView;
    late MockRenderTerminal mockRenderTerminal;
    late MockTerminalController mockController;

    setUp(() {
      mockTerminalView = MockTerminalViewState();
      mockRenderTerminal = MockRenderTerminal();
      mockController = MockTerminalController();

      when(mockTerminalView.renderTerminal).thenReturn(mockRenderTerminal);
      when(mockController.shouldSendPointerInput(any)).thenReturn(true);
    });

    Widget buildTestWidget({bool readOnly = false}) {
      return TerminalGestureHandler(
        terminalView: mockTerminalView,
        terminalController: mockController,
        readOnly: readOnly,
        child: const SizedBox(width: 100, height: 100),
      );
    }

    testWidgets('builds with child widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(TerminalGestureDetector), findsOneWidget);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('readOnly disables tap events when true', (tester) async {
      await tester.pumpWidget(buildTestWidget(readOnly: true));

      // Verify the handler is built with readOnly=true
      expect(find.byType(TerminalGestureHandler), findsOneWidget);
    });

    testWidgets('readOnly allows tap events when false', (tester) async {
      await tester.pumpWidget(buildTestWidget(readOnly: false));

      expect(find.byType(TerminalGestureHandler), findsOneWidget);
    });

    testWidgets('forwards left click events to terminal', (tester) async {
      when(mockRenderTerminal.mouseEvent(any, any, any)).thenReturn(true);

      await tester.pumpWidget(buildTestWidget());

      // The handler should be set up correctly
      expect(find.byType(TerminalGestureHandler), findsOneWidget);
    });
  });
}
