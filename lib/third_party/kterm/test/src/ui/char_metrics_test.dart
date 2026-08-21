import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:test/test.dart';
import 'package:kterm/src/ui/char_metrics.dart';
import 'package:kterm/src/ui/terminal_text_style.dart';

void main() {
  group('calcCharSize', () {
    test(
        'Given default style, When calcCharSize called, Then returns valid size',
        () {
      // Arrange
      const style = TerminalStyle();
      final textScaler = TextScaler.noScaling;

      // Act
      final size = calcCharSize(style, textScaler);

      // Assert
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    });

    test(
        'Given custom font size, When calcCharSize called, Then returns larger size',
        () {
      // Arrange
      const style = TerminalStyle(fontSize: 24.0);
      final textScaler = TextScaler.noScaling;

      // Act
      final size = calcCharSize(style, textScaler);

      // Assert
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    });

    test(
        'Given textScaler, When calcCharSize called, Then accounts for scaling',
        () {
      // Arrange
      const style = TerminalStyle();
      final textScaler = TextScaler.linear(2.0);

      // Act
      final size = calcCharSize(style, textScaler);

      // Assert
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    });

    test(
        'Given default style, When calcCharSize called, Then width is less than height',
        () {
      // Arrange - monospace fonts typically have width < height
      const style = TerminalStyle();
      final textScaler = TextScaler.noScaling;

      // Act
      final size = calcCharSize(style, textScaler);

      // Assert - typical monospace has wider height than width per character
      expect(size.height, greaterThan(size.width));
    });

    test(
        'Given different styles, When calcCharSize called, Then returns different sizes',
        () {
      // Arrange
      const style1 = TerminalStyle(fontSize: 12.0);
      const style2 = TerminalStyle(fontSize: 18.0);
      final textScaler = TextScaler.noScaling;

      // Act
      final size1 = calcCharSize(style1, textScaler);
      final size2 = calcCharSize(style2, textScaler);

      // Assert
      expect(size2.width, greaterThan(size1.width));
      expect(size2.height, greaterThan(size1.height));
    });
  });
}
