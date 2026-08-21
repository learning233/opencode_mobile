import 'package:test/test.dart';
import 'package:kterm/src/core/escape/emitter.dart';

void main() {
  group('EscapeEmitter', () {
    late EscapeEmitter emitter;

    setUp(() {
      emitter = const EscapeEmitter();
    });

    group('primaryDeviceAttributes()', () {
      test('returns correct sequence', () {
        final result = emitter.primaryDeviceAttributes();
        expect(result, equals('\x1b[?1;2c'));
      });

      test('returns non-empty string', () {
        final result = emitter.primaryDeviceAttributes();
        expect(result.isNotEmpty, isTrue);
      });

      test('starts with ESC', () {
        final result = emitter.primaryDeviceAttributes();
        expect(result.codeUnitAt(0), equals(0x1B)); // ESC
      });
    });

    group('secondaryDeviceAttributes()', () {
      test('returns correct format', () {
        final result = emitter.secondaryDeviceAttributes();
        // Format: \x1b[>model;version;0c (note: source has [> which may be a bug)
        expect(result, startsWith('\x1b[>'));
        expect(result, endsWith('c'));
      });

      test('contains version number', () {
        final result = emitter.secondaryDeviceAttributes();
        expect(result.contains(';0;'), isTrue);
      });

      test('starts with ESC', () {
        final result = emitter.secondaryDeviceAttributes();
        expect(result.codeUnitAt(0), equals(0x1B)); // ESC
      });
    });

    group('tertiaryDeviceAttributes()', () {
      test('returns correct sequence', () {
        final result = emitter.tertiaryDeviceAttributes();
        expect(result, equals('\x1bP!|00000000\x1b\\'));
      });
    });

    group('operatingStatus()', () {
      test('returns correct sequence', () {
        final result = emitter.operatingStatus();
        expect(result, equals('\x1b[0n'));
      });
    });

    group('cursorPosition()', () {
      test('returns correct sequence for basic position', () {
        final result = emitter.cursorPosition(1, 1);
        expect(result, equals('\x1b[1;1R'));
      });

      test('y comes before x in the sequence', () {
        final result = emitter.cursorPosition(10, 5);
        expect(result, equals('\x1b[5;10R'));
      });

      test('handles large coordinates', () {
        final result = emitter.cursorPosition(100, 200);
        expect(result, equals('\x1b[200;100R'));
      });

      test('handles origin position (1, 1)', () {
        final result = emitter.cursorPosition(1, 1);
        expect(result, equals('\x1b[1;1R'));
      });
    });

    group('bracketedPaste()', () {
      test('wraps text correctly', () {
        final result = emitter.bracketedPaste('hello');
        expect(result, equals('\x1b[200~hello\x1b[201~'));
      });

      test('handles empty string', () {
        final result = emitter.bracketedPaste('');
        expect(result, equals('\x1b[200~\x1b[201~'));
      });

      test('handles special characters', () {
        final result = emitter.bracketedPaste('hello\nworld');
        expect(result, equals('\x1b[200~hello\nworld\x1b[201~'));
      });

      test('handles unicode characters', () {
        final result = emitter.bracketedPaste('你好世界');
        expect(result, equals('\x1b[200~你好世界\x1b[201~'));
      });
    });

    group('size()', () {
      test('returns correct sequence', () {
        final result = emitter.size(24, 80);
        expect(result, equals('\x1b[8;24;80t'));
      });

      test('rows come before cols', () {
        final result = emitter.size(100, 200);
        expect(result, equals('\x1b[8;100;200t'));
      });

      test('handles common terminal sizes', () {
        expect(emitter.size(24, 80), equals('\x1b[8;24;80t'));
        expect(emitter.size(25, 80), equals('\x1b[8;25;80t'));
        expect(emitter.size(30, 120), equals('\x1b[8;30;120t'));
      });
    });
  });
}
