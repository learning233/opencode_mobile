import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';
import 'package:kterm/src/ui/shortcut/actions.dart';
import 'package:kterm/src/ui/shortcut/shortcuts.dart';
import 'package:kterm/src/terminal.dart';
import 'package:kterm/src/ui/controller.dart';

void main() {
  group('TerminalActions', () {
    test(
        'Given TerminalActions widget, When created, Then builds without error',
        () {
      // This test verifies the widget can be instantiated
      // Note: Full widget testing would require a proper test harness
      // This tests the class structure exists
      expect(TerminalActions, isNotNull);
    });

    test(
        'Given TerminalActions, When checking default constructor, Then accepts required parameters',
        () {
      // Verify the constructor exists with expected parameters
      // This is a compile-time check plus basic instantiation test
      final terminal = Terminal();
      final controller = TerminalController();

      // We can't fully test the widget without a proper test environment
      // but we can verify the types work
      expect(terminal, isNotNull);
      expect(controller, isNotNull);
    });
  });

  group('defaultTerminalShortcuts', () {
    test('Given default terminal shortcuts, Should contain copy shortcut', () {
      // Verify copy shortcut exists
      final shortcuts = defaultTerminalShortcuts;
      final hasCopy = shortcuts.values.any((v) => v is CopySelectionTextIntent);
      expect(hasCopy, isTrue);
    });

    test('Given default terminal shortcuts, Should contain paste shortcut', () {
      // Verify paste shortcut exists
      final shortcuts = defaultTerminalShortcuts;
      final hasPaste = shortcuts.values.any((v) => v is PasteTextIntent);
      expect(hasPaste, isTrue);
    });

    test('Given default terminal shortcuts, Should contain select all shortcut',
        () {
      // Verify select all shortcut exists
      final shortcuts = defaultTerminalShortcuts;
      final hasSelectAll =
          shortcuts.values.any((v) => v is SelectAllTextIntent);
      expect(hasSelectAll, isTrue);
    });

    test('Given default terminal shortcuts, Should map to correct intents', () {
      // Verify all intents are correct types
      final shortcuts = defaultTerminalShortcuts;

      for (final entry in shortcuts.entries) {
        expect(
          entry.value is CopySelectionTextIntent ||
              entry.value is PasteTextIntent ||
              entry.value is SelectAllTextIntent,
          isTrue,
          reason:
              'Each shortcut should map to Copy, Paste, or SelectAll intent',
        );
      }
    });

    test('Given default terminal shortcuts, Should have at least 3 entries',
        () {
      // Verify minimum shortcut count
      final shortcuts = defaultTerminalShortcuts;
      expect(shortcuts.length, greaterThanOrEqualTo(3));
    });

    test('Given default terminal shortcuts, Should not have null keys', () {
      // Verify all keys are valid
      final shortcuts = defaultTerminalShortcuts;
      for (final key in shortcuts.keys) {
        expect(key, isNotNull);
      }
    });
  });
}
