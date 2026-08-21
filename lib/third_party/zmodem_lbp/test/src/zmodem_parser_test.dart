import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zmodem_lbp/src/zmodem_frame_types.dart';
import 'package:zmodem_lbp/src/zmodem_parser.dart';
import 'package:zmodem_lbp/src/consts.dart' as consts;

void main() async {
  final session1Data = await File('test/fixture/session1.bin').readAsBytes();

  group('ZModemParser', () {
    test('works with automatic state machine', () async {
      final parser = ZModemParser();
      parser.addData(session1Data);

      checkFrame(parser, consts.ZSINIT, ZFrameFormat.hexHeader, true);
      // Fixture has invalid CRC on the attn subpacket after ZSINIT
      checkFrame(parser, consts.ZCRCW, ZFrameFormat.dataSubpacket, false, 2);
      checkFrame(parser, consts.ZFILE, ZFrameFormat.binaryHeader, true);
      checkFrame(parser, consts.ZCRCW, ZFrameFormat.dataSubpacket, true, 26);
      checkFrame(parser, consts.ZDATA, ZFrameFormat.binaryHeader, true);
      checkFrame(parser, consts.ZCRCG, ZFrameFormat.dataSubpacket, true, 107);
      checkFrame(parser, consts.ZCRCE, ZFrameFormat.dataSubpacket, true, 0);
      checkFrame(parser, consts.ZEOF, ZFrameFormat.hexHeader, true);
      checkFrame(parser, consts.ZFIN, ZFrameFormat.hexHeader, true);
    });

    test('works byte by byte', () {
      final parser = ZModemParser();

      for (final byte in session1Data) {
        parser.addData(Uint8List.fromList([byte]));
      }

      checkFrame(parser, consts.ZSINIT, ZFrameFormat.hexHeader, true);
      checkFrame(parser, consts.ZCRCW, ZFrameFormat.dataSubpacket, false, 2);
      checkFrame(parser, consts.ZFILE, ZFrameFormat.binaryHeader, true);
      checkFrame(parser, consts.ZCRCW, ZFrameFormat.dataSubpacket, true, 26);
      checkFrame(parser, consts.ZDATA, ZFrameFormat.binaryHeader, true);
      checkFrame(parser, consts.ZCRCG, ZFrameFormat.dataSubpacket, true, 107);
      checkFrame(parser, consts.ZCRCE, ZFrameFormat.dataSubpacket, true, 0);
      checkFrame(parser, consts.ZEOF, ZFrameFormat.hexHeader, true);
      checkFrame(parser, consts.ZFIN, ZFrameFormat.hexHeader, true);
    });

    test('corrupt CRC hex header yields crcValid == false', () {
      final parser = ZModemParser();
      final bytes = Uint8List.fromList([
        // Build a hex header: ZPAD ZPAD ZDLE ZHEX type p0 p1 p2 p3 crcHi crcLo CR LF XON
        consts.ZPAD, consts.ZPAD, consts.ZDLE, consts.ZHEX,
        // type=ZRINIT (0x01), p0=0, p1=0, p2=0, p3=64 (CANFDX|CANOVIO)
        ...[
          0x30,
          0x31,
          0x30,
          0x30,
          0x30,
          0x30,
          0x30,
          0x30,
          0x34,
          0x30,
        ], // 01 00 00 00 40
        // CRC: deliberately wrong (all zeros instead of correct value)
        ...[0x30, 0x30, 0x30, 0x30], // 00 00
        consts.CR, consts.LF, consts.XON,
      ]);
      parser.addData(bytes);
      expect(parser.moveNext(), isTrue);
      final frame = parser.current;
      expect(frame.format, ZFrameFormat.hexHeader);
      expect(frame.crcValid, isFalse);
    });
  });
}

void checkFrame(
  ZModemParser parser,
  int type,
  ZFrameFormat format,
  bool crcValid, [
  int? dataLength,
]) {
  expect(parser.moveNext(), isTrue);
  final frame = parser.current;
  expect(frame.type, type);
  expect(frame.format, format);
  expect(frame.crcValid, crcValid);
  if (dataLength != null) {
    expect(frame.data.length, dataLength);
  }
}
