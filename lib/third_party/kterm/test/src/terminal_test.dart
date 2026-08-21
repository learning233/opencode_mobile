import 'dart:async';

import 'package:test/test.dart';
import 'package:kterm/core.dart';

void main() {
  group('Terminal.inputHandler', () {
    test('can be set to null', () {
      final terminal = Terminal(inputHandler: null);
      expect(() => terminal.keyInput(TerminalKey.keyA), returnsNormally);
    });

    test('can be changed', () {
      final handler1 = _TestInputHandler();
      final handler2 = _TestInputHandler();
      final terminal = Terminal(inputHandler: handler1);

      terminal.keyInput(TerminalKey.keyA);
      expect(handler1.events, isNotEmpty);

      terminal.inputHandler = handler2;

      terminal.keyInput(TerminalKey.keyA);
      expect(handler2.events, isNotEmpty);
    });
  });

  group('Terminal.mouseInput', () {
    test('can handle mouse events', () {
      final output = <String>[];

      final terminal = Terminal(onOutput: output.add);

      terminal.mouseInput(
        TerminalMouseButton.left,
        TerminalMouseButtonState.down,
        CellOffset(10, 10),
      );

      expect(output, isEmpty);

      // enable mouse reporting
      terminal.write('\x1b[?1000h');

      terminal.mouseInput(
        TerminalMouseButton.left,
        TerminalMouseButtonState.down,
        CellOffset(10, 10),
      );

      expect(output, ['\x1B[M +,']);
    });
  });

  group('Terminal.reflowEnabled', () {
    test('prevents reflow when set to false', () {
      final terminal = Terminal(reflowEnabled: false);

      terminal.write('Hello World');
      terminal.resize(5, 5);

      expect(terminal.buffer.lines[0].toString(), 'Hello');
      expect(terminal.buffer.lines[1].toString(), isEmpty);
    });

    test('preserves hidden cells when reflow is disabled', () {
      final terminal = Terminal(reflowEnabled: false);

      terminal.write('Hello World');
      terminal.resize(5, 5);
      terminal.resize(20, 5);

      expect(terminal.buffer.lines[0].toString(), 'Hello World');
      expect(terminal.buffer.lines[1].toString(), isEmpty);
    });

    test('can be set at runtime', () {
      final terminal = Terminal(reflowEnabled: true);

      terminal.resize(5, 5);
      terminal.write('Hello World');
      terminal.reflowEnabled = false;
      terminal.resize(20, 5);

      expect(terminal.buffer.lines[0].toString(), 'Hello');
      expect(terminal.buffer.lines[1].toString(), ' Worl');
      expect(terminal.buffer.lines[2].toString(), 'd');
    });
  });

  group('Terminal.mouseInput', () {
    test('applys to the main buffer', () {
      final terminal = Terminal(
        wordSeparators: {
          'z'.codeUnitAt(0),
        },
      );

      expect(
        terminal.mainBuffer.wordSeparators,
        contains('z'.codeUnitAt(0)),
      );
    });

    test('applys to the alternate buffer', () {
      final terminal = Terminal(
        wordSeparators: {
          'z'.codeUnitAt(0),
        },
      );

      expect(
        terminal.altBuffer.wordSeparators,
        contains('z'.codeUnitAt(0)),
      );
    });
  });

  group('Terminal.onPrivateOSC', () {
    test(r'works with \a end', () {
      String? lastCode;
      List<String>? lastData;

      final terminal = Terminal(
        onPrivateOSC: (String code, List<String> data) {
          lastCode = code;
          lastData = data;
        },
      );

      terminal.write('\x1b]6\x07');

      expect(lastCode, '6');
      expect(lastData, []);

      terminal.write('\x1b]66;hello world\x07');

      expect(lastCode, '66');
      expect(lastData, ['hello world']);

      terminal.write('\x1b]666;hello;world\x07');

      expect(lastCode, '666');
      expect(lastData, ['hello', 'world']);

      terminal.write('\x1b]hello;world\x07');

      expect(lastCode, 'hello');
      expect(lastData, ['world']);
    });

    test(r'works with \x1b\ end', () {
      String? lastCode;
      List<String>? lastData;

      final terminal = Terminal(
        onPrivateOSC: (String code, List<String> data) {
          lastCode = code;
          lastData = data;
        },
      );

      terminal.write('\x1b]6\x1b\\');

      expect(lastCode, '6');
      expect(lastData, []);

      terminal.write('\x1b]66;hello world\x1b\\');

      expect(lastCode, '66');
      expect(lastData, ['hello world']);

      terminal.write('\x1b]666;hello;world\x1b\\');

      expect(lastCode, '666');
      expect(lastData, ['hello', 'world']);

      terminal.write('\x1b]hello;world\x1b\\');

      expect(lastCode, 'hello');
      expect(lastData, ['world']);
    });

    test('do not receive common osc', () {
      String? lastCode;
      List<String>? lastData;

      final terminal = Terminal(
        onPrivateOSC: (String code, List<String> data) {
          lastCode = code;
          lastData = data;
        },
      );

      terminal.write('\x1b]0;hello world\x07');

      expect(lastCode, isNull);
      expect(lastData, isNull);
    });
  });

  group('Terminal.write buffer integrity', () {
    /// Terminal.write() is synchronous: buffer is always correct immediately.
    /// This is the key invariant that the PTY ackRead flow-control fix relies on.
    ///
    /// Bug: with ackRead=true in flutter_pty, the C read thread blocks on
    /// pthread_mutex until Dart calls ackRead(). If Dart's event loop is busy
    /// (e.g. many rapid chunks), ackRead() is delayed, blocking the PTY read.
    /// Without microtask(), terminal.write() completes but ackRead() is stuck
    /// behind other microtasks → PTY read thread is blocked longer than needed.
    ///
    /// With microtask(), terminal.write() is synchronous (buffer always correct),
    /// and ackRead() fires as the next microtask, quickly unblocking the PTY
    /// read thread so the next chunk arrives promptly.
    ///
    /// These tests verify the buffer-invariants that make the fix safe.

    test('buffer order preserved with 300ms delayed ackRead (broken pattern)',
        () async {
      final terminal = Terminal();

      final chunks = [
        'redis-cli -h 10.128.0.125 hlen MAIL_TYPE\n',
        '206\n',
        "Warning: Using a password with '-a'\n",
      ];

      for (final chunk in chunks) {
        terminal.write(chunk);
        // Simulate 300ms delay before ackRead() fires (slow event loop / high
        // RTT). Buffer should still be correct because write() is synchronous.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      final bufferText = terminal.buffer.getText();
      expect(bufferText, contains('10.128.0.125'));
      expect(bufferText, contains('206'));
      expect(bufferText, contains("Warning: Using a password"));

      // Verify order
      final p1 = bufferText.indexOf('10.128.0.125');
      final p2 = bufferText.indexOf('206');
      final p3 = bufferText.indexOf('Warning');
      expect(p1, lessThan(p2));
      expect(p2, lessThan(p3));
    });

    test('buffer order preserved with 100ms rapid delayed ackRead (100 chunks)',
        () async {
      final terminal = Terminal();

      for (var i = 0; i < 100; i++) {
        terminal.write('line$i\n');
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final bufferText = terminal.buffer.getText();
      for (var i = 0; i < 100; i++) {
        expect(bufferText, contains('line$i'));
      }

      for (var i = 0; i < 99; i++) {
        final posI = bufferText.indexOf('line$i\n');
        final posI1 = bufferText.indexOf('line${i + 1}\n');
        expect(posI, lessThan(posI1),
            reason: 'line$i should appear before line${i + 1}');
      }
    });

    test(
        'buffer order preserved with microtask-deferred ackRead (correct '
        'pattern)', () async {
      final terminal = Terminal();

      final chunks = [
        'command1\n',
        'output1\n',
        'command2\n',
        'output2\n',
      ];

      for (final chunk in chunks) {
        terminal.write(chunk);
        // Correct pattern: schedule ackRead as next microtask (non-blocking)
        Future.microtask(() {});
      }

      // Drain microtasks
      await Future<void>.delayed(Duration.zero);

      final bufferText = terminal.buffer.getText();
      expect(bufferText, contains('command1'));
      expect(bufferText, contains('output1'));
      expect(bufferText, contains('command2'));
      expect(bufferText, contains('output2'));

      final cmd1 = bufferText.indexOf('command1');
      final out1 = bufferText.indexOf('output1');
      final cmd2 = bufferText.indexOf('command2');
      final out2 = bufferText.indexOf('output2');
      expect(cmd1, lessThan(out1));
      expect(out1, lessThan(cmd2));
      expect(cmd2, lessThan(out2));
    });
  });
}

class _TestInputHandler implements TerminalInputHandler {
  final events = <TerminalKeyboardEvent>[];

  @override
  String? call(TerminalKeyboardEvent event) {
    events.add(event);
    return null;
  }
}
