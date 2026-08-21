import 'dart:typed_data';

import 'package:zmodem_lbp/src/buffer.dart';
import 'package:zmodem_lbp/src/consts.dart' as consts;
import 'package:zmodem_lbp/src/crc.dart';
import 'package:zmodem_lbp/src/metrics.dart';
import 'package:zmodem_lbp/src/zmodem_frame_types.dart';

enum _ParseState { expectHeader, expectData }

class ZModemParser implements Iterator<ZFrame> {
  final _buffer = ChunkBuffer();
  late final Iterator<ZFrame?> _parser = _createParser().iterator;
  ZFrame? _current;
  static const _maxDataSubpacketSize = 64 * 1024;

  /// Optional metrics collector for diagnostics and fuzz testing.
  ZModemMetrics? metrics;

  void Function(int)? onPlainText;
  void Function()? onCancel;

  /// Used to communicate back from the sub-gestors ([_parseHexHeader],
  /// [_parseBinaryPacket]) to the main state machine so it can decide the
  /// next state based on the type of header that was just yielded.
  int? _lastHeaderType;

  @override
  ZFrame get current {
    if (_current == null) {
      throw StateError('No frame has been parsed yet');
    }
    return _current!;
  }

  void addData(Uint8List data) {
    _buffer.add(data);
  }

  @override
  bool moveNext() {
    _parser.moveNext();
    final frame = _parser.current;
    if (frame == null) return false;
    _current = frame;
    return true;
  }

  Iterable<ZFrame?> _createParser() sync* {
    var state = _ParseState.expectHeader;
    final dataBuffer = BytesBuilder();

    while (true) {
      switch (state) {
        case _ParseState.expectHeader:
          if (_buffer.isNotEmpty && _buffer.peek() != consts.ZPAD) {
            _handleDirtyChar(_buffer.readByte());
            continue;
          }
          while (_buffer.length < 4) {
            yield null;
            continue;
          }
          if (_buffer.peek() == consts.ZPAD) {
            if (_buffer.peek(1) == consts.ZPAD &&
                _buffer.peek(2) == consts.ZDLE &&
                _buffer.peek(3) == consts.ZHEX) {
              _buffer.expect(consts.ZPAD);
              _buffer.expect(consts.ZPAD);
              _buffer.expect(consts.ZDLE);
              _buffer.expect(consts.ZHEX);
              yield* _parseHexHeader();
              state = _nextHeaderState();
              continue;
            }
            if (_buffer.peek(1) == consts.ZDLE &&
                _buffer.peek(2) == consts.ZBIN) {
              _buffer.expect(consts.ZPAD);
              _buffer.expect(consts.ZDLE);
              _buffer.expect(consts.ZBIN);
              yield* _parseBinaryPacket();
              state = _nextHeaderState();
              continue;
            }
          }
          _handleDirtyChar(_buffer.readByte());
          break;

        case _ParseState.expectData:
          while (true) {
            final char = _buffer.readEscaped();
            if (char == null) {
              yield null;
              break;
            }

            if (dataBuffer.length > _maxDataSubpacketSize) {
              throw StateError(
                'Data subpacket exceeded max size of $_maxDataSubpacketSize',
              );
            }

            if (char == (consts.ZCRCE | consts.ZDLEESC) ||
                char == (consts.ZCRCG | consts.ZDLEESC) ||
                char == (consts.ZCRCQ | consts.ZDLEESC) ||
                char == (consts.ZCRCW | consts.ZDLEESC)) {
              final terminator = char ^ consts.ZDLEESC;
              while (!_buffer.hasEscaped) {
                yield null;
              }
              final crcHi = _buffer.readEscaped();
              if (crcHi == null) {
                yield null;
                break;
              }
              while (!_buffer.hasEscaped) {
                yield null;
              }
              final crcLo = _buffer.readEscaped();
              if (crcLo == null) {
                yield null;
                break;
              }

              final receivedCrc = (crcHi << 8) | crcLo;
              final rawData = dataBuffer.takeBytes();
              final crcInput = Uint8List.fromList([...rawData, terminator]);
              final computedCrc = computeCrc16(crcInput);

              yield ZFrame(
                type: terminator,
                params: [],
                data: Uint8List.fromList(rawData),
                computedCrc: computedCrc,
                receivedCrc: receivedCrc,
                crcValid: computedCrc == receivedCrc,
                format: ZFrameFormat.dataSubpacket,
              );
              final m = metrics;
              if (m != null) {
                m.framesParsed++;
                m.dataSubpacketsParsed++;
                if (computedCrc != receivedCrc) {
                  m.invalidCrcCount++;
                }
                if (terminator == consts.ZCRCW) {
                  m.dataPacketReplyWait++;
                }
                if (terminator == consts.ZCRCQ || terminator == consts.ZCRCW) {
                  m.dataPacketsWithReply++;
                }
              }

              if (terminator == consts.ZCRCE || terminator == consts.ZCRCW) {
                state = _ParseState.expectHeader;
              }
              break;
            }

            dataBuffer.addByte(char);
          }
          break;
      }
    }
  }

  _ParseState _nextHeaderState() {
    if (_lastHeaderType == null) return _ParseState.expectHeader;
    final introduces = _lastHeaderType! == consts.ZFILE ||
        _lastHeaderType! == consts.ZSINIT ||
        _lastHeaderType! == consts.ZDATA;
    return introduces ? _ParseState.expectData : _ParseState.expectHeader;
  }

