import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app_logger.dart';

/// Local on-device cache for sent image parts, keyed by `<messageId>_<partId>`.
///
/// The server stores image parts inline as base64 data URLs, so re-rendering
/// history must `base64Decode` each one on the main thread. Reading the cached
/// file instead avoids that cost. Part ids are client-generated (`prt_xxx`) and
/// preserved by the server across history fetches, so the same key hits after a
/// restart or a session re-open.
class ImageCache {
  ImageCache({Directory? baseDir}) : _baseDir = baseDir;

  final Directory? _baseDir;

  static const _dirName = 'image_cache';

  Future<Directory> _dir() async {
    final root = _baseDir ?? await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, _dirName));
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> write(String messageId, String partId, List<int> bytes) async {
    try {
      final dir = await _dir();
      await File(p.join(dir.path, '${messageId}_$partId.img'))
          .writeAsBytes(bytes, flush: true);
    } catch (e) {
      AppLogger.e('ImageCache.write failed: $e');
    }
  }

  Future<File?> find(String messageId, String partId) async {
    try {
      final dir = await _dir();
      final file = File(p.join(dir.path, '${messageId}_$partId.img'));
      if (await file.exists()) return file;
    } catch (e) {
      AppLogger.e('ImageCache.find failed: $e');
    }
    return null;
  }

  /// Delete cache files not modified within [maxAge]. Call once at startup to
  /// stop the cache from growing without bound.
  Future<void> cleanup({Duration maxAge = const Duration(days: 7)}) async {
    try {
      final dir = await _dir();
      final now = DateTime.now();
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          if (now.difference(stat.modified) > maxAge) {
            await entity.delete();
          }
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.e('ImageCache.cleanup failed: $e');
    }
  }
}

/// Shared instance used by the send path and message rendering.
final defaultImageCache = ImageCache();
