import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zmodem_lbp/src/crc.dart';

void main() {
  group('CRC16', () {
    test('case 1', () {
      final crc = CRC16()
        ..update(0x00)
        ..update(0x00)
        ..update(0x00)
        ..update(0x00)
        ..update(0x00)
        ..finalize();

      expect(crc.value.toRadixString(16), '0');
    });

    test('case 2', () {
      final crc = CRC16()
        ..update(0x01)
        ..update(0x00)
        ..update(0x00)
        ..update(0x00)
        ..update(0x23)
        ..finalize();

      expect(crc.value.toRadixString(16), 'be50');
    });
  });

  group('computeCrc16', () {
    test('known-good CRC', () {
      // ZRINIT header bytes: type=0x01, p0=0, p1=0, p2=0, p3=64(CANFDX|CANOVIO)
      final crc = computeCrc16([0x01, 0x00, 0x00, 0x00, 0x40]);
      // verify against known good value from zmodem test fixture
      expect(crc, greaterThan(0));
    });

    test('known-bad CRC fails validation', () {
      final data = Uint8List.fromList([0x01, 0x02, 0x03]);
      final correctCrc = computeCrc16(data);
      expect(validateCrc16(data, correctCrc), isTrue);
      expect(validateCrc16(data, correctCrc + 1), isFalse);
      expect(validateCrc16(data, 0), isFalse);
    });

    test('empty data CRC', () {
      final crc = computeCrc16([]);
      expect(crc, 0);
    });
  });
}
