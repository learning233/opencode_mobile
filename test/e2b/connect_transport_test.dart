import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/e2b/e2b.dart';

void main() {
  group('ConnectTransport Protocol Tests (Replicated from rpc.test.ts / connect.test.ts)', () {
    test('encode single frame with 5-byte header', () {
      final jsonPayload = {'message': 'hello world', 'count': 100};
      final frameBytes = ConnectTransport.encodeFrame(jsonPayload);

      // Flag (1 byte) + Length (4 bytes) = 5 bytes header
      expect(frameBytes[0], equals(0x00)); // ConnectFrameFlag.data

      final len = (frameBytes[1] << 24) |
          (frameBytes[2] << 16) |
          (frameBytes[3] << 8) |
          frameBytes[4];

      expect(len, equals(frameBytes.length - 5));
    });

    test('decode single data frame successfully', () {
      final jsonPayload = {'status': 'ok', 'pid': 1234};
      final encoded = ConnectTransport.encodeFrame(jsonPayload);

      final decoded = ConnectTransport.decodeFrames(encoded);
      expect(decoded.length, equals(1));
      expect(decoded[0].flag, equals(ConnectFrameFlag.data));
      expect(decoded[0].jsonMap, equals(jsonPayload));
    });

    test('decode multiple streamed frames in single buffer', () {
      final frame1 = ConnectTransport.encodeFrame({'event': 'start', 'pid': 1});
      final frame2 = ConnectTransport.encodeFrame({'event': 'data', 'stdout': 'aGVsbG8='});
      final frame3 = ConnectTransport.encodeFrame(
        {'event': 'end', 'exit_code': 0},
        flag: ConnectFrameFlag.endOfStream,
      );

      final builder = BytesBuilder();
      builder.add(frame1);
      builder.add(frame2);
      builder.add(frame3);

      final frames = ConnectTransport.decodeFrames(builder.toBytes());
      expect(frames.length, equals(3));
      expect(frames[0].flag, equals(ConnectFrameFlag.data));
      expect(frames[0].jsonMap?['event'], equals('start'));

      expect(frames[1].flag, equals(ConnectFrameFlag.data));
      expect(frames[1].jsonMap?['event'], equals('data'));

      expect(frames[2].flag, equals(ConnectFrameFlag.endOfStream));
      expect(frames[2].jsonMap?['event'], equals('end'));
    });

    test('decodeFrames ignores incomplete trailing bytes without crashing', () {
      final frame = ConnectTransport.encodeFrame({'foo': 'bar'});
      final incomplete = Uint8List.fromList([...frame, 0x00, 0x00, 0x01]); // Incomplete 3-byte prefix

      final frames = ConnectTransport.decodeFrames(incomplete);
      expect(frames.length, equals(1));
      expect(frames[0].jsonMap?['foo'], equals('bar'));
    });
  });
}
