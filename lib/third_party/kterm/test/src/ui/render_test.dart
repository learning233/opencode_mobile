import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:kterm/src/terminal.dart';
import 'package:kterm/src/ui/controller.dart';
import 'package:kterm/src/ui/render.dart';
import 'package:kterm/src/ui/terminal_theme.dart';
import 'package:kterm/src/ui/terminal_text_style.dart';
import 'package:kterm/src/ui/themes.dart';
import 'package:kterm/src/ui/cursor_type.dart';
import 'package:kterm/src/core/buffer/buffer.dart';

import 'render_test.mocks.dart';

@GenerateMocks(
    [Terminal, TerminalController, ViewportOffset, FocusNode, Buffer])
void main() {
  group('RenderTerminal', () {
    late MockTerminal mockTerminal;
    late MockTerminalController mockController;
    late MockViewportOffset mockOffset;
    late MockFocusNode mockFocusNode;
    late MockBuffer mockBuffer;
    late TerminalTheme theme;
    late TerminalStyle textStyle;

    setUp(() {
      mockTerminal = MockTerminal();
      mockController = MockTerminalController();
      mockOffset = MockViewportOffset();
      mockFocusNode = MockFocusNode();
      mockBuffer = MockBuffer();

      theme = TerminalThemes.defaultTheme;
      textStyle = const TerminalStyle(fontSize: 14.0);

      // Setup default mock behaviors
      when(mockTerminal.buffer).thenReturn(mockBuffer);
      when(mockTerminal.viewWidth).thenReturn(80);
      when(mockTerminal.viewHeight).thenReturn(24);
      when(mockTerminal.cursorVisibleMode).thenReturn(false);
      when(mockTerminal.addListener(any)).thenReturn(null);
      when(mockTerminal.removeListener(any)).thenReturn(null);
      when(mockTerminal.mouseInput(any, any, any)).thenReturn(true);

      when(mockController.addListener(any)).thenReturn(null);
      when(mockController.removeListener(any)).thenReturn(null);
      when(mockController.selection).thenReturn(null);
      when(mockController.highlights).thenReturn([]);
      when(mockController.isSearching).thenReturn(false);
      when(mockController.hasSearchResults).thenReturn(false);
      when(mockController.shouldSendPointerInput(any)).thenReturn(true);

      when(mockOffset.addListener(any)).thenReturn(null);
      when(mockOffset.removeListener(any)).thenReturn(null);
      when(mockOffset.pixels).thenReturn(0.0);
      when(mockOffset.applyViewportDimension(any)).thenReturn(true);
      when(mockOffset.applyContentDimensions(any, any)).thenReturn(true);

      when(mockFocusNode.addListener(any)).thenReturn(null);
      when(mockFocusNode.removeListener(any)).thenReturn(null);
      when(mockFocusNode.hasFocus).thenReturn(true);
    });

    RenderTerminal createRenderWidget() {
      return RenderTerminal(
        terminal: mockTerminal,
        controller: mockController,
        offset: mockOffset,
        padding: EdgeInsets.zero,
        autoResize: false,
        textStyle: textStyle,
        textScaler: TextScaler.linear(1.0),
        theme: theme,
        focusNode: mockFocusNode,
        cursorType: TerminalCursorType.block,
        alwaysShowCursor: false,
      );
    }

    test('hitTestSelf always returns true', () {
      final render = createRenderWidget();
      expect(render.hitTestSelf(const Offset(0, 0)), isTrue);
    });

    test('isRepaintBoundary is true', () {
      final render = createRenderWidget();
      expect(render.isRepaintBoundary, isTrue);
    });

    test('cellSize returns valid dimensions', () {
      final render = createRenderWidget();
      final size = render.cellSize;
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    });

    test('render terminal has required properties', () {
      final render = createRenderWidget();
      // Verify the render object has required properties
      expect(render, isA<RenderBox>());
      expect(render.isRepaintBoundary, isTrue);
    });
  });
}
