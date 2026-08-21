// Seed 000: a minimal valid ZRINIT hex frame.
// ZPAD ZPAD ZDLE ZHEX "01 00 00 00 21 CRC_hi CRC_lo" CR LF XON
//
// type=0x01 (ZRINIT), flags=0x21 (CANFDX|CANFC32)
const List<int> seed000 = [
  0x2a, 0x2a, 0x18, 0x42, // header prefix
  // Hex header bytes as ASCII chars:
  0x30, 0x31, // 01
  0x30, 0x30, // 00
  0x30, 0x30, // 00
  0x30, 0x30, // 00
  0x32, 0x31, // 21 (CANFDX | CANFC32)
  0x38, 0x31, // CRC high byte
  0x41, 0x45, // CRC low byte
  0x0d, 0x0a, 0x11, // CR LF XON
];
