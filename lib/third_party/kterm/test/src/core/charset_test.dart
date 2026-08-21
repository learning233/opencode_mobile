import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/charset.dart';

void main() {
  group('Charset', () {
    late Charset charset;

    setUp(() {
      charset = Charset();
    });

    test('default translator is ASCII', () {
      expect(charset.translate(65), equals(65)); // 'A'
      expect(charset.translate(97), equals(97)); // 'a'
    });

    group('designate', () {
      test('designates charset at index', () {
        // '0' = 48 in ASCII
        charset.designate(0, '0'.codeUnitAt(0));
        expect(charset.translate(0x5f), equals(0x00A0)); // decSpecGraphics
      });

      test('designate does nothing for unknown charset', () {
        charset.designate(0, 'X'.codeUnitAt(0)); // Unknown charset
        expect(charset.translate(65), equals(65));
      });
    });

    group('use', () {
      test('switches to designated charset', () {
        charset.designate(1, '0'.codeUnitAt(0));
        charset.use(1);
        expect(charset.translate(0x5f), equals(0x00A0));
      });

      test('falls back to ASCII for unknown index', () {
        charset.use(99);
        expect(charset.translate(65), equals(65));
      });
    });

    group('save/restore', () {
      test('saves and restores charset state', () {
        charset.designate(1, '0'.codeUnitAt(0));
        charset.use(1);
        charset.save();

        charset.use(0); // Switch to default
        expect(charset.translate(0x5f), equals(0x5f)); // ASCII

        charset.restore();
        expect(charset.translate(0x5f), equals(0x00A0)); // decSpecGraphics
      });

      test('save can be called multiple times', () {
        charset.designate(0, '0'.codeUnitAt(0));
        charset.save();

        charset.use(0);
        charset.save();

        charset.designate(0, 'B'.codeUnitAt(0)); // ASCII (default)
        charset.restore(); // Should restore to first save

        expect(charset.translate(0x5f), equals(0x00A0));
      });
    });
  });

  group('asciiTranslator', () {
    test('returns same codepoint', () {
      expect(asciiTranslator(65), equals(65));
      expect(asciiTranslator(0), equals(0));
      expect(asciiTranslator(127), equals(127));
    });
  });

  group('decSpecGraphicsTranslator', () {
    test('translates graphic characters', () {
      expect(decSpecGraphicsTranslator(0x5f), equals(0x00A0));
      expect(decSpecGraphicsTranslator(0x60), equals(0x25C6));
      expect(decSpecGraphicsTranslator(0x61), equals(0x2592));
    });

    test('returns same for characters >= 127', () {
      expect(decSpecGraphicsTranslator(127), equals(127));
      expect(decSpecGraphicsTranslator(128), equals(128));
    });

    test('returns same for unmapped characters', () {
      expect(decSpecGraphicsTranslator(0x30), equals(0x30)); // '0'
      expect(decSpecGraphicsTranslator(0x41), equals(0x41)); // 'A'
    });
  });
}
