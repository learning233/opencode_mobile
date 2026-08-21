import 'package:kterm/src/utils/hash_values.dart';

class CellData {
  CellData({
    required this.foreground,
    required this.background,
    required this.flags,
    required this.content,
    this.underlineStyle = 0,
    this.underlineColor = 0,
    this.imageData = 0,
    this.hyperlinkId = 0,
  });

  factory CellData.empty() {
    return CellData(
      foreground: 0,
      background: 0,
      flags: 0,
      content: 0,
      underlineStyle: 0,
      underlineColor: 0,
      imageData: 0,
      hyperlinkId: 0,
    );
  }

  int foreground;

  int background;

  int flags;

  int content;

  /// Underline style: 0=none, 1=single, 2=curly, 3=dotted, 4=dashed
  int underlineStyle;

  /// Underline color encoded like foreground/background (type + value)
  int underlineColor;

  /// Packed image data: upper 16 bits = image ID, lower 16 bits = placement ID
  int imageData;

  /// Hyperlink ID (0 = no hyperlink)
  int hyperlinkId;

  /// Get image ID from imageData
  int get imageId => CellImage.getImageId(imageData);

  /// Get placement ID from imageData
  int get placementId => CellImage.getPlacementId(imageData);

  /// Check if cell has an image
  bool get hasImage => CellImage.hasImage(imageData);

  int getHash() {
    return hashValues(foreground, background, flags, content, underlineStyle,
        underlineColor, imageData, hyperlinkId);
  }

  @override
  String toString() {
    return 'CellData{foreground: $foreground, background: $background, flags: $flags, content: $content, underlineStyle: $underlineStyle, underlineColor: $underlineColor, imageData: $imageData, hyperlinkId: $hyperlinkId}';
  }
}

abstract class CellAttr {
  static const bold = 1 << 0;
  static const faint = 1 << 1;
  static const italic = 1 << 2;
  static const underline = 1 << 3;
  static const blink = 1 << 4;
  static const inverse = 1 << 5;
  static const invisible = 1 << 6;
  static const strikethrough = 1 << 7;

  // Underline style constants (used in CellData.underlineStyle)
  static const underlineStyleNone = 0;
  static const underlineStyleSingle = 1;
  static const underlineStyleDouble = 2;
  static const underlineStyleCurly = 3;
  static const underlineStyleDotted = 4;
  static const underlineStyleDashed = 5;
}

abstract class CellColor {
  static const valueMask = 0xFFFFFF;

  static const typeShift = 25;
  static const typeMask = 3 << typeShift;

  static const normal = 0 << typeShift;
  static const named = 1 << typeShift;
  static const palette = 2 << typeShift;
  static const rgb = 3 << typeShift;
}

abstract class CellContent {
  static const codepointMask = 0x1fffff;

  static const widthShift = 22;
  // static const widthMask = 3 << widthShift;
}

/// Helper for packing image data (image ID + placement ID) into a single integer.
/// Reuses the underlineColor slot in BufferLine for storage.
abstract class CellImage {
  /// Image ID is stored in upper 16 bits
  static const imageIdShift = 16;
  static const imageIdMask = 0xFFFF0000;

  /// Placement ID is stored in lower 16 bits
  static const placementIdShift = 0;
  static const placementIdMask = 0x0000FFFF;

  /// Pack image ID and placement ID into single integer
  static int packImageData(int imageId, int placementId) {
    return ((imageId << imageIdShift) & imageIdMask) |
        ((placementId << placementIdShift) & placementIdMask);
  }

  /// Extract image ID from packed integer
  static int getImageId(int packed) {
    return (packed & imageIdMask) >> imageIdShift;
  }

  /// Extract placement ID from packed integer
  static int getPlacementId(int packed) {
    return (packed & placementIdMask) >> placementIdShift;
  }

  /// Check if packed data contains an image (imageId > 0)
  static bool hasImage(int packed) {
    return getImageId(packed) != 0;
  }
}
