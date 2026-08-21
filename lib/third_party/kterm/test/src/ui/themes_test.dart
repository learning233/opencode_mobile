import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/themes.dart';

void main() {
  group('TerminalThemes', () {
    group('defaultTheme', () {
      test('Given defaultTheme, When cursor accessed, Then returns color', () {
        expect(TerminalThemes.defaultTheme.cursor, isA<Color>());
      });

      test(
          'Given defaultTheme, When foreground accessed, Then returns light gray',
          () {
        expect(
          TerminalThemes.defaultTheme.foreground.value,
          equals(0XFFCCCCCC),
        );
      });

      test(
          'Given defaultTheme, When background accessed, Then returns dark gray',
          () {
        expect(
          TerminalThemes.defaultTheme.background.value,
          equals(0XFF16171E),
        );
      });

      test(
          'Given defaultTheme, When all colors accessed, Then returns non-null colors',
          () {
        expect(TerminalThemes.defaultTheme.black, isNotNull);
        expect(TerminalThemes.defaultTheme.red, isNotNull);
        expect(TerminalThemes.defaultTheme.green, isNotNull);
        expect(TerminalThemes.defaultTheme.yellow, isNotNull);
        expect(TerminalThemes.defaultTheme.blue, isNotNull);
        expect(TerminalThemes.defaultTheme.magenta, isNotNull);
        expect(TerminalThemes.defaultTheme.cyan, isNotNull);
        expect(TerminalThemes.defaultTheme.white, isNotNull);
        expect(TerminalThemes.defaultTheme.brightBlack, isNotNull);
        expect(TerminalThemes.defaultTheme.brightRed, isNotNull);
        expect(TerminalThemes.defaultTheme.brightGreen, isNotNull);
        expect(TerminalThemes.defaultTheme.brightYellow, isNotNull);
        expect(TerminalThemes.defaultTheme.brightBlue, isNotNull);
        expect(TerminalThemes.defaultTheme.brightMagenta, isNotNull);
        expect(TerminalThemes.defaultTheme.brightCyan, isNotNull);
        expect(TerminalThemes.defaultTheme.brightWhite, isNotNull);
      });

      test(
          'Given defaultTheme, When search colors accessed, Then returns colors',
          () {
        expect(TerminalThemes.defaultTheme.searchHitBackground, isNotNull);
        expect(
            TerminalThemes.defaultTheme.searchHitBackgroundCurrent, isNotNull);
        expect(TerminalThemes.defaultTheme.searchHitForeground, isNotNull);
      });
    });

    group('whiteOnBlack', () {
      test('Given whiteOnBlack, When foreground accessed, Then returns white',
          () {
        expect(
          TerminalThemes.whiteOnBlack.foreground.value,
          equals(0XFFFFFFFF),
        );
      });

      test('Given whiteOnBlack, When background accessed, Then returns black',
          () {
        expect(
          TerminalThemes.whiteOnBlack.background.value,
          equals(0XFF000000),
        );
      });

      test(
          'Given whiteOnBlack, When colors accessed, Then returns non-null colors',
          () {
        expect(TerminalThemes.whiteOnBlack.black, isNotNull);
        expect(TerminalThemes.whiteOnBlack.white, isNotNull);
      });
    });
  });
}
