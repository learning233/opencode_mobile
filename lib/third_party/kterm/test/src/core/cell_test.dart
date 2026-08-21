import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/cell.dart';

void main() {
  group('CellData', () {
    test('creates with required parameters', () {
      final cell = CellData(
        foreground: 1,
        background: 2,
        flags: 3,
        content: 65, // 'A'
      );

      expect(cell.foreground, equals(1));
      expect(cell.background, equals(2));
      expect(cell.flags, equals(3));
      expect(cell.content, equals(65));
    });

    test('creates with default optional parameters', () {
      final cell = CellData(
        foreground: 1,
        background: 2,
        flags: 3,
        content: 65,
      );

      expect(cell.underlineStyle, equals(0));
      expect(cell.underlineColor, equals(0));
      expect(cell.imageData, equals(0));
      expect(cell.hyperlinkId, equals(0));
    });

    test('empty factory creates cell with all zeros', () {
      final cell = CellData.empty();

      expect(cell.foreground, equals(0));
      expect(cell.background, equals(0));
      expect(cell.flags, equals(0));
      expect(cell.content, equals(0));
      expect(cell.underlineStyle, equals(0));
      expect(cell.underlineColor, equals(0));
      expect(cell.imageData, equals(0));
      expect(cell.hyperlinkId, equals(0));
    });

    test('getHash returns consistent value', () {
      final cell = CellData(
        foreground: 1,
        background: 2,
        flags: 3,
        content: 65,
      );

      final hash1 = cell.getHash();
      final hash2 = cell.getHash();

      expect(hash1, equals(hash2));
    });

    test('toString returns formatted string', () {
      final cell = CellData(
        foreground: 1,
        background: 2,
        flags: 3,
        content: 65,
      );

      expect(cell.toString(), contains('CellData'));
      expect(cell.toString(), contains('foreground: 1'));
    });
  });

  group('CellAttr', () {
    test('bold flag is correct value', () {
      expect(CellAttr.bold, equals(1 << 0));
    });

    test('faint flag is correct value', () {
      expect(CellAttr.faint, equals(1 << 1));
    });

    test('italic flag is correct value', () {
      expect(CellAttr.italic, equals(1 << 2));
    });

    test('underline flag is correct value', () {
      expect(CellAttr.underline, equals(1 << 3));
    });

    test('blink flag is correct value', () {
      expect(CellAttr.blink, equals(1 << 4));
    });

    test('inverse flag is correct value', () {
      expect(CellAttr.inverse, equals(1 << 5));
    });

    test('invisible flag is correct value', () {
      expect(CellAttr.invisible, equals(1 << 6));
    });

    test('strikethrough flag is correct value', () {
      expect(CellAttr.strikethrough, equals(1 << 7));
    });

    test('underline style constants are correct', () {
      expect(CellAttr.underlineStyleNone, equals(0));
      expect(CellAttr.underlineStyleSingle, equals(1));
      expect(CellAttr.underlineStyleDouble, equals(2));
      expect(CellAttr.underlineStyleCurly, equals(3));
      expect(CellAttr.underlineStyleDotted, equals(4));
      expect(CellAttr.underlineStyleDashed, equals(5));
    });
  });

  group('CellColor', () {
    test('valueMask is correct', () {
      expect(CellColor.valueMask, equals(0xFFFFFF));
    });

    test('typeShift is correct', () {
      expect(CellColor.typeShift, equals(25));
    });

    test('typeMask is correct', () {
      expect(CellColor.typeMask, equals(3 << 25));
    });

    test('color types have correct values', () {
      expect(CellColor.normal, equals(0 << 25));
      expect(CellColor.named, equals(1 << 25));
      expect(CellColor.palette, equals(2 << 25));
      expect(CellColor.rgb, equals(3 << 25));
    });
  });

  group('CellContent', () {
    test('codepointMask is correct', () {
      expect(CellContent.codepointMask, equals(0x1fffff));
    });

    test('widthShift is correct', () {
      expect(CellContent.widthShift, equals(22));
    });
  });

  group('CellImage', () {
    test('packImageData packs correctly', () {
      final packed = CellImage.packImageData(1, 2);
      expect(CellImage.getImageId(packed), equals(1));
      expect(CellImage.getPlacementId(packed), equals(2));
    });

    test('getImageId extracts correct bits', () {
      final packed = CellImage.packImageData(0x1234, 0x5678);
      expect(CellImage.getImageId(packed), equals(0x1234));
    });

    test('getPlacementId extracts correct bits', () {
      final packed = CellImage.packImageData(0x1234, 0x5678);
      expect(CellImage.getPlacementId(packed), equals(0x5678));
    });

    test('hasImage returns true when imageId > 0', () {
      final packed = CellImage.packImageData(1, 0);
      expect(CellImage.hasImage(packed), isTrue);
    });

    test('hasImage returns false when imageId is 0', () {
      final packed = CellImage.packImageData(0, 0);
      expect(CellImage.hasImage(packed), isFalse);
    });

    test('CellData.imageId getter works', () {
      final cell = CellData(
        foreground: 0,
        background: 0,
        flags: 0,
        content: 0,
        imageData: CellImage.packImageData(42, 7),
      );

      expect(cell.imageId, equals(42));
    });

    test('CellData.placementId getter works', () {
      final cell = CellData(
        foreground: 0,
        background: 0,
        flags: 0,
        content: 0,
        imageData: CellImage.packImageData(42, 7),
      );

      expect(cell.placementId, equals(7));
    });

    test('CellData.hasImage returns true when cell has image', () {
      final cell = CellData(
        foreground: 0,
        background: 0,
        flags: 0,
        content: 0,
        imageData: CellImage.packImageData(1, 0),
      );

      expect(cell.hasImage, isTrue);
    });

    test('CellData.hasImage returns false when cell has no image', () {
      final cell = CellData(
        foreground: 0,
        background: 0,
        flags: 0,
        content: 0,
        imageData: 0,
      );

      expect(cell.hasImage, isFalse);
    });
  });
}
