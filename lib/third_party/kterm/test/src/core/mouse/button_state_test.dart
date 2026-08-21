import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/mouse/button_state.dart';

void main() {
  group('TerminalMouseButtonState', () {
    test('has up state', () {
      expect(TerminalMouseButtonState.up, isNotNull);
    });

    test('has down state', () {
      expect(TerminalMouseButtonState.down, isNotNull);
    });

    test('has exactly 2 values', () {
      expect(TerminalMouseButtonState.values.length, equals(2));
    });
  });
}
