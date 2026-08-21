import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencode_app/models/session_runtime_state.dart';
import 'package:opencode_app/utils/image_compressor.dart';

PickedImage _png(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(200, 30, 30));
  return (
    bytes: Uint8List.fromList(img.encodePng(image)),
    mime: 'image/png',
    ext: 'png',
  );
}

void main() {
  group('compressImageSync', () {
    test('downscales a large PNG to maxDim', () {
      final result = compressImageSync(_png(2000, 1200), maxDim: 800);

      expect(result.ext, 'png');
      expect(result.mime, 'image/png');
      final decoded = img.decodeImage(result.bytes)!;
      expect(decoded.width, 800);
      expect(decoded.height, 480);
    });

    test('re-encodes a large JPEG as jpg', () {
      final image = img.Image(width: 1600, height: 900);
      img.fill(image, color: img.ColorRgb8(10, 200, 10));
      final original = (
        bytes: Uint8List.fromList(img.encodeJpg(image)),
        mime: 'image/jpeg',
        ext: 'jpeg',
      );

      final result = compressImageSync(original, maxDim: 800);

      expect(result.ext, 'jpg');
      expect(result.mime, 'image/jpeg');
      final decoded = img.decodeImage(result.bytes)!;
      expect(decoded.width, 800);
      expect(decoded.height, 450);
    });

    test('keeps a small image unchanged', () {
      final original = _png(100, 100);

      final result = compressImageSync(original, maxDim: 800);

      expect(result, same(original));
    });

    test('keeps an animated gif unchanged', () {
      final original = (
        bytes: Uint8List.fromList([1, 2, 3]),
        mime: 'image/gif',
        ext: 'gif',
      );

      final result = compressImageSync(original);

      expect(result, same(original));
    });

    test('returns the original when decode fails', () {
      final original = (
        bytes: Uint8List.fromList([1, 2, 3]),
        mime: 'image/png',
        ext: 'png',
      );

      final result = compressImageSync(original);

      expect(result, same(original));
    });
  });
}
