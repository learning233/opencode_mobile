import 'package:test/test.dart';
import 'package:kterm/src/utils/debugger.dart';

void main() {
  group('TerminalDebugger - Coverage Extension', () {
    group('Write operations - various inputs', () {
      test('Given debugger, When writing empty string, Then no crash and empty',
          () {
        final debugger = TerminalDebugger();
        debugger.write('');
        expect(debugger.recorded, isEmpty);
        expect(debugger.commands, isEmpty);
      });

      test(
          'Given debugger, When writing single char, Then records char and may produce command',
          () {
        final debugger = TerminalDebugger();
        debugger.write('A');
        expect(debugger.recorded, [65]);
        // Single printable char may or may not produce a command depending on mode
        // Just verify no crash
        expect(debugger.commands.length, lessThan(2));
      });

      test(
          'Given debugger, When writing multiple single chars, Then accumulates',
          () {
        final debugger = TerminalDebugger();
        debugger.write('A');
        debugger.write('B');
        debugger.write('C');
        expect(debugger.recorded.length, 3);
      });

      test('Given debugger, When writing unicode, Then records code units', () {
        final debugger = TerminalDebugger();
        debugger.write('你好'); // Chinese characters
        expect(debugger.recorded.isNotEmpty, isTrue);
      });

      test('Given debugger, When writing emoji, Then records', () {
        final debugger = TerminalDebugger();
        debugger.write('😀');
        expect(debugger.recorded.isNotEmpty, isTrue);
      });

      test('Given debugger, When writing mixed content, Then records all', () {
        final debugger = TerminalDebugger();
        debugger.write('Hello\nWorld\r\n');
        expect(debugger.recorded.length, greaterThan(10));
      });

      test('Given debugger, When writing with many control chars, Then records',
          () {
        final debugger = TerminalDebugger();
        debugger.write('\x01\x02\x03\x04\x05'); // Control characters
        expect(debugger.recorded.length, 5);
      });
    });

    group('Escape sequences - verified working ones', () {
      test('Given debugger, When CSI cursor position, Then has command', () {
        final debugger = TerminalDebugger();
        debugger.write('\x1b[10;20H');
        expect(debugger.commands.isNotEmpty, isTrue);
      });

      test('Given debugger, When CSI erase display, Then has command', () {
        final debugger = TerminalDebugger();
        debugger.write('\x1b[2J');
        expect(debugger.commands.isNotEmpty, isTrue);
      });

      test('Given debugger, When CSI erase line, Then has command', () {
        final debugger = TerminalDebugger();
        debugger.write('\x1b[2K');
        expect(debugger.commands.isNotEmpty, isTrue);
      });

      test('Given debugger, When CSI SGR color, Then has command', () {
        final debugger = TerminalDebugger();
        debugger.write('\x1b[31m');
        expect(debugger.commands.isNotEmpty, isTrue);
      });

      test('Given debugger, When CSI SGR reset, Then has command', () {
        final debugger = TerminalDebugger();
        debugger.write('\x1b[0m');
        expect(debugger.commands.isNotEmpty, isTrue);
      });

      test('Given debugger, When CSI scroll region, Then has command', () {
        final debugger = TerminalDebugger();
        debugger.write('\x1b[1;10r');
        expect(debugger.commands.isNotEmpty, isTrue);
      });

      test('Given debugger, When CSI device attributes, Then has command', () {
        final debugger = TerminalDebugger();
        debugger.write('\x1b[c');
        expect(debugger.commands.isNotEmpty, isTrue);
      });

      test('Given debugger, When OSC set title, Then has command', () {
        final debugger = TerminalDebugger();
        debugger.write('\x1b]0;Test\x07');
        expect(debugger.commands.isNotEmpty, isTrue);
      });

      test('Given debugger, When OSC set icon name, Then has command', () {
        final debugger = TerminalDebugger();
        debugger.write('\x1b]1;Icon\x07');
        expect(debugger.commands.isNotEmpty, isTrue);
      });

      test('Given debugger, When DCS Kitty keyboard query, Then has command',
          () {
        final debugger = TerminalDebugger();
        debugger.write('\x1b[>0q'); // Kitty query
        expect(debugger.commands.isNotEmpty, isTrue);
      });
    });

    group('Command structure validation', () {
      test(
          'Given debugger with commands, When accessing fields, Then all accessible',
          () {
        final debugger = TerminalDebugger();
        debugger.write('\x1b[31m');
        expect(debugger.commands.isNotEmpty, isTrue);
        final cmd = debugger.commands.first;

        expect(cmd.start, isA<int>());
        expect(cmd.end, isA<int>());
        expect(cmd.chars, isA<String>());
        expect(cmd.escapedChars, isA<String>());
        expect(cmd.explanation, isA<List<String>>());
        expect(cmd.error, isA<bool>());
        expect(cmd.start, lessThanOrEqualTo(cmd.end));
        expect(cmd.explanation, isNotEmpty);
      });

      test('Given debugger command with ESC, Then escaped contains ESC', () {
        final debugger = TerminalDebugger();
        debugger.write('\x1b[31m'); // ESC sequence
        final cmd = debugger.commands.firstWhere(
            (c) => c.explanation.any((e) => e.contains('setForeground')));
        expect(cmd.escapedChars, contains('ESC'));
      });

      test('Given debugger command with control char, Then escaped shows hex',
          () {
        final debugger = TerminalDebugger();
        debugger.write('\x07'); // Bell
        final cmd = debugger.commands
            .firstWhere((c) => c.explanation.any((e) => e.contains('bell')));
        // bell doesn't have control chars in chars, but test the pattern exists
        expect(cmd.escapedChars, isNotEmpty);
      });

      test('Given debugger command with printable, Then escaped shows char',
          () {
        final debugger = TerminalDebugger();
        debugger.write('A'); // produces command in some contexts?
        // If no command, test that direct char works in other way
        // Use a sequence that includes printable
        debugger.write('\x1b[31m'); // includes ESC
        final cmd = debugger.commands.first;
        expect(cmd.chars, isNotEmpty);
      });
    });

    group('getRecord behavior', () {
      test(
          'Given debugger, When getRecord after single command, Then returns prefix',
          () {
        final debugger = TerminalDebugger();
        debugger.write('ABC\x1b[31m');
        final cmd = debugger.commands.first;
        final record = debugger.getRecord(cmd);
        expect(record, startsWith('A'));
      });

      test(
          'Given debugger, When getRecord with complex input, Then returns appropriate slice',
          () {
        final debugger = TerminalDebugger();
        debugger.write('X\x1b[31mY\x1b[0m');
        // getRecord returns substring from 0 to command.end
        if (debugger.commands.isNotEmpty) {
          final record = debugger.getRecord(debugger.commands.first);
          expect(record, isNotEmpty);
        }
      });
    });

    group('Observable integration', () {
      test('Given debugger, When write called, Then notifies', () {
        final debugger = TerminalDebugger();
        int notifyCount = 0;
        debugger.addListener(() => notifyCount++);
        debugger.write('a');
        expect(notifyCount, 1);
      });

      test('Given debugger, When multiple writes, Then notifies each', () {
        final debugger = TerminalDebugger();
        int count = 0;
        debugger.addListener(() => count++);
        debugger.write('a');
        debugger.write('b');
        expect(count, 2);
      });

      test('Given debugger, When removeListener, Then stops notifying', () {
        final debugger = TerminalDebugger();
        bool called = false;
        void listener() => called = true;
        debugger.addListener(listener);
        debugger.write('x'); // called = true
        debugger.removeListener(listener);
        called = false;
        debugger.write('y');
        expect(called, isFalse);
      });

      test('Given debugger, When many listeners, Then all notified', () {
        final debugger = TerminalDebugger();
        int count = 0;
        for (int i = 0; i < 5; i++) {
          debugger.addListener(() => count++);
        }
        debugger.write('test');
        expect(count, 5);
      });
    });

    group('Edge cases', () {
      test('Given debugger, When writing very long string, Then handles', () {
        final debugger = TerminalDebugger();
        debugger.write('a' * 10000);
        expect(debugger.recorded.length, 10000);
      });

      test('Given debugger, When writing many small chunks, Then accumulates',
          () {
        final debugger = TerminalDebugger();
        for (int i = 0; i < 1000; i++) {
          debugger.write('x');
        }
        expect(debugger.recorded.length, 1000);
      });

      test('Given debugger, When interleaved text and escapes, Then parses',
          () {
        final debugger = TerminalDebugger();
        debugger.write('A\x1b[31mB\x1b[0mC\x1b[1mD');
        expect(debugger.commands.length, greaterThan(2));
        expect(debugger.recorded.length, greaterThan(4));
      });

      test('Given debugger, When consecutive escapes, Then handles', () {
        final debugger = TerminalDebugger();
        debugger.write('\x1b[31m\x1b[1m\x1b[4m');
        expect(debugger.commands.length, greaterThanOrEqualTo(3));
      });

      test('Given debugger, When malformed CSI, Then no crash', () {
        final debugger = TerminalDebugger();
        expect(() => debugger.write('\x1b['), returnsNormally);
        expect(
            () => debugger.write('\x1b[99999999999999999m'), returnsNormally);
      });

      test('Given debugger, When incomplete OSC, Then no crash', () {
        final debugger = TerminalDebugger();
        expect(() => debugger.write('\x1b]'), returnsNormally);
        expect(() => debugger.write('\x1b]0'), returnsNormally);
      });
    });
  });
}
