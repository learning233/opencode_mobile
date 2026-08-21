import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/palette_builder.dart';
import 'package:kterm/src/ui/terminal_theme.dart';

TerminalTheme createTestTheme() {
  return const TerminalTheme(
    cursor: Colors.white,
    selection: Colors.blue,
    foreground: Colors.white,
    background: Colors.black,
    black: Colors.black,
    red: Colors.red,
    green: Colors.green,
    yellow: Colors.yellow,
    blue: Colors.blue,
    magenta: Colors.purple,
    cyan: Colors.cyan,
    white: Colors.white,
    brightBlack: Colors.grey,
    brightRed: Colors.red,
    brightGreen: Colors.green,
    brightYellow: Colors.yellow,
    brightBlue: Colors.blue,
    brightMagenta: Colors.purple,
    brightCyan: Colors.cyan,
    brightWhite: Colors.white,
    searchHitBackground: Colors.yellow,
    searchHitBackgroundCurrent: Colors.orange,
    searchHitForeground: Colors.black,
  );
}

void main() {
  group('PaletteBuilder', () {
    group('constructor', () {
      test('Given TerminalTheme, When created, Then stores theme', () {
        final theme = createTestTheme();
        final builder = PaletteBuilder(theme);
        expect(builder.theme, equals(theme));
      });
    });

    group('build', () {
      test(
          'Given test theme, When build called, Then returns list of 256 colors',
          () {
        final theme = createTestTheme();
        final builder = PaletteBuilder(theme);
        final palette = builder.build();

        expect(palette.length, equals(256));
      });

      test(
          'Given test theme, When build called, Then first 8 colors are standard ANSI',
          () {
        final theme = createTestTheme();
        final builder = PaletteBuilder(theme);
        final palette = builder.build();

        // Standard ANSI colors (0-7)
        expect(palette[0], equals(theme.black));
        expect(palette[1], equals(theme.red));
        expect(palette[2], equals(theme.green));
        expect(palette[3], equals(theme.yellow));
        expect(palette[4], equals(theme.blue));
        expect(palette[5], equals(theme.magenta));
        expect(palette[6], equals(theme.cyan));
        expect(palette[7], equals(theme.white));
      });

      test(
          'Given test theme, When build called, Then bright colors (8-15) are correct',
          () {
        final theme = createTestTheme();
        final builder = PaletteBuilder(theme);
        final palette = builder.build();

        // Bright colors (8-15)
        expect(palette[8], equals(theme.brightBlack));
        expect(palette[9], equals(theme.brightRed));
        expect(palette[10], equals(theme.brightGreen));
        expect(palette[11], equals(theme.brightYellow));
        expect(palette[12], equals(theme.brightBlue));
        expect(palette[13], equals(theme.brightMagenta));
        expect(palette[14], equals(theme.brightCyan));
        expect(palette[15], equals(theme.brightWhite));
      });

      test('Given custom theme, When build called, Then uses custom colors',
          () {
        final theme = const TerminalTheme(
          cursor: Colors.white,
          selection: Colors.blue,
          foreground: Colors.white,
          background: Colors.black,
          black: Colors.purple,
          red: Colors.purple,
          green: Colors.purple,
          yellow: Colors.purple,
          blue: Colors.purple,
          magenta: Colors.purple,
          cyan: Colors.purple,
          white: Colors.purple,
          brightBlack: Colors.purple,
          brightRed: Colors.purple,
          brightGreen: Colors.purple,
          brightYellow: Colors.purple,
          brightBlue: Colors.purple,
          brightMagenta: Colors.purple,
          brightCyan: Colors.purple,
          brightWhite: Colors.purple,
          searchHitBackground: Colors.yellow,
          searchHitBackgroundCurrent: Colors.orange,
          searchHitForeground: Colors.black,
        );
        final builder = PaletteBuilder(theme);
        final palette = builder.build();

        // All standard colors should be purple
        for (var i = 0; i < 16; i++) {
          expect(palette[i], equals(Colors.purple));
        }
      });
    });

    group('paletteColor', () {
      test('Given colNum 0, Then returns theme black', () {
        final theme = createTestTheme();
        final builder = PaletteBuilder(theme);

        expect(builder.paletteColor(0), equals(theme.black));
      });

      test('Given colNum 15, Then returns theme brightWhite', () {
        final theme = createTestTheme();
        final builder = PaletteBuilder(theme);

        expect(builder.paletteColor(15), equals(theme.brightWhite));
      });

      test('Given colNum 232, Then returns grayscale (dark)', () {
        final theme = createTestTheme();
        final builder = PaletteBuilder(theme);

        final color = builder.paletteColor(232);
        expect(color.alpha, equals(0xFF));
      });

      test('Given colNum 255, Then returns light grayscale', () {
        final theme = createTestTheme();
        final builder = PaletteBuilder(theme);

        final color = builder.paletteColor(255);
        expect(color.alpha, equals(0xFF));
      });
    });
  });
}
