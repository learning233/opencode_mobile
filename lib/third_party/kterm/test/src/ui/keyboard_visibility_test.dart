import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/keyboard_visibility.dart';

void main() {
  group('KeyboardVisibilty', () {
    testWidgets(
      'Given KeyboardVisibilty, When created, Then renders child',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: KeyboardVisibilty(
              child: Text('Test'),
            ),
          ),
        );

        expect(find.text('Test'), findsOneWidget);
      },
    );

    testWidgets(
      'Given KeyboardVisibilty with callbacks, When created, Then has callbacks',
      (tester) async {
        var showCalled = false;
        var hideCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: KeyboardVisibilty(
              child: const Text('Test'),
              onKeyboardShow: () => showCalled = true,
              onKeyboardHide: () => hideCalled = true,
            ),
          ),
        );

        final state = tester.state<KeyboardVisibiltyState>(
          find.byType(KeyboardVisibilty),
        );

        expect(state, isNotNull);
      },
    );
  });
}
