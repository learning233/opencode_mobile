import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zmodem_lbp/src/consts.dart' as consts;
import 'package:zmodem_lbp/src/zmodem_frame_types.dart';
import 'package:zmodem_lbp/src/zmodem_parser.dart';

/// State transition fuzz test: send valid frames in intentionally wrong order
/// and ensure the core never hangs, crashes, or enters unrecoverable states.
///
/// This tests the parser's robustness when frames arrive in invalid sequences
/// (as can happen during line noise or protocol violations).
void main() {
  group('State transition fuzz', () {
    test('hex header out of order does not crash', () {
      // Valid ZRINIT hex frame bytes as raw data
      final raw = Uint8List.fromList([
        0x2a, 0x2a, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
        // "0100000021" + CRC hex followed by CR LF XON
        0x30, 0x31, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x32,
        0x31, // type+params
        0x38, 0x31, 0x41, 0x45, // CRC
        0x0d, 0x0a, 0x11,
        // Second frame: ZFIN
        0x2a, 0x2a, 0x18, 0x42,
        0x30, 0x38, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30,
        0x41, 0x45, 0x30, 0x30,
        0x0d, 0x0a, 0x11,
      ]);
      final parser = ZModemParser();
      parser.addData(raw);

      int frameCount = 0;
      while (parser.moveNext()) {
        frameCount++;
      }
      expect(frameCount, greaterThan(0));
    });

    test('binary header with unexpected type does not crash', () {
      final raw = Uint8List.fromList([
        0x2a, 0x18, 0x41, // ZPAD ZDLE ZBIN
        0x10, // type = ZCAN (0x10)
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, // CRC placeholder
      ]);
      final parser = ZModemParser();
      parser.addData(raw);

      while (parser.moveNext()) {}
    });

    test('data subpacket with no preceding header does not crash', () {
      final raw = Uint8List.fromList([
        0x18, 0x6b, // ZDLE ZCRCW
        0x48, 0x65, 0x6c, 0x6c, 0x6f, // "Hello"
        0x18, 0x18, 0x58, // escaped ZDLE in data
        0x00, 0x00, // CRC placeholder
      ]);
      final parser = ZModemParser();
      parser.addData(raw);

      while (parser.moveNext()) {}
    });

    test('random bytes do not cause infinite loop', () {
      final rng = _SeededRng(99);
      for (var i = 0; i < 20; i++) {
        final bytes = Uint8List(rng.nextInt(256) + 8);
        for (var j = 0; j < bytes.length; j++) {
          bytes[j] = rng.nextInt(256);
        }
        final parser = ZModemParser();
        parser.addData(bytes);

        int steps = 0;
        while (parser.moveNext()) {
          steps++;
          if (steps > 10000) {
            fail('Infinite loop detected');
          }
        }
      }
    });

    test('valid frames after garbage are parsed correctly', () {
      final raw = Uint8List.fromList([
        // Garbage
        0xFF, 0xFE, 0xFD, 0x00, 0x01, 0x02, 0x03,
        // Valid ZRINIT hex header
        0x2a, 0x2a, 0x18, 0x42,
        0x30, 0x31, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x32, 0x31,
        0x38, 0x31, 0x41, 0x45,
        0x0d, 0x0a, 0x11,
      ]);
      final parser = ZModemParser();
      parser.addData(raw);

      final frames = <ZFrame>[];
      while (parser.moveNext()) {
        frames.add(parser.current);
      }

      expect(frames, isNotEmpty);
      expect(frames.any((f) => f.type == consts.ZRINIT), isTrue);
    });
  });
}

class _SeededRng {
  int _state;
  _SeededRng(this._state);

  int nextInt(int max) {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state % max;
  }
}
