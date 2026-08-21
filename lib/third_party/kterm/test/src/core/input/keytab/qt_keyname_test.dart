import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/input/keytab/qt_keyname.dart';
import 'package:kterm/src/core/input/keys.dart';

void main() {
  group('qtKeynameMap', () {
    group('navigation keys', () {
      test(
          'Given qtKeynameMap, When contains Escape, Then maps to TerminalKey.escape',
          () {
        // Assert
        expect(qtKeynameMap['Escape'], equals(TerminalKey.escape));
      });

      test(
          'Given qtKeynameMap, When contains Tab, Then maps to TerminalKey.tab',
          () {
        // Assert
        expect(qtKeynameMap['Tab'], equals(TerminalKey.tab));
      });

      test(
          'Given qtKeynameMap, When contains Backspace, Then maps to TerminalKey.backspace',
          () {
        // Assert
        expect(qtKeynameMap['Backspace'], equals(TerminalKey.backspace));
      });

      test('Given qtKeynameMap, When contains arrow keys, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['Left'], equals(TerminalKey.arrowLeft));
        expect(qtKeynameMap['Right'], equals(TerminalKey.arrowRight));
        expect(qtKeynameMap['Up'], equals(TerminalKey.arrowUp));
        expect(qtKeynameMap['Down'], equals(TerminalKey.arrowDown));
      });

      test(
          'Given qtKeynameMap, When contains Home and End, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['Home'], equals(TerminalKey.home));
        expect(qtKeynameMap['End'], equals(TerminalKey.end));
      });

      test(
          'Given qtKeynameMap, When contains PageUp and PageDown, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['PageUp'], equals(TerminalKey.pageUp));
        expect(qtKeynameMap['PageDown'], equals(TerminalKey.pageDown));
        expect(qtKeynameMap['PgUp'], equals(TerminalKey.pageUp));
        expect(qtKeynameMap['PgDown'], equals(TerminalKey.pageDown));
      });
    });

    group('function keys', () {
      test('Given qtKeynameMap, When contains F1-F12, Then maps correctly', () {
        // Assert
        expect(qtKeynameMap['F1'], equals(TerminalKey.f1));
        expect(qtKeynameMap['F12'], equals(TerminalKey.f12));
        expect(qtKeynameMap['F24'], equals(TerminalKey.f24));
      });

      test(
          'Given qtKeynameMap, When contains function keys F13-F24, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['F13'], equals(TerminalKey.f13));
        expect(qtKeynameMap['F20'], equals(TerminalKey.f20));
      });
    });

    group('modifier keys', () {
      test(
          'Given qtKeynameMap, When contains modifier keys, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['Shift'], equals(TerminalKey.shift));
        expect(qtKeynameMap['Control'], equals(TerminalKey.control));
        expect(qtKeynameMap['Meta'], equals(TerminalKey.meta));
        expect(qtKeynameMap['Alt'], equals(TerminalKey.alt));
      });

      test('Given qtKeynameMap, When contains lock keys, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['CapsLock'], equals(TerminalKey.capsLock));
        expect(qtKeynameMap['NumLock'], equals(TerminalKey.numLock));
        expect(qtKeynameMap['ScrollLock'], equals(TerminalKey.scrollLock));
      });
    });

    group('alphanumeric keys', () {
      test('Given qtKeynameMap, When contains digit keys, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['0'], equals(TerminalKey.digit0));
        expect(qtKeynameMap['9'], equals(TerminalKey.digit9));
      });

      test('Given qtKeynameMap, When contains letter keys, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['A'], equals(TerminalKey.keyA));
        expect(qtKeynameMap['Z'], equals(TerminalKey.keyZ));
      });

      test(
          'Given qtKeynameMap, When contains punctuation keys, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['Space'], equals(TerminalKey.space));
        expect(qtKeynameMap['Comma'], equals(TerminalKey.comma));
        expect(qtKeynameMap['Period'], equals(TerminalKey.period));
        expect(qtKeynameMap['Slash'], equals(TerminalKey.slash));
        expect(qtKeynameMap['Semicolon'], equals(TerminalKey.semicolon));
        expect(qtKeynameMap['Minus'], equals(TerminalKey.minus));
      });
    });

    group('media keys', () {
      test('Given qtKeynameMap, When contains media keys, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['MediaPlay'], equals(TerminalKey.mediaPlay));
        expect(qtKeynameMap['MediaStop'], equals(TerminalKey.mediaStop));
        expect(qtKeynameMap['MediaPause'], equals(TerminalKey.mediaPause));
        expect(qtKeynameMap['MediaRecord'], equals(TerminalKey.mediaRecord));
      });

      test('Given qtKeynameMap, When contains volume keys, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['VolumeUp'], equals(TerminalKey.audioVolumeUp));
        expect(qtKeynameMap['VolumeDown'], equals(TerminalKey.audioVolumeDown));
        expect(qtKeynameMap['VolumeMute'], equals(TerminalKey.audioVolumeMute));
      });
    });

    group('special keys', () {
      test(
          'Given qtKeynameMap, When contains Return and Enter, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['Return'], equals(TerminalKey.returnKey));
        expect(qtKeynameMap['Enter'], equals(TerminalKey.enter));
        expect(qtKeynameMap['NumEnter'], equals(TerminalKey.numpadEnter));
      });

      test(
          'Given qtKeynameMap, When contains Insert and Delete, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['Insert'], equals(TerminalKey.insert));
        expect(qtKeynameMap['Delete'], equals(TerminalKey.delete));
      });

      test(
          'Given qtKeynameMap, When contains clipboard keys, Then maps correctly',
          () {
        // Assert
        expect(qtKeynameMap['Copy'], equals(TerminalKey.copy));
        expect(qtKeynameMap['Cut'], equals(TerminalKey.cut));
        expect(qtKeynameMap['Save'], equals(TerminalKey.save));
        expect(qtKeynameMap['Open'], equals(TerminalKey.open));
        expect(qtKeynameMap['Find'], equals(TerminalKey.find));
        expect(qtKeynameMap['Undo'], equals(TerminalKey.undo));
        expect(qtKeynameMap['Redo'], equals(TerminalKey.redo));
      });
    });

    test(
        'Given qtKeynameMap, When checked, Then contains expected number of mappings',
        () {
      // Assert - verify map has substantial entries
      expect(qtKeynameMap.length, greaterThan(50));
    });
  });
}
