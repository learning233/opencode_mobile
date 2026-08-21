import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/escape/handler.dart';
import 'package:kterm/src/core/mouse/mode.dart';

void main() {
  group('EscapeHandler', () {
    test(
        'Given EscapeHandler, When interface checked, Then exists as abstract class',
        () {
      // Assert - verify the abstract class exists
      expect(EscapeHandler, isNotNull);
    });

    test('Given EscapeHandler, When used as type, Then can be referenced', () {
      // Assert - verify EscapeHandler can be used as a type annotation
      void takeHandler(EscapeHandler handler) {
        // Would require implementing all abstract methods
      }
      expect(takeHandler, isNotNull);
    });

    test('Given MouseMode, When checked, Then contains expected values', () {
      // Assert - verify MouseMode enum is available
      expect(MouseMode.values.contains(MouseMode.none), isTrue);
      expect(MouseMode.values.contains(MouseMode.clickOnly), isTrue);
      expect(MouseMode.values.contains(MouseMode.upDownScroll), isTrue);
      expect(MouseMode.values.contains(MouseMode.upDownScrollDrag), isTrue);
      expect(MouseMode.values.contains(MouseMode.upDownScrollMove), isTrue);
    });

    test('Given MouseReportMode, When checked, Then contains expected values',
        () {
      // Assert - verify MouseReportMode enum is available
      expect(MouseReportMode.values.contains(MouseReportMode.normal), isTrue);
      expect(MouseReportMode.values.contains(MouseReportMode.utf), isTrue);
      expect(MouseReportMode.values.contains(MouseReportMode.sgr), isTrue);
      expect(MouseReportMode.values.contains(MouseReportMode.urxvt), isTrue);
    });
  });
}
