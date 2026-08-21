// Corpus generator — produces valid ZModem frames as .bin files.
// Uses the same CRC16 and escaping as lib/src/ so the parser accepts them.

import 'dart:io';
import 'dart:typed_data';

import 'package:zmodem_lbp/src/consts.dart' as consts;
import 'package:zmodem_lbp/src/crc.dart';
import 'package:zmodem_lbp/src/escape.dart';

/// Escaped byte writer that mirrors [BytesBuilderExtension.addEscapedByte].
void _addEscaped(BytesBuilder b, int byte) {
  b.addEscapedByte(byte);
}

/// Hex-mode frame: ZPAD ZPAD ZDLE ZHEX <12 hex chars> CR LF XON
List<int> _hexFrame(int type, int p0, int p1, int p2, int p3) {
  final crc = CRC16()
    ..update(type)
    ..update(p0)
    ..update(p1)
    ..update(p2)
    ..update(p3)
    ..finalize();

  final buf = <int>[];
  void emitHex(int v) {
    buf.addAll(v.toRadixString(16).padLeft(2, '0').toUpperCase().codeUnits);
  }

  buf.addAll([consts.ZPAD, consts.ZPAD, consts.ZDLE, consts.ZHEX]);
  emitHex(type);
  emitHex(p0);
  emitHex(p1);
  emitHex(p2);
  emitHex(p3);
  emitHex(crc.value >> 8);
  emitHex(crc.value & 0xff);
  buf.addAll([0x0d, 0x0a, 0x11]); // CR LF XON
  return buf;
}

/// Binary-mode (ZBIN) header: ZPAD ZPAD ZDLE ZBIN <5 escaped bytes> <2 escaped CRC>
List<int> _binHeader(int type, int p0, int p1, int p2, int p3) {
  final crc = CRC16()
    ..update(type)
    ..update(p0)
    ..update(p1)
    ..update(p2)
    ..update(p3)
    ..finalize();

  final b = BytesBuilder();
  b.addByte(consts.ZPAD);
  b.addByte(consts.ZPAD);
  b.addByte(consts.ZDLE);
  b.addByte(consts.ZBIN);
  _addEscaped(b, type);
  _addEscaped(b, p0);
  _addEscaped(b, p1);
  _addEscaped(b, p2);
  _addEscaped(b, p3);
  _addEscaped(b, crc.value >> 8);
  _addEscaped(b, crc.value & 0xff);
  return b.takeBytes();
}

/// Data subpacket: escaped data bytes + ZDLE + terminator + 2 escaped CRC bytes.
/// CRC covers (data_bytes + terminator).
List<int> _dataSubpacket(List<int> data, int terminator) {
  final crcInput = [...data, terminator];
  final crc = CRC16();
  for (final byte in crcInput) {
    crc.update(byte);
  }
  crc.finalize();

  final b = BytesBuilder();
  b.addEscapedData(Uint8List.fromList(data));
  b.addByte(consts.ZDLE);
  b.addByte(terminator); // ZCRCE / ZCRCG / ZCRCQ / ZCRCW
  _addEscaped(b, crc.value >> 8);
  _addEscaped(b, crc.value & 0xff);
  return b.takeBytes();
}

/// Writes bytes to test/fuzz/corpus/{name}.bin
void writeCorpus(String name, List<int> bytes) {
  final dir = Directory('test/fuzz/corpus');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('${dir.path}/$name.bin').writeAsBytesSync(bytes);
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  print('  ✓ $name.bin  (${bytes.length} bytes)');
  print('    hex: $hex');
}

