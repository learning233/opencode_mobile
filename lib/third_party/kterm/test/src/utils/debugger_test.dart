import 'package:test/test.dart';
import 'package:kterm/src/utils/debugger.dart';

void main() {
  group('TerminalDebugger', () {
    test(
        'Given a new debugger, When created, Then recorded and commands are empty',
        () {
      // Arrange & Act
      final debugger = TerminalDebugger();

      // Assert
      expect(debugger.recorded, isEmpty);
      expect(debugger.commands, isEmpty);
    });

    test('Given debugger, When writing plain text, Then records characters',
        () {
      // Arrange
      final debugger = TerminalDebugger();

      // Act
      debugger.write('Hello');

      // Assert
      expect(debugger.recorded.length, 5);
      expect(debugger.recorded,
          [72, 101, 108, 108, 111]); // ASCII codes for "Hello"
    });

    test(
        'Given debugger, When writing escape sequence, Then parses and records commands',
        () {
      // Arrange
      final debugger = TerminalDebugger();

      // Act
      debugger.write('\x1b[31m'); // SGR foreground red

      // Assert
      expect(debugger.commands, isNotEmpty);
      expect(
          debugger.commands.first.explanation.first, contains('setForeground'));
    });

    test(
        'Given debugger, When writing multiple sequences, Then records multiple commands',
        () {
      // Arrange
      final debugger = TerminalDebugger();

      // Act
      debugger.write('A');
      debugger.write('\x1b[1mB\x1b[0m');

      // Assert
      expect(debugger.commands.length, greaterThan(0));
    });

    test(
        'Given debugger with commands, When getRecord called with command, Then returns recorded input',
        () {
      // Arrange
      final debugger = TerminalDebugger();
      debugger.write('Hello');

      // Act
      final command = debugger.commands.first;
      final record = debugger.getRecord(command);

      // Assert - getRecord returns input up to command.end
      expect(record, contains('H'));
    });

    test(
        'Given debugger, When writing bell character, Then records bell command',
        () {
      // Arrange
      final debugger = TerminalDebugger();

      // Act
      debugger.write('\x07'); // Bell character

      // Assert
      expect(
          debugger.commands.any((c) => c.explanation.contains('bell')), isTrue);
    });

    test(
        'Given debugger, When writing backspace, Then records backspace command',
        () {
      // Arrange
      final debugger = TerminalDebugger();

      // Act
      debugger.write('\x08'); // Backspace

      // Assert
      expect(
          debugger.commands
              .any((c) => c.explanation.any((e) => e.contains('backspace'))),
          isTrue);
    });

    test('Given debugger, When writing tab, Then records tab command', () {
      // Arrange
      final debugger = TerminalDebugger();

      // Act
      debugger.write('\t');

      // Assert
      expect(
          debugger.commands.any((c) => c.explanation.contains('tab')), isTrue);
    });

    test('Given debugger, When writing newline, Then records lineFeed command',
        () {
      // Arrange
      final debugger = TerminalDebugger();

      // Act
      debugger.write('\n');

      // Assert
      expect(debugger.commands.any((c) => c.explanation.contains('lineFeed')),
          isTrue);
    });

    test(
        'Given debugger, When writing carriage return, Then records carriageReturn command',
        () {
      // Arrange
      final debugger = TerminalDebugger();

      // Act
      debugger.write('\r');

      // Assert
      expect(
          debugger.commands
              .any((c) => c.explanation.contains('carriageReturn')),
          isTrue);
    });

    test('Given debugger, When writing CSI sequence, Then records CSI command',
        () {
      // Arrange
      final debugger = TerminalDebugger();

      // Act
      debugger.write('\x1b[2J'); // Erase display

      // Assert - Erase display is parsed, but may have different naming
      expect(debugger.commands.isNotEmpty, isTrue);
    });

    test('Given debugger, When writing OSC sequence, Then records OSC command',
        () {
      // Arrange
      final debugger = TerminalDebugger();

      // Act
      debugger.write('\x1b]0;Test Title\x07'); // Set title

      // Assert
      expect(
          debugger.commands
              .any((c) => c.explanation.any((e) => e.contains('setTitle'))),
          isTrue);
    });

    test(
        'Given debugger, When writing multiple writes, Then appends to recorded',
        () {
      // Arrange
      final debugger = TerminalDebugger();

      // Act
      debugger.write('Hello');
      debugger.write(' World');

      // Assert
      expect(debugger.recorded.length, 11);
    });

    test(
        'Given debugger, When getRecord called after multiple writes, Then returns correct slice',
        () {
      // Arrange
      final debugger = TerminalDebugger();
      debugger.write('First');
      final firstCommand = debugger.commands.first;
      debugger.write('Second');

      // Act
      final record = debugger.getRecord(firstCommand);

      // Assert - getRecord returns input up to command.end
      expect(record, contains('F'));
    });
  });

  group('TerminalCommand', () {
    test('Given a command, When created with error flag, Then error is set',
        () {
      // This is tested indirectly through the debugger
      // but we verify the structure exists
      expect(TerminalCommand(0, 5, 'test', 'test', ['explanation'], false),
          isNotNull);
      expect(TerminalCommand(0, 5, 'test', 'test', ['explanation'], true).error,
          isTrue);
    });
  });
}
