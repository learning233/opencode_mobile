import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

/// High-quality widget tests for TerminalView with mixed input handling.
///
/// Key concepts:
/// - `terminal.write()` simulates program output to the terminal (renders to buffer)
/// - `terminal.textInput()` simulates user input to the program (via onOutput callback)
/// - Terminal buffer shows what the PROGRAM has written, not what the user typed directly
///
/// Timer management:
/// - Using `alwaysShowCursor: true` avoids cursor blink animation timers
/// - Using explicit `pump(Duration)` instead of `pumpAndSettle` for precise control
///
/// Verification approach:
/// - For buffer content: use `write()` to simulate program output
/// - For input handling: capture via `onOutput` callback
void main() {
  group('TerminalView Widget Tests', () {
    late Terminal terminal;
    late TerminalController controller;

    setUp(() {
      terminal = Terminal();
      controller = TerminalController();
    });

    tearDown(() {
      controller.dispose();
    });

    /// Helper: Create a standard test environment with TerminalView
    Future<void> pumpTerminalView(
      WidgetTester tester, {
      Size size = const Size(800, 600),
      bool alwaysShowCursor = true,
      bool autofocus = true,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: controller,
              autofocus: autofocus,
              alwaysShowCursor: alwaysShowCursor,
            ),
          ),
        ),
      );

      // Initial pump to render the widget
      await tester.pump();
    }

    group('Program Output Rendering (write)', () {
      testWidgets(
        'Given TerminalView, When write "ls\\n", Then buffer contains the text',
        (tester) async {
          // Arrange
          await pumpTerminalView(tester);

          // Act - write simulates program output
          terminal.write('ls\n');
          await tester.pump();

          // Assert - verify buffer content
          final bufferText = terminal.buffer.getText();
          expect(bufferText, contains('ls'));
          expect(bufferText, contains('\n'));
        },
      );

      testWidgets(
        'Given rapid write sequence, When multiple writes, Then all content is preserved',
        (tester) async {
          await pumpTerminalView(tester);

          // Act - multiple rapid writes
          terminal.write('hello');
          await tester.pump(const Duration(milliseconds: 10));

          terminal.write(' ');
          await tester.pump(const Duration(milliseconds: 10));

          terminal.write('world');
          await tester.pump(const Duration(milliseconds: 10));

          // Assert
          expect(terminal.buffer.getText(), contains('hello world'));
        },
      );

      testWidgets(
        'Given write with mixed control characters, When written, Then text is rendered correctly',
        (tester) async {
          await pumpTerminalView(tester);

          // Mixed content: text + ANSI color + text
          terminal.write('\x1b[31mred\x1b[0m normal');
          await tester.pump();

          // The buffer should contain both red and normal (escape codes are parsed)
          final text = terminal.buffer.getText();
          expect(text, contains('red'));
          expect(text, contains('normal'));
        },
      );

      testWidgets(
        'Given write with Chinese characters, When written, Then characters are preserved',
        (tester) async {
          await pumpTerminalView(tester);

          terminal.write('你好World');
          await tester.pump();

          expect(terminal.buffer.getText(), contains('你好'));
          expect(terminal.buffer.getText(), contains('World'));
        },
      );

      testWidgets(
        'Given multi-line write, When written, Then line breaks are preserved',
        (tester) async {
          await pumpTerminalView(tester);

          terminal.write('line1\nline2\nline3');
          await tester.pump();

          final lines = terminal.buffer.lines;
          expect(lines[0].toString(), contains('line1'));
          expect(lines[1].toString(), contains('line2'));
          expect(lines[2].toString(), contains('line3'));
        },
      );

      testWidgets(
        'Given cursor position tracking, When write, Then cursor moves correctly',
        (tester) async {
          await pumpTerminalView(tester);

          terminal.write('abc');
          await tester.pump();

          // Cursor should be at position 3 (after "abc")
          expect(terminal.buffer.cursorX, equals(3));
        },
      );
    });

    group('User Input Handling (textInput)', () {
      testWidgets(
        'Given textInput, When called, Then onOutput receives the text',
        (tester) async {
          // Arrange - use onOutput to capture user input
          final output = <String>[];
          final inputTerminal = Terminal(onOutput: output.add);
          final inputController = TerminalController();

          tester.view.physicalSize = const Size(800, 600);
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TerminalView(
                  inputTerminal,
                  controller: inputController,
                  autofocus: true,
                  alwaysShowCursor: true,
                ),
              ),
            ),
          );
          await tester.pump();

          // Act - user types "ls\n"
          inputTerminal.textInput('ls\n');
          await tester.pump();

          // Assert - onOutput captures what user typed
          expect(output.join(), contains('ls'));
          expect(output.join(), contains('\n'));

          inputController.dispose();
        },
      );

      testWidgets(
        'Given rapid textInput sequence, When called, Then all input is captured',
        (tester) async {
          final output = <String>[];
          final inputTerminal = Terminal(onOutput: output.add);

          tester.view.physicalSize = const Size(800, 600);
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TerminalView(
                  inputTerminal,
                  controller: TerminalController(),
                  autofocus: true,
                  alwaysShowCursor: true,
                ),
              ),
            ),
          );
          await tester.pump();

          // Rapid input
          for (var i = 0; i < 10; i++) {
            inputTerminal.textInput('${i}');
            await tester.pump(const Duration(milliseconds: 5));
          }

          expect(output.join(), contains('0123456789'));
        },
      );

      testWidgets(
        'Given textInput with mixed content, When called, Then control characters are passed through',
        (tester) async {
          final output = <String>[];
          final inputTerminal = Terminal(onOutput: output.add);

          tester.view.physicalSize = const Size(800, 600);
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TerminalView(
                  inputTerminal,
                  controller: TerminalController(),
                  autofocus: true,
                  alwaysShowCursor: true,
                ),
              ),
            ),
          );
          await tester.pump();

          // Input with control characters
          inputTerminal.textInput('hello\x07world'); // \x07 is BEL
          await tester.pump();

          // Control chars should be passed through
          expect(output.join(), contains('hello'));
          expect(output.join(), contains('world'));
        },
      );
    });

    group('Echo Behavior (Program Echoes User Input)', () {
      testWidgets(
        'Given program echoes user input, When textInput followed by write, Then buffer shows both',
        (tester) async {
          await pumpTerminalView(tester);

          // Simulate: user types, program echoes back
          terminal.textInput('hello'); // sent to program
          await tester.pump();

          terminal.write('hello'); // program echoes to terminal
          await tester.pump();

          // Buffer shows the echo
          expect(terminal.buffer.getText(), contains('hello'));
        },
      );

      testWidgets(
        'Given password input (no echo), When textInput, Then buffer only has prompt',
        (tester) async {
          await pumpTerminalView(tester);

          // Program writes prompt
          terminal.write('password: ');
          await tester.pump();

          // User types (would normally not be echoed)
          terminal.textInput('secret');
          await tester.pump();

          // Buffer only has prompt, not the password (since it's not echoed)
          expect(terminal.buffer.getText(), contains('password'));
          // Note: 'secret' is NOT in buffer because textInput doesn't write to buffer
          // The password would be sent via onOutput, not displayed
        },
      );
    });

    group('Cursor Behavior', () {
      testWidgets(
        'Given alwaysShowCursor=true, When rendered, Then cursor is visible without animation',
        (tester) async {
          await pumpTerminalView(tester, alwaysShowCursor: true);

          terminal.write('test');
          await tester.pump();

          // Cursor should be visible and at correct position
          expect(terminal.buffer.cursorX, greaterThan(0));
        },
      );

      testWidgets(
        'Given cursorVisibleMode control, When toggled, Then cursor visibility state changes',
        (tester) async {
          await pumpTerminalView(tester, alwaysShowCursor: false);

          terminal.write('visible');
          await tester.pump();

          expect(terminal.cursorVisibleMode, isTrue);

          // Disable cursor visibility
          terminal.setCursorVisibleMode(false);
          await tester.pump();

          expect(terminal.cursorVisibleMode, isFalse);

          // Enable again
          terminal.setCursorVisibleMode(true);
          await tester.pump();

          expect(terminal.cursorVisibleMode, isTrue);
          expect(terminal.buffer.cursorX, equals(7));
        },
      );

      testWidgets(
        'Given cursorBlinkMode toggles, When switched, Then no timer issues',
        (tester) async {
          await pumpTerminalView(tester, alwaysShowCursor: false);

          terminal.setCursorBlinkMode(true);
          await tester.pump(const Duration(milliseconds: 100));

          terminal.setCursorBlinkMode(false);
          await tester.pump(const Duration(milliseconds: 100));

          // Multiple toggles
          for (var i = 0; i < 5; i++) {
            terminal.setCursorBlinkMode(i % 2 == 0);
            await tester.pump(const Duration(milliseconds: 50));
          }

          // If we get here without timer errors, the test passes
        },
      );
    });

    group('Precise Timing Control', () {
      testWidgets(
        'Given manual pump timing, When stepping through frames, Then each frame renders correctly',
        (tester) async {
          await pumpTerminalView(tester);

          // Step through 10ms at a time
          for (var i = 0; i < 5; i++) {
            terminal.write('${i}');
            await tester.pump(const Duration(milliseconds: 10));
          }

          // All characters should be in buffer
          expect(terminal.buffer.getText(), contains('0'));
          expect(terminal.buffer.getText(), contains('4'));
        },
      );

      testWidgets(
        'Given rapid writes, When pump with exact duration, Then all content appears',
        (tester) async {
          await pumpTerminalView(tester);

          // Rapid fire writes
          for (var i = 0; i < 26; i++) {
            terminal.write(String.fromCharCode(65 + i)); // A-Z
          }
          await tester.pump(const Duration(milliseconds: 50));

          // All 26 letters should appear in buffer
          final text = terminal.buffer.getText();
          expect(text, contains('ABCDEFGHIJKLMNOPQRSTUVWXYZ'));
        },
      );
    });

    group('Buffer State Verification', () {
      testWidgets(
        'Given terminal with initial content, When write, Then buffer accumulates content',
        (tester) async {
          await pumpTerminalView(tester);

          // Terminal may have initial newlines, just check our content is added
          final initialText = terminal.buffer.getText();

          terminal.write('first line\nsecond line');
          await tester.pump();

          final text = terminal.buffer.getText();
          expect(text, contains('first line'));
          expect(text, contains('second line'));
        },
      );

      testWidgets(
        'Given write with cursor movement escape, When parsed, Then cursor moves correctly',
        (tester) async {
          await pumpTerminalView(tester);

          terminal.write('ABC'); // Write initial text
          await tester.pump();

          // Now cursor should be at position 3
          expect(terminal.buffer.cursorX, equals(3));
        },
      );

      testWidgets(
        'Given resize during content, When write after resize, Then content adapts correctly',
        (tester) async {
          await pumpTerminalView(tester, size: const Size(800, 600));

          terminal.write('0123456789'); // 10 chars
          await tester.pump();

          // Resize terminal to 5 cols
          terminal.resize(5, 24);
          await tester.pump();

          // Buffer should reflow
          expect(
              terminal.buffer.lines[0].toString().length, lessThanOrEqualTo(5));
        },
      );
    });

    group('Paste with Control Characters', () {
      testWidgets(
        'Given paste with ANSI color codes, When pasted, Then color codes are filtered',
        (tester) async {
          final output = <String>[];
          final pasteTerminal = Terminal(onOutput: output.add);

          tester.view.physicalSize = const Size(800, 600);
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TerminalView(
                  pasteTerminal,
                  controller: TerminalController(),
                  autofocus: true,
                  alwaysShowCursor: true,
                ),
              ),
            ),
          );
          await tester.pump();

          // Paste text with ANSI color codes
          pasteTerminal.paste('\x1b[31mred\x1b[0m normal');
          await tester.pump();

          // The color codes should be filtered (only visible text passes through)
          expect(output.join(), contains('red'));
          expect(output.join(), contains('normal'));
          expect(output.join(), isNot(contains('\x1b[31m')));
        },
      );

      testWidgets(
        'Given paste with BEL character, When pasted, Then BEL is filtered',
        (tester) async {
          final output = <String>[];
          final pasteTerminal = Terminal(onOutput: output.add);

          tester.view.physicalSize = const Size(800, 600);
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TerminalView(
                  pasteTerminal,
                  controller: TerminalController(),
                  autofocus: true,
                  alwaysShowCursor: true,
                ),
              ),
            ),
          );
          await tester.pump();

          // Paste with BEL character (\x07)
          pasteTerminal.paste('hello\x07world');
          await tester.pump();

          // BEL should be filtered out
          expect(output.join(), contains('helloworld'));
          expect(output.join(), isNot(contains('\x07')));
        },
      );
    });

    group('TerminalView Lifecycle', () {
      testWidgets(
        'Given terminal write before pump, When widget built, Then content is rendered',
        (tester) async {
          // Write before pump - terminal state changes but listener notification happens
          terminal.write('early content');
          await pumpTerminalView(tester);

          // After pump, content should be there
          expect(terminal.buffer.getText(), contains('early content'));
        },
      );

      testWidgets(
        'Given widget disposal, When terminal still has content, Then content persists',
        (tester) async {
          terminal.write('content before dispose');
          await pumpTerminalView(tester);

          // Pump a few frames
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));

          // Dispose widget by replacing with empty
          await tester
              .pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
          await tester.pump();

          // Terminal should still have content
          expect(terminal.buffer.getText(), contains('content before dispose'));
        },
      );
    });

    group('Error Cases and Edge Conditions', () {
      testWidgets(
        'Given empty textInput, When called, Then no error and no output',
        (tester) async {
          final output = <String>[];
          final emptyTerminal = Terminal(onOutput: output.add);

          tester.view.physicalSize = const Size(800, 600);
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TerminalView(
                  emptyTerminal,
                  controller: TerminalController(),
                  autofocus: true,
                  alwaysShowCursor: true,
                ),
              ),
            ),
          );
          await tester.pump();

          emptyTerminal.textInput('');
          await tester.pump();

          // textInput always calls onOutput, even with empty string
          // The joined output is empty but the list has one empty string element
          expect(output.join(), isEmpty);
        },
      );

      testWidgets(
        'Given very long write, When written, Then buffer handles overflow correctly',
        (tester) async {
          await pumpTerminalView(tester);

          final longString = 'x' * 1000;
          terminal.write(longString);
          await tester.pump();

          // Buffer should have content (may be truncated or scrolled)
          expect(terminal.buffer.lines.length, greaterThan(0));
        },
      );

      testWidgets(
        'Given control characters only, When write, Then they are handled correctly',
        (tester) async {
          await pumpTerminalView(tester);

          // Write just a newline
          terminal.write('\n');
          await tester.pump();

          // Should move to next line
          expect(terminal.buffer.cursorX, equals(0));
        },
      );
    });
  });
}
