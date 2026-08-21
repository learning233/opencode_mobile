import 'dart:typed_data';

import 'package:zmodem_lbp/src/consts.dart' as consts;
import 'package:zmodem_lbp/src/crc.dart';
import 'package:zmodem_lbp/src/escape.dart';
import 'package:zmodem_lbp/src/util/int.dart';
import 'package:zmodem_lbp/src/util/string.dart';
import 'package:zmodem_lbp/src/zmodem_fileinfo.dart';

abstract class ZModemPacket {
  int get type;

  // bool get isCorrupted;

  // bool? get isBinaryFormat;

  Uint8List encode();
}

class ZModemHeader implements ZModemPacket {
  @override
  final int type;

  final int p0;
  final int p1;
  final int p2;
  final int p3;

  final bool isBinary;

  ZModemHeader(
    this.type,
    this.p0,
    this.p1,
    this.p2,
    this.p3, {
    this.isBinary = false,
  });

  factory ZModemHeader._littleEndian(
    int type,
    int value, {
    bool isBinary = false,
  }) {
    return ZModemHeader(
      type,
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
      isBinary: isBinary,
    );
  }

  factory ZModemHeader.rqinit() {
    return ZModemHeader(consts.ZRQINIT, 0, 0, 0, 0);
  }

  factory ZModemHeader.rinit() {
    return ZModemHeader(consts.ZRINIT, 0, 0, 0, consts.CANFDX | consts.CANOVIO);
  }

  factory ZModemHeader.ack() {
    return ZModemHeader(consts.ZACK, 0, 0, 0, 0);
  }

  factory ZModemHeader.rpos(int offset) {
    return ZModemHeader._littleEndian(consts.ZRPOS, offset);
  }

  factory ZModemHeader.fin() {
    return ZModemHeader(consts.ZFIN, 0, 0, 0, 0);
  }

  factory ZModemHeader.file() {
    return ZModemHeader(consts.ZFILE, 0, 0, 0, 0, isBinary: true);
  }

  factory ZModemHeader.skip() {
    return ZModemHeader(consts.ZSKIP, 0, 0, 0, 0);
  }

  factory ZModemHeader.data(int offset) {
    return ZModemHeader._littleEndian(consts.ZDATA, offset, isBinary: true);
  }

  factory ZModemHeader.eof(int offset) {
    return ZModemHeader._littleEndian(consts.ZEOF, offset, isBinary: true);
  }

  @override
  String toString() {
    final type = _frameTypeToString(this.type);
    return 'ZModemHeader($type, ${p0.hex}, ${p1.hex}, ${p2.hex}, ${p3.hex})';
  }

  @override
  Uint8List encode() {
    return isBinary ? toBinary() : toHex();
  }

  Uint8List toBinary() {
    final buffer = BytesBuilder();
    buffer.addByte(consts.ZPAD);
    buffer.addByte(consts.ZDLE);
    buffer.addByte(consts.ZBIN);
    buffer.addEscapedByte(type);
    buffer.addEscapedByte(p0);
    buffer.addEscapedByte(p1);
    buffer.addEscapedByte(p2);
    buffer.addEscapedByte(p3);
    final crc = CRC16()
      ..update(type)
      ..update(p0)
      ..update(p1)
      ..update(p2)
      ..update(p3)
      ..finalize();
    buffer.addEscapedByte(crc.value >> 8);
    buffer.addEscapedByte(crc.value & 0xff);
    return buffer.takeBytes();
  }

  Uint8List toHex() {
    final buffer = StringBuffer();
    buffer.writeCharCode(consts.ZPAD);
    buffer.writeCharCode(consts.ZPAD);
    buffer.writeCharCode(consts.ZDLE);
    buffer.writeCharCode(consts.ZHEX);
    buffer.write(byteToHex(type));
    buffer.write(byteToHex(p0));
    buffer.write(byteToHex(p1));
    buffer.write(byteToHex(p2));
    buffer.write(byteToHex(p3));
    final crc = CRC16()
      ..update(type)
      ..update(p0)
      ..update(p1)
      ..update(p2)
      ..update(p3)
      ..finalize();
    buffer.write(byteToHex(crc.value >> 8));
    buffer.write(byteToHex(crc.value & 0xff));
    buffer.writeCharCode(consts.CR);
    buffer.writeCharCode(consts.LF);
    buffer.writeCharCode(consts.XON);
    return Uint8List.fromList(buffer.toString().codeUnits);
  }
}

