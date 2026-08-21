import 'package:test/test.dart';
import 'package:kterm/src/core/cursor.dart';
import 'package:kterm/src/core/cell.dart';

void main() {
  group('CursorStyle', () {
    group('color settings', () {
      test('setForegroundColor16 sets named color', () {
        final style = CursorStyle();
        style.setForegroundColor16(7); // white
        expect(style.foreground, equals(7 | CellColor.named));
      });

      test('setForegroundColor256 sets palette color', () {
        final style = CursorStyle();
        style.setForegroundColor256(128);
        expect(style.foreground, equals(128 | CellColor.palette));
      });

      test('setForegroundColorRgb sets RGB color', () {
        final style = CursorStyle();
        style.setForegroundColorRgb(255, 128, 64);
        expect(style.foreground,
            equals((255 << 16) | (128 << 8) | 64 | CellColor.rgb));
      });

      test('setBackgroundColor16 sets named color', () {
        final style = CursorStyle();
        style.setBackgroundColor16(1); // black
        expect(style.background, equals(1 | CellColor.named));
      });

      test('setBackgroundColor256 sets palette color', () {
        final style = CursorStyle();
        style.setBackgroundColor256(200);
        expect(style.background, equals(200 | CellColor.palette));
      });

      test('setBackgroundColorRgb sets RGB color', () {
        final style = CursorStyle();
        style.setBackgroundColorRgb(0, 255, 128);
        expect(style.background,
            equals((0 << 16) | (255 << 8) | 128 | CellColor.rgb));
      });

      test('resetForegroundColor resets to default', () {
        final style = CursorStyle();
        style.setForegroundColorRgb(255, 0, 0);
        style.resetForegroundColor();
        expect(style.foreground, equals(0));
      });

      test('resetBackgroundColor resets to default', () {
        final style = CursorStyle();
        style.setBackgroundColorRgb(0, 0, 255);
        style.resetBackgroundColor();
        expect(style.background, equals(0));
      });
    });

    group('attribute flags', () {
      test('setBold sets bold flag', () {
        final style = CursorStyle();
        style.setBold();
        expect(style.isBold, isTrue);
      });

      test('unsetBold clears bold flag', () {
        final style = CursorStyle();
        style.setBold();
        style.unsetBold();
        expect(style.isBold, isFalse);
      });

      test('setFaint sets faint flag', () {
        final style = CursorStyle();
        style.setFaint();
        expect(style.isFaint, isTrue);
      });

      test('unsetFaint clears faint flag', () {
        final style = CursorStyle();
        style.setFaint();
        style.unsetFaint();
        expect(style.isFaint, isFalse);
      });

      test('setItalic sets italic flag', () {
        final style = CursorStyle();
        style.setItalic();
        expect(style.isItalis, isTrue);
      });

      test('unsetItalic clears italic flag', () {
        final style = CursorStyle();
        style.setItalic();
        style.unsetItalic();
        expect(style.isItalis, isFalse);
      });

      test('setUnderline sets underline flag', () {
        final style = CursorStyle();
        style.setUnderline();
        expect(style.isUnderline, isTrue);
      });

      test('unsetUnderline clears underline flag and resets style', () {
        final style = CursorStyle();
        style.setUnderlineStyle(CellAttr.underlineStyleDouble);
        style.setUnderline();
        style.unsetUnderline();
        expect(style.isUnderline, isFalse);
        expect(style.underlineStyle, equals(CellAttr.underlineStyleNone));
      });

      test('setBlink sets blink flag', () {
        final style = CursorStyle();
        style.setBlink();
        expect(style.isBlink, isTrue);
      });

      test('unsetBlink clears blink flag', () {
        final style = CursorStyle();
        style.setBlink();
        style.unsetBlink();
        expect(style.isBlink, isFalse);
      });

      test('setInverse sets inverse flag', () {
        final style = CursorStyle();
        style.setInverse();
        expect(style.isInverse, isTrue);
      });

      test('unsetInverse clears inverse flag', () {
        final style = CursorStyle();
        style.setInverse();
        style.unsetInverse();
        expect(style.isInverse, isFalse);
      });

      test('setInvisible sets invisible flag', () {
        final style = CursorStyle();
        style.setInvisible();
        expect(style.isInvisible, isTrue);
      });

      test('unsetInvisible clears invisible flag', () {
        final style = CursorStyle();
        style.setInvisible();
        style.unsetInvisible();
        expect(style.isInvisible, isFalse);
      });

      test('setStrikethrough sets strikethrough flag', () {
        final style = CursorStyle();
        style.setStrikethrough();
        expect((style.attrs & CellAttr.strikethrough) != 0, isTrue);
      });

      test('unsetStrikethrough clears strikethrough flag', () {
        final style = CursorStyle();
        style.setStrikethrough();
        style.unsetStrikethrough();
        expect((style.attrs & CellAttr.strikethrough) == 0, isTrue);
      });

      test('multiple attributes can be combined', () {
        final style = CursorStyle();
        style.setBold();
        style.setItalic();
        style.setUnderline();
        expect(style.isBold, isTrue);
        expect(style.isItalis, isTrue);
        expect(style.isUnderline, isTrue);
      });
    });

    group('underline styles', () {
      test('setUnderlineStyle sets single underline', () {
        final style = CursorStyle();
        style.setUnderlineStyle(CellAttr.underlineStyleSingle);
        expect(style.underlineStyle, equals(CellAttr.underlineStyleSingle));
        expect(style.isUnderline, isTrue);
      });

      test('setUnderlineStyle sets double underline', () {
        final style = CursorStyle();
        style.setUnderlineStyle(CellAttr.underlineStyleDouble);
        expect(style.underlineStyle, equals(CellAttr.underlineStyleDouble));
        expect(style.isUnderline, isTrue);
      });

      test('setUnderlineStyle sets curly underline', () {
        final style = CursorStyle();
        style.setUnderlineStyle(CellAttr.underlineStyleCurly);
        expect(style.underlineStyle, equals(CellAttr.underlineStyleCurly));
      });

      test('setUnderlineStyle sets dotted underline', () {
        final style = CursorStyle();
        style.setUnderlineStyle(CellAttr.underlineStyleDotted);
        expect(style.underlineStyle, equals(CellAttr.underlineStyleDotted));
      });

      test('setUnderlineStyle sets dashed underline', () {
        final style = CursorStyle();
        style.setUnderlineStyle(CellAttr.underlineStyleDashed);
        expect(style.underlineStyle, equals(CellAttr.underlineStyleDashed));
      });

      test('setUnderlineColor256 sets palette color', () {
        final style = CursorStyle();
        style.setUnderlineColor256(196);
        expect(style.underlineColor, equals(196 | CellColor.palette));
      });

      test('setUnderlineColorRgb sets RGB color', () {
        final style = CursorStyle();
        style.setUnderlineColorRgb(128, 64, 32);
        expect(style.underlineColor,
            equals((128 << 16) | (64 << 8) | 32 | CellColor.rgb));
      });

      test('resetUnderlineColor resets to default', () {
        final style = CursorStyle();
        style.setUnderlineColorRgb(255, 0, 0);
        style.resetUnderlineColor();
        expect(style.underlineColor, equals(0));
      });
    });

    group('copy()', () {
      test('creates independent copy', () {
        final original = CursorStyle();
        original.setForegroundColorRgb(255, 0, 0);
        original.setBackgroundColor256(128);
        original.setBold();
        original.setUnderlineStyle(CellAttr.underlineStyleDouble);
        original.setUnderlineColor256(200);

        final copy = original.copy();

        // Verify values are copied
        expect(copy.foreground, equals(original.foreground));
        expect(copy.background, equals(original.background));
        expect(copy.attrs, equals(original.attrs));
        expect(copy.underlineStyle, equals(original.underlineStyle));
        expect(copy.underlineColor, equals(original.underlineColor));

        // Modify original and verify copy is independent
        original.setForegroundColorRgb(0, 0, 255);
        original.setItalic();
        expect(copy.foreground, isNot(equals(original.foreground)));
        expect(copy.isItalis, isFalse);
      });
    });

    group('reset()', () {
      test('resets all values to default', () {
        final style = CursorStyle();
        style.setForegroundColorRgb(255, 0, 0);
        style.setBackgroundColor256(100);
        style.setBold();
        style.setUnderlineStyle(CellAttr.underlineStyleDouble);
        style.setUnderlineColor256(200);
        style.hyperlinkId = 42;

        style.reset();

        expect(style.foreground, equals(0));
        expect(style.background, equals(0));
        expect(style.attrs, equals(0));
        expect(style.underlineStyle, equals(0));
        expect(style.underlineColor, equals(0));
        expect(style.hyperlinkId, equals(0));
      });
    });

    group('empty singleton', () {
      test('CursorStyle.empty is accessible', () {
        final style = CursorStyle.empty;
        expect(style.foreground, equals(0));
        expect(style.background, equals(0));
        expect(style.attrs, equals(0));
      });
    });
  });

  group('CursorPosition', () {
    test('stores x and y coordinates', () {
      final pos = CursorPosition(10, 5);
      expect(pos.x, equals(10));
      expect(pos.y, equals(5));
    });

    test('can be modified', () {
      final pos = CursorPosition(1, 1);
      pos.x = 20;
      pos.y = 15;
      expect(pos.x, equals(20));
      expect(pos.y, equals(15));
    });
  });
}
