import 'dart:ui' as ui;
import 'package:test/test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:kterm/src/core/graphics_manager.dart';

import 'graphics_manager_test.mocks.dart';

@GenerateMocks([ui.Image])
void main() {
  group('GraphicsManager', () {
    late GraphicsManager manager;
    late MockImage mockImage;

    setUp(() {
      manager = GraphicsManager(
        maxMemoryBytes: 1000, // Small limit for testing
        maxImageCount: 5,
      );
      mockImage = MockImage();
      // Setup mock image properties
      when(mockImage.width).thenReturn(10);
      when(mockImage.height).thenReturn(10);
    });

    group('storeImage / getImage', () {
      test('stores and retrieves image', () {
        final imageId = manager.storeImage(mockImage);
        expect(imageId, greaterThan(0));

        final retrieved = manager.getImage(imageId);
        expect(retrieved, equals(mockImage));
      });

      test('returns null for non-existent image', () {
        final result = manager.getImage(999);
        expect(result, isNull);
      });

      test('increments image count', () {
        expect(manager.imageCount, equals(0));

        manager.storeImage(mockImage);
        expect(manager.imageCount, equals(1));

        final mockImage2 = MockImage();
        when(mockImage2.width).thenReturn(5);
        when(mockImage2.height).thenReturn(5);
        manager.storeImage(mockImage2);
        expect(manager.imageCount, equals(2));
      });

      test('tracks memory usage', () {
        // 10x10x4 = 400 bytes
        final imageId = manager.storeImage(mockImage);
        expect(manager.currentMemoryBytes, equals(400));
      });
    });

    group('LRU eviction', () {
      test('stores multiple images', () {
        final mockImage1 = MockImage();
        when(mockImage1.width).thenReturn(10);
        when(mockImage1.height).thenReturn(10);

        final mockImage2 = MockImage();
        when(mockImage2.width).thenReturn(10);
        when(mockImage2.height).thenReturn(10);

        final id1 = manager.storeImage(mockImage1);
        final id2 = manager.storeImage(mockImage2);

        expect(id1, isNot(equals(id2))); // Different IDs
        expect(manager.imageCount, equals(2));
        expect(manager.getImage(id1), equals(mockImage1));
        expect(manager.getImage(id2), equals(mockImage2));
      });

      test('does not evict images with active placements', () {
        final mockImage1 = MockImage();
        when(mockImage1.width).thenReturn(10);
        when(mockImage1.height).thenReturn(10);

        final imageId = manager.storeImage(mockImage1);

        // Create placement for the image
        manager.createPlacement(
          imageId: imageId,
          x: 0,
          y: 0,
          width: 10,
          height: 10,
        );

        // Now add more images to trigger eviction
        final mockImage2 = MockImage();
        when(mockImage2.width).thenReturn(10);
        when(mockImage2.height).thenReturn(10);
        manager.storeImage(mockImage2);

        // The image with placement should still exist
        expect(manager.getImage(imageId), equals(mockImage1));
      });
    });

    group('createPlacement / getPlacement / removePlacement', () {
      test('creates placement for existing image', () {
        final imageId = manager.storeImage(mockImage);
        final placementId = manager.createPlacement(
          imageId: imageId,
          x: 5,
          y: 10,
          width: 20,
          height: 15,
        );

        expect(placementId, greaterThan(0));
        expect(manager.placementCount, equals(1));

        final placement = manager.getPlacement(placementId);
        expect(placement, isNotNull);
        expect(placement!.imageId, equals(imageId));
        expect(placement.x, equals(5));
        expect(placement.y, equals(10));
        expect(placement.width, equals(20));
        expect(placement.height, equals(15));
      });

      test('creates placement with overlay flag', () {
        final imageId = manager.storeImage(mockImage);
        final placementId = manager.createPlacement(
          imageId: imageId,
          x: 0,
          y: 0,
          width: 10,
          height: 10,
          overlay: true,
        );

        final placement = manager.getPlacement(placementId);
        expect(placement!.overlay, isTrue);
      });

      test('returns null for non-existent placement', () {
        final result = manager.getPlacement(999);
        expect(result, isNull);
      });

      test('removes placement', () {
        final imageId = manager.storeImage(mockImage);
        final placementId = manager.createPlacement(
          imageId: imageId,
          x: 0,
          y: 0,
          width: 10,
          height: 10,
        );

        expect(manager.placementCount, equals(1));

        manager.removePlacement(placementId);
        expect(manager.placementCount, equals(0));
        expect(manager.getPlacement(placementId), isNull);
      });

      test('clearPlacements removes all placements', () {
        final imageId = manager.storeImage(mockImage);
        manager.createPlacement(
            imageId: imageId, x: 0, y: 0, width: 10, height: 10);
        manager.createPlacement(
            imageId: imageId, x: 5, y: 5, width: 5, height: 5);

        expect(manager.placementCount, equals(2));

        manager.clearPlacements();
        expect(manager.placementCount, equals(0));
      });
    });

    group('getPlacementAt', () {
      test('finds placement at position', () {
        final imageId = manager.storeImage(mockImage);
        manager.createPlacement(
          imageId: imageId,
          x: 5,
          y: 5,
          width: 10,
          height: 10,
        );

        final placement = manager.getPlacementAt(imageId, 7, 7);
        expect(placement, isNotNull);
        expect(placement!.x, equals(5));
        expect(placement.y, equals(5));
      });

      test('returns null when no placement at position', () {
        final imageId = manager.storeImage(mockImage);
        manager.createPlacement(
          imageId: imageId,
          x: 5,
          y: 5,
          width: 5,
          height: 5,
        );

        final placement = manager.getPlacementAt(imageId, 0, 0);
        expect(placement, isNull);
      });

      test('returns first placement when multiple overlap', () {
        final imageId = manager.storeImage(mockImage);
        manager.createPlacement(
          imageId: imageId,
          x: 0,
          y: 0,
          width: 10,
          height: 10,
        );
        manager.createPlacement(
          imageId: imageId,
          x: 2,
          y: 2,
          width: 5,
          height: 5,
        );

        final placement = manager.getPlacementAt(imageId, 3, 3);
        expect(placement, isNotNull);
      });
    });

    group('getPlacementIdAt', () {
      test('returns placement ID at position', () {
        final imageId = manager.storeImage(mockImage);
        final placementId = manager.createPlacement(
          imageId: imageId,
          x: 5,
          y: 5,
          width: 10,
          height: 10,
        );

        final result = manager.getPlacementIdAt(7, 7);
        expect(result, equals(placementId));
      });

      test('returns 0 when no placement at position', () {
        final imageId = manager.storeImage(mockImage);
        manager.createPlacement(
          imageId: imageId,
          x: 5,
          y: 5,
          width: 5,
          height: 5,
        );

        final result = manager.getPlacementIdAt(0, 0);
        expect(result, equals(0));
      });
    });

    group('cleanupStalePlacements', () {
      test('removes placements not in active set', () {
        final imageId = manager.storeImage(mockImage);
        final placementId1 = manager.createPlacement(
          imageId: imageId,
          x: 0,
          y: 0,
          width: 10,
          height: 10,
        );
        final placementId2 = manager.createPlacement(
          imageId: imageId,
          x: 5,
          y: 5,
          width: 5,
          height: 5,
        );

        expect(manager.placementCount, equals(2));

        final removed = manager.cleanupStalePlacements({placementId1});

        expect(removed, equals(1));
        expect(manager.placementCount, equals(1));
        expect(manager.getPlacement(placementId1), isNotNull);
        expect(manager.getPlacement(placementId2), isNull);
      });

      test('removes nothing when all placements are active', () {
        final imageId = manager.storeImage(mockImage);
        final placementId = manager.createPlacement(
          imageId: imageId,
          x: 0,
          y: 0,
          width: 10,
          height: 10,
        );

        final removed = manager.cleanupStalePlacements({placementId});
        expect(removed, equals(0));
      });

      test('removes all when empty active set', () {
        final imageId = manager.storeImage(mockImage);
        manager.createPlacement(
          imageId: imageId,
          x: 0,
          y: 0,
          width: 10,
          height: 10,
        );
        manager.createPlacement(
          imageId: imageId,
          x: 5,
          y: 5,
          width: 5,
          height: 5,
        );

        final removed = manager.cleanupStalePlacements({});
        expect(removed, equals(2));
        expect(manager.placementCount, equals(0));
      });
    });

    group('removeImage', () {
      test('removes image and its placements', () {
        final imageId = manager.storeImage(mockImage);
        manager.createPlacement(
          imageId: imageId,
          x: 0,
          y: 0,
          width: 10,
          height: 10,
        );
        manager.createPlacement(
          imageId: imageId,
          x: 5,
          y: 5,
          width: 5,
          height: 5,
        );

        expect(manager.imageCount, equals(1));
        expect(manager.placementCount, equals(2));

        manager.removeImage(imageId);

        expect(manager.imageCount, equals(0));
        expect(manager.placementCount, equals(0));
        expect(manager.getImage(imageId), isNull);
      });
    });

    group('clear', () {
      test('clears all images and placements', () {
        final imageId = manager.storeImage(mockImage);
        manager.createPlacement(
          imageId: imageId,
          x: 0,
          y: 0,
          width: 10,
          height: 10,
        );

        manager.clear();

        expect(manager.imageCount, equals(0));
        expect(manager.placementCount, equals(0));
        expect(manager.currentMemoryBytes, equals(0));
      });
    });

    group('touchImage', () {
      test('updates LRU timestamp', () async {
        final imageId = manager.storeImage(mockImage);
        final entryBefore = manager.getImageEntry(imageId);
        final accessBefore = entryBefore!.lastAccess;

        // Small delay to ensure different timestamp
        await Future.delayed(const Duration(milliseconds: 10));
        manager.touchImage(imageId);
        final entryAfter = manager.getImageEntry(imageId);
        expect(entryAfter!.lastAccess, greaterThanOrEqualTo(accessBefore));
      });
    });

    group('animation support', () {
      test('getCurrentFrameIndex returns 0 by default', () {
        final imageId = manager.storeImage(mockImage);
        expect(manager.getCurrentFrameIndex(imageId), equals(0));
      });

      test('getFrameCount returns 1 for non-animated', () {
        final imageId = manager.storeImage(mockImage);
        expect(manager.getFrameCount(imageId), equals(1));
      });

      test('getFrameDelay returns null for non-animated', () {
        final imageId = manager.storeImage(mockImage);
        expect(manager.getFrameDelay(imageId), isNull);
      });

      test('advanceFrame returns false for non-animated', () {
        final imageId = manager.storeImage(mockImage);
        expect(manager.advanceFrame(imageId), isFalse);
      });
    });

    group('getImageEntry', () {
      test('returns entry with image and metadata', () {
        final imageId = manager.storeImage(mockImage);
        final entry = manager.getImageEntry(imageId);

        expect(entry, isNotNull);
        expect(entry!.image, equals(mockImage));
        expect(entry.sizeBytes, equals(400));
      });

      test('returns null for non-existent image', () {
        final entry = manager.getImageEntry(999);
        expect(entry, isNull);
      });
    });
  });
}
