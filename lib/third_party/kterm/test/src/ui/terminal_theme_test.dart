import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/terminal_theme.dart';
import 'package:kterm/src/ui/themes.dart';

void main() {
  group('TerminalTheme', () {
    test(
        'Given default theme, When created, Then contains search highlight colors',
        () {
      const theme = TerminalTheme(
        cursor: Color(0XAAAEAFAD),
        selection: Color(0XAAAEAFAD),
        foreground: Color(0XFFCCCCCC),
        background: Color(0XFF1E1E1E),
        black: Color(0XFF000000),
        red: Color(0XFFCD3131),
        green: Color(0XFF0DBC79),
        yellow: Color(0XFFE5E510),
        blue: Color(0XFF2472C8),
        magenta: Color(0XFFBC3FBC),
        cyan: Color(0XFF11A8CD),
        white: Color(0XFFE5E5E5),
        brightBlack: Color(0XFF666666),
        brightRed: Color(0XFFF14C4C),
        brightGreen: Color(0XFF23D18B),
        brightYellow: Color(0XFFF5F543),
        brightBlue: Color(0XFF3B8EEA),
        brightMagenta: Color(0XFFD670D6),
        brightCyan: Color(0XFF29B8DB),
        brightWhite: Color(0XFFFFFFFF),
        searchHitBackground: Color(0XFFFFFF2B),
        searchHitBackgroundCurrent: Color(0XFF31FF26),
        searchHitForeground: Color(0XFF000000),
      );

      expect(theme.searchHitBackground, equals(const Color(0XFFFFFF2B)));
      expect(theme.searchHitBackgroundCurrent, equals(const Color(0XFF31FF26)));
      expect(theme.searchHitForeground, equals(const Color(0XFF000000)));
    });

    test(
        'Given custom theme, When setting search colors, Then uses custom colors',
        () {
      const customSearchBg = Color(0xFF00FF00);
      const customSearchBgCurrent = Color(0xFF0000FF);
      const customSearchFg = Color(0xFFFFFFFF);

      const theme = TerminalTheme(
        cursor: Color(0XAAAEAFAD),
        selection: Color(0XAAAEAFAD),
        foreground: Color(0XFFCCCCCC),
        background: Color(0XFF1E1E1E),
        black: Color(0XFF000000),
        red: Color(0XFFCD3131),
        green: Color(0XFF0DBC79),
        yellow: Color(0XFFE5E510),
        blue: Color(0XFF2472C8),
        magenta: Color(0XFFBC3FBC),
        cyan: Color(0XFF11A8CD),
        white: Color(0XFFE5E5E5),
        brightBlack: Color(0XFF666666),
        brightRed: Color(0XFFF14C4C),
        brightGreen: Color(0XFF23D18B),
        brightYellow: Color(0XFFF5F543),
        brightBlue: Color(0XFF3B8EEA),
        brightMagenta: Color(0XFFD670D6),
        brightCyan: Color(0XFF29B8DB),
        brightWhite: Color(0XFFFFFFFF),
        searchHitBackground: customSearchBg,
        searchHitBackgroundCurrent: customSearchBgCurrent,
        searchHitForeground: customSearchFg,
      );

      expect(theme.searchHitBackground, equals(customSearchBg));
      expect(theme.searchHitBackgroundCurrent, equals(customSearchBgCurrent));
      expect(theme.searchHitForeground, equals(customSearchFg));
    });

    test(
        'Given default theme from TerminalThemes, When accessing, Then has valid search colors',
        () {
      final theme = TerminalThemes.defaultTheme;

      expect(theme.searchHitBackground, isA<Color>());
      expect(theme.searchHitBackgroundCurrent, isA<Color>());
      expect(theme.searchHitForeground, isA<Color>());
      expect(theme.searchHitBackground, equals(const Color(0XFFFFFF2B)));
      expect(theme.searchHitBackgroundCurrent, equals(const Color(0XFF31FF26)));
      expect(theme.searchHitForeground, equals(const Color(0XFF000000)));
    });

    test(
        'Given whiteOnBlack theme, When accessing, Then has valid search colors',
        () {
      final theme = TerminalThemes.whiteOnBlack;

      expect(theme.searchHitBackground, isA<Color>());
      expect(theme.searchHitBackgroundCurrent, isA<Color>());
      expect(theme.searchHitForeground, isA<Color>());
    });

    test(
        'Given terminal theme, When creating, Then has all required color fields',
        () {
      const theme = TerminalTheme(
        cursor: Color(0XAAAEAFAD),
        selection: Color(0XAAAEAFAD),
        foreground: Color(0XFFCCCCCC),
        background: Color(0XFF1E1E1E),
        black: Color(0XFF000000),
        red: Color(0XFFCD3131),
        green: Color(0XFF0DBC79),
        yellow: Color(0XFFE5E510),
        blue: Color(0XFF2472C8),
        magenta: Color(0XFFBC3FBC),
        cyan: Color(0XFF11A8CD),
        white: Color(0XFFE5E5E5),
        brightBlack: Color(0XFF666666),
        brightRed: Color(0XFFF14C4C),
        brightGreen: Color(0XFF23D18B),
        brightYellow: Color(0XFFF5F543),
        brightBlue: Color(0XFF3B8EEA),
        brightMagenta: Color(0XFFD670D6),
        brightCyan: Color(0XFF29B8DB),
        brightWhite: Color(0XFFFFFFFF),
        searchHitBackground: Color(0XFFFFFF2B),
        searchHitBackgroundCurrent: Color(0XFF31FF26),
        searchHitForeground: Color(0XFF000000),
      );

      // Verify all standard colors
      expect(theme.foreground, equals(const Color(0XFFCCCCCC)));
      expect(theme.background, equals(const Color(0XFF1E1E1E)));
      expect(theme.black, equals(const Color(0XFF000000)));
      expect(theme.red, equals(const Color(0XFFCD3131)));
      expect(theme.green, equals(const Color(0XFF0DBC79)));
      expect(theme.yellow, equals(const Color(0XFFE5E510)));
      expect(theme.blue, equals(const Color(0XFF2472C8)));
      expect(theme.magenta, equals(const Color(0XFFBC3FBC)));
      expect(theme.cyan, equals(const Color(0XFF11A8CD)));
      expect(theme.white, equals(const Color(0XFFE5E5E5)));

      // Verify bright colors
      expect(theme.brightBlack, equals(const Color(0XFF666666)));
      expect(theme.brightRed, equals(const Color(0XFFF14C4C)));
      expect(theme.brightGreen, equals(const Color(0XFF23D18B)));
      expect(theme.brightYellow, equals(const Color(0XFFF5F543)));
      expect(theme.brightBlue, equals(const Color(0XFF3B8EEA)));
      expect(theme.brightMagenta, equals(const Color(0XFFD670D6)));
      expect(theme.brightCyan, equals(const Color(0XFF29B8DB)));
      expect(theme.brightWhite, equals(const Color(0XFFFFFFFF)));

      // Verify cursor and selection
      expect(theme.cursor, equals(const Color(0XAAAEAFAD)));
      expect(theme.selection, equals(const Color(0XAAAEAFAD)));
    });
  });
}
