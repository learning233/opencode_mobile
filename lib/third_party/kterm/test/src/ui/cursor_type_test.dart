import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/cursor_type.dart';

void main() {
  group('TerminalCursorType', () {
    test('Given block, When name accessed, Then returns block', () {
      expect(TerminalCursorType.block.name, equals('block'));
    });

    test('Given underline, When name accessed, Then returns underline', () {
      expect(TerminalCursorType.underline.name, equals('underline'));
    });

    test('Given verticalBar, When name accessed, Then returns verticalBar', () {
      expect(TerminalCursorType.verticalBar.name, equals('verticalBar'));
    });

    test('Given all values, When enumerated, Then has 3 values', () {
      expect(TerminalCursorType.values.length, equals(3));
    });
  });
}
