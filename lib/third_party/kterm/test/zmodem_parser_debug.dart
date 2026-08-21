import 'dart:typed_data';
import 'package:zmodem_lbp/zmodem.dart';

void main() {
  // ZFIN frame from the test
  final finish = Uint8List.fromList([
    0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
    0x30, 0x38, // frame type '08' (ZFIN)
    0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, // p0-p3 = '00000000'
    0x30, 0x32, 0x32, 0x64, // CRC '022d'
    0x0D, 0x0A, // CR LF
    0x11 // XON
  ]);

  final parser = ZModemParser();
  parser.addData(finish);

  int count = 0;
  while (parser.moveNext()) {
    count++;
    print('Packet $count: ${parser.current}');
  }
  print('Done. Total packets: $count');
}
