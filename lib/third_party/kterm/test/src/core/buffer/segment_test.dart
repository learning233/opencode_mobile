import 'package:test/test.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('BufferSegment', () {
    group('Constructor', () {
      test('Given full bounds, When created, Then fields are set', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          2,
          8,
        );
        expect(segment.range, isA<BufferRangeLine>());
        expect(segment.line, 3);
        expect(segment.start, 2);
        expect(segment.end, 8);
      });

      test('Given null start, When created, Then start is null', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          null,
          8,
        );
        expect(segment.start, isNull);
        expect(segment.end, 8);
      });

      test('Given null end, When created, Then end is null', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          2,
          null,
        );
        expect(segment.start, 2);
        expect(segment.end, isNull);
      });

      test('Given both null, When created, Then both are null', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          null,
          null,
        );
        expect(segment.start, isNull);
        expect(segment.end, isNull);
      });

      test('Given start > end, When created, Then throws assertion', () {
        expect(
          () => BufferSegment(
            BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
            3,
            10,
            5,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('Given start == end, When created, Then valid (equal bounds)', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          5,
          5,
        );
        expect(segment.start, 5);
        expect(segment.end, 5);
      });
    });

    group('isWithin', () {
      test('Given position on same line within bounds, Then returns true', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          2,
          8,
        );
        expect(segment.isWithin(CellOffset(2, 3)), isTrue);
        expect(segment.isWithin(CellOffset(5, 3)), isTrue);
        expect(segment.isWithin(CellOffset(8, 3)), isTrue);
      });

      test('Given position on same line outside bounds, Then returns false',
          () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          2,
          8,
        );
        expect(segment.isWithin(CellOffset(1, 3)), isFalse);
        expect(segment.isWithin(CellOffset(9, 3)), isFalse);
      });

      test('Given position on different line, Then returns false', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          2,
          8,
        );
        expect(segment.isWithin(CellOffset(5, 2)), isFalse);
        expect(segment.isWithin(CellOffset(5, 4)), isFalse);
      });

      test('Given null start (unbounded start), Then checks only end', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          null,
          5,
        );
        expect(segment.isWithin(CellOffset(0, 3)), isTrue);
        expect(segment.isWithin(CellOffset(3, 3)), isTrue);
        expect(segment.isWithin(CellOffset(5, 3)), isTrue);
        expect(segment.isWithin(CellOffset(6, 3)), isFalse);
      });

      test('Given null end (unbounded end), Then checks only start', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          5,
          null,
        );
        expect(segment.isWithin(CellOffset(5, 3)), isTrue);
        expect(segment.isWithin(CellOffset(8, 3)), isTrue);
        expect(segment.isWithin(CellOffset(4, 3)), isFalse);
      });

      test(
          'Given both null (full line), Then all positions on line return true',
          () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          null,
          null,
        );
        expect(segment.isWithin(CellOffset(0, 3)), isTrue);
        expect(segment.isWithin(CellOffset(100, 3)), isTrue);
      });
    });

    group('toString', () {
      test(
          'Given segment with bounds, When toString, Then returns formatted string',
          () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          2,
          8,
        );
        expect(segment.toString(), contains('Segment'));
        expect(segment.toString(), contains('3'));
        expect(segment.toString(), contains('2'));
        expect(segment.toString(), contains('8'));
      });

      test('Given segment with null start, When toString, Then shows "start"',
          () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          null,
          8,
        );
        expect(segment.toString(), contains('start'));
        expect(segment.toString(), contains('8'));
      });

      test('Given segment with null end, When toString, Then shows "end"', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          2,
          null,
        );
        expect(segment.toString(), contains('end'));
        expect(segment.toString(), contains('2'));
      });
    });

    group('hashCode', () {
      test('Given same segment, When hashCode called, Then equal hash codes',
          () {
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));
        final segment1 = BufferSegment(range, 3, 2, 8);
        final segment2 = BufferSegment(range, 3, 2, 8);
        expect(segment1.hashCode, equals(segment2.hashCode));
      });

      test('Given different segments, When hashCode called, Then may differ',
          () {
        final segment1 = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          2,
          8,
        );
        final segment2 = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          2,
          9,
        );
        // Different end value, hash codes likely different
        expect(segment1.hashCode, isNot(equals(segment2.hashCode)));
      });

      test('Given segment, When hashCode called, Then returns int', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          2,
          8,
        );
        expect(segment.hashCode, isA<int>());
      });
    });

    group('Equality', () {
      test('Given two equal segments, When equality checked, Then returns true',
          () {
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));
        final segment1 = BufferSegment(range, 3, 2, 8);
        final segment2 = BufferSegment(range, 3, 2, 8);
        expect(segment1 == segment2, isTrue);
      });

      test(
          'Given segments with different range, When equality checked, Then returns false',
          () {
        final range1 = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));
        final range2 = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 6));
        final segment1 = BufferSegment(range1, 3, 2, 8);
        final segment2 = BufferSegment(range2, 3, 2, 8);
        expect(segment1 == segment2, isFalse);
      });

      test(
          'Given segments with different line, When equality checked, Then returns false',
          () {
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));
        final segment1 = BufferSegment(range, 3, 2, 8);
        final segment2 = BufferSegment(range, 4, 2, 8);
        expect(segment1 == segment2, isFalse);
      });

      test(
          'Given segments with different start, When equality checked, Then returns false',
          () {
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));
        final segment1 = BufferSegment(range, 3, 2, 8);
        final segment2 = BufferSegment(range, 3, 3, 8);
        expect(segment1 == segment2, isFalse);
      });

      test(
          'Given segments with different end, When equality checked, Then returns false',
          () {
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));
        final segment1 = BufferSegment(range, 3, 2, 8);
        final segment2 = BufferSegment(range, 3, 2, 9);
        expect(segment1 == segment2, isFalse);
      });

      test('Given segment compared to null, Then returns false', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          2,
          8,
        );
        expect(segment == null, isFalse);
      });

      test('Given segment compared to non-Segment, Then returns false', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          2,
          8,
        );
        expect(segment == 'string', isFalse);
        expect(segment == 123, isFalse);
      });

      test('Given same instance, When equality checked, Then returns true', () {
        final segment = BufferSegment(
          BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5)),
          3,
          2,
          8,
        );
        expect(segment == segment, isTrue);
      });
    });
  });
}
