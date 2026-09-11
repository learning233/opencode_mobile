/// File kinds supported by the multi-view system.
enum FileKind { code, markdown, image, audio }

/// Known image extensions (broad set, used for kind detection).
const kImageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
  '.wbmp',
  '.ico',
  '.svg',
  '.tiff',
  '.tif',
  '.avif',
  '.heic',
  '.heif',
};

/// Flutter 原生解码器（Skia `ui.instantiateImageCodec` / `Image.memory`）
/// 可直接渲染的子集：JPEG/PNG/GIF（含动图)/WebP（含动图)/BMP/WBMP。
/// svg/ico/tiff/tif/avif/heic/heif 不在此列（svg 需 flutter_svg，
/// ico/tiff/avif/heic 需 image 包或原生解码），UI 应显示“不支持”而非空白。
const kPreviewableImageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
  '.wbmp',
};

/// Known audio extensions supported for direct playback.
const kAudioExtensions = {
  '.mp3',
  '.wav',
  '.m4a',
  '.aac',
  '.ogg',
  '.oga',
  '.opus',
  '.flac',
  '.wma',
};

/// Known markdown extensions supported for rich preview.
const kMarkdownExtensions = {'.md', '.markdown', '.mdown', '.mkdn'};

/// Detect the [FileKind] from file [path] and optional [mimeType].
FileKind detectFileKind(String path, {String? mimeType}) {
  if (mimeType != null && mimeType.isNotEmpty) {
    final lowerMime = mimeType.toLowerCase();
    if (lowerMime.startsWith('image/')) return FileKind.image;
    if (lowerMime.startsWith('audio/')) return FileKind.audio;
    if (lowerMime == 'text/markdown' || lowerMime == 'text/x-markdown') {
      return FileKind.markdown;
    }
  }

  final dotIdx = path.lastIndexOf('.');
  if (dotIdx == -1) return FileKind.code;
  final ext = path.substring(dotIdx).toLowerCase();

  if (kImageExtensions.contains(ext)) return FileKind.image;
  if (kAudioExtensions.contains(ext)) return FileKind.audio;
  if (kMarkdownExtensions.contains(ext)) return FileKind.markdown;

  return FileKind.code;
}

/// Check whether [path] is an image file based on extension.
bool isImageFilePath(String path) => detectFileKind(path) == FileKind.image;

/// Check whether [path] can be rendered by Flutter's native image codec.
/// svg/ico/tiff/avif/heic 等返回 false，调用方应显示“不支持”占位。
bool isPreviewableImageFilePath(String path) {
  final dotIdx = path.lastIndexOf('.');
  if (dotIdx == -1) return false;
  final ext = path.substring(dotIdx).toLowerCase();
  return kPreviewableImageExtensions.contains(ext);
}

/// Check whether [path] is an audio file based on extension.
bool isAudioFilePath(String path) => detectFileKind(path) == FileKind.audio;

/// Check whether [path] is a markdown file based on extension.
bool isMarkdownFilePath(String path) =>
    detectFileKind(path) == FileKind.markdown;