void main() {
  print('Generating corpus files...\n');

  // ── 1. ZRQINIT — Receiver initiates session ──
  writeCorpus(
      'zrqinit',
      _hexFrame(consts.ZRQINIT, consts.CANFC32 | consts.CANFDX | consts.CANOVIO,
          0, 0, 0));

  // ── 2. ZRINIT with ESCCTL|ESC8 flags ──
  writeCorpus(
      'zrinit_escctl',
      _hexFrame(consts.ZRINIT, consts.CANFC32 | consts.ESCCTL | consts.ESC8, 0,
          0, 0));

  // ── 3. ZFILE with data subpacket (filename + properties) ──
  {
    final header = _hexFrame(consts.ZFILE, 0, 0, 0, 0);
    final fname = 'example.txt'.codeUnits;
    final fprops = '1064 1000 0 0 0 40 0 0 0'.codeUnits;
    final payload = [...fname, 0, ...fprops, 0];
    writeCorpus(
        'zfile_example', [...header, ..._dataSubpacket(payload, consts.ZCRCW)]);
  }

  // ── 4. ZDATA header (offset 0) ──
  writeCorpus('zdata_offset0', _hexFrame(consts.ZDATA, 0, 0, 0, 0));

  // ── 5. ZEOF — End of file (pos=5) ──
  writeCorpus('zeof', _hexFrame(consts.ZEOF, 0, 0, 0, 5));

  // ── 7. ZFIN — Finish ──
  writeCorpus('zfin', _hexFrame(consts.ZFIN, 0, 0, 0, 0));

  // ── 8. ZACK with position ──
  writeCorpus('zack_pos5', _hexFrame(consts.ZACK, 0, 0, 0, 5));

  // ── 9. ZRPOS (request resend from byte 3) ──
  writeCorpus('zrpos', _hexFrame(consts.ZRPOS, 0, 0, 0, 3));

  // ── 10. Full multi-frame session ──
  {
    final s = <int>[];
    s.addAll(
        _hexFrame(consts.ZRQINIT, consts.CANFC32 | consts.CANFDX, 0, 0, 0));
    s.addAll(_hexFrame(consts.ZRINIT,
        consts.CANFC32 | consts.CANFDX | consts.CANOVIO, 0, 0, 0));
    s.addAll(_hexFrame(consts.ZFILE, 0, 0, 0, 0));
    final fname = 'readme.md'.codeUnits;
    final fprops = '1024 100064 0 0 0 40 0 0 0'.codeUnits;
    s.addAll(_dataSubpacket([...fname, 0, ...fprops, 0], consts.ZCRCW));
    s.addAll(_hexFrame(consts.ZDATA, 0, 0, 0, 0));
    s.addAll(_dataSubpacket(
        [0x23, 0x20, 0x5a, 0x4d, 0x6f, 0x64, 0x65, 0x6d], consts.ZCRCE));
    s.addAll(_hexFrame(consts.ZEOF, 0, 0, 0, 8));
    s.addAll(_hexFrame(consts.ZFIN, 0, 0, 0, 0));
    writeCorpus('full_session', s);
  }

  // ── 11. ZCRC — CRC request ──
  writeCorpus('zcrc_request', _hexFrame(consts.ZCRC, 0, 0, 0, 0));

  // ── 12. ZCOMPL — Complete ──
  writeCorpus('zcompl', _hexFrame(consts.ZCOMPL, 0, 0, 0, 0));

  // ── 13. ZFREECNT — Free space request ──
  writeCorpus('zfreecnt', _hexFrame(consts.ZFREECNT, 0, 0, 0, 0));

  // ── 14. Binary mode header (ZBIN) ──
  writeCorpus('zrinit_bin',
      _binHeader(consts.ZRINIT, consts.CANFC32 | consts.CANFDX, 0, 0, 0));

  // ── 15. ZNAK — Negative ACK ──
  writeCorpus('znak', _hexFrame(consts.ZNAK, 0, 0, 0, 0));

  // ── 16. ZDATA with non-zero offset (little-endian: 1024 = 0x00 0x04 0x00 0x00) ──
  writeCorpus('zdata_offset1024', _hexFrame(consts.ZDATA, 0, 4, 0, 0));

  // ── 17. ZSINIT — Sender init with data subpacket ──
  {
    final header = _hexFrame(consts.ZSINIT, 0, 0, 0, 0);
    writeCorpus('zsinit', [
      ...header,
      ..._dataSubpacket([consts.ESCCTL | consts.ESC8], consts.ZCRCW)
    ]);
  }

  // ── 18. ZCHALLENGE (0x0e) with random value ──
  writeCorpus(
      'zchallenge', _hexFrame(consts.ZCHALLENGE, 0x1f, 0x3a, 0x5c, 0x7e));

  // ── 19. ZSKIP — Skip file ──
  writeCorpus('zskip', _hexFrame(consts.ZSKIP, 0, 0, 0, 0));

  // ── 20. ZRINIT with CANFDX|CANOVIO|CANFC32|CANBRK (0x27) ──
  writeCorpus('zrinit_fdx', _hexFrame(consts.ZRINIT, 0x27, 0, 0, 0));

  // ── 21. ZFILE with 'source.c' via ZCRCW ──
  {
    final header = _hexFrame(consts.ZFILE, 0, 0, 0, 0);
    final fname = 'source.c'.codeUnits;
    final fprops = '2048 100755 0 0 0 40 0 0 1'.codeUnits;
    writeCorpus('zfile_source', [
      ...header,
      ..._dataSubpacket([...fname, 0, ...fprops, 0], consts.ZCRCW)
    ]);
  }

  // ── 22. ZFILE with ZCRCQ data subpacket (expects ACK) ──
  {
    final header = _hexFrame(consts.ZFILE, 0, 0, 0, 0);
    final fname = 'ack_test'.codeUnits;
    final fprops = '512 0 0 0 0 40 0 0 0'.codeUnits;
    writeCorpus('zfile_zcrcq', [
      ...header,
      ..._dataSubpacket([...fname, 0, ...fprops, 0], consts.ZCRCQ)
    ]);
  }

  // ── 23. ZFERR (file error) with error code ──
  writeCorpus('zferr', _hexFrame(consts.ZFERR, 0, 0, 0, 1));

  // ── 24. ZABORT — Abort session ──
  writeCorpus('zabort', _hexFrame(consts.ZABORT, 0, 0, 0, 0));

  // ── 25. ZCOMMAND — Execute remote command ──
  writeCorpus('zcommand', _hexFrame(consts.ZCOMMAND, 0, 0, 0, 0));

  // ── 26. ZSTDERR — Stderr data header ──
  writeCorpus('zstderr', _hexFrame(consts.ZSTDERR, 0, 0, 0, 0));

  // ── 27. ZCAN — Cancel header (single frame, not 5 CAN bytes) ──
  writeCorpus('zcan_header', _hexFrame(consts.ZCAN, 0, 0, 0, 0));

  // ── 28. ZBIN32 header (CRC32) — just the binary header preamble ──
  writeCorpus(
      'zrin32_header', _binHeader(consts.ZRINIT, consts.CANFC32, 0, 0, 0));

  print('\nDone.');
}
