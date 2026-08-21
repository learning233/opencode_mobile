import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/mouse/mode.dart';

void main() {
  group('MouseMode', () {
    test('Given none, When reportScroll accessed, Then returns false', () {
      expect(MouseMode.none.reportScroll, isFalse);
    });

    test('Given clickOnly, When reportScroll accessed, Then returns false', () {
      expect(MouseMode.clickOnly.reportScroll, isFalse);
    });

    test('Given upDownScroll, When reportScroll accessed, Then returns true',
        () {
      expect(MouseMode.upDownScroll.reportScroll, isTrue);
    });

    test(
        'Given upDownScrollDrag, When reportScroll accessed, Then returns true',
        () {
      expect(MouseMode.upDownScrollDrag.reportScroll, isTrue);
    });

    test(
        'Given upDownScrollMove, When reportScroll accessed, Then returns true',
        () {
      expect(MouseMode.upDownScrollMove.reportScroll, isTrue);
    });
  });

  group('MouseReportMode', () {
    test('Given normal, When name accessed, Then returns normal', () {
      expect(MouseReportMode.normal.name, equals('normal'));
    });

    test('Given utf, When name accessed, Then returns utf', () {
      expect(MouseReportMode.utf.name, equals('utf'));
    });

    test('Given sgr, When name accessed, Then returns sgr', () {
      expect(MouseReportMode.sgr.name, equals('sgr'));
    });

    test('Given urxvt, When name accessed, Then returns urxvt', () {
      expect(MouseReportMode.urxvt.name, equals('urxvt'));
    });

    test('Given all modes, When enumerated, Then has 4 values', () {
      expect(MouseReportMode.values.length, equals(4));
    });
  });
}
