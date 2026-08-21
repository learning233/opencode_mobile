import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/buffer/cell_offset.dart';
import 'package:kterm/src/core/cursor.dart';
import 'package:kterm/src/core/mouse/button.dart';
import 'package:kterm/src/core/mouse/button_state.dart';
import 'package:kterm/src/core/mouse/handler.dart';
import 'package:kterm/src/core/mouse/mode.dart';
import 'package:kterm/src/core/platform.dart';
import 'package:kterm/src/core/state.dart';

class FakeTerminalState implements TerminalState {
  @override
  int viewWidth = 80;
  @override
  int viewHeight = 24;
  @override
  CursorStyle cursor = CursorStyle.empty;
  @override
  bool reflowEnabled = true;
  @override
  bool insertMode = false;
  @override
  bool lineFeedMode = false;
  @override
  bool cursorKeysMode = false;
  @override
  bool reverseDisplayMode = false;
  @override
  bool originMode = false;
  @override
  bool autoWrapMode = true;
  @override
  MouseMode mouseMode = MouseMode.none;
  @override
  MouseReportMode mouseReportMode = MouseReportMode.normal;
  @override
  bool cursorBlinkMode = true;
  @override
  bool cursorVisibleMode = true;
  @override
  bool appKeypadMode = false;
  @override
  bool reportFocusMode = false;
  @override
  bool altBufferMouseScrollMode = false;
  @override
  bool bracketedPasteMode = false;
}

TerminalMouseEvent createMouseEvent({
  TerminalMouseButton button = TerminalMouseButton.left,
  TerminalMouseButtonState buttonState = TerminalMouseButtonState.down,
  CellOffset? position,
  MouseMode mouseMode = MouseMode.clickOnly,
  MouseReportMode reportMode = MouseReportMode.normal,
}) {
  final state = FakeTerminalState()
    ..mouseMode = mouseMode
    ..mouseReportMode = reportMode;

  return TerminalMouseEvent(
    button: button,
    buttonState: buttonState,
    position: position ?? const CellOffset(0, 0),
    state: state,
    platform: TerminalTargetPlatform.linux,
  );
}

