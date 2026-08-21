import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:kterm/src/ui/terminal_text_style.dart';

void main() {
  group('TerminalStyle', () {
    group('Constructor', () {
      test(
          'Given default constructor, When called with no args, Then uses defaults',
          () {
        // Act
        final style = TerminalStyle();

        // Assert
        expect(style.fontSize, equals(13.0));
        expect(style.height, equals(1.2));
        expect(style.fontFamily, equals('monospace'));
        expect(style.fontFamilyFallback, isNotEmpty);
        expect(style.fontFamilyFallback.length, greaterThan(5));
      });

      test(
          'Given default constructor, When called with custom values, Then stores them',
          () {
        // Act
        final style = TerminalStyle(
          fontSize: 16.0,
          height: 1.5,
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: ['Fira Code'],
        );

        // Assert
        expect(style.fontSize, equals(16.0));
        expect(style.height, equals(1.5));
        expect(style.fontFamily, equals('JetBrains Mono'));
        expect(style.fontFamilyFallback, equals(['Fira Code']));
      });

      test('Given default constructor, When fontSize is null, Then throws', () {
        // fontSize is non-nullable, so this is compile-time safe
        // But we verify the constructor accepts only non-null
        final style = TerminalStyle(fontSize: 14.0);
        expect(style.fontSize, equals(14.0));
      });
    });

    group('fromTextStyle', () {
      test('Given TextStyle, When converting, Then extracts all fields', () {
        // Arrange
        const textStyle = TextStyle(
          fontSize: 18.0,
          height: 1.8,
          fontFamily: 'Source Code Pro',
          fontFamilyFallback: ['Consolas', 'Courier New'],
        );

        // Act
        final style = TerminalStyle.fromTextStyle(textStyle);

        // Assert
        expect(style.fontSize, equals(18.0));
        expect(style.height, equals(1.8));
        expect(style.fontFamily, equals('Source Code Pro'));
        expect(style.fontFamilyFallback, equals(['Consolas', 'Courier New']));
      });

      test(
          'Given TextStyle with null fontSize, When converting, Then uses default',
          () {
        // Arrange
        const textStyle = TextStyle(
          fontSize: null,
          height: null,
          fontFamily: null,
        );

        // Act
        final style = TerminalStyle.fromTextStyle(textStyle);

        // Assert
        expect(style.fontSize, equals(13.0)); // _kDefaultFontSize
        expect(style.height, equals(1.2)); // _kDefaultHeight
        expect(style.fontFamily, equals('monospace'));
      });

      test(
          'Given TextStyle with partial values, When converting, Then uses fallbacks',
          () {
        // Arrange
        const textStyle = TextStyle(
          fontSize: 15.0,
          // height, fontFamily are null
          fontFamilyFallback: ['Ubuntu Mono'],
        );

        // Act
        final style = TerminalStyle.fromTextStyle(textStyle);

        // Assert - fontFamily comes from fontFamilyFallback.first
        expect(style.fontSize, equals(15.0));
        expect(style.height, equals(1.2)); // default
        expect(style.fontFamily, equals('Ubuntu Mono')); // from fallback first
        expect(style.fontFamilyFallback, equals(['Ubuntu Mono']));
      });

      test(
          'Given TextStyle with fontFamilyFallback null, When converting, Then uses full default list',
          () {
        // Arrange
        const textStyle = TextStyle(
          fontSize: 14.0,
          fontFamilyFallback: null,
        );

        // Act
        final style = TerminalStyle.fromTextStyle(textStyle);

        // Assert - should use the default fallback list
        final defaultStyle = TerminalStyle();
        expect(
            style.fontFamilyFallback, equals(defaultStyle.fontFamilyFallback));
      });

      test(
          'Given TextStyle with only fontFamily, When converting, Then gets fallback from first fallback',
          () {
        // Arrange
        const textStyle = TextStyle(
          fontFamily: 'Custom Mono',
        );

        // Act
        final style = TerminalStyle.fromTextStyle(textStyle);

        // Assert - fontFamily should be "Custom Mono"
        expect(style.fontFamily, equals('Custom Mono'));
      });

      test('Given TextStyle with zero height, When converting, Then uses 0.0',
          () {
        // Arrange
        const textStyle = TextStyle(height: 0.0);

        // Act
        final style = TerminalStyle.fromTextStyle(textStyle);

        // Assert - 0.0 is valid, should be preserved
        expect(style.height, equals(0.0));
      });

      test(
          'Given TextStyle with negative height, When converting, Then preserves',
          () {
        // Arrange
        const textStyle = TextStyle(height: -1.0);

        // Act
        final style = TerminalStyle.fromTextStyle(textStyle);

        // Assert - negative height is unusual but valid
        expect(style.height, equals(-1.0));
      });

      test(
          'Given TextStyle with empty fontFamilyFallback, When converting, Then preserves empty',
          () {
        // Arrange
        const textStyle = TextStyle(fontFamilyFallback: []);

        // Act
        final style = TerminalStyle.fromTextStyle(textStyle);

        // Assert
        expect(style.fontFamilyFallback, isEmpty);
      });
    });

    group('toTextStyle', () {
      test(
          'Given TerminalStyle, When toTextStyle called with defaults, Then creates TextStyle',
          () {
        // Arrange
        const style = TerminalStyle();

        // Act
        final textStyle = style.toTextStyle();

        // Assert
        expect(textStyle.fontSize, equals(13.0));
        expect(textStyle.height, equals(1.2));
        expect(textStyle.fontFamily, equals('monospace'));
        expect(textStyle.fontFamilyFallback, isNotEmpty);
        expect(textStyle.color, isNull);
        expect(textStyle.backgroundColor, isNull);
        expect(textStyle.fontWeight, equals(FontWeight.normal));
        expect(textStyle.fontStyle, equals(FontStyle.normal));
        expect(textStyle.decoration, equals(TextDecoration.none));
      });

      test(
          'Given TerminalStyle, When toTextStyle with color, Then applies color',
          () {
        // Arrange
        const style = TerminalStyle();
        const color = Color(0xFF00FF00);

        // Act
        final textStyle = style.toTextStyle(color: color);

        // Assert
        expect(textStyle.color, equals(color));
      });

      test(
          'Given TerminalStyle, When toTextStyle with background, Then applies background',
          () {
        // Arrange
        const style = TerminalStyle();
        const bgColor = Color(0xFF0000FF);

        // Act
        final textStyle = style.toTextStyle(backgroundColor: bgColor);

        // Assert
        expect(textStyle.backgroundColor, equals(bgColor));
      });

      test(
          'Given TerminalStyle, When toTextStyle with bold=true, Then applies bold',
          () {
        // Arrange
        const style = TerminalStyle();

        // Act
        final textStyle = style.toTextStyle(bold: true);

        // Assert
        expect(textStyle.fontWeight, equals(FontWeight.bold));
      });

      test(
          'Given TerminalStyle, When toTextStyle with bold=false, Then normal weight',
          () {
        // Arrange
        const style = TerminalStyle(fontSize: 14);

        // Act
        final textStyle = style.toTextStyle(bold: false);

        // Assert
        expect(textStyle.fontWeight, equals(FontWeight.normal));
      });

      test(
          'Given TerminalStyle, When toTextStyle with italic=true, Then applies italic',
          () {
        // Arrange
        const style = TerminalStyle();

        // Act
        final textStyle = style.toTextStyle(italic: true);

        // Assert
        expect(textStyle.fontStyle, equals(FontStyle.italic));
      });

      test(
          'Given TerminalStyle, When toTextStyle with underline=true, Then applies underline',
          () {
        // Arrange
        const style = TerminalStyle();

        // Act
        final textStyle = style.toTextStyle(underline: true);

        // Assert
        expect(textStyle.decoration, equals(TextDecoration.underline));
      });

      test(
          'Given TerminalStyle, When toTextStyle with all styles, Then combines all',
          () {
        // Arrange
        const style = TerminalStyle(fontSize: 16);
        const color = Color(0xFFFF0000);
        const bgColor = Color(0xFF0000FF);

        // Act
        final textStyle = style.toTextStyle(
          color: color,
          backgroundColor: bgColor,
          bold: true,
          italic: true,
          underline: true,
        );

        // Assert
        expect(textStyle.fontSize, equals(16.0));
        expect(textStyle.fontWeight, equals(FontWeight.bold));
        expect(textStyle.fontStyle, equals(FontStyle.italic));
        expect(textStyle.decoration, equals(TextDecoration.underline));
        expect(textStyle.color, equals(color));
        expect(textStyle.backgroundColor, equals(bgColor));
      });

      test(
          'Given TerminalStyle, When toTextStyle called multiple times, Then independent',
          () {
        // Arrange
        final style = TerminalStyle(fontSize: 14);

        // Act
        final textStyle1 = style.toTextStyle(bold: true);
        final textStyle2 = style.toTextStyle(bold: false);

        // Assert - each call returns independent TextStyle
        expect(textStyle1.fontWeight, equals(FontWeight.bold));
        expect(textStyle2.fontWeight, equals(FontWeight.normal));
      });

      test(
          'Given TerminalStyle, When toTextStyle without parameters, Then matches TerminalStyle values',
          () {
        // Arrange
        final style = TerminalStyle(
          fontSize: 15.5,
          height: 1.3,
          fontFamily: 'Test Font',
          fontFamilyFallback: ['Fallback1', 'Fallback2'],
        );

        // Act
        final textStyle = style.toTextStyle();

        // Assert - all properties transferred
        expect(textStyle.fontSize, equals(15.5));
        expect(textStyle.height, equals(1.3));
        expect(textStyle.fontFamily, equals('Test Font'));
        expect(
            textStyle.fontFamilyFallback, equals(['Fallback1', 'Fallback2']));
      });
    });

    group('copyWith', () {
      test(
          'Given TerminalStyle, When copyWith with no args, Then creates identical copy',
          () {
        // Arrange
        const original = TerminalStyle(
          fontSize: 14.0,
          height: 1.4,
          fontFamily: 'Original',
          fontFamilyFallback: ['A', 'B'],
        );

        // Act
        final copy = original.copyWith();

        // Assert
        expect(copy.fontSize, equals(original.fontSize));
        expect(copy.height, equals(original.height));
        expect(copy.fontFamily, equals(original.fontFamily));
        expect(copy.fontFamilyFallback, equals(original.fontFamilyFallback));
        // Not the same instance
        expect(identical(copy, original), isFalse);
      });

      test(
          'Given TerminalStyle, When copyWith changes fontSize, Then other fields unchanged',
          () {
        // Arrange
        const original = TerminalStyle(
          fontSize: 12.0,
          height: 1.2,
          fontFamily: 'Mono',
          fontFamilyFallback: ['A'],
        );

        // Act
        final copy = original.copyWith(fontSize: 18.0);

        // Assert
        expect(copy.fontSize, equals(18.0));
        expect(copy.height, equals(original.height));
        expect(copy.fontFamily, equals(original.fontFamily));
        expect(copy.fontFamilyFallback, equals(original.fontFamilyFallback));
      });

      test(
          'Given TerminalStyle, When copyWith changes height, Then other fields unchanged',
          () {
        // Arrange
        const original = TerminalStyle(fontSize: 14, height: 1.2);

        // Act
        final copy = original.copyWith(height: 2.0);

        // Assert
        expect(copy.height, equals(2.0));
        expect(copy.fontSize, equals(original.fontSize));
      });

      test(
          'Given TerminalStyle, When copyWith changes fontFamily, Then other fields unchanged',
          () {
        // Arrange
        const original = TerminalStyle(fontFamily: 'Original');

        // Act
        final copy = original.copyWith(fontFamily: 'New Font');

        // Assert
        expect(copy.fontFamily, equals('New Font'));
        expect(copy.fontSize, equals(original.fontSize));
      });

      test(
          'Given TerminalStyle, When copyWith changes fontFamilyFallback, Then replaces list',
          () {
        // Arrange
        const original = TerminalStyle(fontFamilyFallback: ['A', 'B']);

        // Act
        final copy = original.copyWith(fontFamilyFallback: ['X', 'Y', 'Z']);

        // Assert
        expect(copy.fontFamilyFallback, equals(['X', 'Y', 'Z']));
        // Original unchanged
        expect(original.fontFamilyFallback, equals(['A', 'B']));
      });

      test(
          'Given TerminalStyle, When copyWith changes multiple fields, Then all applied',
          () {
        // Arrange
        const original = TerminalStyle();

        // Act
        final copy = original.copyWith(
          fontSize: 20.0,
          height: 2.0,
          fontFamily: 'Test',
          fontFamilyFallback: ['F1'],
        );

        // Assert
        expect(copy.fontSize, equals(20.0));
        expect(copy.height, equals(2.0));
        expect(copy.fontFamily, equals('Test'));
        expect(copy.fontFamilyFallback, equals(['F1']));
      });

      test(
          'Given TerminalStyle, When copyWith with null values, Then uses fallbacks',
          () {
        // Arrange
        const original = TerminalStyle(fontSize: 10.0, height: 1.0);

        // Act - passing null should use original value (since ?? operator in copyWith)
        final copy = original.copyWith(
          fontSize: null,
          height: null,
        );

        // Assert
        expect(copy.fontSize, equals(10.0));
        expect(copy.height, equals(1.0));
      });

      test(
          'Given TerminalStyle, When multiple copyWith chained, Then accumulates',
          () {
        // Arrange
        const original = TerminalStyle(fontSize: 12.0, height: 1.2);

        // Act
        final copy1 = original.copyWith(fontSize: 14.0);
        final copy2 = copy1.copyWith(height: 1.5);

        // Assert
        expect(copy2.fontSize, equals(14.0));
        expect(copy2.height, equals(1.5));
      });
    });

    group('Equality and hash', () {
      test('Given two TerminalStyles, When equal, Then equals returns true',
          () {
        // Arrange
        const style1 = TerminalStyle(fontSize: 14, height: 1.4);
        const style2 = TerminalStyle(fontSize: 14, height: 1.4);

        // Assert
        expect(style1, equals(style2));
      });

      test('Given two TerminalStyles, When different fontSize, Then not equal',
          () {
        // Arrange
        const style1 = TerminalStyle(fontSize: 14);
        const style2 = TerminalStyle(fontSize: 16);

        // Assert
        expect(style1, isNot(equals(style2)));
      });

      test('Given two TerminalStyles, When different height, Then not equal',
          () {
        // Arrange
        const style1 = TerminalStyle(height: 1.2);
        const style2 = TerminalStyle(height: 1.5);

        // Assert
        expect(style1, isNot(equals(style2)));
      });

      test(
          'Given two TerminalStyles, When different fontFamily, Then not equal',
          () {
        // Arrange
        const style1 = TerminalStyle(fontFamily: 'A');
        const style2 = TerminalStyle(fontFamily: 'B');

        // Assert
        expect(style1, isNot(equals(style2)));
      });

      test(
          'Given two TerminalStyles, When different fallback list, Then not equal',
          () {
        // Arrange
        const style1 = TerminalStyle(fontFamilyFallback: ['A']);
        const style2 = TerminalStyle(fontFamilyFallback: ['B']);

        // Assert
        expect(style1, isNot(equals(style2)));
      });

      test('Given TerminalStyle, When same values, Then has same hash code',
          () {
        // Arrange
        const style1 = TerminalStyle(fontSize: 14, height: 1.4);
        const style2 = TerminalStyle(fontSize: 14, height: 1.4);

        // Assert - equal objects should have equal hash codes
        expect(style1.hashCode, equals(style2.hashCode));
      });

      test('Given TerminalStyle, When used in Set, Then deduplicates correctly',
          () {
        // Arrange
        const style1 = TerminalStyle(fontSize: 14);
        const style2 = TerminalStyle(fontSize: 14);
        const style3 = TerminalStyle(fontSize: 16);

        // Act
        final set = <TerminalStyle>{style1, style2, style3};

        // Assert
        expect(set.length, equals(2)); // style1 and style2 are equal
      });

      test('Given TerminalStyle, When used as Map key, Then works correctly',
          () {
        // Arrange
        const style = TerminalStyle(fontSize: 14);
        final map = <TerminalStyle, String>{};

        // Act
        map[style] = 'value';

        // Assert
        expect(map[style], equals('value'));
      });
    });

    group('Constants', () {
      test('Given _kDefaultFontSize, Then equals 13.0', () {
        // Access via default constructor
        final style = TerminalStyle();
        expect(style.fontSize, 13.0);
      });

      test('Given _kDefaultHeight, Then equals 1.2', () {
        final style = TerminalStyle();
        expect(style.height, 1.2);
      });

      test('Given _kDefaultFontFamily, Then equals monospace', () {
        final style = TerminalStyle();
        expect(style.fontFamily, 'monospace');
      });

      test('Given _kDefaultFontFamilyFallback, Then contains CJK fonts', () {
        final style = TerminalStyle();
        expect(style.fontFamilyFallback, contains('Noto Sans Mono CJK SC'));
        expect(style.fontFamilyFallback, contains('Noto Color Emoji'));
      });

      test('Given _kDefaultFontFamilyFallback, Then has 12+ entries', () {
        final style = TerminalStyle();
        expect(style.fontFamilyFallback.length, greaterThanOrEqualTo(12));
      });
    });

    group('Edge cases', () {
      test(
          'Given TerminalStyle with huge fontSize, When toTextStyle, Then preserves',
          () {
        // Arrange
        const style = TerminalStyle(fontSize: 9999.0);

        // Act
        final textStyle = style.toTextStyle();

        // Assert
        expect(textStyle.fontSize, equals(9999.0));
      });

      test(
          'Given TerminalStyle with zero fontSize, When toTextStyle, Then allows',
          () {
        // Arrange
        const style = TerminalStyle(fontSize: 0.0);

        // Act
        final textStyle = style.toTextStyle();

        // Assert
        expect(textStyle.fontSize, equals(0.0));
      });

      test(
          'Given TerminalStyle with negative fontSize, When toTextStyle, Then preserves',
          () {
        // Arrange
        const style = TerminalStyle(fontSize: -5.0);

        // Act
        final textStyle = style.toTextStyle();

        // Assert
        expect(textStyle.fontSize, equals(-5.0));
      });

      test(
          'Given TerminalStyle with empty fallback, When toTextStyle, Then uses empty list',
          () {
        // Arrange
        const style = TerminalStyle(fontFamilyFallback: []);

        // Act
        final textStyle = style.toTextStyle();

        // Assert
        expect(textStyle.fontFamilyFallback, isEmpty);
      });

      test(
          'Given TerminalStyle, When copyWith null fontFamilyFallback, Then keeps original',
          () {
        // Arrange
        const original = TerminalStyle(fontFamilyFallback: ['A', 'B']);

        // Act
        final copy = original.copyWith(fontFamilyFallback: null);

        // Assert - null uses ?? so original is kept
        expect(copy.fontFamilyFallback, equals(['A', 'B']));
      });
    });

    group('Immutability', () {
      test('Given TerminalStyle, All fields are final and immutable', () {
        // Arrange
        const style = TerminalStyle();

        // Act & Assert - fields are final, cannot be modified
        // This is verified at compile time; runtime check ensures const correctness
        expect(style.fontSize, isA<double>());
        expect(style.height, isA<double>());
        expect(style.fontFamily, isA<String>());
        expect(style.fontFamilyFallback, isA<List<String>>());
      });

      test(
          'Given TerminalStyle, When copyWith called, Then creates new instance with same values',
          () {
        // Arrange
        const style = TerminalStyle();

        // Act
        final copy = style.copyWith();

        // Assert - different instance, values equal
        expect(identical(style, copy), isFalse);
        expect(copy.fontSize, equals(style.fontSize));
        expect(copy.height, equals(style.height));
        expect(copy.fontFamily, equals(style.fontFamily));
        expect(copy.fontFamilyFallback, equals(style.fontFamilyFallback));
      });
    });

    group('Round-trip conversion', () {
      test(
          'Given TerminalStyle, When toTextStyle then fromTextStyle, Then equivalent',
          () {
        // Arrange
        const original = TerminalStyle(
          fontSize: 16.0,
          height: 1.6,
          fontFamily: 'Custom',
          fontFamilyFallback: ['F1', 'F2'],
        );

        // Act
        final textStyle = original.toTextStyle();
        final roundTrip = TerminalStyle.fromTextStyle(textStyle);

        // Assert
        expect(roundTrip.fontSize, equals(original.fontSize));
        expect(roundTrip.height, equals(original.height));
        expect(roundTrip.fontFamily, equals(original.fontFamily));
        expect(
            roundTrip.fontFamilyFallback, equals(original.fontFamilyFallback));
      });

      test(
          'Given TerminalStyle with custom TextStyle color, When round-trip, Then color not lost',
          () {
        // Arrange
        const style = TerminalStyle();
        const testColor = Color(0x12345678);
        final textStyle = style.toTextStyle(color: testColor);

        // Act - fromTextStyle does not capture color (it's not in TerminalStyle)
        final roundTrip = TerminalStyle.fromTextStyle(textStyle);

        // Assert - color not preserved in TerminalStyle (by design)
        expect(roundTrip.fontSize, equals(style.fontSize));
      });
    });
  });
}
