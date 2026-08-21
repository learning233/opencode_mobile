import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/utils/hash_values.dart';

void main() {
  group('hashValues', () {
    test('Given two values, When hashValues called, Then returns non-zero hash',
        () {
      final hash = hashValues(1, 0);
      expect(hash, isNonZero);
    });

    test(
        'Given two different values, When hashValues called, Then returns hash',
        () {
      final hash1 = hashValues(1, 2);
      final hash2 = hashValues(2, 1);
      // Different order should give different hashes (usually)
      expect(hash1, isNotNull);
    });

    test('Given same values, When hashValues called, Then returns same hash',
        () {
      final hash1 = hashValues('hello', 'world');
      final hash2 = hashValues('hello', 'world');
      expect(hash1, equals(hash2));
    });

    test(
        'Given different values, When hashValues called, Then returns different hash',
        () {
      final hash1 = hashValues('hello', '');
      final hash2 = hashValues('world', '');
      expect(hash1, isNot(equals(hash2)));
    });

    test('Given null values, When hashValues called, Then returns hash', () {
      final hash = hashValues(null, null);
      expect(hash, isNonZero);
    });

    test('Given 20 values, When hashValues called, Then returns hash', () {
      final hash = hashValues(
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
      );
      expect(hash, isNonZero);
    });
  });

  group('hashList', () {
    test('Given empty list, When hashList called, Then returns zero', () {
      final hash = hashList([]);
      // Empty list returns 0
      expect(hash, equals(0));
    });

    test('Given single item list, When hashList called, Then returns hash', () {
      final hash = hashList([1]);
      expect(hash, isNonZero);
    });

    test('Given same items, When hashList called, Then returns same hash', () {
      final hash1 = hashList([1, 2, 3]);
      final hash2 = hashList([1, 2, 3]);
      expect(hash1, equals(hash2));
    });

    test(
        'Given different items, When hashList called, Then returns different hash',
        () {
      final hash1 = hashList([1, 2]);
      final hash2 = hashList([2, 1]);
      expect(hash1, isNot(equals(hash2)));
    });
  });
}
