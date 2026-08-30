import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import '../models/session_runtime_state.dart';

/// Compress a single picked image so the server-stored history payload stays
/// small. opencode stores image parts inline as base64 data URLs, so every
/// history fetch re-downloads them; shrinking the image here is the only
/// client-side lever for that volume.
///
/// - Animated GIF and HEIC are returned unchanged (cannot be safely re-encoded).
/// - Images already within [maxDim] that are not JPEG are returned unchanged.
/// - Otherwise the image is downscaled (never upscaled) to fit [maxDim] on its
///   longest edge and re-encoded: JPEG → JPEG at [quality], everything else → PNG.
///
/// Pure and log-free so it is safe to run on a background isolate.
PickedImage compressImageSync(
  PickedImage image, {
  int maxDim = 1280,
  int quality = 85,
}) {
  final ext = image.ext.toLowerCase();
  if (ext == 'gif' || ext == 'heic' || ext == 'heif') return image;
  try {
    final decoded = img.decodeImage(image.bytes);
    if (decoded == null) return image;
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final isJpeg = ext == 'jpg' || ext == 'jpeg';
    if (longest <= maxDim && !isJpeg) return image;

    var resized = decoded;
    if (longest > maxDim) {
      final scale = maxDim / longest;
      resized = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }
    final bytes = isJpeg
        ? img.encodeJpg(resized, quality: quality)
        : img.encodePng(resized);
    return (
      bytes: Uint8List.fromList(bytes),
      mime: isJpeg ? 'image/jpeg' : 'image/png',
      ext: isJpeg ? 'jpg' : 'png',
    );
  } catch (_) {
    return image;
  }
}

/// Compress a batch of images. Intended to run inside [Isolate.run] so the
/// decode/resize/encode work never blocks the UI isolate.
List<PickedImage> compressImagesSync(
  List<PickedImage> images, {
  int maxDim = 1280,
  int quality = 85,
}) {
  return [
    for (final image in images)
      compressImageSync(image, maxDim: maxDim, quality: quality),
  ];
}

/// Compress a batch of images and base64-encode them in the same pass.
///
/// Encoding is deliberately done here (not on the caller's isolate): several
/// megabytes of `base64Encode` would otherwise stall the UI thread at send
/// time. Returns one record per input image, in order, with the (possibly
/// unchanged) image plus its data-URL-ready base64 string.
List<({PickedImage image, String base64})> compressAndEncodeImagesSync(
  List<PickedImage> images, {
  int maxDim = 1280,
  int quality = 85,
}) {
  return [
    for (final image in compressImagesSync(
      images,
      maxDim: maxDim,
      quality: quality,
    ))
      (image: image, base64: base64Encode(image.bytes)),
  ];
}
