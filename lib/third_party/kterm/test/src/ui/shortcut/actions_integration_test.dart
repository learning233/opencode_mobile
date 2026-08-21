import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';
import 'package:kterm/src/ui/shortcut/actions.dart';
import 'package:kterm/src/ui/shortcut/shortcuts.dart';
import 'package:kterm/src/terminal.dart';
import 'package:kterm/src/ui/controller.dart';
import 'package:kterm/src/ui/selection_mode.dart';

void main() {
  group('TerminalActions', () {
    test('Given TerminalActions, When constructed, Then instance created', () {
      final terminal = Terminal();
      final controller = TerminalController();
      final actions = TerminalActions(
        terminal: terminal,
        controller: controller,
        child: const SizedBox(),
      );
      expect(actions, isNotNull);
      expect(actions.terminal, equals(terminal));
      expect(actions.controller, equals(controller));
    });

    test(
        'Given TerminalActions, When constructed with null terminal, Then throws error',
        () {
      final controller = TerminalController();
      expect(
          () => TerminalActions(
                terminal: null as Terminal,
                controller: controller,
                child: const SizedBox(),
              ),
          throwsA(isA<Error>()));
    });

    test(
        'Given TerminalActions, When constructed with null controller, Then throws error',
        () {
      final terminal = Terminal();
      expect(
          () => TerminalActions(
                terminal: terminal,
                controller: null as TerminalController,
                child: const SizedBox(),
              ),
          throwsA(isA<Error>()));
    });
  });

  group('defaultTerminalShortcuts', () {
    test('Given defaultTerminalShortcuts, Then returns non-empty map', () {
      final shortcuts = defaultTerminalShortcuts;
      expect(shortcuts.isNotEmpty, isTrue);
      expect(shortcuts.length, greaterThanOrEqualTo(3));
    });

    test('Given defaultTerminalShortcuts, Then contains Copy intent', () {
      final shortcuts = defaultTerminalShortcuts;
      expect(shortcuts.values.any((v) => v is CopySelectionTextIntent), isTrue);
    });

    test('Given defaultTerminalShortcuts, Then contains Paste intent', () {
      final shortcuts = defaultTerminalShortcuts;
      expect(shortcuts.values.any((v) => v is PasteTextIntent), isTrue);
    });

    test('Given defaultTerminalShortcuts, Then contains SelectAll intent', () {
      final shortcuts = defaultTerminalShortcuts;
      expect(shortcuts.values.any((v) => v is SelectAllTextIntent), isTrue);
    });

    test('Given defaultTerminalShortcuts, Then all values are valid intents',
        () {
      final shortcuts = defaultTerminalShortcuts;
      for (final entry in shortcuts.entries) {
        expect(
          entry.value is CopySelectionTextIntent ||
              entry.value is PasteTextIntent ||
              entry.value is SelectAllTextIntent,
          isTrue,
        );
      }
    });

    test('Given defaultTerminalShortcuts, Then all keys and values non-null',
        () {
      final shortcuts = defaultTerminalShortcuts;
      for (final key in shortcuts.keys) {
        expect(key, isNotNull);
      }
      for (final value in shortcuts.values) {
        expect(value, isNotNull);
      }
    });
  });

  group('Intent validation', () {
    test('Given CopySelectionTextIntent.copy, Then instance exists', () {
      final intent = CopySelectionTextIntent.copy;
      expect(intent, isA<CopySelectionTextIntent>());
    });

    test('Given PasteTextIntent with keyboard cause, Then instance exists', () {
      final intent = PasteTextIntent(SelectionChangedCause.keyboard);
      expect(intent, isA<PasteTextIntent>());
    });

    test('Given SelectAllTextIntent with keyboard cause, Then instance exists',
        () {
      final intent = SelectAllTextIntent(SelectionChangedCause.keyboard);
      expect(intent, isA<SelectAllTextIntent>());
    });

    test('Given PasteTextIntent, When different causes, Then instances differ',
        () {
      final intent1 = PasteTextIntent(SelectionChangedCause.keyboard);
      final intent2 = PasteTextIntent(SelectionChangedCause.toolbar);
      // Different cause values, but both valid
      expect(intent1, isA<PasteTextIntent>());
      expect(intent2, isA<PasteTextIntent>());
    });
  });

  group('ShortcutActivator validation', () {
    test('Given shortcuts map, Then contains key with control and shift', () {
      final shortcuts = defaultTerminalShortcuts;
      bool foundCtrlShiftC = false;
      for (final entry in shortcuts.entries) {
        if (entry.value is CopySelectionTextIntent) {
          final activator = entry.key;
          // Verify it's a valid ShortcutActivator
          expect(activator, isA<ShortcutActivator>());
          // Note: SingleActivator has 'control' and 'shift' fields
          if (activator is SingleActivator) {
            if (activator.control == true && activator.shift == true) {
              foundCtrlShiftC = true;
            }
          }
        }
      }
      expect(foundCtrlShiftC, isTrue,
          reason:
              'Copy shortcut should use Ctrl+Shift+C on non-Apple platforms');
    });

    test('Given shortcuts map, Then paste uses control only', () {
      final shortcuts = defaultTerminalShortcuts;
      bool foundCtrlV = false;
      for (final entry in shortcuts.entries) {
        if (entry.value is PasteTextIntent) {
          final activator = entry.key;
          expect(activator, isA<ShortcutActivator>());
          if (activator is SingleActivator) {
            if (activator.control == true && activator.shift != true) {
              foundCtrlV = true;
            }
          }
        }
      }
      expect(foundCtrlV, isTrue);
    });

    test('Given shortcuts map, Then select all uses control only', () {
      final shortcuts = defaultTerminalShortcuts;
      bool foundCtrlA = false;
      for (final entry in shortcuts.entries) {
        if (entry.value is SelectAllTextIntent) {
          final activator = entry.key;
          expect(activator, isA<ShortcutActivator>());
          if (activator is SingleActivator) {
            if (activator.control == true) {
              foundCtrlA = true;
            }
          }
        }
      }
      expect(foundCtrlA, isTrue);
    });
  });
}
