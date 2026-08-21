import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zmodem_lbp/src/zmodem_frame_types.dart';
import 'package:zmodem_lbp/src/zmodem_parser.dart';

/// Corpus replay test: load all .bin seed files from test/fuzz/corpus/,
/// feed each through the parser, and ensure:
/// 1. No crash or hang
/// 2. At least one frame is produced
/// 3. The session produces a deterministic set of frames under chunked ingestion
///
/// Add failing seeds as .bin files to the corpus directory.
void main() {
  group('Corpus replay', () {
    final dir = Directory('test/fuzz/corpus');
    if (!dir.existsSync()) {
      test('corpus directory does not exist', () => print('(no corpus yet)'));
      return;
    }

    final binFiles = dir.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.bin'),
        );

    for (final file in binFiles) {
      test('replay ${file.uri.pathSegments.last}', () async {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) return;

        // Bulk parse
        final bulkParser = ZModemParser();
        bulkParser.addData(bytes);
        final bulkFrames = <ZFrame>[];
        while (bulkParser.moveNext()) {
          bulkFrames.add(bulkParser.current);
        }
        expect(bulkFrames, isNotEmpty,
            reason: 'Seed ${file.path} produced no frames');

        // Fragmented parse (byte-by-byte must match)
        final fragmentParser = ZModemParser();
        for (var i = 0; i < bytes.length; i++) {
          fragmentParser.addData(Uint8List.fromList([bytes[i]]));
        }
        final fragmentFrames = <ZFrame>[];
        while (fragmentParser.moveNext()) {
          fragmentFrames.add(fragmentParser.current);
        }

        expect(fragmentFrames.length, bulkFrames.length,
            reason:
                'Byte-at-a-time parsing of ${file.path} gave different frame count');
        for (var i = 0; i < bulkFrames.length; i++) {
          expect(fragmentFrames[i].type, bulkFrames[i].type);
          expect(fragmentFrames[i].format, bulkFrames[i].format);
          expect(fragmentFrames[i].data.length, bulkFrames[i].data.length);
        }
      });
    }
  });
}