class ZModemDataPacket implements ZModemPacket {
  @override
  final int type;

  final Uint8List data;

  ZModemDataPacket(this.type, this.data);

  factory ZModemDataPacket.fileInfo(ZModemFileInfo fileInfo) {
    final buffer = BytesBuilder();
    writeCString(buffer, fileInfo.pathname);

    final properties = StringBuffer();
    if (fileInfo.length != null) {
      properties.write(fileInfo.length);
      properties.write(' ${fileInfo.modificationTime ?? 0}');
      if (fileInfo.mode != null) {
        properties.write(' ${fileInfo.mode}');
        if (fileInfo.filesRemaining != null) {
          properties.write(' 0'); // serial number, must be 0
          properties.write(' ${fileInfo.filesRemaining}');
          if (fileInfo.bytesRemaining != null) {
            properties.write(' ${fileInfo.bytesRemaining}');
          }
        }
      }
    }
    writeCString(buffer, properties.toString());

    return ZModemDataPacket(consts.ZCRCW, buffer.takeBytes());
  }

  factory ZModemDataPacket.fileData(
    Uint8List data, {
    bool reply = false,
    bool eof = false,
  }) {
    final type = reply
        ? eof
            ? consts.ZCRCW
            : consts.ZCRCQ
        : eof
            ? consts.ZCRCE
            : consts.ZCRCG;
    return ZModemDataPacket(type, data);
  }

  @override
  Uint8List encode() {
    return toBinary();
  }

  Uint8List toBinary() {
    final buffer = BytesBuilder();
    buffer.addEscapedData(data);
    buffer.addByte(consts.ZDLE);
    buffer.addByte(type);
    final crc = CRC16()
      ..updateAll(data)
      ..update(type)
      ..finalize();
    buffer.addEscapedByte(crc.value >> 8);
    buffer.addEscapedByte(crc.value & 0xff);
    return buffer.takeBytes();
  }

  @override
  String toString() {
    final type = _frameTypeToString(this.type);
    return 'ZModemDataPacket($type, ${data.length})';
  }
}

String byteToHex(int byte) {
  assert(byte >= 0 && byte <= 255);
  final result = byte.toRadixString(16);
  return result.length == 1 ? '0$result' : result;
}

String _frameTypeToString(int type) {
  switch (type) {
    case consts.ZRQINIT:
      return 'ZRQINIT';
    case consts.ZRINIT:
      return 'ZRINIT';
    case consts.ZSINIT:
      return 'ZSINIT';
    case consts.ZACK:
      return 'ZACK';
    case consts.ZFILE:
      return 'ZFILE';
    case consts.ZSKIP:
      return 'ZSKIP';
    case consts.ZNAK:
      return 'ZNAK';
    case consts.ZABORT:
      return 'ZABORT';
    case consts.ZFIN:
      return 'ZFIN';
    case consts.ZRPOS:
      return 'ZRPOS';
    case consts.ZDATA:
      return 'ZDATA';
    case consts.ZEOF:
      return 'ZEOF';
    case consts.ZFERR:
      return 'ZFERR';
    case consts.ZCRC:
      return 'ZCRC';
    case consts.ZCHALLENGE:
      return 'ZCHALLENGE';
    case consts.ZCOMPL:
      return 'ZCOMPL';
    case consts.ZCAN:
      return 'ZCAN';
    case consts.ZFREECNT:
      return 'ZFREECNT';
    case consts.ZCOMMAND:
      return 'ZCOMMAND';
    case consts.ZSTDERR:
      return 'ZSTDERR';
    case consts.ZCRCE:
      return 'ZCRCE';
    case consts.ZCRCG:
      return 'ZCRCG';
    case consts.ZCRCQ:
      return 'ZCRCQ';
    case consts.ZCRCW:
      return 'ZCRCW';
    default:
      return 'UNKNOWN';
  }
}

class ZModemAbortSequence implements ZModemPacket {
  const ZModemAbortSequence();

  @override
  int get type => consts.ZABORT;

  static final abortSequence = Uint8List.fromList([
    consts.CAN,
    consts.CAN,
    consts.CAN,
    consts.CAN,
    consts.CAN,
  ]);

  @override
  Uint8List encode() {
    return abortSequence;
  }
}

class ZModemOverAndOut implements ZModemPacket {
  const ZModemOverAndOut();

  @override
  int get type => consts.ZFIN;

  static final overAndOut = Uint8List.fromList('OO'.codeUnits);

  @override
  Uint8List encode() {
    return overAndOut;
  }
}
