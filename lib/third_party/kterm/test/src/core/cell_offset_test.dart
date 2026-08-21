import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/buffer/cell_offset.dart';
import 'package:kterm/src/core/buffer/range_line.dart';

void main() {
  group('CellOffset', () {
    test('creates with x and y coordinates', () {
      const offset = CellOffset(5, 10);

      expect(offset.x, equals(5));
      expect(offset.y, equals(10));
    });

    group('isEqual', () {
      test('returns true when coordinates match', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(5, 10);

        expect(offset1.isEqual(offset2), isTrue);
      });

      test('returns false when x differs', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(6, 10);

        expect(offset1.isEqual(offset2), isFalse);
      });

      test('returns false when y differs', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(5, 11);

        expect(offset1.isEqual(offset2), isFalse);
      });
    });

    group('isBefore', () {
      test('returns true when y is less', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(5, 11);

        expect(offset1.isBefore(offset2), isTrue);
      });

      test('returns true when y equals and x is less', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(10, 10);

        expect(offset1.isBefore(offset2), isTrue);
      });

      test('returns false when y is greater', () {
        const offset1 = CellOffset(5, 11);
        const offset2 = CellOffset(5, 10);

        expect(offset1.isBefore(offset2), isFalse);
      });
    });

    group('isAfter', () {
      test('returns true when y is greater', () {
        const offset1 = CellOffset(5, 11);
        const offset2 = CellOffset(5, 10);

        expect(offset1.isAfter(offset2), isTrue);
      });

      test('returns true when y equals and x is greater', () {
        const offset1 = CellOffset(10, 10);
        const offset2 = CellOffset(5, 10);

        expect(offset1.isAfter(offset2), isTrue);
      });

      test('returns false when y is less', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(5, 11);

        expect(offset1.isAfter(offset2), isFalse);
      });
    });

    group('isBeforeOrSame', () {
      test('returns true when same', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(5, 10);

        expect(offset1.isBeforeOrSame(offset2), isTrue);
      });

      test('returns true when before', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(10, 10);

        expect(offset1.isBeforeOrSame(offset2), isTrue);
      });

      test('returns false when after', () {
        const offset1 = CellOffset(10, 10);
        const offset2 = CellOffset(5, 10);

        expect(offset1.isBeforeOrSame(offset2), isFalse);
      });
    });

    group('isAfterOrSame', () {
      test('returns true when same', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(5, 10);

        expect(offset1.isAfterOrSame(offset2), isTrue);
      });

      test('returns true when after', () {
        const offset1 = CellOffset(10, 10);
        const offset2 = CellOffset(5, 10);

        expect(offset1.isAfterOrSame(offset2), isTrue);
      });

      test('returns false when before', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(10, 10);

        expect(offset1.isAfterOrSame(offset2), isFalse);
      });
    });

    group('isAtSameRow', () {
      test('returns true when y matches', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(20, 10);

        expect(offset1.isAtSameRow(offset2), isTrue);
      });

      test('returns false when y differs', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(5, 11);

        expect(offset1.isAtSameRow(offset2), isFalse);
      });
    });

    group('isAtSameColumn', () {
      test('returns true when x matches', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(5, 20);

        expect(offset1.isAtSameColumn(offset2), isTrue);
      });

      test('returns false when x differs', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(6, 10);

        expect(offset1.isAtSameColumn(offset2), isFalse);
      });
    });

    group('isWithin', () {
      test('returns true when offset is within range', () {
        const offset = CellOffset(5, 5);
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 10));

        expect(offset.isWithin(range), isTrue);
      });

      test('returns false when offset is outside range', () {
        const offset = CellOffset(15, 15);
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 10));

        expect(offset.isWithin(range), isFalse);
      });
    });

    group('hashCode', () {
      test('equal offsets have equal hashCodes', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(5, 10);

        expect(offset1.hashCode, equals(offset2.hashCode));
      });

      test('different offsets have different hashCodes', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(6, 10);

        expect(offset1.hashCode, isNot(equals(offset2.hashCode)));
      });
    });

    group('equality', () {
      test('same coordinates are equal', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(5, 10);

        expect(offset1, equals(offset2));
      });

      test('different coordinates are not equal', () {
        const offset1 = CellOffset(5, 10);
        const offset2 = CellOffset(6, 10);

        expect(offset1, isNot(equals(offset2)));
      });

      test('different type is not equal', () {
        const offset = CellOffset(5, 10);

        expect(offset, isNot(equals('CellOffset(5, 10)')));
      });
    });

    test('toString returns formatted string', () {
      const offset = CellOffset(5, 10);

      expect(offset.toString(), equals('CellOffset(5, 10)'));
    });
  });
}
