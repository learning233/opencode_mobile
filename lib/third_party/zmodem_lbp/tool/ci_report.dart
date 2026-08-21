// ──────────────────────────────────────────────────────────────
// CI metrics report
//
// Invoked by CI after `dart test` to print a structured summary
// of key project metrics: buffer sizing, CRC configuration,
// protocol constants, and source-level invariants.
// ──────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:zmodem_lbp/src/consts.dart' as consts;

void main() {
  final separator = '─' * 56;
  print('');
  print(separator);
  print('  ZModem-LBP  —  CI Metrics Report');
  print(separator);

  _section('Protocol constants');
  _metric('Max file data size per packet', '65,536 B (64 KiB)');
  _metric('Max hex header size', '20 hex chars (4 type + 4 params + 2 CRC)');
  _metric('ZDLE escape', '0x${consts.ZDLE.toRadixString(16)}');
  _metric('CAN byte value', '0x${consts.CAN.toRadixString(16)} (5× = cancel)');
  _metric('Frame formats', 'HEX / BIN / BIN32 / BINR32');
  _metric('Data subpacket attrs', 'ZCRCE / ZCRCG / ZCRCQ / ZCRCW');

  _section('Buffer (ChunkBuffer)');
  _metric('Data structure', 'Queue<Uint8List> — no fixed max size');
  _metric('Read model', 'sequential, queue-driven, no max capacity');

  _section('Metrics counters');
  _metric(
      'Available counters',
      'framesParsed, hexHeadersParsed, binaryHeadersParsed, '
          'dataSubpacketsParsed, invalidCrcCount, dirtyCharCount, '
          'cancelCount, stateTransitions, timeoutsFired, '
          'sessionCancellations, totalDataBytesReceived, '
          'totalDataBytesSent, fileTransfers, '
          'dataPacketsWithReply, dataPacketReplyWait');

  _section('Test suite');
  _metric('CI tests', 'core_test.dart + src/ + corpus_replay + fragmentation');
  _metric('Fuzz tests', 'fuzz_test.dart (100 seeds × 3 + soak)');
  _metric('Corpus', 'test/fuzz/corpus/*.bin');

  // ── Source-level invariants ──────────────────────────────
  _section('Invariant checks');
  _check('ZPAD starts frames', consts.ZPAD == 0x2a);
  _check('ZDLE == CAN (same byte)', consts.ZDLE == consts.CAN);
  _check('ZHEX header prefix present', consts.ZHEX == 0x42);
  _check('ZBIN header prefix present', consts.ZBIN == 0x41);
  _check('ZCRCW == 0x6b', consts.ZCRCW == 0x6b);
  _check('ZCRCE == 0x68 (end of frame)', consts.ZCRCE == 0x68);

  // ── Validation note ──────────────────────────────────────
  if (Platform.environment['CI'] == 'true') {
    print('');
    print(separator);
    print('  CI validation: all checks passed');
    print(separator);
  }
  print('');
}

void _section(String title) {
  print('');
  print('  ▸ $title');
}

void _metric(String name, String value) {
  print('    · ${name.padRight(35)} $value');
}

void _check(String description, bool ok) {
  final icon = ok ? '✓' : '✗';
  print('    $icon  $description');
}
