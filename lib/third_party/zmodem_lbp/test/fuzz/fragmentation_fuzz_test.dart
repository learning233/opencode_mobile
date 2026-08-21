import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zmodem_lbp/src/zmodem_frame_types.dart';
import 'package:zmodem_lbp/src/zmodem_parser.dart';

/// Fuzz test: feed the parser with valid ZMODEM data split into fragments
/// of varying sizes to detect state machine bugs in the chunk buffer.
///
/// Ensures that byte-level fragmentation (network splits, small read buffers)
/// does not cause frame corruption, hangs, or crashes.
void main() {
  late Uint8List sessionData;

  setUp(() async {
    sessionData = await File('test/fixture/session1.bin').readAsBytes();
  });

  group('Fragmentation fuzz', () {
    test('byte-at-a-time produces same frames as bulk', () {
      final bulkParser = ZModemParser();
      bulkParser.addData(sessionData);
      final bulkFrames = _collectFrames(bulkParser);

      final fragmentParser = ZModemParser();
      for (var i = 0; i < sessionData.length; i++) {
        fragmentParser.addData(Uint8List.fromList([sessionData[i]]));
      }
      final fragmentFrames = _collectFrames(fragmentParser);

      expect(fragmentFrames.length, bulkFrames.length);
      for (var i = 0; i < bulkFrames.length; i++) {
        expect(fragmentFrames[i].type, bulkFrames[i].type);
        expect(fragmentFrames[i].format, bulkFrames[i].format);
        expect(fragmentFrames[i].crcValid, bulkFrames[i].crcValid);
        expect(fragmentFrames[i].data.length, bulkFrames[i].data.length);
        expect(fragmentFrames[i].params, bulkFrames[i].params);
      }
    });

    test('random chunk sizes produce same frames', () {
      final bulkParser = ZModemParser();
      bulkParser.addData(sessionData);
      final bulkFrames = _collectFrames(bulkParser);

      final rng = _SeededRng(42);
      final chunkSizeParser = ZModemParser();
      var offset = 0;
      while (offset < sessionData.length) {
        final chunkSize = 1 + rng.nextInt(32);
        final end = (offset + chunkSize).clamp(0, sessionData.length);
        chunkSizeParser.addData(sessionData.sublist(offset, end));
        offset = end;
      }
      final chunkFrames = _collectFrames(chunkSizeParser);

      expect(chunkFrames.length, bulkFrames.length);
      for (var i = 0; i < bulkFrames.length; i++) {
        expect(chunkFrames[i].type, bulkFrames[i].type);
        expect(chunkFrames[i].format, bulkFrames[i].format);
      }
    });

    test('noise around each byte segment does not crash', () {
      for (var i = 0; i < sessionData.length; i += 100) {
        final end = (i + 50).clamp(0, sessionData.length);
        final segment = sessionData.sublist(i, end);
        final noise =
            Uint8List.fromList([0x00, 0xFF, 0x55, ...segment, 0xAA, 0xBB]);
        final parser = ZModemParser();
        parser.addData(noise);
        // Should not crash. May or may not produce frames.
        _collectFrames(parser);
      }
    });

    test('large fragmentation soaks', () {
      const seed = 12345;
      final rng = _SeededRng(seed);
      for (var i = 0; i < 50; i++) {
        final parser = ZModemParser();
        var offset = 0;
        while (offset < sessionData.length) {
          final chunk = 1 + rng.nextInt(128);
          final end = (offset + chunk).clamp(0, sessionData.length);
          parser.addData(sessionData.sublist(offset, end));
          offset = end;
        }
        // Drain completely
        while (parser.moveNext()) {
          // consume
        }
      }
    });
  });
}

List<ZFrame> _collectFrames(ZModemParser parser) {
  final frames = <ZFrame>[];
  while (parser.moveNext()) {
    frames.add(parser.current);
  }
  return frames;
}

class _SeededRng {
  int _state;
  _SeededRng(this._state);

  int nextInt(int max) {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state % max;
  }
}
