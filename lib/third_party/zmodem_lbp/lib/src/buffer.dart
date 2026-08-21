import 'dart:collection';
import 'dart:typed_data';

class ChunkBuffer {
  /// The chunks that have been added to the buffer but not yet consumed. Each
  /// chunk is guaranteed to have at least one byte.
  final _backlog = Queue<Uint8List>();

  /// The number of bytes in the buffer that have not been consumed.
  var _length = 0;

  /// Read offset into [_chunkOffset].
  var _readOffset = 0;

  Uint8List? _currentChunk;

  Uint8List? get currentChunk => _currentChunk;

  /// Number of bytes in the buffer that have not been consumed.
  int get length => _length;

  bool get isEmpty => _length == 0;

  bool get isNotEmpty => _length > 0;

  void clear() {
    _backlog.clear();
    _currentChunk = null;
    _length = 0;
    _readOffset = 0;
  }

  void add(Uint8List chunk) {
    if (chunk.isEmpty) {
      return;
    }
    if (_currentChunk != null) {
      _backlog.add(chunk);
    } else {
      _currentChunk = chunk;
    }
    _length += chunk.length;
  }

  void expect(int byte) {
    final actual = readByte();

    if (actual != byte) {
      throw StateError(
        'Expected 0x${byte.toRadixString(16)}, got 0x${actual.toRadixString(16)}',
      );
    }
  }

  int? peek([int offset = 0]) {
    var currentChunk = _currentChunk;

    if (currentChunk == null) {
      return null;
    }

    if (_readOffset + offset < currentChunk.length) {
      return currentChunk[_readOffset + offset];
    }
    offset -= (currentChunk.length - _readOffset);

    for (var chunk in _backlog) {
      if (offset < chunk.length) {
        return chunk[offset];
      }
      offset -= chunk.length;
    }

    return null;
  }

  int readByte() {
    while (true) {
      var currentChunk = _currentChunk;

      if (currentChunk == null) {
        throw StateError('No chunk has been added to the buffer yet');
      }

      if (_readOffset < currentChunk.length) {
        _length--;
        return currentChunk[_readOffset++];
      }

      if (_backlog.isEmpty) {
        throw StateError('No more bytes to read');
      }

      _currentChunk = _backlog.removeFirst();
      _readOffset = 0;
    }
  }
}
