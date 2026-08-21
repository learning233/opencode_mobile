import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:kterm/src/core/buffer/cell_offset.dart';
import 'package:kterm/src/core/mouse/button.dart';
import 'package:kterm/src/core/mouse/button_state.dart';
import 'package:kterm/src/terminal_view.dart';
import 'package:kterm/src/ui/controller.dart';
import 'package:kterm/src/ui/gesture/gesture_detector.dart';
import 'package:kterm/src/ui/pointer_input.dart';
import 'package:kterm/src/ui/render.dart';

class TerminalGestureHandler extends StatefulWidget {
  const TerminalGestureHandler({
    super.key,
    required this.terminalView,
    required this.terminalController,
    this.child,
    this.onTapUp,
    this.onSingleTapUp,
    this.onTapDown,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onTertiaryTapDown,
    this.onTertiaryTapUp,
    this.readOnly = false,
  });

  final TerminalViewState terminalView;

  final TerminalController terminalController;

  final Widget? child;

  final GestureTapUpCallback? onTapUp;

  final GestureTapUpCallback? onSingleTapUp;

  final GestureTapDownCallback? onTapDown;

  final GestureTapDownCallback? onSecondaryTapDown;

  final GestureTapUpCallback? onSecondaryTapUp;

  final GestureTapDownCallback? onTertiaryTapDown;

  final GestureTapUpCallback? onTertiaryTapUp;

  final bool readOnly;

  @override
  State<TerminalGestureHandler> createState() => _TerminalGestureHandlerState();
}

class _TerminalGestureHandlerState extends State<TerminalGestureHandler> {
  TerminalViewState get terminalView => widget.terminalView;

  RenderTerminal get renderTerminal => terminalView.renderTerminal;

  // DragStartDetails? _lastDragStartDetails;

  LongPressStartDetails? _lastLongPressStartDetails;

  Timer? _autoScrollTimer;
  Offset? _dragPosition;
  CellOffset? _dragStartCellOffset;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _startAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_dragPosition == null || _dragStartCellOffset == null) return;

      final viewportHeight = renderTerminal.size.height;
      final dy = _dragPosition!.dy;

      double scrollDelta = 0;
      if (dy < 0) {
        scrollDelta = (dy / 10).clamp(-50.0, -10.0);
      } else if (dy > viewportHeight) {
        scrollDelta = ((dy - viewportHeight) / 10).clamp(10.0, 50.0);
      }

      if (scrollDelta != 0) {
        final scrollController = terminalView.scrollController;
        if (scrollController.hasClients) {
          final newOffset = (scrollController.offset + scrollDelta).clamp(
            scrollController.position.minScrollExtent,
            scrollController.position.maxScrollExtent,
          );
          if (newOffset != scrollController.offset) {
            scrollController.jumpTo(newOffset);
            renderTerminal.selectCharactersFromCell(
              _dragStartCellOffset!,
              _dragPosition!,
            );
          }
        }
      }
    });
  }

  void _stopAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return TerminalGestureDetector(
      child: widget.child,
      onTapUp: widget.onTapUp,
      onSingleTapUp: onSingleTapUp,
      onTapDown: onTapDown,
      onSecondaryTapDown: onSecondaryTapDown,
      onSecondaryTapUp: onSecondaryTapUp,
      onTertiaryTapDown: onSecondaryTapDown,
      onTertiaryTapUp: onSecondaryTapUp,
      onLongPressStart: onLongPressStart,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      // onLongPressUp: onLongPressUp,
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      onDragCancel: onDragCancel,
      onDoubleTapDown: onDoubleTapDown,
    );
  }

  bool get _shouldSendTapEvent =>
      !widget.readOnly &&
      widget.terminalController.shouldSendPointerInput(PointerInput.tap);

  void _tapDown(
    GestureTapDownCallback? callback,
    TapDownDetails details,
    TerminalMouseButton button, {
    bool forceCallback = false,
  }) {
    // Check if the terminal should and can handle the tap down event.
    var handled = false;
    if (_shouldSendTapEvent) {
      handled = renderTerminal.mouseEvent(
        button,
        TerminalMouseButtonState.down,
        details.localPosition,
      );
    }
    // If the event was not handled by the terminal, use the supplied callback.
    if (!handled || forceCallback) {
      callback?.call(details);
    }
  }

  void _tapUp(
    GestureTapUpCallback? callback,
    TapUpDetails details,
    TerminalMouseButton button, {
    bool forceCallback = false,
  }) {
    // Check if the terminal should and can handle the tap up event.
    var handled = false;
    if (_shouldSendTapEvent) {
      handled = renderTerminal.mouseEvent(
        button,
        TerminalMouseButtonState.up,
        details.localPosition,
      );
    }
    // If the event was not handled by the terminal, use the supplied callback.
    if (!handled || forceCallback) {
      callback?.call(details);
    }
  }

  void onTapDown(TapDownDetails details) {
    // onTapDown is special, as it will always call the supplied callback.
    // The TerminalView depends on it to bring the terminal into focus.
    _tapDown(
      widget.onTapDown,
      details,
      TerminalMouseButton.left,
      forceCallback: true,
    );
  }

  void onSingleTapUp(TapUpDetails details) {
    _tapUp(widget.onSingleTapUp, details, TerminalMouseButton.left);
  }

  void onSecondaryTapDown(TapDownDetails details) {
    _tapDown(widget.onSecondaryTapDown, details, TerminalMouseButton.right);
  }

  void onSecondaryTapUp(TapUpDetails details) {
    _tapUp(widget.onSecondaryTapUp, details, TerminalMouseButton.right);
  }

  void onTertiaryTapDown(TapDownDetails details) {
    _tapDown(widget.onTertiaryTapDown, details, TerminalMouseButton.middle);
  }

  void onTertiaryTapUp(TapUpDetails details) {
    _tapUp(widget.onTertiaryTapUp, details, TerminalMouseButton.right);
  }

  void onDoubleTapDown(TapDownDetails details) {
    renderTerminal.selectWord(details.localPosition);
  }

  void onLongPressStart(LongPressStartDetails details) {
    _lastLongPressStartDetails = details;
    _dragStartCellOffset = renderTerminal.getCellOffset(details.localPosition);
    renderTerminal.selectWord(details.localPosition);
  }

  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_dragStartCellOffset != null) {
      renderTerminal.selectCharactersFromCell(
        _dragStartCellOffset!,
        details.localPosition,
      );
    } else if (_lastLongPressStartDetails != null) {
      renderTerminal.selectCharacters(
        _lastLongPressStartDetails!.localPosition,
        details.localPosition,
      );
    }
  }

  // void onLongPressUp() {}

  void onDragStart(DragStartDetails details) {
    // _lastDragStartDetails = details;
    _dragPosition = details.localPosition;
    _dragStartCellOffset = renderTerminal.getCellOffset(details.localPosition);

    details.kind == PointerDeviceKind.mouse
        ? renderTerminal.selectCharacters(details.localPosition)
        : renderTerminal.selectWord(details.localPosition);

    _startAutoScrollTimer();
  }

  void onDragUpdate(DragUpdateDetails details) {
    _dragPosition = details.localPosition;
    if (_dragStartCellOffset != null) {
      renderTerminal.selectCharactersFromCell(
        _dragStartCellOffset!,
        details.localPosition,
      );
    }
  }

  void onDragEnd(DragEndDetails details) {
    _stopAutoScrollTimer();
    _dragPosition = null;
    _dragStartCellOffset = null;
  }

  void onDragCancel() {
    _stopAutoScrollTimer();
    _dragPosition = null;
    _dragStartCellOffset = null;
  }
}
