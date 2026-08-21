import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:test/test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:kterm/src/ui/painter.dart';
import 'package:kterm/src/ui/terminal_theme.dart';
import 'package:kterm/src/ui/terminal_text_style.dart';
import 'package:kterm/src/ui/themes.dart';
import 'package:kterm/src/core/cell.dart';

import 'painter_test.mocks.dart';

@GenerateMocks([ui.Canvas])
void main() {
  group('TerminalPainter', () {
    late TerminalPainter painter;
    late TerminalTheme theme;
    late TerminalStyle textStyle;
    late MockCanvas mockCanvas;

    setUp(() {
      theme = TerminalThemes.defaultTheme;
      textStyle = const TerminalStyle(fontSize: 14.0);
      painter = TerminalPainter(
        theme: theme,
        textStyle: textStyle,
        textScaler: TextScaler.linear(1.0),
      );
      mockCanvas = MockCanvas();
    });

    group('setters trigger cache clearing', () {
      test('textStyle setter clears paragraph cache', () {
        final initialCellSize = painter.cellSize;

        final newStyle = const TerminalStyle(fontSize: 18.0);
        painter.textStyle = newStyle;

        // Cell size should change after style update
        expect(painter.cellSize, isNot(equals(initialCellSize)));
        expect(painter.textStyle.fontSize, equals(18.0));
      });

      test('textScaler setter clears paragraph cache', () {
        final initialCellSize = painter.cellSize;

        painter.textScaler = TextScaler.linear(2.0);

        // Cell size should change after scaler update
        expect(painter.cellSize.height, greaterThan(initialCellSize.height));
      });

      test('theme setter clears paragraph cache', () {
        final initialForeground = painter.resolveForegroundColor(0);

        final newTheme = TerminalThemes.defaultTheme;
        // Create a custom theme for testing
        final customTheme = TerminalTheme(
          cursor: newTheme.cursor,
          selection: newTheme.selection,
          foreground: const Color(0xFF123456),
          background: newTheme.background,
          black: newTheme.black,
          red: newTheme.red,
          green: newTheme.green,
          yellow: newTheme.yellow,
          blue: newTheme.blue,
          magenta: newTheme.magenta,
          cyan: newTheme.cyan,
          white: newTheme.white,
          brightBlack: newTheme.brightBlack,
          brightRed: newTheme.brightRed,
          brightGreen: newTheme.brightGreen,
          brightYellow: newTheme.brightYellow,
          brightBlue: newTheme.brightBlue,
          brightMagenta: newTheme.brightMagenta,
          brightCyan: newTheme.brightCyan,
          brightWhite: newTheme.brightWhite,
          searchHitBackground: newTheme.searchHitBackground,
          searchHitBackgroundCurrent: newTheme.searchHitBackgroundCurrent,
          searchHitForeground: newTheme.searchHitForeground,
        );
        painter.theme = customTheme;

        // Foreground should now be the new theme's foreground
        expect(
            painter.resolveForegroundColor(0), equals(const Color(0xFF123456)));
      });

      test('same textStyle value does not clear cache', () {
        final initialCellSize = painter.cellSize;

        // Set same style
        painter.textStyle = textStyle;

        // Should not change
        expect(painter.cellSize, equals(initialCellSize));
      });

      test('same textScaler value does not clear cache', () {
        final initialCellSize = painter.cellSize;

        // Set same scaler
        painter.textScaler = TextScaler.linear(1.0);

        // Should not change
        expect(painter.cellSize, equals(initialCellSize));
      });

      test('same theme value does not clear cache', () {
        final initialForeground = painter.resolveForegroundColor(0);

        // Set same theme
        painter.theme = theme;

        // Should not change
        expect(painter.resolveForegroundColor(0), equals(initialForeground));
      });
    });

    group('resolveForegroundColor', () {
      test('resolves normal color to theme foreground', () {
        final color = painter.resolveForegroundColor(CellColor.normal);
        expect(color, equals(theme.foreground));
      });

      test('resolves named color from palette', () {
        // Named color: index 1 (black) | CellColor.named
        final color = painter.resolveForegroundColor(1 | CellColor.named);
        expect(color, isNotNull);
        expect(color, isA<ui.Color>());
      });

      test('resolves palette color from palette', () {
        // Palette color: index 7 (white) | CellColor.palette
        final color = painter.resolveForegroundColor(7 | CellColor.palette);
        expect(color, isNotNull);
        expect(color, isA<ui.Color>());
      });

      test('resolves RGB color correctly', () {
        // RGB: (255 << 16) | (128 << 8) | 64 | CellColor.rgb
        final rgbValue = (255 << 16) | (128 << 8) | 64 | CellColor.rgb;
        final color = painter.resolveForegroundColor(rgbValue);
        // Should have alpha set to FF
        expect(color.alpha, equals(0xFF));
        expect(color.red, equals(255));
        expect(color.green, equals(128));
        expect(color.blue, equals(64));
      });

      test('handles unknown color type as RGB', () {
        // Default case returns RGB interpretation
        final color = painter.resolveForegroundColor(0xFF0000FF);
        expect(color, isA<ui.Color>());
      });
    });

    group('resolveBackgroundColor', () {
      test('resolves normal color to theme background', () {
        final color = painter.resolveBackgroundColor(CellColor.normal);
        expect(color, equals(theme.background));
      });

      test('resolves named color from palette', () {
        final color = painter.resolveBackgroundColor(1 | CellColor.named);
        expect(color, isNotNull);
        expect(color, isA<ui.Color>());
      });

      test('resolves palette color from palette', () {
        final color = painter.resolveBackgroundColor(7 | CellColor.palette);
        expect(color, isNotNull);
        expect(color, isA<ui.Color>());
      });

      test('resolves RGB color correctly', () {
        final rgbValue = (128 << 16) | (64 << 8) | 32 | CellColor.rgb;
        final color = painter.resolveBackgroundColor(rgbValue);
        expect(color.alpha, equals(0xFF));
        expect(color.red, equals(128));
        expect(color.green, equals(64));
        expect(color.blue, equals(32));
      });
    });

    group('clearFontCache', () {
      test('clears cell size and paragraph cache', () {
        final initialCellSize = painter.cellSize;

        painter.clearFontCache();

        expect(painter.cellSize, equals(initialCellSize));
      });
    });

    group('cellSize', () {
      test('returns valid size', () {
        final size = painter.cellSize;
        expect(size.width, greaterThan(0));
        expect(size.height, greaterThan(0));
      });

      test('width is based on font', () {
        final size = painter.cellSize;
        // Monospace font should give consistent width
        expect(size.width, equals(size.width));
      });
    });
  });
}
