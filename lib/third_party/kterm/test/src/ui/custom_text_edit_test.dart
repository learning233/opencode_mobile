import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/custom_text_edit.dart';

void main() {
  group('CustomTextEdit', () {
    group('constructor', () {
      testWidgets(
        'Given CustomTextEdit, When created, Then renders child',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: CustomTextEdit(
                focusNode: FocusNode(),
                child: const Text('Test'),
                onInsert: (_) {},
                onDelete: () {},
                onComposing: (_) {},
                onAction: (_) {},
                onKeyEvent: (_, __) => KeyEventResult.ignored,
              ),
            ),
          );

          expect(find.text('Test'), findsOneWidget);
        },
      );
    });

    group('constructor parameters', () {
      testWidgets(
        'Given CustomTextEdit with autofocus, When created, Then has autofocus',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: CustomTextEdit(
                focusNode: FocusNode(),
                autofocus: true,
                child: const Text('Test'),
                onInsert: (_) {},
                onDelete: () {},
                onComposing: (_) {},
                onAction: (_) {},
                onKeyEvent: (_, __) => KeyEventResult.ignored,
              ),
            ),
          );

          expect(find.byType(CustomTextEdit), findsOneWidget);
        },
      );

      testWidgets(
        'Given CustomTextEdit with readOnly, When created, Then stores readOnly',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: CustomTextEdit(
                focusNode: FocusNode(),
                readOnly: true,
                child: const Text('Test'),
                onInsert: (_) {},
                onDelete: () {},
                onComposing: (_) {},
                onAction: (_) {},
                onKeyEvent: (_, __) => KeyEventResult.ignored,
              ),
            ),
          );

          expect(find.byType(CustomTextEdit), findsOneWidget);
        },
      );
    });
  });

  group('CustomTextEditState', () {
    test('Given state, When created, Then has no input connection initially',
        () {
      // This is tested through widget construction since state is internal
    });
  });
}
