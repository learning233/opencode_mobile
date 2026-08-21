import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/painting.dart';

import 'package:kterm/core.dart';
import 'package:kterm/src/core/graphics_manager.dart';
import 'package:kterm/src/ui/cursor_type.dart';
import 'package:kterm/src/ui/palette_builder.dart';
import 'package:kterm/src/ui/paragraph_cache.dart';
import 'package:kterm/src/ui/terminal_theme.dart';
import 'package:kterm/src/ui/terminal_text_style.dart';

/// Encapsulates the logic for painting various terminal elements.
class TerminalPainter {
  TerminalPainter({
    required TerminalTheme theme,
    required TerminalStyle textStyle,
    required TextScaler textScaler,
    GraphicsManager? graphicsManager,
  })  : _textStyle = textStyle,
        _theme = theme,
        _textScaler = textScaler,
        _graphicsManager = graphicsManager;

  /// A lookup table from terminal colors to Flutter colors.
  late var _colorPalette = PaletteBuilder(_theme).build();

  /// Size of each character in the terminal.
  late var _cellSize = _measureCharSize();

  /// The cached for cells in the terminal. Should be cleared when the same
  /// cell no longer produces the same visual output. For example, when
  /// [_textStyle] is changed, or when the system font changes.
  final _paragraphCache = ParagraphCache(10240);

  /// Graphics manager for rendering images
  final GraphicsManager? _graphicsManager;

  TerminalStyle get textStyle => _textStyle;
  TerminalStyle _textStyle;
  set textStyle(TerminalStyle value) {
    if (value == _textStyle) return;
    _textStyle = value;
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler = TextScaler.linear(1.0);
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  TerminalTheme get theme => _theme;
  TerminalTheme _theme;
  set theme(TerminalTheme value) {
    if (value == _theme) return;
    _theme = value;
    _colorPalette = PaletteBuilder(value).build();
    _paragraphCache.clear();
  }

  Size _measureCharSize() {
    const test = 'mmmmmmmmmm';

    final textStyle = _textStyle.toTextStyle();
    final builder = ParagraphBuilder(textStyle.getParagraphStyle());
    builder.pushStyle(
      textStyle.getTextStyle(textScaler: _textScaler),
    );
    builder.addText(test);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));

    final result = Size(
      paragraph.maxIntrinsicWidth / test.length,
      paragraph.height,
    );

