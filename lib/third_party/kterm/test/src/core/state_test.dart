import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/state.dart';
import 'package:kterm/src/core/cursor.dart';
import 'package:kterm/src/core/mouse/mode.dart';

class MockTerminalState implements TerminalState {
  @override
  int get viewWidth => 80;

  @override
  int get viewHeight => 24;

  @override
  CursorStyle get cursor => CursorStyle();

  @override
  bool get reflowEnabled => true;

  @override
  bool get insertMode => false;

  @override
  bool get lineFeedMode => false;

  @override
  bool get cursorKeysMode => false;

  @override
  bool get reverseDisplayMode => false;

  @override
  bool get originMode => false;

  @override
  bool get autoWrapMode => true;

  @override
  MouseMode get mouseMode => MouseMode.none;

  @override
  MouseReportMode get mouseReportMode => MouseReportMode.normal;

  @override
  bool get cursorBlinkMode => false;

  @override
  bool get cursorVisibleMode => true;

  @override
  bool get appKeypadMode => false;

  @override
  bool get reportFocusMode => false;

  @override
  bool get altBufferMouseScrollMode => false;

  @override
  bool get bracketedPasteMode => false;
}

void main() {
  group('TerminalState', () {
    late MockTerminalState state;

    setUp(() {
      state = MockTerminalState();
    });

    test('view dimensions are accessible', () {
      expect(state.viewWidth, equals(80));
      expect(state.viewHeight, equals(24));
    });

    test('cursor is accessible', () {
      expect(state.cursor, isA<CursorStyle>());
    });

    test('reflowEnabled is accessible', () {
      expect(state.reflowEnabled, isTrue);
    });

    group('modes', () {
      test('insertMode is accessible', () {
        expect(state.insertMode, isFalse);
      });

      test('lineFeedMode is accessible', () {
        expect(state.lineFeedMode, isFalse);
      });

      test('cursorKeysMode is accessible', () {
        expect(state.cursorKeysMode, isFalse);
      });

      test('reverseDisplayMode is accessible', () {
        expect(state.reverseDisplayMode, isFalse);
      });

      test('originMode is accessible', () {
        expect(state.originMode, isFalse);
      });

      test('autoWrapMode is accessible', () {
        expect(state.autoWrapMode, isTrue);
      });

      test('cursorBlinkMode is accessible', () {
        expect(state.cursorBlinkMode, isFalse);
      });

      test('cursorVisibleMode is accessible', () {
        expect(state.cursorVisibleMode, isTrue);
      });

      test('appKeypadMode is accessible', () {
        expect(state.appKeypadMode, isFalse);
      });

      test('reportFocusMode is accessible', () {
        expect(state.reportFocusMode, isFalse);
      });

      test('altBufferMouseScrollMode is accessible', () {
        expect(state.altBufferMouseScrollMode, isFalse);
      });

      test('bracketedPasteMode is accessible', () {
        expect(state.bracketedPasteMode, isFalse);
      });
    });

    group('mouse modes', () {
      test('mouseMode is accessible', () {
        expect(state.mouseMode, equals(MouseMode.none));
      });

      test('mouseReportMode is accessible', () {
        expect(state.mouseReportMode, equals(MouseReportMode.normal));
      });
    });

    test('mock implements all TerminalState getters', () {
      // This test ensures that if TerminalState interface changes,
      // this test will fail and alert developers to update the mock
      expect(state.viewWidth, isA<int>());
      expect(state.viewHeight, isA<int>());
      expect(state.cursor, isA<CursorStyle>());
      expect(state.reflowEnabled, isA<bool>());
      expect(state.insertMode, isA<bool>());
      expect(state.lineFeedMode, isA<bool>());
      expect(state.cursorKeysMode, isA<bool>());
      expect(state.reverseDisplayMode, isA<bool>());
      expect(state.originMode, isA<bool>());
      expect(state.autoWrapMode, isA<bool>());
      expect(state.mouseMode, isA<MouseMode>());
      expect(state.mouseReportMode, isA<MouseReportMode>());
      expect(state.cursorBlinkMode, isA<bool>());
      expect(state.cursorVisibleMode, isA<bool>());
      expect(state.appKeypadMode, isA<bool>());
      expect(state.reportFocusMode, isA<bool>());
      expect(state.altBufferMouseScrollMode, isA<bool>());
      expect(state.bracketedPasteMode, isA<bool>());
    });
  });
}
