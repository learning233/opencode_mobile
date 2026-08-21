import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/platform.dart';

void main() {
  group('TerminalTargetPlatform', () {
    test('Given TerminalTargetPlatform, When checked, Then contains unknown',
        () {
      // Assert
      expect(
          TerminalTargetPlatform.values
              .contains(TerminalTargetPlatform.unknown),
          isTrue);
    });

    test(
        'Given TerminalTargetPlatform, When checked, Then contains mobile platforms',
        () {
      // Assert
      expect(
          TerminalTargetPlatform.values
              .contains(TerminalTargetPlatform.android),
          isTrue);
      expect(TerminalTargetPlatform.values.contains(TerminalTargetPlatform.ios),
          isTrue);
      expect(
          TerminalTargetPlatform.values
              .contains(TerminalTargetPlatform.fuchsia),
          isTrue);
    });

    test(
        'Given TerminalTargetPlatform, When checked, Then contains desktop platforms',
        () {
      // Assert
      expect(
          TerminalTargetPlatform.values.contains(TerminalTargetPlatform.linux),
          isTrue);
      expect(
          TerminalTargetPlatform.values.contains(TerminalTargetPlatform.macos),
          isTrue);
      expect(
          TerminalTargetPlatform.values
              .contains(TerminalTargetPlatform.windows),
          isTrue);
    });

    test('Given TerminalTargetPlatform, When checked, Then contains web', () {
      // Assert
      expect(TerminalTargetPlatform.values.contains(TerminalTargetPlatform.web),
          isTrue);
    });

    test(
        'Given TerminalTargetPlatform, When checked, Then has expected number of values',
        () {
      // Assert
      expect(TerminalTargetPlatform.values.length, equals(8));
    });
  });
}