    paragraph.dispose();
    return result;
  }

  /// The size of each character in the terminal.
  Size get cellSize => _cellSize;

  /// When the set of font available to the system changes, call this method to
  /// clear cached state related to font rendering.
  void clearFontCache() {
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  /// Paints the cursor based on the current cursor type.
  void paintCursor(
    Canvas canvas,
    Offset offset, {
    required TerminalCursorType cursorType,
    bool hasFocus = true,
  }) {
    final paint = Paint()
      ..color = _theme.cursor
      ..strokeWidth = 1;

    if (!hasFocus) {
      paint.style = PaintingStyle.stroke;
      canvas.drawRect(offset & _cellSize, paint);
      return;
    }

    switch (cursorType) {
      case TerminalCursorType.block:
        // Use difference blend mode to invert the colors under the cursor
        // This makes the text visible while the cursor is clearly shown
        paint.style = PaintingStyle.fill;
        paint.blendMode = BlendMode.difference;
        canvas.drawRect(offset & _cellSize, paint);
        return;
      case TerminalCursorType.underline:
        return canvas.drawLine(
          Offset(offset.dx, _cellSize.height - 1),
          Offset(offset.dx + _cellSize.width, _cellSize.height - 1),
          paint,
        );
      case TerminalCursorType.verticalBar:
        return canvas.drawLine(
          Offset(offset.dx, 0),
          Offset(offset.dx, _cellSize.height),
          paint,
        );
    }
  }

  @pragma('vm:prefer-inline')
  void paintHighlight(Canvas canvas, Offset offset, int length, Color color) {
    final endOffset =
        offset.translate(length * _cellSize.width, _cellSize.height);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    canvas.drawRect(
      Rect.fromPoints(offset, endOffset),
      paint,
    );
  }

  /// Paints [line] to [canvas] at [offset]. The x offset of [offset] is usually
  /// 0, and the y offset is the top of the line.
  void paintLine(
    Canvas canvas,
    Offset offset,
    BufferLine line,
  ) {
    final cellData = CellData.empty();
    final cellWidth = _cellSize.width;

    for (var i = 0; i < line.length; i++) {
      line.getCellData(i, cellData);

      final charWidth = cellData.content >> CellContent.widthShift;

      // Skip zero-width or negative-width cells (control characters)
      if (charWidth > 0) {
        final cellOffset = offset.translate(i * cellWidth, 0);
        paintCell(canvas, cellOffset, cellData);
      }

      if (charWidth == 2) {
        i++;
      }
    }
  }

  @pragma('vm:prefer-inline')
  void paintCell(Canvas canvas, Offset offset, CellData cellData) {
    paintCellBackground(canvas, offset, cellData);
    paintCellForeground(canvas, offset, cellData);
    paintCellUnderline(canvas, offset, cellData);
  }

  /// Paints underlines for the cell based on the underline style.
  void paintCellUnderline(Canvas canvas, Offset offset, CellData cellData) {
    final underlineStyle = cellData.underlineStyle;
    if (underlineStyle == CellAttr.underlineStyleNone) return;
    // Single underline is handled by Flutter's TextStyle, no need to paint again
    if (underlineStyle == CellAttr.underlineStyleSingle) return;

    // Don't render underline for zero-width or negative-width cells (control characters)
    final charWidth = cellData.content >> CellContent.widthShift;
    if (charWidth <= 0) return;

    // Determine underline color
    final underlineColor = cellData.underlineColor;
    Color color;
    if (underlineColor == 0) {
      // Default to foreground color
      color = resolveForegroundColor(cellData.foreground);
    } else {
      color = resolveUnderlineColor(underlineColor);
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final cellWidth = _cellSize.width;
    final cellHeight = _cellSize.height;
    final y = cellHeight - 1; // Bottom of the cell

    switch (underlineStyle) {
      case CellAttr.underlineStyleSingle:
        canvas.drawLine(
          Offset(offset.dx, y),
          Offset(offset.dx + cellWidth, y),
          paint,
        );
        break;
      case CellAttr.underlineStyleDouble:
        // Double underline - two lines
        canvas.drawLine(
          Offset(offset.dx, y - 2),
          Offset(offset.dx + cellWidth, y - 2),
          paint,
        );
        canvas.drawLine(
          Offset(offset.dx, y),
          Offset(offset.dx + cellWidth, y),
          paint,
        );
        break;
      case CellAttr.underlineStyleCurly:
        _drawCurlyUnderline(canvas, offset, cellWidth, cellHeight, paint);
        break;
      case CellAttr.underlineStyleDotted:
        _drawDottedUnderline(canvas, offset, cellWidth, cellHeight, paint);
        break;
      case CellAttr.underlineStyleDashed:
        _drawDashedUnderline(canvas, offset, cellWidth, cellHeight, paint);
        break;
    }
  }

  /// Draws a curly (wave) underline.
  void _drawCurlyUnderline(Canvas canvas, Offset offset, double cellWidth,
      double cellHeight, Paint paint) {
    final path = Path();
    final y = cellHeight - 2;
    final amplitude = 1.5;
    final frequency = 0.15;

    path.moveTo(offset.dx, y);

    for (double x = 0; x <= cellWidth; x++) {
      final yOffset = amplitude * math.sin(x * frequency * 2 * math.pi);
      path.lineTo(offset.dx + x, y + yOffset);
    }

    canvas.drawPath(path, paint);
  }

  /// Draws a dotted underline.
  void _drawDottedUnderline(Canvas canvas, Offset offset, double cellWidth,
      double cellHeight, Paint paint) {
    final y = cellHeight - 2;
    final dotSpacing = 3.0;
    final dotRadius = 1.0;

    paint.style = PaintingStyle.fill;

    for (double x = dotRadius; x < cellWidth; x += dotSpacing) {
      canvas.drawCircle(
        Offset(offset.dx + x, y),
        dotRadius,
        paint,
      );
    }
  }

  /// Draws a dashed underline.
  void _drawDashedUnderline(Canvas canvas, Offset offset, double cellWidth,
      double cellHeight, Paint paint) {
    final y = cellHeight - 1;
    final dashLength = 4.0;
    final gapLength = 3.0;

    paint.style = PaintingStyle.stroke;

    double x = 0;
    while (x < cellWidth) {
      final endX = math.min(x + dashLength, cellWidth);
      canvas.drawLine(
        Offset(offset.dx + x, y),
        Offset(offset.dx + endX, y),
        paint,
      );
      x += dashLength + gapLength;
    }
  }

  /// Resolve underline color from cell color value.
  @pragma('vm:prefer-inline')
  Color resolveUnderlineColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.foreground;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

  /// Render all "below text" images that overlap with the given line range.
  /// Returns the number of images rendered.
  int renderBelowImages(
    Canvas canvas,
    int startLine,
    int endLine,
    double cellWidth,
    double cellHeight,
  ) {
    if (_graphicsManager == null) return 0;
    if (_graphicsManager!.placements.isEmpty) return 0;

    int rendered = 0;
    for (final entry in _graphicsManager!.placements.entries) {
      final placement = entry.value;
      // Skip above-text images
      if (placement.overlay) continue;

      // Check if placement overlaps with visible lines
      if (placement.y + placement.height <= startLine ||
          placement.y >= endLine) {
        continue;
      }

      final image = _graphicsManager!.getImage(placement.imageId);
      if (image == null) continue;

      // Calculate destination rectangle in pixels
      final destX = placement.x * cellWidth;
      final destY = placement.y * cellHeight;
      final destWidth = placement.width * cellWidth;
      final destHeight = placement.height * cellHeight;

      // Calculate source rectangle (full image)
      final srcRect = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final dstRect = Rect.fromLTWH(destX, destY, destWidth, destHeight);

      canvas.drawImageRect(image, srcRect, dstRect, Paint());
      rendered++;
    }

    return rendered;
  }

  /// Render all "above text" images that overlap with the given line range.
  /// Returns the number of images rendered.
  int renderAboveImages(
    Canvas canvas,
    int startLine,
    int endLine,
    double cellWidth,
    double cellHeight,
  ) {
    if (_graphicsManager == null) return 0;
    if (_graphicsManager!.placements.isEmpty) return 0;

    int rendered = 0;
    for (final entry in _graphicsManager!.placements.entries) {
      final placement = entry.value;
      // Skip below-text images
      if (!placement.overlay) continue;

      // Check if placement overlaps with visible lines
      if (placement.y + placement.height <= startLine ||
          placement.y >= endLine) {
        continue;
      }

      final image = _graphicsManager!.getImage(placement.imageId);
      if (image == null) continue;

      // Calculate destination rectangle in pixels
      final destX = placement.x * cellWidth;
      final destY = placement.y * cellHeight;
      final destWidth = placement.width * cellWidth;
      final destHeight = placement.height * cellHeight;

      // Calculate source rectangle (full image)
      final srcRect = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final dstRect = Rect.fromLTWH(destX, destY, destWidth, destHeight);

      // Use Paint with filter quality for better scaling
      final paint = Paint()..filterQuality = FilterQuality.medium;
      canvas.drawImageRect(image, srcRect, dstRect, paint);
      rendered++;
    }

    return rendered;
  }

  /// Paints the character in the cell represented by [cellData] to [canvas] at
  /// [offset].
  @pragma('vm:prefer-inline')
  void paintCellForeground(Canvas canvas, Offset offset, CellData cellData) {
    final charCode = cellData.content & CellContent.codepointMask;
    if (charCode == 0) return;

    final cacheKey = cellData.getHash() ^ _textScaler.hashCode;
    var paragraph = _paragraphCache.getLayoutFromCache(cacheKey);

    if (paragraph == null) {
      final cellFlags = cellData.flags;

      var color = cellFlags & CellFlags.inverse == 0
          ? resolveForegroundColor(cellData.foreground)
          : resolveBackgroundColor(cellData.background);

      if (cellData.flags & CellFlags.faint != 0) {
        color = color.withValues(alpha: 0.5);
      }

      final style = _textStyle.toTextStyle(
        color: color,
        bold: cellFlags & CellFlags.bold != 0,
        italic: cellFlags & CellFlags.italic != 0,
        underline: cellFlags & CellFlags.underline != 0,
      );

      var char = String.fromCharCode(charCode);

      paragraph = _paragraphCache.performAndCacheLayout(
        char,
        style,
        _textScaler,
        cacheKey,
      );
    }

    canvas.drawParagraph(paragraph, offset);
  }

  /// Paints the background of a cell represented by [cellData] to [canvas] at
  /// [offset].
  @pragma('vm:prefer-inline')
  void paintCellBackground(Canvas canvas, Offset offset, CellData cellData) {
    final charWidth = cellData.content >> CellContent.widthShift;
    // Skip zero-width or negative-width cells (control characters)
    if (charWidth <= 0) return;

    late Color color;
    final colorType = cellData.background & CellColor.typeMask;

    if (cellData.flags & CellFlags.inverse != 0) {
      color = resolveForegroundColor(cellData.foreground);
    } else if (colorType == CellColor.normal) {
      return;
    } else {
      color = resolveBackgroundColor(cellData.background);
    }

    final paint = Paint()..color = color;
    final doubleWidth = cellData.content >> CellContent.widthShift == 2;
    final widthScale = doubleWidth ? 2 : 1;
    final size = Size(_cellSize.width * widthScale + 1, _cellSize.height);
    canvas.drawRect(offset & size, paint);
  }

  /// Get the effective foreground color for a cell from information encoded in
  /// [cellColor].
  @pragma('vm:prefer-inline')
  Color resolveForegroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.foreground;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

  /// Get the effective background color for a cell from information encoded in
  /// [cellColor].
  @pragma('vm:prefer-inline')
  Color resolveBackgroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.background;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }
}
