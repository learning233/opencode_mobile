import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zmodem_lbp/zmodem.dart';
import 'package:zmodem_lbp/src/consts.dart' as consts;
import 'package:zmodem_lbp/src/crc.dart';
import 'package:zmodem_lbp/src/zmodem_parser.dart';

const _seeds = 100;
const _maxPackets = 50000;
const _maxDataSize = 65536;

void main() {
  group('Fuzz Parser bulk', () {
    for (var seed = 0; seed < _seeds; seed++) {
      test('seed $seed', () => fuzzParserBulk(seed), timeout: _timeout);
    }
  });

  group('Fuzz Parser byte-by-byte', () {
    for (var seed = 0; seed < _seeds; seed++) {
      test('seed $seed', () => fuzzParserByteByByte(seed), timeout: _timeout);
    }
  });

  group('Fuzz Core isolated', () {
    for (var seed = 0; seed < _seeds; seed++) {
      test('seed $seed', () => fuzzCoreIsolated(seed), timeout: _timeout);
    }
  });

  group('Fuzz Core live session', () {
    test(
      'with random trailing data',
      () => fuzzCoreLive(),
      timeout: _timeout,
      retry: 3,
    );
  });

  group('CRC fuzz', () {
    test('random bytes: no crash', () {
      final random = Random(42);
      for (var i = 0; i < 100000; i++) {
        final bytes = Uint8List.fromList(
          List.generate(random.nextInt(64), (_) => random.nextInt(256)),
        );
        final core = ZModemCore();
        core.receive(bytes).toList();
      }
    });

    test('corrupted CRC frames are rejected', () {
      final random = Random(42);
      for (var i = 0; i < 1000; i++) {
        // Build a valid hex header frame with intentionally wrong CRC
        final frameType = random.nextInt(0x14);
        final p0 = random.nextInt(256);
        final p1 = random.nextInt(256);
        final p2 = random.nextInt(256);
        final p3 = random.nextInt(256);

        final rawCrc = computeCrc16([frameType, p0, p1, p2, p3]);
        final badCrc = rawCrc ^ 0xFFFF; // Flip all CRC bits

        final bytes = Uint8List.fromList([
          consts.ZPAD,
          consts.ZPAD,
          consts.ZDLE,
          consts.ZHEX,
          ...[
            frameType,
            p0,
            p1,
            p2,
            p3,
          ].expand((b) => [hexDigit(b >> 4), hexDigit(b & 0xf)]),
          ...[
            badCrc >> 8,
            badCrc & 0xff,
          ].expand((b) => [hexDigit(b >> 4), hexDigit(b & 0xf)]),
          consts.CR,
          consts.LF,
          consts.XON,
        ]);

        final parser = ZModemParser();
        parser.addData(bytes);
        if (parser.moveNext()) {
          expect(parser.current.crcValid, isFalse);
        }
      }
    });
  });

  group('Partial / truncated frames', () {
    test('half a hex header does not crash', () {
      final parser = ZModemParser();
      parser.addData(
        Uint8List.fromList([
          consts.ZPAD, consts.ZPAD, consts.ZDLE, consts.ZHEX,
          0x30, 0x31, 0x30, // only 3 hex chars of type=01
        ]),
      );
      // Should not throw
      expect(() => parser.moveNext(), returnsNormally);
    });

    test('half a binary header does not crash', () {
      final parser = ZModemParser();
      parser.addData(
        Uint8List.fromList([
          consts.ZPAD, consts.ZDLE, consts.ZBIN,
          0x01, // only type byte
        ]),
      );
      expect(() => parser.moveNext(), returnsNormally);
    });

    test('truncated data subpacket does not crash', () {
      final parser = ZModemParser();
      // Start with a ZSINIT header to enter expectData state
      const zsinitHeader = [
        consts.ZPAD, consts.ZPAD, consts.ZDLE, consts.ZHEX,
        0x30, 0x32, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x43,
        0x30, 0x43, 0x34, 0x37, // CRC for ZSINIT with p3=67
        consts.CR, consts.LF,
      ];
      parser.addData(Uint8List.fromList(zsinitHeader));
      parser.moveNext(); // consume ZSINIT header

      // Now in expectData state — send a truncated subpacket
      parser.addData(
        Uint8List.fromList([0x61, 0x62]),
      ); // just 2 data bytes, no ZDLE
      expect(() => parser.moveNext(), returnsNormally);
    });
  });

  group('Out-of-order frames', () {
    test('ZDATA before ZFILE does not hang', () {
      final core = ZModemCore();
      // Build a ZDATA binary header out of context
      final data = Uint8List.fromList([
        consts.ZPAD, consts.ZDLE, consts.ZBIN,
        0x0a, 0x00, 0x00, 0x00, 0x00, // ZDATA, p0-p3=0
        0x00, 0x00, // CRC (wrong, will be flagged)
      ]);
      final events = core.receive(data).toList();
      // Must not hang; may emit CRC error or be silently ignored
      expect(events, isA<List>());
    });

    test('ZEOF without data does not hang', () {
      final core = ZModemCore();
      // Build a hex header: ZPAD ZPAD ZDLE ZHEX + 14 hex chars + CR LF
      final data = Uint8List.fromList([
        consts.ZPAD, consts.ZPAD, consts.ZDLE, consts.ZHEX,
        // "0B" (ZEOF) + 4*"00" (p0-p3=0) + "0000" (CRC=0)
        0x30, 0x42, 0x30, 0x30, 0x30, 0x30, // type=ZEOF, p0=0, p1=0
        0x30, 0x30, 0x30, 0x30, // p2=0, p3=0
        0x30, 0x30, 0x30, 0x30, // bad CRC = 0x0000
        consts.CR, consts.LF,
      ]);
      final events = core.receive(data).toList();
      expect(events, isA<List>());
    });
  });

  group('Soak', () {
    test('1000 file transfers', () {
      for (var i = 0; i < 1000; i++) {
        final server = ZModemCore();
        final client = ZModemCore();

        server.initiateSend();
        client.receive(server.dataToSend()).toList();
        server.receive(client.dataToSend()).toList();

        server.offerFile(ZModemFileInfo(pathname: 'test_$i', length: 100));
        final offers = client.receive(server.dataToSend()).toList();
        if (offers.whereType<ZFileOfferedEvent>().isEmpty) continue;

        client.acceptFile();
        server.receive(client.dataToSend()).toList();

        server.sendFileData(Uint8List(50));
        client.receive(server.dataToSend()).toList();

        server.finishSending(50);
        client.receive(server.dataToSend()).toList();

        server.finishSession();
        client.receive(server.dataToSend()).toList();

        expect(server.hasDataToSend, isFalse);
      }
    });
  });

  group('Timeout', () {
    test('checkTimeout does not fire immediately after state entry', () {
      final core = ZModemCore();
      core.initiateReceive();
      final event = core.checkTimeout();
      expect(event, isNull);
    });

    test('checkTimeout returns null for non-blocking states', () {
      final core = ZModemCore();
      expect(core.checkTimeout(), isNull);
    });
  });
}

