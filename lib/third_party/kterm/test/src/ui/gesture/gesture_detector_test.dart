import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/gesture/gesture_detector.dart';

void main() {
  group('TerminalGestureDetector', () {
    testWidgets('builds with child widget', (tester) async {
      await tester.pumpWidget(
        const TerminalGestureDetector(
          child: SizedBox(width: 100, height: 100),
        ),
      );

      expect(find.byType(RawGestureDetector), findsOneWidget);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('accepts tap callbacks', (tester) async {
      await tester.pumpWidget(
        TerminalGestureDetector(
          onTapDown: (_) {},
          onTapUp: (_) {},
          child: const SizedBox(width: 100, height: 100),
        ),
      );

      // Widget should build without error
      expect(find.byType(RawGestureDetector), findsOneWidget);
    });

    testWidgets('accepts single tap callback', (tester) async {
      await tester.pumpWidget(
        TerminalGestureDetector(
          onSingleTapUp: (_) {},
          child: const SizedBox(width: 100, height: 100),
        ),
      );

      expect(find.byType(RawGestureDetector), findsOneWidget);
    });

    testWidgets('accepts double tap callback', (tester) async {
      await tester.pumpWidget(
        TerminalGestureDetector(
          onDoubleTapDown: (_) {},
          child: const SizedBox(width: 100, height: 100),
        ),
      );

      expect(find.byType(RawGestureDetector), findsOneWidget);
    });

    testWidgets('accepts secondary tap callbacks', (tester) async {
      await tester.pumpWidget(
        TerminalGestureDetector(
          onSecondaryTapDown: (_) {},
          onSecondaryTapUp: (_) {},
          child: const SizedBox(width: 100, height: 100),
        ),
      );

      expect(find.byType(RawGestureDetector), findsOneWidget);
    });

    testWidgets('accepts tertiary tap callbacks', (tester) async {
      await tester.pumpWidget(
        TerminalGestureDetector(
          onTertiaryTapDown: (_) {},
          onTertiaryTapUp: (_) {},
          child: const SizedBox(width: 100, height: 100),
        ),
      );

      expect(find.byType(RawGestureDetector), findsOneWidget);
    });

    testWidgets('accepts long press callbacks', (tester) async {
      await tester.pumpWidget(
        TerminalGestureDetector(
          onLongPressStart: (_) {},
          onLongPressMoveUpdate: (_) {},
          child: const SizedBox(width: 100, height: 100),
        ),
      );

      expect(find.byType(RawGestureDetector), findsOneWidget);
    });

    testWidgets('accepts drag callbacks', (tester) async {
      await tester.pumpWidget(
        TerminalGestureDetector(
          onDragStart: (_) {},
          onDragUpdate: (_) {},
          child: const SizedBox(width: 100, height: 100),
        ),
      );

      expect(find.byType(RawGestureDetector), findsOneWidget);
    });

    testWidgets('accepts all gesture callbacks simultaneously', (tester) async {
      await tester.pumpWidget(
        TerminalGestureDetector(
          onTapDown: (_) {},
          onTapUp: (_) {},
          onSingleTapUp: (_) {},
          onDoubleTapDown: (_) {},
          onSecondaryTapDown: (_) {},
          onSecondaryTapUp: (_) {},
          onTertiaryTapDown: (_) {},
          onTertiaryTapUp: (_) {},
          onLongPressStart: (_) {},
          onLongPressMoveUpdate: (_) {},
          onDragStart: (_) {},
          onDragUpdate: (_) {},
          child: const SizedBox(width: 100, height: 100),
        ),
      );

      expect(find.byType(RawGestureDetector), findsOneWidget);
    });

    testWidgets('widget tree contains RawGestureDetector with child',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: TerminalGestureDetector(
            child: Text('Test'),
          ),
        ),
      );

      expect(find.byType(RawGestureDetector), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('works without any callbacks', (tester) async {
      await tester.pumpWidget(
        const TerminalGestureDetector(
          child: SizedBox(width: 100, height: 100),
        ),
      );

      expect(find.byType(RawGestureDetector), findsOneWidget);
    });
  });
}
