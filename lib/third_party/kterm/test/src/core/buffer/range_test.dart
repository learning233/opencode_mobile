import 'package:test/test.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('BufferRange', () {
    group('BufferRange (abstract base class)', () {
      test(
          'Given BufferRange, When accessed via subclass, Then isNormalized works',
          () {
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));
        expect(range.isNormalized, isTrue);
      });

      test(
          'Given BufferRange, When accessed via subclass, Then isCollapsed works',
          () {
        final range = BufferRangeLine.collapsed(CellOffset(5, 5));
        expect(range.isCollapsed, isTrue);
      });

      test('Given BufferRange, When compared to null, Then returns false', () {
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));
        expect(range == null, isFalse);
      });

      test('Given BufferRange, When compared to non-Range, Then returns false',
          () {
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));
        expect(range == 'string', isFalse);
        expect(range == 123, isFalse);
      });
    });

    group('BufferRangeLine', () {
      test('Given a normal range, When created, Then begin and end are set',
          () {
        // Arrange & Act
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));

        // Assert
        expect(range.begin.x, 0);
        expect(range.begin.y, 0);
        expect(range.end.x, 10);
        expect(range.end.y, 5);
      });

      test(
          'Given a collapsed range, When created with BufferRange.collapsed, Then begin equals end',
          () {
        // Arrange & Act
        final range = BufferRangeLine.collapsed(CellOffset(5, 5));

        // Assert
        expect(range.begin.x, 5);
        expect(range.begin.y, 5);
        expect(range.end.x, 5);
        expect(range.end.y, 5);
      });

      test(
          'Given a range where begin is before end, When isNormalized checked, Then returns true',
          () {
        // Arrange
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));

        // Act & Assert
        expect(range.isNormalized, isTrue);
      });

      test(
          'Given a range where begin equals end, When isNormalized checked, Then returns true',
          () {
        // Arrange
        final range = BufferRangeLine(CellOffset(5, 5), CellOffset(5, 5));

        // Act & Assert
        expect(range.isNormalized, isTrue);
      });

      test(
          'Given a range where begin is after end, When isNormalized checked, Then returns false',
          () {
        // Arrange
        final range = BufferRangeLine(CellOffset(10, 5), CellOffset(0, 0));

        // Act & Assert
        expect(range.isNormalized, isFalse);
      });

      test(
          'Given a range where begin equals end, When isCollapsed checked, Then returns true',
          () {
        // Arrange
        final range = BufferRangeLine.collapsed(CellOffset(5, 5));

        // Act & Assert
        expect(range.isCollapsed, isTrue);
      });

      test(
          'Given a range where begin is not equal to end, When isCollapsed checked, Then returns false',
          () {
        // Arrange
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));

        // Act & Assert
        expect(range.isCollapsed, isFalse);
      });

      test(
          'Given a reversed range, When normalized called, Then returns properly ordered range',
          () {
        // Arrange
        final range = BufferRangeLine(CellOffset(10, 5), CellOffset(0, 0));

        // Act
        final normalized = range.normalized;

        // Assert
        expect(normalized.begin.x, 0);
        expect(normalized.begin.y, 0);
        expect(normalized.end.x, 10);
        expect(normalized.end.y, 5);
      });

      test(
          'Given a position inside the range, When contains called, Then returns true',
          () {
        // Arrange
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));

        // Act & Assert
        expect(range.contains(CellOffset(5, 3)), isTrue);
        expect(range.contains(CellOffset(0, 0)), isTrue);
        expect(range.contains(CellOffset(10, 5)), isTrue);
      });

      test(
          'Given a position outside the range, When contains called, Then returns false',
          () {
        // Arrange
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));

        // Act & Assert
        expect(range.contains(CellOffset(11, 5)), isFalse);
        expect(range.contains(CellOffset(0, 6)), isFalse);
        expect(range.contains(CellOffset(-1, 0)), isFalse);
      });

      test(
          'Given two overlapping ranges, When merge called, Then returns the smallest range containing both',
          () {
        // Arrange
        final range1 = BufferRangeLine(CellOffset(0, 0), CellOffset(5, 5));
        final range2 = BufferRangeLine(CellOffset(3, 3), CellOffset(10, 10));

        // Act
        final merged = range1.merge(range2);

        // Assert
        expect(merged.begin.x, 0);
        expect(merged.begin.y, 0);
        expect(merged.end.x, 10);
        expect(merged.end.y, 10);
      });

      test(
          'Given two non-overlapping ranges, When merge called, Then returns the union range',
          () {
        // Arrange
        final range1 = BufferRangeLine(CellOffset(0, 0), CellOffset(3, 3));
        final range2 = BufferRangeLine(CellOffset(5, 5), CellOffset(10, 10));

        // Act
        final merged = range1.merge(range2);

        // Assert
        expect(merged.begin.x, 0);
        expect(merged.begin.y, 0);
        expect(merged.end.x, 10);
        expect(merged.end.y, 10);
      });

      test(
          'Given a position inside the range, When extend called, Then returns the same range',
          () {
        // Arrange
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));

        // Act
        final extended = range.extend(CellOffset(5, 3));

        // Assert
        expect(extended.begin.x, 0);
        expect(extended.begin.y, 0);
        expect(extended.end.x, 10);
        expect(extended.end.y, 5);
      });

      test(
          'Given a position outside the range, When extend called, Then returns expanded range',
          () {
        // Arrange
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));

        // Act
        final extended = range.extend(CellOffset(15, 10));

        // Assert
        expect(extended.begin.x, 0);
        expect(extended.begin.y, 0);
        expect(extended.end.x, 15);
        expect(extended.end.y, 10);
      });

      test('Given two equal ranges, When equality checked, Then returns true',
          () {
        // Arrange
        final range1 = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));
        final range2 = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));

        // Act & Assert
        expect(range1 == range2, isTrue);
      });

      test(
          'Given two different ranges, When equality checked, Then returns false',
          () {
        // Arrange
        final range1 = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));
        final range2 = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 6));

        // Act & Assert
        expect(range1 == range2, isFalse);
      });

      test('Given a range, When toString called, Then returns formatted string',
          () {
        // Arrange
        final range = BufferRangeLine(CellOffset(0, 0), CellOffset(10, 5));

        // Act & Assert
        expect(range.toString(), contains('Line Range'));
      });
    });

    group('BufferRangeBlock', () {
      test(
          'Given a normal block range, When created, Then begin and end are set',
          () {
        // Arrange & Act
        final range = BufferRangeBlock(CellOffset(0, 0), CellOffset(10, 5));

        // Assert
        expect(range.begin.x, 0);
        expect(range.begin.y, 0);
        expect(range.end.x, 10);
        expect(range.end.y, 5);
      });

      test(
          'Given a reversed block range, When normalized called, Then returns properly ordered range',
          () {
        // Arrange
        final range = BufferRangeBlock(CellOffset(10, 5), CellOffset(0, 0));

        // Act
        final normalized = range.normalized;

        // Assert
        expect(normalized.begin.x, 0);
        expect(normalized.begin.y, 0);
        expect(normalized.end.x, 10);
        expect(normalized.end.y, 5);
      });

      test(
          'Given a position inside the block range, When contains called, Then returns true',
          () {
        // Arrange
        final range = BufferRangeBlock(CellOffset(0, 0), CellOffset(10, 5));

        // Act & Assert
        expect(range.contains(CellOffset(5, 3)), isTrue);
      });

      test(
          'Given a position outside the block range, When contains called, Then returns false',
          () {
        // Arrange
        final range = BufferRangeBlock(CellOffset(0, 0), CellOffset(10, 5));

        // Act & Assert
        expect(range.contains(CellOffset(11, 5)), isFalse);
      });

      test(
          'Given two overlapping block ranges, When merge called, Then returns the union range',
          () {
        // Arrange
        final range1 = BufferRangeBlock(CellOffset(0, 0), CellOffset(5, 5));
        final range2 = BufferRangeBlock(CellOffset(3, 3), CellOffset(10, 10));

        // Act
        final merged = range1.merge(range2);

        // Assert
        expect(merged.begin.x, 0);
        expect(merged.begin.y, 0);
        expect(merged.end.x, 10);
        expect(merged.end.y, 10);
      });

      test(
          'Given a block range, When toSegments called, Then returns segments for each row',
          () {
        // Arrange
        final range = BufferRangeBlock(CellOffset(2, 0), CellOffset(5, 2));

        // Act
        final segments = range.toSegments().toList();

        // Assert
        expect(segments.length, 3);
      });

      test('Given block range, When hashCode called, Then returns int', () {
        final range = BufferRangeBlock(CellOffset(0, 0), CellOffset(10, 5));
        expect(range.hashCode, isA<int>());
      });
    });
  });
}
