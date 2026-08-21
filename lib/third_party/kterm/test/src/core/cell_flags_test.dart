import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/buffer/cell_flags.dart';

void main() {
  group('CellFlags', () {
    test('bold has correct bit value', () {
      expect(CellFlags.bold, equals(1 << 0));
    });

    test('faint has correct bit value', () {
      expect(CellFlags.faint, equals(1 << 1));
    });

    test('italic has correct bit value', () {
      expect(CellFlags.italic, equals(1 << 2));
    });

    test('underline has correct bit value', () {
      expect(CellFlags.underline, equals(1 << 3));
    });

    test('blink has correct bit value', () {
      expect(CellFlags.blink, equals(1 << 4));
    });

    test('inverse has correct bit value', () {
      expect(CellFlags.inverse, equals(1 << 5));
    });

    test('invisible has correct bit value', () {
      expect(CellFlags.invisible, equals(1 << 6));
    });

    test('all flags can be combined', () {
      final combined = CellFlags.bold |
          CellFlags.faint |
          CellFlags.italic |
          CellFlags.underline |
          CellFlags.blink |
          CellFlags.inverse |
          CellFlags.invisible;

      expect(combined, equals(0x7F));
    });

    test('individual flags can be checked', () {
      final flags = CellFlags.bold | CellFlags.italic;

      expect(flags & CellFlags.bold, isNonZero);
      expect(flags & CellFlags.faint, equals(0));
      expect(flags & CellFlags.italic, isNonZero);
    });
  });
}
