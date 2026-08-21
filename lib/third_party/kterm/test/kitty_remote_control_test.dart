import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('Remote Control DCS Tests', () {
    test('DCS +q terminal name query triggers response', () {
      final terminal = Terminal();
      final outputs = <String>[];

      terminal.onOutput = (data) => outputs.add(data);

      // DCS +qTN - query terminal name
      terminal.write('\x1bP+q544e\x1b\\');

      // Should respond with terminal name
      expect(outputs.isNotEmpty, isTrue);
      expect(outputs.first, contains('kterm'));
    });

    test('DCS +q clipboard query triggers response', () {
      final terminal = Terminal();
      final outputs = <String>[];

      terminal.onOutput = (data) => outputs.add(data);

      // DCS +q636c - query clipboard
      terminal.write('\x1bP+q636c\x1b\\');

      // Should have response (even if empty)
      expect(outputs.isNotEmpty, isTrue);
    });

    test('DCS +q version query triggers response', () {
      final terminal = Terminal();
      final outputs = <String>[];

      terminal.onOutput = (data) => outputs.add(data);

      // DCS +q5643 - query version
      terminal.write('\x1bP+q5643\x1b\\');

      expect(outputs.isNotEmpty, isTrue);
    });

    test('DCS +q list supported queries', () {
      final terminal = Terminal();
      final outputs = <String>[];

      terminal.onOutput = (data) => outputs.add(data);

      // DCS +q? - list supported queries
      terminal.write('\x1bP+q3f\x1b\\');

      expect(outputs.isNotEmpty, isTrue);
    });
  });
}