void main() {
  group('TerminalMouseEvent', () {
    test('Given valid parameters, When created, Then stores all properties',
        () {
      final event = createMouseEvent(
        button: TerminalMouseButton.right,
        buttonState: TerminalMouseButtonState.up,
        position: const CellOffset(10, 5),
      );

      expect(event.button, equals(TerminalMouseButton.right));
      expect(event.buttonState, equals(TerminalMouseButtonState.up));
      expect(event.position.x, equals(10));
      expect(event.position.y, equals(5));
    });
  });

  group('ClickMouseHandler', () {
    test(
        'Given clickOnly mode with left button down, When call called, Then returns report string',
        () {
      final handler = ClickMouseHandler();
      final event = createMouseEvent(
        button: TerminalMouseButton.left,
        buttonState: TerminalMouseButtonState.down,
        mouseMode: MouseMode.clickOnly,
      );

      final result = handler.call(event);

      expect(result, isNotNull);
    });

    test(
        'Given clickOnly mode with right button down, When call called, Then returns report string',
        () {
      final handler = ClickMouseHandler();
      final event = createMouseEvent(
        button: TerminalMouseButton.right,
        buttonState: TerminalMouseButtonState.down,
        mouseMode: MouseMode.clickOnly,
      );

      final result = handler.call(event);

      expect(result, isNotNull);
    });

    test(
        'Given clickOnly mode with middle button down, When call called, Then returns report string',
        () {
      final handler = ClickMouseHandler();
      final event = createMouseEvent(
        button: TerminalMouseButton.middle,
        buttonState: TerminalMouseButtonState.down,
        mouseMode: MouseMode.clickOnly,
      );

      final result = handler.call(event);

      expect(result, isNotNull);
    });

    test(
        'Given clickOnly mode with button up, When call called, Then returns null',
        () {
      final handler = ClickMouseHandler();
      final event = createMouseEvent(
        button: TerminalMouseButton.left,
        buttonState: TerminalMouseButtonState.up,
        mouseMode: MouseMode.clickOnly,
      );

      final result = handler.call(event);

      expect(result, isNull);
    });

    test('Given none mode, When call called, Then returns null', () {
      final handler = ClickMouseHandler();
      final event = createMouseEvent(mouseMode: MouseMode.none);

      final result = handler.call(event);

      expect(result, isNull);
    });

    test('Given upDownScroll mode, When call called, Then returns null', () {
      final handler = ClickMouseHandler();
      final event = createMouseEvent(mouseMode: MouseMode.upDownScroll);

      final result = handler.call(event);

      expect(result, isNull);
    });
  });

  group('UpDownMouseHandler', () {
    test(
        'Given upDownScroll mode with wheel up, When call called, Then returns null',
        () {
      final handler = UpDownMouseHandler();
      final event = createMouseEvent(
        button: TerminalMouseButton.wheelUp,
        buttonState: TerminalMouseButtonState.up,
        mouseMode: MouseMode.upDownScroll,
      );

      final result = handler.call(event);

      expect(result, isNull);
    });

    test(
        'Given upDownScroll mode with wheel down down, When call called, Then returns report',
        () {
      final handler = UpDownMouseHandler();
      final event = createMouseEvent(
        button: TerminalMouseButton.wheelDown,
        buttonState: TerminalMouseButtonState.down,
        mouseMode: MouseMode.upDownScroll,
      );

      final result = handler.call(event);

      expect(result, isNotNull);
    });

    test(
        'Given upDownScrollDrag mode with left button, When call called, Then returns report',
        () {
      final handler = UpDownMouseHandler();
      final event = createMouseEvent(
        button: TerminalMouseButton.left,
        buttonState: TerminalMouseButtonState.down,
        mouseMode: MouseMode.upDownScrollDrag,
      );

      final result = handler.call(event);

      expect(result, isNotNull);
    });

    test(
        'Given upDownScrollMove mode with left button, When call called, Then returns report',
        () {
      final handler = UpDownMouseHandler();
      final event = createMouseEvent(
        button: TerminalMouseButton.left,
        buttonState: TerminalMouseButtonState.down,
        mouseMode: MouseMode.upDownScrollMove,
      );

      final result = handler.call(event);

      expect(result, isNotNull);
    });

    test('Given none mode, When call called, Then returns null', () {
      final handler = UpDownMouseHandler();
      final event = createMouseEvent(mouseMode: MouseMode.none);

      final result = handler.call(event);

      expect(result, isNull);
    });

    test('Given clickOnly mode, When call called, Then returns null', () {
      final handler = UpDownMouseHandler();
      final event = createMouseEvent(mouseMode: MouseMode.clickOnly);

      final result = handler.call(event);

      expect(result, isNull);
    });
  });

  group('CascadeMouseHandler', () {
    test(
        'Given first handler returns result, When call called, Then returns first result',
        () {
      final handler1 = _MockHandler('result1');
      final handler2 = _MockHandler('result2');
      final cascade = CascadeMouseHandler([handler1, handler2]);
      final event = createMouseEvent();

      final result = cascade.call(event);

      expect(result, equals('result1'));
    });

    test(
        'Given first handler returns null, When call called, Then returns second result',
        () {
      final handler1 = _MockHandler(null);
      final handler2 = _MockHandler('result2');
      final cascade = CascadeMouseHandler([handler1, handler2]);
      final event = createMouseEvent();

      final result = cascade.call(event);

      expect(result, equals('result2'));
    });

    test('Given all handlers return null, When call called, Then returns null',
        () {
      final handler1 = _MockHandler(null);
      final handler2 = _MockHandler(null);
      final cascade = CascadeMouseHandler([handler1, handler2]);
      final event = createMouseEvent();

      final result = cascade.call(event);

      expect(result, isNull);
    });
  });

  group('defaultMouseHandler', () {
    test(
        'Given default handler with clickOnly mode, When call called, Then returns result',
        () {
      final event = createMouseEvent(
        button: TerminalMouseButton.left,
        buttonState: TerminalMouseButtonState.down,
        mouseMode: MouseMode.clickOnly,
      );

      final result = defaultMouseHandler.call(event);

      expect(result, isNotNull);
    });

    test(
        'Given default handler with upDownScroll mode, When call called, Then returns result',
        () {
      final event = createMouseEvent(
        button: TerminalMouseButton.wheelDown,
        buttonState: TerminalMouseButtonState.down,
        mouseMode: MouseMode.upDownScroll,
      );

      final result = defaultMouseHandler.call(event);

      expect(result, isNotNull);
    });
  });
}

class _MockHandler implements TerminalMouseHandler {
  final String? _result;

  _MockHandler(this._result);

  @override
  String? call(TerminalMouseEvent event) => _result;
}
