import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/color.dart';

void main() {
  group('NamedColor', () {
    test('standard colors have correct values', () {
      expect(NamedColor.black, equals(0));
      expect(NamedColor.red, equals(1));
      expect(NamedColor.green, equals(2));
      expect(NamedColor.yellow, equals(3));
      expect(NamedColor.blue, equals(4));
      expect(NamedColor.magenta, equals(5));
      expect(NamedColor.cyan, equals(6));
      expect(NamedColor.white, equals(7));
    });

    test('bright colors have correct values', () {
      expect(NamedColor.brightBlack, equals(8));
      expect(NamedColor.brightRed, equals(9));
      expect(NamedColor.brightGreen, equals(10));
      expect(NamedColor.brightYellow, equals(11));
      expect(NamedColor.brightBlue, equals(12));
      expect(NamedColor.brightMagenta, equals(13));
      expect(NamedColor.brightCyan, equals(14));
      expect(NamedColor.brightWhite, equals(15));
    });

    test('bright colors are 8 more than standard colors', () {
      expect(NamedColor.brightBlack - NamedColor.black, equals(8));
      expect(NamedColor.brightRed - NamedColor.red, equals(8));
      expect(NamedColor.brightGreen - NamedColor.green, equals(8));
      expect(NamedColor.brightYellow - NamedColor.yellow, equals(8));
      expect(NamedColor.brightBlue - NamedColor.blue, equals(8));
      expect(NamedColor.brightMagenta - NamedColor.magenta, equals(8));
      expect(NamedColor.brightCyan - NamedColor.cyan, equals(8));
      expect(NamedColor.brightWhite - NamedColor.white, equals(8));
    });
  });
}
