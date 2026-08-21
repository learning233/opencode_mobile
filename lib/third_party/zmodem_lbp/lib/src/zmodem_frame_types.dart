import 'dart:typed_data';

import 'package:zmodem_lbp/src/consts.dart' as consts;

enum ZFrameFormat { hexHeader, binaryHeader, dataSubpacket }

class ZFrame {
  final int type;
  final List<int> params;
  final Uint8List data;
  final int computedCrc;
  final int receivedCrc;
  final bool crcValid;
  final ZFrameFormat format;

  ZFrame({
    required this.type,
    required this.params,
    required this.data,
    required this.computedCrc,
    required this.receivedCrc,
    required this.crcValid,
    required this.format,
  });

  @override
  String toString() {
    return 'ZFrame($type, p: $params, data: ${data.length}, crcValid: $crcValid, fmt: $format)';
  }
}

bool zframeIntroducesData(ZFrame frame) {
  return frame.type == consts.ZFILE ||
      frame.type == consts.ZSINIT ||
      frame.type == consts.ZDATA;
}
