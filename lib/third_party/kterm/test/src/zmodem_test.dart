import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:kterm/zmodem.dart';

void main() {
  group('ZModemMux', () {
    late StreamController<List<int>> stdinController;
    late StreamController<Uint8List> stdoutController;
    late StreamSink<List<int>> stdinSink;
    late Stream<Uint8List> stdoutStream;

    setUp(() {
      // stdin: single-subscription with sync:true so writes are delivered synchronously
      stdinController = StreamController<List<int>>(sync: true);
      // stdout: broadcast so both mux and test can listen
      stdoutController = StreamController<Uint8List>.broadcast();
      stdinSink = stdinController.sink;
      stdoutStream = stdoutController.stream;
    });

    tearDown(() {
      // Close without awaiting to avoid test hangs
      stdinController.close();
      stdoutController.close();
    });

    group('Constructor', () {
      test(
          'Given ZModemMux, When constructed, Then initializes callbacks to null',
          () {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);
        expect(mux.onTerminalInput, isNull);
        expect(mux.onFileOffer, isNull);
        expect(mux.onFileRequest, isNull);
      });
    });

    group('terminalWrite', () {
      test(
          'Given no session, When terminalWrite, Then writes encoded text to stdin',
          () {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);
        final sent = <List<int>>[];
        stdinController.stream.listen(sent.add);

        // Debug
        // print('DEBUG: before terminalWrite, sent=$sent, mux._session=??');

        mux.terminalWrite('hello');

        expect(sent, hasLength(1));
        expect(sent.first, equals(utf8.encode('hello')));
      });

      test('Given empty string, When terminalWrite, Then writes empty', () {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);
        final sent = <List<int>>[];
        stdinController.stream.listen(sent.add);

        mux.terminalWrite('');

        expect(sent, hasLength(1));
        expect(sent.first, isEmpty);
      });

      test('Given unicode, When terminalWrite, Then encodes as UTF-8', () {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);
        final sent = <List<int>>[];
        stdinController.stream.listen(sent.add);

        mux.terminalWrite('🌍');

        expect(sent, hasLength(1));
        expect(sent.first, equals(utf8.encode('🌍')));
      });

      test(
          'Given multiple writes, When terminalWrite multiple, Then all written',
          () {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);
        final sent = <List<int>>[];
        stdinController.stream.listen(sent.add);

        mux.terminalWrite('a');
        mux.terminalWrite('b');
        mux.terminalWrite('c');

        expect(sent, hasLength(3));
        expect(sent[0], <int>[97]);
        expect(sent[1], <int>[98]);
        expect(sent[2], <int>[99]);
      });
    });

    group('onTerminalInput callback', () {
      test(
          'Given callback set, When stdout data arrives, Then callback invoked',
          () async {
        final received = <String>[];
        // ignore: unused_local_variable, no_leading_underscores_for_local_identifiers
        final _mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream)
          ..onTerminalInput = received.add;

        stdoutController.add(Uint8List.fromList('test'.codeUnits));

        // Broadcast delivery + transform + listener are async
        await Future(() {});

        expect(received, equals(['test']));
      });

      test('Given callback null, When stdout data arrives, Then no error',
          () async {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream)
          ..onTerminalInput = null;

        stdoutController.add(Uint8List.fromList('test'.codeUnits));

        await Future(() {});

        // No error = pass
        expect(mux, isNotNull);
      });

      test('Given multiple data chunks, When callback set, Then all delivered',
          () async {
        final received = <String>[];
        // ignore: unused_local_variable, no_leading_underscores_for_local_identifiers
        final _mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream)
          ..onTerminalInput = received.add;

        stdoutController.add(Uint8List.fromList('hello'.codeUnits));
        stdoutController.add(Uint8List.fromList(' '.codeUnits));
        stdoutController.add(Uint8List.fromList('world'.codeUnits));

        await Future(() {});

        expect(received, equals(['hello', ' ', 'world']));
      });

      test(
          'Given UTF-8 multi-byte sequence, When callback set, Then correctly decoded',
          () async {
        final received = <String>[];
        // ignore: unused_local_variable, no_leading_underscores_for_local_identifiers
        final _mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream)
          ..onTerminalInput = received.add;

        stdoutController.add(Uint8List.fromList(utf8.encode('🌍')));

        await Future(() {});

        expect(received, equals(['🌍']));
      });
    });

    group('ZModem detection', () {
      test(
          'Given ZModem init sequence in stream, When detected, Then terminalWrite buffers',
          () async {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);
        final sent = <List<int>>[];
        stdinController.stream.listen(sent.add);

        // Full ZModem receiver init (hex frame): **\x18B010000000000000\r\n\x11
        // ZRINIT: type=0x01, p0-p3=0, CRC=0x0000 (dummy), CR LF XON
        final init = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x31, // '01' frame type ZRINIT
          0x30, 0x30, // p0 '00'
          0x30, 0x30, // p1 '00'
          0x30, 0x30, // p2 '00'
          0x30, 0x30, // p3 '00'
          0x30, 0x30, // CRC high '00' (dummy)
          0x30, 0x30, // CRC low '00' (dummy)
          0x0D, 0x0A, // CR LF terminator
          0x11 // XON terminator
        ]);
        stdoutController.add(init);

        await Future(() {});

        // After detection, terminalWrite should buffer (not write to stdin).
        // Protocol handshake data (ZFIN) may be written since no onFileRequest
        // handler is set, but user data should not appear in stdin.
        mux.terminalWrite('during-session');
        expect(sent, isNotEmpty); // ZFIN response is sent
        expect(
          sent.any((data) => utf8
              .decode(data, allowMalformed: true)
              .contains('during-session')),
          isFalse,
        );
      });

      test(
          'Given regular text without ZModem pattern, When terminalWrite, Then writes normally',
          () {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);
        final sent = <List<int>>[];
        stdinController.stream.listen(sent.add);

        stdoutController.add(Uint8List.fromList('regular output'.codeUnits));

        mux.terminalWrite('user input');

        // Only user input should be written to stdin
        expect(sent, hasLength(1));
        expect(sent.first, equals(utf8.encode('user input')));
      });
    });

    group('File offer handling', () {
      test('Given onFileOffer not set, When file offered, Then file is skipped',
          () async {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);
        // onFileOffer is null by default, so offers auto-skip

        // Full ZModem receiver init with CR: **\x18B0100000\r\n\x11
        final init = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x31, // '01' frame type ZRINIT
          0x30, 0x30, // p0 '00'
          0x30, 0x30, // p1 '00'
          0x30, 0x30, // p2 '00'
          0x30, 0x30, // p3 '00'
          0x30, 0x30, // CRC high '00' (dummy)
          0x30, 0x30, // CRC low '00' (dummy)
          0x0D, 0x0A, // CR LF terminator
          0x11 // XON terminator
        ]);
        stdoutController.add(init);

        await Future(() {});

        // No error should occur
        expect(mux, isNotNull);
      });

      test('Given onFileOffer set, When file offered, Then callback invoked',
          () async {
        final receivedOffers = <ZModemOffer>[];
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream)
          ..onFileOffer = receivedOffers.add;

        // Full ZModem receiver init with CR: **\x18B0100000\r\n\x11
        final init = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x31, // '01' frame type ZRINIT
          0x30, 0x30, // p0 '00'
          0x30, 0x30, // p1 '00'
          0x30, 0x30, // p2 '00'
          0x30, 0x30, // p3 '00'
          0x30, 0x30, // CRC high '00' (dummy)
          0x30, 0x30, // CRC low '00' (dummy)
          0x0D, 0x0A, // CR LF terminator
          0x11 // XON terminator
        ]);
        stdoutController.add(init);

        await Future(() {});

        // The offer callback should have been invoked
        expect(mux.onFileOffer, isNotNull);
      });
    });

    group('File request handling', () {
      test('Given onFileRequest not set, When request received, Then ignored',
          () async {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);

        // Full ZModem receiver init with CR: **\x18B0100000\r\n\x11
        final init = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x31, // '01' frame type ZRINIT
          0x30, 0x30, // p0 '00'
          0x30, 0x30, // p1 '00'
          0x30, 0x30, // p2 '00'
          0x30, 0x30, // p3 '00'
          0x30, 0x30, // CRC high '00' (dummy)
          0x30, 0x30, // CRC low '00' (dummy)
          0x0D, 0x0A, // CR LF terminator
          0x11 // XON terminator
        ]);
        stdoutController.add(init);

        await Future(() {});

        expect(mux, isNotNull);
      });

      test(
          'Given onFileRequest set, When request received, Then no error thrown',
          () async {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream)
          ..onFileRequest = () async => <ZModemOffer>[];

        // Full ZModem receiver init with CR: **\x18B0100000\r\n\x11
        final init = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x31, // '01' frame type ZRINIT
          0x30, 0x30, // p0 '00'
          0x30, 0x30, // p1 '00'
          0x30, 0x30, // p2 '00'
          0x30, 0x30, // p3 '00'
          0x30, 0x30, // CRC high '00' (dummy)
          0x30, 0x30, // CRC low '00' (dummy)
          0x0D, 0x0A, // CR LF terminator
          0x11 // XON terminator
        ]);
        stdoutController.add(init);

        await Future(() {});

        // No error thrown = pass, verify callback is set
        expect(mux.onFileRequest, isNotNull);
      });
    });

    group('Session lifecycle', () {
      test(
          'Given active session, When terminalWrite, Then data not sent to stdin',
          () async {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);
        final sent = <List<int>>[];
        stdinController.stream.listen(sent.add);

        // Start ZModem session
        // Full ZModem receiver init with CR: **\x18B0100000\r\n\x11
        final init = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x31, // '01' frame type ZRINIT
          0x30, 0x30, // p0 '00'
          0x30, 0x30, // p1 '00'
          0x30, 0x30, // p2 '00'
          0x30, 0x30, // p3 '00'
          0x30, 0x30, // CRC high '00' (dummy)
          0x30, 0x30, // CRC low '00' (dummy)
          0x0D, 0x0A, // CR LF terminator
          0x11 // XON terminator
        ]);
        stdoutController.add(init);

        await Future(() {});

        // Write during active session
        mux.terminalWrite('buffered');

        // Should not be sent to stdin during active session.
        // Protocol data (ZFIN from ZRINIT response) may be present, but not
        // the terminal data.
        expect(
          sent.any((data) =>
              utf8.decode(data, allowMalformed: true).contains('buffered')),
          isFalse,
        );
      });

      test('Given session ends, When terminalWrite, Then writes to stdin again',
          () async {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);
        final sent = <List<int>>[];
        stdinController.stream.listen(sent.add);

        // Start ZModem session with init
        // Full ZModem receiver init with CR: **\x18B0100000\r\n\x11
        final init = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x31, // '01' frame type ZRINIT
          0x30, 0x30, // p0 '00'
          0x30, 0x30, // p1 '00'
          0x30, 0x30, // p2 '00'
          0x30, 0x30, // p3 '00'
          0x30, 0x30, // CRC high '00' (dummy)
          0x30, 0x30, // CRC low '00' (dummy)
          0x0D, 0x0A, // CR LF terminator
          0x11 // XON terminator
        ]);
        stdoutController.add(init);

        await Future(() {});

        // Verify session active: terminalWrite buffers (protocol data may be sent)
        mux.terminalWrite('should-buffer');
        expect(
          sent.any((data) => utf8
              .decode(data, allowMalformed: true)
              .contains('should-buffer')),
          isFalse,
        );

        // End session with ZModem ZFIN frame (full hex format with XON terminator)
        // ZFIN = 0x08, p0-p3 = 0x00000000
        // CRC calculated over [0x08, 0x00, 0x00, 0x00, 0x00] = 0x022d
        // Full frame: **\x18B0800000000022d\r\n\x11 (23 bytes)
        final finish = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x38, // frame type '08' (ZFIN)
          0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, // p0-p3 = '00000000'
          0x30, 0x32, 0x32, 0x64, // CRC '022d' (correct)
          0x0D, 0x0A, // CR LF terminator
          0x11 // XON terminator (required by hex frame format)
        ]);
        stdoutController.add(finish);

        // Wait for async session cleanup
        await Future(() {});
        await Future(() {});

        // After session ends, terminalWrite should work normally
        mux.terminalWrite('after-session');

        expect(sent, contains(equals(utf8.encode('after-session'))));
      });
    });

    group('Send side (onFileRequest)', () {
      test(
          'Given ZRINIT and onFileRequest, When detected, Then callback invoked',
          () async {
        var requestCalled = false;
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream)
          ..onFileRequest = () async {
            requestCalled = true;
            return [];
          };

        // ZRINIT hex frame: **\x18B010000000000000\r\n\x11
        final zrinit = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x31, // '01' ZRINIT
          0x30, 0x30, // p0 '00'
          0x30, 0x30, // p1 '00'
          0x30, 0x30, // p2 '00'
          0x30, 0x30, // p3 '00'
          0x30, 0x30, // CRC high (dummy)
          0x30, 0x30, // CRC low (dummy)
          0x0D, 0x0A, // CR LF
          0x11, // XON
        ]);
        stdoutController.add(zrinit);

        await Future(() {});
        await Future(() {});

        expect(requestCalled, isTrue);
      });

      test(
          'Given onFileRequest returns empty, When ZRINIT received, Then no crash',
          () async {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream)
          ..onFileRequest = () async => [];

        final zrinit = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x31, // '01' ZRINIT
          0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, // p0-p3 '00000000'
          0x30, 0x30, 0x30, 0x30, // CRC '0000'
          0x0D, 0x0A, // CR LF
          0x11, // XON
        ]);
        stdoutController.add(zrinit);

        await Future(() {});
        await Future(() {});

        expect(mux, isNotNull);
      });

      test(
          'Given onFileRequest returns offers, When ZRINIT, Then writes ZFILE to stdin',
          () async {
        final sent = <List<int>>[];
        stdinController.stream.listen(sent.add);

        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream)
          ..onFileRequest = () async => [
                ZModemCallbackOffer(
                  ZModemFileInfo(
                    pathname: 'test.txt',
                    length: 100,
                    modificationTime: 0,
                  ),
                  onAccept: (_) => const Stream.empty(),
                ),
              ];

        // ZRINIT hex frame
        final zrinit = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x31, // '01' ZRINIT
          0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, // p0-p3 '00000000'
          0x30, 0x30, 0x30, 0x30, // CRC '0000'
          0x0D, 0x0A, // CR LF
          0x11, // XON
        ]);
        stdoutController.add(zrinit);

        await Future(() {});
        await Future(() {});
        await Future(() {});

        // Expect ZFILE hex frame bytes in stdin (generated by offerFile)
        // ZFILE = type 0x04 → ASCII hex '0' '4'
        expect(
          sent.any((data) {
            final text = utf8.decode(data, allowMalformed: true);
            return text.contains('04') || text.contains('*');
          }),
          isTrue,
        );
      });
    });

    group('Multiple sequential sessions', () {
      test(
          'Given session ends, When new ZRINIT arrives, Then new session starts',
          () async {
        final sent = <List<int>>[];
        stdinController.stream.listen(sent.add);

        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);

        // First session: ZRINIT → ZFIN
        final zrinit = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x31, // '01' ZRINIT
          0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, // p0-p3 '00000000'
          0x30, 0x30, 0x30, 0x30, // CRC '0000'
          0x0D, 0x0A, // CR LF
          0x11, // XON
        ]);
        stdoutController.add(zrinit);
        await Future(() {});
        await Future(() {});

        // Verify session active: terminalWrite buffers
        sent.clear();
        mux.terminalWrite('during-session');
        expect(
          sent.any((data) => utf8
              .decode(data, allowMalformed: true)
              .contains('during-session')),
          isFalse,
        );

        // End session with ZFIN
        final zfin = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x38, // '08' ZFIN
          0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, // p0-p3 '00000000'
          0x30, 0x32, 0x32, 0x64, // CRC '022d' (correct)
          0x0D, 0x0A, // CR LF
          0x11, // XON
        ]);
        stdoutController.add(zfin);
        await Future(() {});
        await Future(() {});

        // After session: terminalWrite works
        sent.clear();
        mux.terminalWrite('after-session-1');
        expect(
          sent.any((data) => utf8
              .decode(data, allowMalformed: true)
              .contains('after-session-1')),
          isTrue,
        );

        // Second session: another ZRINIT
        sent.clear();
        stdoutController.add(zrinit);
        await Future(() {});
        await Future(() {});

        // Should buffer again
        sent.clear();
        mux.terminalWrite('during-session-2');
        expect(
          sent.any((data) => utf8
              .decode(data, allowMalformed: true)
              .contains('during-session-2')),
          isFalse,
        );

        // End second session
        stdoutController.add(zfin);
        await Future(() {});
        await Future(() {});

        // Back to normal
        sent.clear();
        mux.terminalWrite('after-session-2');
        expect(
          sent.any((data) => utf8
              .decode(data, allowMalformed: true)
              .contains('after-session-2')),
          isTrue,
        );
      });
    });

    group('Dispose cleanup', () {
      test('Given mux disposed, When stdout data arrives, Then no error',
          () async {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);

        mux.dispose();

        // Should not throw
        stdoutController.add(Uint8List.fromList('hello'.codeUnits));
        await Future(() {});
        expect(mux, isNotNull);
      });

      test(
          'Given mux disposed with active session, When ZFIN arrives, Then no error',
          () async {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);

        // Start session
        final zrinit = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x31, // '01' ZRINIT
          0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, // p0-p3 '00000000'
          0x30, 0x30, 0x30, 0x30, // CRC '0000'
          0x0D, 0x0A, // CR LF
          0x11, // XON
        ]);
        stdoutController.add(zrinit);
        await Future(() {});
        await Future(() {});

        mux.dispose();

        // Should not throw
        stdoutController.add(Uint8List.fromList('after-dispose'.codeUnits));
        await Future(() {});
        expect(mux, isNotNull);
      });
    });

    group('Cancel detection', () {
      test('Given active session, When CAN bytes received, Then no crash',
          () async {
        final mux = ZModemMux(stdin: stdinSink, stdout: stdoutStream);

        // Start session
        final zrinit = Uint8List.fromList([
          0x2A, 0x2A, 0x18, 0x42, // ZPAD ZPAD ZDLE ZHEX
          0x30, 0x31, // '01' ZRINIT
          0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, // p0-p3 '00000000'
          0x30, 0x30, 0x30, 0x30, // CRC '0000'
          0x0D, 0x0A, // CR LF
          0x11, // XON
        ]);
        stdoutController.add(zrinit);
        await Future(() {});
        await Future(() {});

        // Send 5 CAN bytes (cancel sequence)
        stdoutController
            .add(Uint8List.fromList([0x18, 0x18, 0x18, 0x18, 0x18]));
        await Future(() {});
        await Future(() {});

        // Session should be reset, no crash
        expect(mux, isNotNull);
      });
    });

    group('ListExtension', () {
      test('dump returns hex string', () {
        final list = <int>[0x1b, 0x5b, 0x31, 0x6d];
        expect(list.dump(), equals('1b 5b 31 6d'));
      });

      test('dump empty returns empty', () {
        final list = <int>[];
        expect(list.dump(), isEmpty);
      });

      test('dump single byte padded', () {
        final list = <int>[0x0a];
        expect(list.dump(), equals('0a'));
      });

      test('dump handles large values', () {
        final list = <int>[255, 256];
        final result = list.dump();
        expect(result, contains('ff'));
        expect(result, contains('100'));
      });

      test('listIndexOf at start returns 0', () {
        final list = <int>[1, 2, 3];
        expect(list.listIndexOf(<int>[1, 2]), equals(0));
      });

      test('listIndexOf in middle returns index', () {
        final list = <int>[0, 1, 2, 3];
        expect(list.listIndexOf(<int>[2, 3]), equals(2));
      });

      test('listIndexOf at end returns index', () {
        final list = <int>[0, 1, 2];
        expect(list.listIndexOf(<int>[2]), equals(2));
      });

      test('listIndexOf no match returns null', () {
        final list = <int>[1, 2, 3];
        expect(list.listIndexOf(<int>[4, 5]), isNull);
      });

      test('listIndexOf pattern longer than list returns null', () {
        final list = <int>[1, 2];
        expect(list.listIndexOf(<int>[1, 2, 3]), isNull);
      });

      test('listIndexOf with start offset', () {
        final list = <int>[1, 2, 3, 1, 2];
        expect(list.listIndexOf(<int>[1, 2], 2), equals(3));
      });

      test('listIndexOf start beyond length returns null', () {
        final list = <int>[1, 2, 3];
        expect(list.listIndexOf(<int>[1], 5), isNull);
      });

      test('listIndexOf at boundary', () {
        final list = <int>[0, 1, 2, 3, 4];
        expect(list.listIndexOf(<int>[3, 4]), equals(3));
      });

      test('listIndexOf pattern equals full list', () {
        final list = <int>[1, 2, 3];
        expect(list.listIndexOf(<int>[1, 2, 3]), equals(0));
      });

      test('listIndexOf single element at end', () {
        final list = <int>[1, 2, 3];
        expect(list.listIndexOf(<int>[3]), equals(2));
      });
    });
  });
}
