import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('TerminalKey', () {
    group('enum values', () {
      test(
          'Given TerminalKey enum, When checked, Then has correct number of values',
          () {
        // Assert - verify the enum has expected number of values
        expect(TerminalKey.values.length, greaterThan(150));
      });

      test(
          'Given TerminalKey enum, When checked, Then contains common control keys',
          () {
        // Assert - verify control keys exist
        expect(TerminalKey.values.contains(TerminalKey.escape), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.enter), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.backspace), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.tab), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.space), isTrue);
      });

      test(
          'Given TerminalKey enum, When checked, Then contains alphanumeric keys',
          () {
        // Assert - verify alphanumeric keys exist
        expect(TerminalKey.values.contains(TerminalKey.keyA), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.keyZ), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.digit0), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.digit9), isTrue);
      });

      test('Given TerminalKey enum, When checked, Then contains function keys',
          () {
        // Assert - verify function keys exist
        expect(TerminalKey.values.contains(TerminalKey.f1), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.f12), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.f24), isTrue);
      });

      test('Given TerminalKey enum, When checked, Then contains modifier keys',
          () {
        // Assert - verify modifier keys exist
        expect(TerminalKey.values.contains(TerminalKey.controlLeft), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.controlRight), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.shiftLeft), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.shiftRight), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.altLeft), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.altRight), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.metaLeft), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.metaRight), isTrue);
      });

      test(
          'Given TerminalKey enum, When checked, Then contains navigation keys',
          () {
        // Assert - verify navigation keys exist
        expect(TerminalKey.values.contains(TerminalKey.arrowUp), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.arrowDown), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.arrowLeft), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.arrowRight), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.home), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.end), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.pageUp), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.pageDown), isTrue);
      });

      test('Given TerminalKey enum, When checked, Then contains numpad keys',
          () {
        // Assert - verify numpad keys exist
        expect(TerminalKey.values.contains(TerminalKey.numpad0), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.numpad9), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.numpadDivide), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.numpadMultiply), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.numpadSubtract), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.numpadAdd), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.numpadDecimal), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.numpadEnter), isTrue);
      });

      test('Given TerminalKey enum, When checked, Then contains media keys',
          () {
        // Assert - verify media keys exist
        expect(TerminalKey.values.contains(TerminalKey.mediaPlay), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.mediaPause), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.mediaStop), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.mediaRecord), isTrue);
      });

      test('Given TerminalKey enum, When checked, Then contains browser keys',
          () {
        // Assert - verify browser keys exist
        expect(TerminalKey.values.contains(TerminalKey.browserBack), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.browserForward), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.browserRefresh), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.browserHome), isTrue);
      });

      test('Given TerminalKey enum, When checked, Then contains special values',
          () {
        // Assert - verify special values exist
        expect(TerminalKey.values.contains(TerminalKey.none), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.backtab), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.returnKey), isTrue);
      });

      test(
          'Given TerminalKey enum, When checked, Then contains union modifier keys',
          () {
        // Assert - verify union modifier keys exist
        expect(TerminalKey.values.contains(TerminalKey.shift), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.meta), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.alt), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.control), isTrue);
      });

      test(
          'Given TerminalKey enum, When checked, Then contains game button keys',
          () {
        // Assert - verify game button keys exist
        expect(TerminalKey.values.contains(TerminalKey.gameButton1), isTrue);
        expect(TerminalKey.values.contains(TerminalKey.gameButtonA), isTrue);
        expect(
            TerminalKey.values.contains(TerminalKey.gameButtonStart), isTrue);
        expect(
            TerminalKey.values.contains(TerminalKey.gameButtonSelect), isTrue);
      });
    });
  });
}
