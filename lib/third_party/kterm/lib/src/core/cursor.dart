import 'package:kterm/src/core/cell.dart';

class CursorStyle {
  int foreground;

  int background;

  int attrs;

  /// Underline style: 0=none, 1=single, 2=double, 3=curly, 4=dotted, 5=dashed
  int underlineStyle;

  /// Underline color encoded like foreground/background (type + value)
  int underlineColor;

  /// Hyperlink ID (0 = no hyperlink)
  int hyperlinkId;

  CursorStyle({
    this.foreground = 0,
    this.background = 0,
    this.attrs = 0,
    this.underlineStyle = 0,
    this.underlineColor = 0,
    this.hyperlinkId = 0,
  });

  static final empty = CursorStyle();

  void setBold() {
    attrs |= CellAttr.bold;
  }

  void setFaint() {
    attrs |= CellAttr.faint;
  }

  void setItalic() {
    attrs |= CellAttr.italic;
  }

  void setUnderline() {
    attrs |= CellAttr.underline;
    underlineStyle = CellAttr.underlineStyleSingle;
  }

  void setBlink() {
    attrs |= CellAttr.blink;
  }

  void setInverse() {
    attrs |= CellAttr.inverse;
  }

  void setInvisible() {
    attrs |= CellAttr.invisible;
  }

  void setStrikethrough() {
    attrs |= CellAttr.strikethrough;
  }

  void setUnderlineStyle(int style) {
    underlineStyle = style;
    // Only style 1 (single) uses the basic underline flag.
    // Styles 2-5 are custom-drawn and should NOT set the attrs underline bit.
    // Style 0 (none) must clear it.
    if (style == CellAttr.underlineStyleSingle) {
      attrs |= CellAttr.underline;
    } else {
      attrs &= ~CellAttr.underline;
    }
  }

  void setUnderlineColor256(int color) {
    underlineColor = color | CellColor.palette;
  }

  void setUnderlineColorRgb(int r, int g, int b) {
    underlineColor = (r << 16) | (g << 8) | b | CellColor.rgb;
  }

  void resetUnderlineColor() {
    underlineColor = 0;
  }

  void unsetBold() {
    attrs &= ~CellAttr.bold;
  }

  void unsetFaint() {
    attrs &= ~CellAttr.faint;
  }

  void unsetItalic() {
    attrs &= ~CellAttr.italic;
  }

  void unsetUnderline() {
    attrs &= ~CellAttr.underline;
    underlineStyle = CellAttr.underlineStyleNone;
    underlineColor = 0;
  }

  void unsetBlink() {
    attrs &= ~CellAttr.blink;
  }

  void unsetInverse() {
    attrs &= ~CellAttr.inverse;
  }

  void unsetInvisible() {
    attrs &= ~CellAttr.invisible;
  }

  void unsetStrikethrough() {
    attrs &= ~CellAttr.strikethrough;
  }

  bool get isBold => (attrs & CellAttr.bold) != 0;

  bool get isFaint => (attrs & CellAttr.faint) != 0;

  bool get isItalis => (attrs & CellAttr.italic) != 0;

  bool get isUnderline =>
      (attrs & CellAttr.underline) != 0 ||
      underlineStyle != CellAttr.underlineStyleNone;

  bool get isBlink => (attrs & CellAttr.blink) != 0;

  bool get isInverse => (attrs & CellAttr.inverse) != 0;

  bool get isInvisible => (attrs & CellAttr.invisible) != 0;

  void setForegroundColor16(int color) {
    foreground = color | CellColor.named;
  }

  void setForegroundColor256(int color) {
    foreground = color | CellColor.palette;
  }

  void setForegroundColorRgb(int r, int g, int b) {
    foreground = (r << 16) | (g << 8) | b | CellColor.rgb;
  }

  void resetForegroundColor() {
    foreground = 0; // | CellColor.normal;
  }

  void setBackgroundColor16(int color) {
    background = color | CellColor.named;
  }

  void setBackgroundColor256(int color) {
    background = color | CellColor.palette;
  }

  void setBackgroundColorRgb(int r, int g, int b) {
    background = (r << 16) | (g << 8) | b | CellColor.rgb;
  }

  void resetBackgroundColor() {
    background = 0; // | CellColor.normal;
  }

  void reset() {
    foreground = 0;
    background = 0;
    attrs = 0;
    underlineStyle = 0;
    underlineColor = 0;
    hyperlinkId = 0;
  }

  CursorStyle copy() {
    return CursorStyle(
      foreground: foreground,
      background: background,
      attrs: attrs,
      underlineStyle: underlineStyle,
      underlineColor: underlineColor,
      hyperlinkId: hyperlinkId,
    );
  }
}

class CursorPosition {
  int x;

  int y;

  CursorPosition(this.x, this.y);
}
