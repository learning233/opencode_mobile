import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/selection_mode.dart';

void main() {
  group('SelectionMode', () {
    test('Given line, When name accessed, Then returns line', () {
      expect(SelectionMode.line.name, equals('line'));
    });

    test('Given block, When name accessed, Then returns block', () {
      expect(SelectionMode.block.name, equals('block'));
    });

    test('Given all values, When enumerated, Then has 2 values', () {
      expect(SelectionMode.values.length, equals(2));
    });
  });
}
