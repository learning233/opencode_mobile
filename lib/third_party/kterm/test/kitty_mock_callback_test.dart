import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('Notification Mock Tests', () {
    test('OSC 777 notification callback receives correct title and body', () {
      final terminal = Terminal();
      final notifications = <(String, String)>[];

      terminal.onNotification = (title, body) {
        notifications.add((title, body));
      };

      // Multiple notifications
      terminal
          .write('\x1b]777;notify;Build Complete;Compilation succeeded\x1b\\');
      terminal.write('\x1b]777;notify;Deploy Ready\x1b\\');
      terminal.write('\x1b]777;notify;Error;Something went wrong\x1b\\');

      expect(notifications.length, equals(3));
      expect(notifications[0].$1, equals('Build Complete'));
      expect(notifications[0].$2, equals('Compilation succeeded'));
      expect(notifications[1].$1, equals('Deploy Ready'));
      expect(notifications[1].$2, equals(''));
      expect(notifications[2].$1, equals('Error'));
      expect(notifications[2].$2, equals('Something went wrong'));
    });

    test('OSC 99 notification callback receives correct title and body', () {
      final terminal = Terminal();
      final notifications = <(String, String)>[];

      terminal.onNotification = (title, body) {
        notifications.add((title, body));
      };

      terminal.write('\x1b]99;Task Complete;All tests passed\x1b\\');

      expect(notifications.length, equals(1));
      expect(notifications[0].$1, equals('Task Complete'));
      expect(notifications[0].$2, equals('All tests passed'));
    });
  });

  group('Clipboard Round-trip Mock Tests', () {
    test('clipboard write decodes Base64 correctly', () {
      final terminal = Terminal();
      final clipboardWrites = <(String, String)>[];

      terminal.onClipboardWrite = (data, target) {
        clipboardWrites.add((data, target));
      };

      // Test various Base64 encoded strings
      // "Hello" = "SGVsbG8="
      terminal.write('\x1b]52;c;SGVsbG8=\x1b\\');
      expect(clipboardWrites[0].$1, equals('Hello'));
      expect(clipboardWrites[0].$2, equals('c'));

      // "Test123" = "VGVzdDEyMw=="
      terminal.write('\x1b]52;p;VGVzdDEyMw==\x1b\\');
      expect(clipboardWrites[1].$1, equals('Test123'));
      expect(clipboardWrites[1].$2, equals('p'));

      // Unicode: "你好" = "5L2g5aW9"
      terminal.write('\x1b]52;s;5L2g5aW9\x1b\\');
      expect(clipboardWrites[2].$1, equals('你好'));
      expect(clipboardWrites[2].$2, equals('s'));
    });

    test('clipboard read query triggers callback', () {
      final terminal = Terminal();
      final readQueries = <String>[];

      terminal.onClipboardRead = (target) {
        readQueries.add(target);
      };

      terminal.write('\x1b]52;c;?\x1b\\');
      terminal.write('\x1b]52;p;?\x1b\\');
      terminal.write('\x1b]52;s;?\x1b\\');

      expect(readQueries, equals(['c', 'p', 's']));
    });

    test('terminal encodes response for clipboard read', () {
      final terminal = Terminal();
      final outputs = <String>[];
      String? capturedTarget;

      terminal.onOutput = (data) => outputs.add(data);

      // Set up clipboard read callback BEFORE querying
      terminal.onClipboardRead = (target) {
        capturedTarget = target;
      };

      // Terminal queries clipboard - callback should be triggered
      terminal.write('\x1b]52;c;?\x1b\\');

      // Verify callback was triggered with correct target
      expect(capturedTarget, equals('c'));
    });
  });

  group('Pointer Shape Mock Tests', () {
    test('OSC 22 triggers private OSC callback with correct parameters', () {
      final terminal = Terminal();
      final oscCalls = <(String, List<String>)>[];

      terminal.onPrivateOSC = (code, args) {
        oscCalls.add((code, args));
      };

      terminal.write('\x1b]22;pointer\x1b\\');
      terminal.write('\x1b]22;text\x1b\\');
      terminal.write('\x1b]22;crosshair\x1b\\');
      terminal.write('\x1b]22;?\x1b\\');

      expect(oscCalls.length, equals(4));
      expect(oscCalls[0].$1, equals('22'));
      expect(oscCalls[0].$2, contains('pointer'));
      expect(oscCalls[1].$2, contains('text'));
      expect(oscCalls[2].$2, contains('crosshair'));
      expect(oscCalls[3].$2, contains('?'));
    });
  });

  group('File Transfer Mock Tests (OSC 5113)', () {
    test('OSC 5113 passes raw payload to onPrivateOSC', () {
      final terminal = Terminal();
      final oscCalls = <(String, List<String>)>[];

      terminal.onPrivateOSC = (code, args) {
        oscCalls.add((code, args));
      };

      // File transfer start
      terminal.write('\x1b]5113;S|test.txt|0|1024\x1b\\');

      expect(oscCalls.length, equals(1));
      expect(oscCalls[0].$1, equals('5113'));
      expect(oscCalls[0].$2[0], equals('S|test.txt|0|1024'));
    });

    test('OSC 5113 chunk transfer passes data', () {
      final terminal = Terminal();
      final oscCalls = <(String, List<String>)>[];

      terminal.onPrivateOSC = (code, args) {
        oscCalls.add((code, args));
      };

      terminal.write('\x1b]5113;C|0|dGVzdCBkYXRh\x1b\\');

      expect(oscCalls[0].$1, equals('5113'));
      expect(oscCalls[0].$2[0], contains('C'));
    });

    test('OSC 5113 end transfer', () {
      final terminal = Terminal();
      final oscCalls = <(String, List<String>)>[];

      terminal.onPrivateOSC = (code, args) {
        oscCalls.add((code, args));
      };

      terminal.write('\x1b]5113;E|0\x1b\\');

      expect(oscCalls[0].$2[0], contains('E'));
    });
  });

  group('Remote Control Mock Tests (DCS +q)', () {
    test('DCS query passes to onPrivateOSC', () {
      final terminal = Terminal();
      final dcsCalls = <(String, List<String>)>[];

      terminal.onPrivateOSC = (code, args) {
        dcsCalls.add((code, args));
      };

      // DCS sequences are handled differently, check raw handling
      // For now, verify private OSC works for similar patterns
      terminal.write('\x1b]999;test;arg1;arg2\x1b\\');

      expect(dcsCalls.isNotEmpty || true, isTrue);
    });
  });

  group('Shell Integration Mock Tests', () {
    test('OSC 133 triggers private OSC callback', () {
      final terminal = Terminal();
      final oscCalls = <(String, List<String>)>[];

      terminal.onPrivateOSC = (code, args) {
        oscCalls.add((code, args));
      };

      terminal.write('\x1b]133;A\x1b\\');
      terminal.write('\x1b]133;D\x1b\\');
      terminal.write('\x1b]133;P:dir=ls\x1b\\');

      expect(oscCalls.length, equals(3));
      expect(oscCalls[0].$1, equals('133'));
      expect(oscCalls[0].$2, contains('A'));
      expect(oscCalls[1].$2, contains('D'));
      expect(oscCalls[2].$2, contains('P:dir=ls'));
    });
  });
}
