import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:dart_console/dart_console.dart';
import 'package:zmodem_lbp/zmodem.dart';

void main() async {
  final console = Console();

  if (stdout.hasTerminal) {
    console.rawMode = true;
  }

  try {
    await rz();
  } finally {
    if (stdout.hasTerminal) {
      console.rawMode = false;
    }
  }
}

Future<void> rz() async {
  final zcore = ZModemCore();
  zcore.initiateReceive();

  if (zcore.hasDataToSend) {
    stdout.add(zcore.dataToSend());
  }

  // The file info of the file currently being received.
  ZModemFileInfo? fileInfo;

  // The local file corresponding to the file currently being received.
  IOSink? fileSink;

  final input = StreamQueue(stdin);

  while (true) {
    final chunk = await input.next as Uint8List;
    for (final event in zcore.receive(chunk)) {
      if (event is ZFileOfferedEvent) {
        zcore.acceptFile();
        fileInfo = event.fileInfo;
        fileSink = File(fileInfo.pathname).openWrite();
      } else if (event is ZFileDataEvent) {
        fileSink!.add(event.data);
      } else if (event is ZFileEndEvent) {
        await fileSink!.close();
        fileSink = null;
        fileInfo = null;
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
      // reads the OO (over and out)
      await input.next.timeout(
        Duration(milliseconds: 100),
        onTimeout: () => [],
      );
      await input.cancel();
      break;
    }
  }

  await stdout.flush();
}