  Iterable<ZFrame?> _parseHexHeader() sync* {
    const asciiFields = 1 + 4 + 2;
    const headerLength = asciiFields * 2;

    while (_buffer.length < headerLength) {
      yield null;
    }

    final frameType = _buffer.readAsciiByte();
    final p0 = _buffer.readAsciiByte();
    final p1 = _buffer.readAsciiByte();
    final p2 = _buffer.readAsciiByte();
    final p3 = _buffer.readAsciiByte();
    final crcHigh = _buffer.readAsciiByte();
    final crcLow = _buffer.readAsciiByte();

    final receivedCrc = (crcHigh << 8) | crcLow;
    final computedCrc = computeCrc16([frameType, p0, p1, p2, p3]);

    while (_buffer.isEmpty) {
      yield null;
    }
    if (_buffer.peek() == consts.CR) {
      _buffer.readByte();
      while (_buffer.isEmpty) {
        yield null;
      }
    }
    _buffer.expect(consts.LF);

    _lastHeaderType = frameType;
    yield ZFrame(
      type: frameType,
      params: [p0, p1, p2, p3],
      data: Uint8List(0),
      computedCrc: computedCrc,
      receivedCrc: receivedCrc,
      crcValid: computedCrc == receivedCrc,
      format: ZFrameFormat.hexHeader,
    );
    final m = metrics;
    if (m != null) {
      m.framesParsed++;
      m.hexHeadersParsed++;
      if (computedCrc != receivedCrc) {
        m.invalidCrcCount++;
      }
    }
  }

  Iterable<ZFrame?> _parseBinaryPacket() sync* {
    while (_buffer.length < 7) {
      yield null;
    }
    while (!_buffer.hasEscaped) {
      yield null;
    }
    final frameType = _buffer.readEscaped()!;

    while (!_buffer.hasEscaped) {
      yield null;
    }
    final p0 = _buffer.readEscaped()!;

    while (!_buffer.hasEscaped) {
      yield null;
    }
    final p1 = _buffer.readEscaped()!;

    while (!_buffer.hasEscaped) {
      yield null;
    }
    final p2 = _buffer.readEscaped()!;

    while (!_buffer.hasEscaped) {
      yield null;
    }
    final p3 = _buffer.readEscaped()!;

    while (!_buffer.hasEscaped) {
      yield null;
    }
    final crcHigh = _buffer.readEscaped()!;

    while (!_buffer.hasEscaped) {
      yield null;
    }
    final crcLow = _buffer.readEscaped()!;

    final receivedCrc = (crcHigh << 8) | crcLow;
    final computedCrc = computeCrc16([frameType, p0, p1, p2, p3]);

    _lastHeaderType = frameType;
    yield ZFrame(
      type: frameType,
      params: [p0, p1, p2, p3],
      data: Uint8List(0),
      computedCrc: computedCrc,
      receivedCrc: receivedCrc,
      crcValid: computedCrc == receivedCrc,
      format: ZFrameFormat.binaryHeader,
    );
    final m = metrics;
    if (m != null) {
      m.framesParsed++;
      m.binaryHeadersParsed++;
      if (computedCrc != receivedCrc) {
        m.invalidCrcCount++;
      }
    }
  }

  var _consecutiveCanCount = 0;

  void _handleDirtyChar(int byte) {
    if (byte == consts.XON) return;
    if (byte == consts.CAN) {
      _consecutiveCanCount++;
      if (_consecutiveCanCount >= 5) {
        _consecutiveCanCount = 0;
        final m = metrics;
        if (m != null) {
          m.cancelCount++;
        }
        _handleCancel();
      }
      return;
    }
    _consecutiveCanCount = 0;
    final m = metrics;
    if (m != null) {
      m.dirtyCharCount++;
    }
    onPlainText?.call(byte);
  }

  void _handleCancel() {
    _buffer.clear();
    _consecutiveCanCount = 0;
    onCancel?.call();
  }
}

extension _ChunkBufferExtensions on ChunkBuffer {
  static int _toHex(int char) {
    if (char >= 0x30 && char <= 0x39) {
      return char - 0x30;
    } else if (char >= 0x41 && char <= 0x46) {
      return char - 0x41 + 10;
    } else if (char >= 0x61 && char <= 0x66) {
      return char - 0x61 + 10;
    } else {
      throw ArgumentError.value(char, 'char', 'Not a hex character');
    }
  }

  int readAsciiByte() {
    final high = _toHex(readByte());
    final low = _toHex(readByte());
    return high * 16 + low;
  }

  int? readEscaped() {
    if (isEmpty) {
      return null;
    }

    if (peek() != consts.ZDLE) {
      return readByte();
    }

    if (length < 2) {
      return null;
    }

    expect(consts.ZDLE);
    final byte = readByte();

    switch (byte) {
      case consts.ZCRCE:
      case consts.ZCRCG:
      case consts.ZCRCQ:
      case consts.ZCRCW:
        return byte | consts.ZDLEESC;
      case consts.ZRUB0:
        return 0x7f;
      case consts.ZRUB1:
        return 0xff;
      default:
        return byte ^ 0x40;
    }
  }

  bool get hasEscaped {
    final next = peek();

    if (next == consts.ZDLE) {
      return length >= 2;
    } else {
      return length >= 1;
    }
  }
}