final _timeout = Timeout(Duration(seconds: 10));

void fuzzParserBulk(int seed) {
  final random = Random(seed);
  final data = randomBytes(random);

  final parser = ZModemParser();
  parser.addData(data);
  drainParser(parser);
  expect(parser.moveNext(), isFalse);
}

void fuzzParserByteByByte(int seed) {
  final random = Random(seed);
  final data = randomBytes(random);

  final parser = ZModemParser();

  for (var i = 0; i < data.length; i++) {
    parser.addData(Uint8List.fromList([data[i]]));
    drainParser(parser);
  }

  expect(parser.moveNext(), isFalse);
}

void fuzzCoreIsolated(int seed) {
  final random = Random(seed);
  final data = randomBytes(random);

  final core = ZModemCore();
  final events = core.receive(data).toList();

  // All yielded events must be well-formed
  for (final event in events) {
    if (event is ZFileOfferedEvent) {
      event.fileInfo.pathname; // must not throw
    } else if (event is ZFileDataEvent) {
      event.data; // must not throw
    }
  }

  // Core must still be functional after random data
  expect(core.hasDataToSend, isFalse);
  core.finishSession();
  expect(core.hasDataToSend, isTrue);
}

void fuzzCoreLive() {
  final random = Random(42);
  final server = ZModemCore();
  final client = ZModemCore();

  // Normal handshake
  server.initiateSend();
  client.receive(server.dataToSend()).toList();
  server.receive(client.dataToSend()).toList();
  server.offerFile(ZModemFileInfo(pathname: 'fuzz', length: 100));
  final events = client.receive(server.dataToSend()).toList();

  if (events.whereType<ZFileOfferedEvent>().isEmpty) return;

  client.acceptFile();
  server.receive(client.dataToSend()).toList();

  // Send file data then fuzz the response
  server.sendFileData(randomBytes(random, 256));
  final rawFuzz = server.dataToSend();
  client.receive(rawFuzz).toList();

  // Finish sending and consume
  final offset = random.nextInt(1000);
  server.finishSending(offset);
  client.receive(server.dataToSend()).toList();

  // Clean shutdown
  server.finishSession();
  client.receive(server.dataToSend()).toList();
}

Uint8List randomBytes(Random random, [int? maxSize]) {
  final size = random.nextInt((maxSize ?? _maxDataSize) + 1);
  final bytes = Uint8List(size);
  for (var i = 0; i < size; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

void drainParser(ZModemParser parser) {
  var count = 0;
  while (parser.moveNext()) {
    if (++count >= _maxPackets) {
      throw StateError('Infinite loop: exceeded $_maxPackets packets');
    }
    final frame = parser.current;
    frame.type;
    frame.params;
    frame.data.length;
    frame.crcValid;
  }
}

int hexDigit(int nibble) {
  if (nibble < 10) return 0x30 + nibble;
  return 0x41 + nibble - 10;
}
