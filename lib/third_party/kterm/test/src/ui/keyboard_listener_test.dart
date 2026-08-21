import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/keyboard_listener.dart';

void main() {
  group('CustomKeyboardListener', () {
    late FocusNode focusNode;

    setUp(() {
      focusNode = FocusNode();
    });

    tearDown(() {
      focusNode.dispose();
    });

    testWidgets('Given valid parameters, When widget built, Then renders child',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomKeyboardListener(
            focusNode: focusNode,
            onInsert: (_) {},
            onComposing: (_) {},
            onKeyEvent: (_, __) => KeyEventResult.ignored,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets(
        'Given autofocus true, When widget built, Then widget builds successfully',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomKeyboardListener(
            focusNode: focusNode,
            autofocus: true,
            onInsert: (_) {},
            onComposing: (_) {},
            onKeyEvent: (_, __) => KeyEventResult.ignored,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomKeyboardListener), findsOneWidget);
    });

    testWidgets(
        'Given key event returns handled, When pressed, Then character is not inserted',
        (tester) async {
      String? insertedText;

      await tester.pumpWidget(
        MaterialApp(
          home: CustomKeyboardListener(
            focusNode: focusNode,
            onInsert: (text) => insertedText = text,
            onComposing: (_) {},
            onKeyEvent: (_, __) => KeyEventResult.handled,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      // Send key event - with handled result, no character should be inserted
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

      expect(insertedText, isNull);
    });

    testWidgets(
        'Given key event returns ignored and no character, When pressed, Then no insert',
        (tester) async {
      String? insertedText;

      await tester.pumpWidget(
        MaterialApp(
          home: CustomKeyboardListener(
            focusNode: focusNode,
            onInsert: (text) => insertedText = text,
            onComposing: (_) {},
            onKeyEvent: (_, __) => KeyEventResult.ignored,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      // Send key without character
      await tester.sendKeyEvent(LogicalKeyboardKey.shift);

      expect(insertedText, isNull);
    });
  });
}
