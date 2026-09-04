import 'dart:async';
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

  static const int _defaultMaxFiles = 200;
  static const int _defaultMaxTotalBytes = 100 * 1024 * 1024; // 100MB

  bool _isValidId(String id) =>
      id.isNotEmpty && !id.contains('/') && !id.contains('\\');

  Future<void> write(String messageId, String partId, List<int> bytes) async {
    if (!_isValidId(messageId) || !_isValidId(partId)) return;
    try {
      final dir = await _dir();
      await File(
        p.join(dir.path, '${messageId}_$partId.img'),
      ).writeAsBytes(bytes, flush: true);
    } catch (e) {
      AppLogger.e('ImageCache.write failed: $e');
    }
  }

  Future<File?> find(
    String messageId,
    String partId, {
    bool touch = true,
  }) async {
    if (!_isValidId(messageId) || !_isValidId(partId)) return null;
    try {
      final dir = await _dir();
      final file = File(p.join(dir.path, '${messageId}_$partId.img'));
      if (await file.exists()) {
        if (touch) {
          try {
            await file.setLastModified(DateTime.now());
          } catch (_) {}
        }
        return file;
      }
    } catch (e) {
      AppLogger.e('ImageCache.find failed: $e');
    }
    return null;
  }

  /// Delete cache files not modified within [maxAge] or exceeding [maxFiles] / [maxTotalBytes].
  /// Call once at startup to stop the cache from growing without bound.
  Future<void> cleanup({
    Duration maxAge = const Duration(days: 7),
    int maxFiles = _defaultMaxFiles,
    int maxTotalBytes = _defaultMaxTotalBytes,
  }) async {
    try {
      final dir = await _dir();
      if (!await dir.exists()) return;
      final now = DateTime.now();
      final entries = <File, ({DateTime modified, int size})>{};
      var total = 0;

      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.img')) continue;
        try {
          final stat = await entity.stat();
          if (now.difference(stat.modified) > maxAge) {
            await entity.delete();
          } else {
            entries[entity] = (modified: stat.modified, size: stat.size);
            total += stat.size;
          }
        } catch (_) {}
      }

      // 超额容量淘汰：若未过期文件依然超出上限，按 mtime 从旧到新删除
      if (entries.length <= maxFiles && total <= maxTotalBytes) return;
      final byOldest = entries.keys.toList()
        ..sort((a, b) => entries[a]!.modified.compareTo(entries[b]!.modified));
      for (final file in byOldest) {
        if (entries.length <= maxFiles && total <= maxTotalBytes) return;
        final info = entries.remove(file);
        total -= info?.size ?? 0;
        try {
          await file.delete();
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.e('ImageCache.cleanup failed: $e');
    }
  }
}

/// Shared instance used by the send path and message rendering.
final defaultImageCache = ImageCache();
