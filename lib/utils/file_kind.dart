/// File kinds supported by the multi-view system.
enum FileKind { code, markdown, image, audio }

/// Known image extensions supported for direct viewing.
const kImageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
  '.ico',
  '.svg',
  '.tiff',
  '.tif',
  '.avif',
  '.heic',
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

/// Check whether [path] is an audio file based on extension.
bool isAudioFilePath(String path) => detectFileKind(path) == FileKind.audio;

/// Check whether [path] is a markdown file based on extension.
bool isMarkdownFilePath(String path) =>
    detectFileKind(path) == FileKind.markdown;
