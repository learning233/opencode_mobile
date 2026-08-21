import 'dart:typed_data';
import 'package:zmodem_lbp/src/consts.dart' as consts;

extension BytesBuilderExtension on BytesBuilder {
  void addEscapedByte(int byte) {
    if (byte == consts.ZDLE) {
      addByte(consts.ZDLE);
      addByte(consts.ZDLEE);
    } else if (byte == 0x8d || byte == 0x0d) {
      addByte(byte);
    } else if (byte == 0x10 ||
        byte == 0x90 ||
        byte == 0x11 ||
        byte == 0x91 ||
        byte == 0x13 ||
        byte == 0x93) {
      addByte(consts.ZDLE);
      addByte(byte ^ 0x40);
    } else {
      addByte(byte);
    }
  }

  void addEscapedData(Uint8List data) {
    for (final byte in data) {
      addEscapedByte(byte);
    }
  }
}

Uint8List escapeData(Uint8List data) {
  final builder = BytesBuilder();
  builder.addEscapedData(data);
  return builder.takeBytes();
}
