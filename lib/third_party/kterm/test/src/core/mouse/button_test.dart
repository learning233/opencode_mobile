import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/mouse/button.dart';

void main() {
  group('TerminalMouseButton', () {
    test('left button has correct id', () {
      expect(TerminalMouseButton.left.id, equals(0));
      expect(TerminalMouseButton.left.isWheel, isFalse);
    });

    test('middle button has correct id', () {
      expect(TerminalMouseButton.middle.id, equals(1));
      expect(TerminalMouseButton.middle.isWheel, isFalse);
    });

    test('right button has correct id', () {
      expect(TerminalMouseButton.right.id, equals(2));
      expect(TerminalMouseButton.right.isWheel, isFalse);
    });

    test('wheel buttons have correct ids', () {
      expect(TerminalMouseButton.wheelUp.id, equals(68));
      expect(TerminalMouseButton.wheelUp.isWheel, isTrue);

      expect(TerminalMouseButton.wheelDown.id, equals(69));
      expect(TerminalMouseButton.wheelDown.isWheel, isTrue);

      expect(TerminalMouseButton.wheelLeft.id, equals(70));
      expect(TerminalMouseButton.wheelLeft.isWheel, isTrue);

      expect(TerminalMouseButton.wheelRight.id, equals(71));
      expect(TerminalMouseButton.wheelRight.isWheel, isTrue);
    });

    test('wheel buttons have isWheel flag set', () {
      expect(TerminalMouseButton.wheelUp.isWheel, isTrue);
      expect(TerminalMouseButton.wheelDown.isWheel, isTrue);
      expect(TerminalMouseButton.wheelLeft.isWheel, isTrue);
      expect(TerminalMouseButton.wheelRight.isWheel, isTrue);
    });

    test('non-wheel buttons have isWheel flag false', () {
      expect(TerminalMouseButton.left.isWheel, isFalse);
      expect(TerminalMouseButton.middle.isWheel, isFalse);
      expect(TerminalMouseButton.right.isWheel, isFalse);
    });

    test('wheel ids are 64 + 4, 64 + 5, etc', () {
      expect(TerminalMouseButton.wheelUp.id, equals(64 + 4));
      expect(TerminalMouseButton.wheelDown.id, equals(64 + 5));
      expect(TerminalMouseButton.wheelLeft.id, equals(64 + 6));
      expect(TerminalMouseButton.wheelRight.id, equals(64 + 7));
    });
  });
}
