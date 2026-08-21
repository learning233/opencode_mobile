import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/infinite_scroll_view.dart';
import 'package:kterm/src/ui/pointer_input.dart';

void main() {
  group('InfiniteScrollView', () {
    testWidgets(
      'Given InfiniteScrollView, When created, Then renders child',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: InfiniteScrollView(
              onScroll: _dummyScroll,
              child: Text('Test Content'),
            ),
          ),
        );

        expect(find.text('Test Content'), findsOneWidget);
      },
    );
  });

  group('PointerInput', () {
    test('Given PointerInput enum, When accessed, Then has tap value', () {
      expect(PointerInput.tap, isNotNull);
    });

    test('Given PointerInput enum, When accessed, Then has scroll value', () {
      expect(PointerInput.scroll, isNotNull);
    });

    test('Given PointerInput enum, When accessed, Then has drag value', () {
      expect(PointerInput.drag, isNotNull);
    });

    test('Given PointerInput enum, When accessed, Then has move value', () {
      expect(PointerInput.move, isNotNull);
    });
  });

  group('PointerInputs', () {
    group('constructor', () {
      test('Given set of inputs, When created, Then stores inputs', () {
        final inputs = PointerInputs({PointerInput.tap, PointerInput.scroll});
        expect(inputs.inputs, contains(PointerInput.tap));
        expect(inputs.inputs, contains(PointerInput.scroll));
      });
    });

    group('none constructor', () {
      test('When created, Then has empty inputs', () {
        const inputs = PointerInputs.none();
        expect(inputs.inputs, isEmpty);
      });
    });

    group('all constructor', () {
      test('When created, Then has all input types', () {
        const inputs = PointerInputs.all();
        expect(inputs.inputs, contains(PointerInput.tap));
        expect(inputs.inputs, contains(PointerInput.scroll));
        expect(inputs.inputs, contains(PointerInput.drag));
        expect(inputs.inputs, contains(PointerInput.move));
        expect(inputs.inputs.length, equals(4));
      });
    });
  });
}

void _dummyScroll(double offset) {}
