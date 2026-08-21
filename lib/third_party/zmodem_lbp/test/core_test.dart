import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zmodem_lbp/zmodem.dart';
import 'package:zmodem_lbp/src/consts.dart' as consts;

void main() {
  group('ZModemCore', () {
    test('can act as both client and server', () {
      final server = ZModemCore();
      final client = ZModemCore();

      server.initiateSend();
      client.receive(server.dataToSend()).drain();
      expect(server.receive(client.dataToSend()), [isA<ZReadyToSendEvent>()]);

      server.offerFile(ZModemFileInfo(pathname: 'foo', length: 123));
      final events = client.receive(server.dataToSend()).toList();
      expect(events, [isA<ZFileOfferedEvent>()]);

      final fileInfo = (events.single as ZFileOfferedEvent).fileInfo;
      expect(fileInfo.pathname, 'foo');
      expect(fileInfo.length, 123);

      client.acceptFile();
      expect(server.receive(client.dataToSend()), [isA<ZFileAcceptedEvent>()]);

      server.sendFileData(Uint8List.fromList([1, 2, 3]));
      expect(client.receive(server.dataToSend()), [isA<ZFileDataEvent>()]);

      server.finishSending(3);
      expect(client.receive(server.dataToSend()), [
        isA<ZFileDataEvent>(), // ZCRCE
        isA<ZFileEndEvent>(), // ZEOF
      ]);

      expect(server.receive(client.dataToSend()), [isA<ZReadyToSendEvent>()]);

      server.finishSession();
      // expect(
      //   client.receive(server.dataToSend()),
      //   [isA<ZSessionFinishedEvent>()],
      // );
    });

    test('cancel sequence resets session', () {
      final core = ZModemCore();
      final cancel = Uint8List.fromList([
        consts.CAN,
        consts.CAN,
        consts.CAN,
        consts.CAN,
        consts.CAN,
      ]);
      final events = core.receive(cancel).toList();
      expect(events, [isA<ZSessionCancelledEvent>()]);
      expect(core.isFinished, isFalse);
      expect(core.hasDataToSend, isFalse);
    });
  });
}

extension on Iterable {
  void drain() {
    for (final _ in this) {}
  }
}
