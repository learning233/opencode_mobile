import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_console/dart_console.dart';
import 'package:zmodem_lbp/zmodem.dart';

void main(List<String> files) async {
  final console = Console();

  if (stdout.hasTerminal) {
    console.rawMode = true;
  }

  try {
    await sz(files);
  } finally {
    if (stdout.hasTerminal) {
      console.rawMode = false;
    }
  }
}

Future<void> sz(List<String> files) async {
  final zcore = ZModemCore(
      // onTrace: File('trace.log').openWrite().writeln,
      );
  zcore.initiateSend();

  if (zcore.hasDataToSend) {
    stdout.add(zcore.dataToSend());
  }

  final filesLeft = Queue.of(files);

  String? currentFile;

  await for (final chunk in stdin) {
    for (final event in zcore.receive(chunk as Uint8List)) {
      if (event is ZReadyToSendEvent) {
        if (filesLeft.isNotEmpty) {
          final file = filesLeft.removeFirst();
          final length = await File(file).length();
          currentFile = file;
          zcore.offerFile(ZModemFileInfo(pathname: file, length: length));
        } else {
          zcore.finishSession();
        }
      } else if (event is ZFileAcceptedEvent) {
        final offset = event.offset;
        final data = File(currentFile!).openRead(offset);
        var bytesSent = 0;
        await for (final chunk in data) {
          zcore.sendFileData(chunk as Uint8List);
          bytesSent += chunk.length;
          stdout.add(zcore.dataToSend());
        }
        zcore.finishSending(offset + bytesSent);
      } else if (event is ZFileSkippedEvent) {
        if (filesLeft.isEmpty) {
          zcore.finishSession();
        }
        continue;
      } else if (event is ZSessionFinishedEvent) {
        // no-op
      } else {
        throw Exception('Unexpected event: $event');
      }
    }

    if (zcore.hasDataToSend) {
      stdout.add(zcore.dataToSend());
    }

    if (zcore.isFinished) {
      break;
    }
  }

  await stdout.flush();
}
