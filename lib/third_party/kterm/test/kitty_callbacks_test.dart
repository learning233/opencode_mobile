import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('OSC 777 Notifications', () {
    test('onNotification callback triggered with title and body', () {
      final terminal = Terminal();
      String? receivedTitle;
      String? receivedBody;

      terminal.onNotification = (title, body) {
        receivedTitle = title;
        receivedBody = body;
      };

      // OSC 777;notify;TestTitle;TestBody
      terminal.write('\x1b]777;notify;TestTitle;TestBody\x1b\\');

      expect(receivedTitle, equals('TestTitle'));
      expect(receivedBody, equals('TestBody'));
    });

    test('onNotification callback triggered with only title', () {
      final terminal = Terminal();
      String? receivedTitle;
      String? receivedBody;

      terminal.onNotification = (title, body) {
        receivedTitle = title;
        receivedBody = body;
      };

      terminal.write('\x1b]777;notify;BuildComplete\x1b\\');

      expect(receivedTitle, equals('BuildComplete'));
      expect(receivedBody, equals(''));
    });
  });

  group('OSC 52 Clipboard', () {
    test('onClipboardWrite callback triggered with decoded data', () {
      final terminal = Terminal();
      String? receivedData;
      String? receivedTarget;

      terminal.onClipboardWrite = (data, target) {
        receivedData = data;
        receivedTarget = target;
      };

      // OSC 52 ; c ; base64("hello world") = aGVsbG8gd29ybGQ=
      terminal.write('\x1b]52;c;aGVsbG8gd29ybGQ=\x1b\\');

      expect(receivedData, equals('hello world'));
      expect(receivedTarget, equals('c'));
    });

    test('onClipboardWrite callback with different target', () {
      final terminal = Terminal();
      String? receivedTarget;

      terminal.onClipboardWrite = (data, target) {
        receivedTarget = target;
      };

      // OSC 52 ; p ; base64("primary")
      terminal.write('\x1b]52;p;cHJpbWFyeQ==\x1b\\');

      expect(receivedTarget, equals('p'));
    });

    test('onClipboardRead callback triggered on query', () {
      final terminal = Terminal();
      String? receivedTarget;

      terminal.onClipboardRead = (target) {
        receivedTarget = target;
      };

      // OSC 52 ; c ; ? - query clipboard
      terminal.write('\x1b]52;c;?\x1b\\');

      expect(receivedTarget, equals('c'));
    });
  });

  group('OSC 52 Clipboard Round-trip', () {
    test('callback can trigger terminal write for response', () {
      final terminal = Terminal();
      final outputs = <String>[];

      terminal.onOutput = (data) => outputs.add(data);

      // When terminal queries clipboard, app provides data via terminal.write
      terminal.write('\x1b]52;c;?\x1b\\');

      // The callback should have been triggered
      // (in real usage, app would call terminal.write with response)
      // Just verify no crash and sequence is parsed
      expect(outputs.isEmpty, isTrue); // No auto-response, app handles it
    });
  });

  group('OSC 22 Pointer Shapes', () {
    test('pointer shape change triggers callback via onPrivateOSC', () {
      final terminal = Terminal();
      String? receivedCode;
      List<String>? receivedArgs;

      terminal.onPrivateOSC = (code, args) {
        receivedCode = code;
        receivedArgs = args;
      };

      // OSC 22;pointer - set pointer shape
      terminal.write('\x1b]22;pointer\x1b\\');

      // Should trigger private OSC callback
      expect(receivedCode, equals('22'));
      expect(receivedArgs, contains('pointer'));
    });
  });

  group('OSC 99 Desktop Notifications', () {
    test('OSC 99 triggers onNotification callback', () {
      final terminal = Terminal();
      String? receivedTitle;
      String? receivedBody;

      terminal.onNotification = (title, body) {
        receivedTitle = title;
        receivedBody = body;
      };

      // OSC 99;title;body
      terminal.write('\x1b]99;Task Complete;Build finished successfully\x1b\\');

      expect(receivedTitle, equals('Task Complete'));
      expect(receivedBody, equals('Build finished successfully'));
    });
  });
}
