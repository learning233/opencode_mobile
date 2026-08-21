import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';
import 'package:kterm/src/ui/shortcut/shortcuts.dart';

void main() {
  group('defaultTerminalShortcuts', () {
    group('structure', () {
      test(
          'Given default terminal shortcuts, When accessed, Then returns non-empty map',
          () {
        // Act
        final shortcuts = defaultTerminalShortcuts;

        // Assert
        expect(shortcuts.isNotEmpty, isTrue);
      });

      test(
          'Given default terminal shortcuts, When checked, Then contains copy intent',
          () {
        // Arrange
        final shortcuts = defaultTerminalShortcuts;

        // Assert
        final hasCopy =
            shortcuts.values.any((v) => v is CopySelectionTextIntent);
        expect(hasCopy, isTrue);
      });

      test(
          'Given default terminal shortcuts, When checked, Then contains paste intent',
          () {
        // Arrange
        final shortcuts = defaultTerminalShortcuts;

        // Assert
        final hasPaste = shortcuts.values.any((v) => v is PasteTextIntent);
        expect(hasPaste, isTrue);
      });

      test(
          'Given default terminal shortcuts, When checked, Then contains select all intent',
          () {
        // Arrange
        final shortcuts = defaultTerminalShortcuts;

        // Assert
        final hasSelectAll =
            shortcuts.values.any((v) => v is SelectAllTextIntent);
        expect(hasSelectAll, isTrue);
      });

      test(
          'Given default terminal shortcuts, When checked, Then has at least 3 shortcuts',
          () {
        // Arrange
        final shortcuts = defaultTerminalShortcuts;

        // Assert
        expect(shortcuts.length, greaterThanOrEqualTo(3));
      });

      test(
          'Given default terminal shortcuts, When checked, Then all values are non-null',
          () {
        // Arrange
        final shortcuts = defaultTerminalShortcuts;

        // Assert
        for (final entry in shortcuts.entries) {
          expect(entry.value, isNotNull);
        }
      });

      test(
          'Given default terminal shortcuts, When checked, Then all keys are non-null',
          () {
        // Arrange
        final shortcuts = defaultTerminalShortcuts;

        // Assert
        for (final key in shortcuts.keys) {
          expect(key, isNotNull);
        }
      });
    });

    group('intent mapping', () {
      test(
          'Given default terminal shortcuts, When checked, Then maps to valid intents',
          () {
        // Arrange
        final shortcuts = defaultTerminalShortcuts;

        // Assert
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
    });
  });
}
