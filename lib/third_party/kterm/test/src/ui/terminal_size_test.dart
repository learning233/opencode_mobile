import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/terminal_size.dart';

void main() {
  group('TerminalSize', () {
    test('Given width and height, When created, Then stores values', () {
      final size = TerminalSize(80, 24);

      expect(size.width, equals(80));
      expect(size.height, equals(24));
    });

    group('equality', () {
      test('Given same dimensions, When compared, Then equals', () {
        final size1 = TerminalSize(80, 24);
        final size2 = TerminalSize(80, 24);

        expect(size1, equals(size2));
      });

      test('Given different width, When compared, Then not equals', () {
        final size1 = TerminalSize(80, 24);
        final size2 = TerminalSize(100, 24);

        expect(size1, isNot(equals(size2)));
      });

      test('Given different height, When compared, Then not equals', () {
        final size1 = TerminalSize(80, 24);
        final size2 = TerminalSize(80, 40);

        expect(size1, isNot(equals(size2)));
      });

      test('Given same instance, When compared with identical, Then equals',
          () {
        final size = TerminalSize(80, 24);

        expect(identical(size, size), isTrue);
      });
    });

    group('hashCode', () {
      test('Given same dimensions, When hashCode accessed, Then same hash', () {
        final size1 = TerminalSize(80, 24);
        final size2 = TerminalSize(80, 24);

        expect(size1.hashCode, equals(size2.hashCode));
      });

      test(
          'Given different dimensions, When hashCode accessed, Then different hash',
          () {
        final size1 = TerminalSize(80, 24);
        final size2 = TerminalSize(100, 40);

        expect(size1.hashCode, isNot(equals(size2.hashCode)));
      });
    });

    group('toString', () {
      test(
          'Given TerminalSize, When toString called, Then returns formatted string',
          () {
        final size = TerminalSize(80, 24);

        expect(size.toString(), equals('TerminalSize(80, 24)'));
      });
    });
  });
}
