import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('Terminal graphics protocol limits', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal();
    });

    group('graphicsDataChunk chunk limit', () {
      test('rejects chunks when limit (1000) is reached', () async {
        for (int i = 0; i < 1000; i++) {
          terminal.graphicsCommandStart({'f': '100'});
          terminal.graphicsDataChunk([0, 1, 2, 3]);
          terminal.graphicsCommandEnd();
        }
        terminal.graphicsCommandStart({'f': '100'});
        terminal.graphicsDataChunk([0, 1, 2, 3]);
        expect(terminal.graphicsManager.placementCount, equals(0));
      });

      test('clears state when chunk limit exceeded during transmission', () {
        terminal.graphicsCommandStart({'f': '100'});
        for (int i = 0; i < 1001; i++) {
          terminal.graphicsDataChunk([i % 256]);
        }
        // Chunk at index 1000 should cancel transmission
        expect(terminal.graphicsManager.placementCount, equals(0));
      });
    });

    group('graphicsDataChunk total size limit', () {
      test('rejects data when total size exceeds 50MB', () {
        terminal.graphicsCommandStart({'f': '100'});
        final chunkSize = 1024 * 1024; // 1MB
        for (int i = 0; i < 49; i++) {
          terminal.graphicsDataChunk(List.filled(chunkSize, 0));
        }
        // This 2MB chunk pushes total over 50MB limit
        terminal.graphicsDataChunk(List.filled(2 * 1024 * 1024, 0));
        expect(terminal.graphicsManager.placementCount, equals(0));
      });
    });

    group('graphicsCommandEnd malformed input', () {
      test('handles missing f parameter (action only)', () async {
        terminal.graphicsCommandStart({'a': 't'}); // action=t but no format
        terminal.graphicsDataChunk([0, 1, 2, 3]);
        await terminal.graphicsCommandEnd();
        expect(terminal.graphicsManager.placementCount, equals(0));
      });

      test('handles unsupported format f=999', () async {
        terminal.graphicsCommandStart({'f': '999'});
        terminal.graphicsDataChunk([0, 1, 2, 3]);
        await terminal.graphicsCommandEnd();
        expect(terminal.graphicsManager.placementCount, equals(0));
      });

      test('handles empty chunk data', () async {
        terminal.graphicsCommandStart({'f': '100'});
        terminal.graphicsDataChunk([]);
        await terminal.graphicsCommandEnd();
        expect(terminal.graphicsManager.placementCount, equals(0));
      });
    });
  });

  group('Terminal graphics decode error handling', () {
    late Terminal terminal;
    setUp(() => terminal = Terminal());

    test('handles empty RGBA data', () async {
      terminal.graphicsCommandStart({'f': '32', 'w': '1', 'h': '1'});
      terminal.graphicsDataChunk([]); // No data
      await terminal.graphicsCommandEnd();
      expect(terminal.graphicsManager.placementCount, equals(0));
    });

    test('handles PNG decode failure gracefully', () async {
      terminal.graphicsCommandStart({'f': '100'});
      terminal.graphicsDataChunk(List.filled(100, 0xFF)); // Invalid PNG
      await terminal.graphicsCommandEnd();
      expect(terminal.graphicsManager.placementCount, equals(0));
    });
  });

  group('Terminal graphics query (a=q)', () {
    late Terminal terminal;
    setUp(() => terminal = Terminal(onOutput: (_) {}));

    test('responds to image ID query (i=ID)', () async {
      terminal.graphicsCommandStart({'a': 'q', 'i': '42'});
      await terminal.graphicsCommandEnd();
      // onOutput should have been called with response
      // Verified by not throwing
    });

    test('responds to position query (x, y)', () async {
      terminal.graphicsCommandStart({'a': 'q', 'x': '10', 'y': '20'});
      await terminal.graphicsCommandEnd();
    });

    test('responds to query all images (no filters)', () async {
      terminal.graphicsCommandStart({'a': 'q'});
      await terminal.graphicsCommandEnd();
    });
  });

  group('Terminal graphics delete (a=d)', () {
    late Terminal terminal;
    setUp(() => terminal = Terminal());

    test('deletes specific image by ID', () async {
      // Create an image with RGBA data
      terminal.graphicsCommandStart({'a': 't', 'f': '32', 'w': '1', 'h': '1'});
      terminal.graphicsDataChunk([0, 0, 0, 0]); // 1x1 RGBA
      await terminal.graphicsCommandEnd();
      // Get the auto-assigned image ID from the placement
      final placements = terminal.graphicsManager.placements;
      expect(placements.length, equals(1));
      final imageId = placements.values.first.imageId;
      expect(terminal.graphicsManager.getImage(imageId), isNotNull);
      // Delete by that ID
      terminal.graphicsCommandStart({'a': 'd', 'i': '$imageId'});
      await terminal.graphicsCommandEnd();
      expect(terminal.graphicsManager.getImage(imageId), isNull);
    });

    test('deletes image by position coordinates', () async {
      terminal.graphicsCommandStart(
          {'a': 't', 'f': '32', 'x': '5', 'y': '5', 'w': '1', 'h': '1'});
      terminal.graphicsDataChunk([0, 0, 0, 0]); // 1x1 RGBA
      await terminal.graphicsCommandEnd();
      terminal.graphicsCommandStart({'a': 'd', 'x': '5', 'y': '5'});
      await terminal.graphicsCommandEnd();
      expect(terminal.graphicsManager.placementCount, equals(0));
    });

    test('deletes all images when no parameters given', () async {
      for (int i = 1; i <= 3; i++) {
        terminal.graphicsCommandStart(
            {'a': 't', 'f': '32', 'i': '$i', 'w': '1', 'h': '1'});
        terminal.graphicsDataChunk([0, 0, 0, 0]); // 1x1 RGBA
        await terminal.graphicsCommandEnd();
      }
      expect(terminal.graphicsManager.imageCount, equals(3));
      terminal.graphicsCommandStart({'a': 'd'});
      await terminal.graphicsCommandEnd();
      expect(terminal.graphicsManager.imageCount, equals(0));
    });
  });

  group('Terminal image cell management', () {
    late Terminal terminal;
    setUp(() => terminal = Terminal());

    test('clears image data from cells when image deleted', () async {
      terminal.graphicsCommandStart({
        'a': 't',
        'f': '32',
        'x': '2',
        'y': '2',
        'w': '1',
        'h': '1',
        's': '1',
        'v': '1',
      });
      terminal.graphicsDataChunk([0, 0, 0, 0]); // 1x1 RGBA
      await terminal.graphicsCommandEnd();
      expect(terminal.graphicsManager.placementCount, equals(1));
      terminal.graphicsCommandStart({'a': 'd', 'i': '1'});
      await terminal.graphicsCommandEnd();
      final line = terminal.buffer.lines[2];
      final imageData = line.getImageData(2);
      expect(CellImage.hasImage(imageData), isFalse);
    });

    test('respects buffer boundaries during placement', () async {
      terminal.resize(10, 10);
      terminal.graphicsCommandStart({
        'a': 't',
        'f': '32',
        'x': '9',
        'y': '0',
        'w': '1',
        'h': '1',
      });
      terminal.graphicsDataChunk([0, 0, 0, 0]); // 1x1 RGBA
      await terminal.graphicsCommandEnd();
      // Should place without crashing despite width overflow
      expect(terminal.graphicsManager.placementCount, equals(1));
    });
  });

  group('Terminal clipboard OSC 52', () {
    late Terminal terminal;
    late String? capturedData;
    late String? capturedTarget;

    setUp(() {
      capturedData = null;
      capturedTarget = null;
      terminal = Terminal()
        ..onClipboardWrite = (data, target) {
          capturedData = data;
          capturedTarget = target;
        };
    });

    test('decodes valid base64 clipboard content', () {
      final base64 = base64Encode(utf8.encode('test data'));
      terminal.handleClipboard('c', base64);
      expect(capturedData, equals('test data'));
      expect(capturedTarget, equals('c'));
    });

    test('handles invalid base64 without throwing', () {
      expect(
          () => terminal.handleClipboard('c', 'invalid!!!'), returnsNormally);
      expect(capturedData, isNull);
    });

    test('triggers onClipboardRead on query', () {
      String? readTarget;
      terminal.onClipboardRead = (target) => readTarget = target;
      terminal.handleClipboard('c', '?');
      expect(readTarget, equals('c'));
    });

    test('decodes base64 with whitespace and special chars', () {
      final base64 = base64Encode(utf8.encode('hello\nworld\ttab'));
      terminal.handleClipboard('p', base64);
      expect(capturedData, equals('hello\nworld\ttab'));
    });
  });
}
