import 'package:flutter/widgets.dart';
import 'package:kterm/src/ui/terminal_theme.dart';

class TerminalThemes {
  static const dark = TerminalTheme(
    cursor: Color(0XAAAEAFAD),
    selection: Color(0XAAAEAFAD),
    foreground: Color(0XFFCCCCCC),
    background: Color(0XFF16171E),
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
    searchHitBackground: Color(0X55FFFF2B),
    searchHitBackgroundCurrent: Color(0X8831FF26),
    searchHitForeground: Color(0XFF000000),
  );

  static const light = TerminalTheme(
    cursor: Color(0XFF333333),
    selection: Color(0X66BBDEFB),
    foreground: Color(0XFF1E1E1E),
    background: Color(0XFFFFFFFF),
    black: Color(0XFF000000),
    red: Color(0XFFCD3131),
    green: Color(0XFF0DBC79),
    yellow: Color(0XFF9A7A00), // Legible golden yellow on white background
    blue: Color(0XFF2472C8),
    magenta: Color(0XFFBC3FBC),
    cyan: Color(0XFF11A8CD),
    white: Color(0XFF888888), // Legible grey for ANSI white text in light mode
    brightBlack:
        Color(0XFFA5A5A5), // Dimmed light grey for suggestions/predictions
    brightRed: Color(0XFFF14C4C),
    brightGreen: Color(0XFF15A069), // Legible bright green on white background
    brightYellow: Color(0XFFB08000), // Legible bright gold on white background
    brightBlue: Color(0XFF3B8EEA),
    brightMagenta: Color(0XFFD670D6),
    brightCyan: Color(0XFF058FA9), // Legible bright cyan on white background
    brightWhite:
        Color(0XFF333333), // Dark grey so ANSI bright white text is visible
    searchHitBackground: Color(0X55FFFF2B),
    searchHitBackgroundCurrent: Color(0X8831FF26),
    searchHitForeground: Color(0XFF000000),
  );

  @Deprecated('Use TerminalThemes.dark instead')
  static const defaultTheme = dark;
}
