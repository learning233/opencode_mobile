import 'package:test/test.dart';
import 'package:kterm/src/utils/lookup_table.dart';

void main() {
  group('FastLookupTable', () {
    group('constructor', () {
      test('creates table from map', () {
        final table = FastLookupTable<String>({0: 'a', 1: 'b', 2: 'c'});
        expect(table[0], equals('a'));
        expect(table[1], equals('b'));
        expect(table[2], equals('c'));
      });

      test('throws on empty map', () {
        // FastLookupTable does not support empty maps
        expect(() => FastLookupTable<String>({}), throwsA(anything));
      });

      test('handles single element', () {
        final table = FastLookupTable<String>({5: 'value'});
        expect(table[5], equals('value'));
        expect(table.maxIndex, equals(5));
      });

      test('finds max index from multiple keys', () {
        final table = FastLookupTable<String>({10: 'a', 5: 'b', 20: 'c'});
        expect(table.maxIndex, equals(20));
      });

      test('handles non-sequential keys', () {
        final table = FastLookupTable<String>({100: 'a', 50: 'b', 75: 'c'});
        expect(table[50], equals('b'));
        expect(table[75], equals('c'));
        expect(table[100], equals('a'));
        expect(table.maxIndex, equals(100));
      });
    });

    group('operator []', () {
      late FastLookupTable<String> table;

      setUp(() {
        table = FastLookupTable<String>({0: 'a', 1: 'b', 2: 'c'});
      });

      test('returns value for valid index', () {
        expect(table[0], equals('a'));
        expect(table[1], equals('b'));
        expect(table[2], equals('c'));
      });

      test('returns null for index not in map', () {
        expect(table[5], isNull);
        expect(table[100], isNull);
      });

      test('throws for negative index', () {
        // FastLookupTable does not support negative indices
        expect(() => table[-1], throwsA(anything));
      });

      test('returns null for index beyond max', () {
        expect(table[10], isNull);
      });

      test('returns null for index at max boundary when not set', () {
        final singleTable = FastLookupTable<String>({5: 'value'});
        // 0-4 are not set
        for (int i = 0; i < 5; i++) {
          expect(singleTable[i], isNull);
        }
        expect(singleTable[5], equals('value'));
      });
    });

    group('maxIndex', () {
      test('returns highest key in map', () {
        final table = FastLookupTable<String>({1: 'a', 10: 'b', 5: 'c'});
        expect(table.maxIndex, equals(10));
      });

      test('throws for empty map', () {
        // FastLookupTable does not support empty maps
        expect(() => FastLookupTable<String>({}), throwsA(anything));
      });
    });

    group('type safety', () {
      test('works with int values', () {
        final table = FastLookupTable<int>({0: 10, 1: 20, 2: 30});
        expect(table[0], equals(10));
        expect(table[1], equals(20));
        expect(table[2], equals(30));
      });

      test('works with bool values', () {
        final table = FastLookupTable<bool>({0: true, 1: false});
        expect(table[0], isTrue);
        expect(table[1], isFalse);
      });

      test('works with custom class values', () {
        final table = FastLookupTable<List<int>>({
          0: [1, 2],
          1: [3, 4]
        });
        expect(table[0], equals([1, 2]));
        expect(table[1], equals([3, 4]));
      });
    });

    group('performance characteristics', () {
      test('access is O(1)', () {
        // Large table for testing
        final map = <int, String>{};
        for (int i = 0; i < 1000; i++) {
          map[i] = 'value_$i';
        }
        final table = FastLookupTable<String>(map);

        // All accesses should be fast (O(1))
        expect(table[0], equals('value_0'));
        expect(table[500], equals('value_500'));
        expect(table[999], equals('value_999'));
      });

      test('handles sparse maps efficiently', () {
        // Sparse map - only 10 values but spread across large range
        final map = <int, String>{};
        for (int i = 0; i < 10; i++) {
          map[i * 100] = 'value_$i';
        }
        final table = FastLookupTable<String>(map);

        // Access should still be O(1)
        expect(table[0], equals('value_0'));
        expect(table[500], equals('value_5'));
        expect(table[900], equals('value_9'));
      });
    });
  });
}
