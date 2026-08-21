import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/buffer/cell_flags.dart';

void main() {
  group('CellFlags', () {
    test('Given CellFlags, When checked, Then contains bold flag', () {
      // Assert
      expect(CellFlags.bold, equals(1 << 0));
    });

    test('Given CellFlags, When checked, Then contains faint flag', () {
      // Assert
      expect(CellFlags.faint, equals(1 << 1));
    });

    test('Given CellFlags, When checked, Then contains italic flag', () {
      // Assert
      expect(CellFlags.italic, equals(1 << 2));
    });

    test('Given CellFlags, When checked, Then contains underline flag', () {
      // Assert
      expect(CellFlags.underline, equals(1 << 3));
    });

    test('Given CellFlags, When checked, Then contains blink flag', () {
      // Assert
      expect(CellFlags.blink, equals(1 << 4));
    });

    test('Given CellFlags, When checked, Then contains inverse flag', () {
      // Assert
      expect(CellFlags.inverse, equals(1 << 5));
    });

    test('Given CellFlags, When checked, Then contains invisible flag', () {
      // Assert
      expect(CellFlags.invisible, equals(1 << 6));
    });

    test(
        'Given CellFlags, When flags combined, Then produce expected bit patterns',
        () {
      // Assert - verify flags can be combined
      final boldItalic = CellFlags.bold | CellFlags.italic;
      expect(boldItalic, equals((1 << 0) | (1 << 2)));
    });
  });
}
