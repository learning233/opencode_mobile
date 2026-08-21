import 'dart:typed_data';
import 'package:zmodem_lbp/zmodem.dart';

void main() {
  final finish = Uint8List.fromList([
    0x2A,
    0x2A,
    0x18,
    0x42,
    0x30,
    0x38,
    0x30,
    0x30,
    0x30,
    0x30,
    0x30,
    0x30,
    0x30,
    0x30,
    0x30,
    0x32,
    0x32,
    0x64,
    0x0D,
    0x0A,
    0x11
  ]);

  final core = ZModemCore();
  final events = core.receive(finish).toList();
  print('Events: $events');
}
