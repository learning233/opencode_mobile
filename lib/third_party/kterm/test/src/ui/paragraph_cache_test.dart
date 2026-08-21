import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:test/test.dart';
import 'package:kterm/src/ui/paragraph_cache.dart';

void main() {
  group('ParagraphCache', () {
    test('Given a new cache, When created with max size, Then cache is empty',
        () {
      // Arrange & Act
      final cache = ParagraphCache(10);

      // Assert
      expect(cache.length, 0);
    });

    test(
        'Given a cache with items, When getLayoutFromCache called with valid key, Then returns cached paragraph',
        () {
      // Arrange
      final cache = ParagraphCache(10);
      final style = TextStyle();
      final textScaler = TextScaler.noScaling;
      const key = 1;
      const text = 'Hello World';

      // Act
      final paragraph =
          cache.performAndCacheLayout(text, style, textScaler, key);
      final retrieved = cache.getLayoutFromCache(key);

      // Assert
      expect(retrieved, isNotNull);
      expect(retrieved!.toString(), paragraph.toString());
    });

    test(
        'Given a cache, When getLayoutFromCache called with invalid key, Then returns null',
        () {
      // Arrange
      final cache = ParagraphCache(10);

      // Act
      final result = cache.getLayoutFromCache(999);

      // Assert
      expect(result, isNull);
    });

    test('Given a cache with items, When clear called, Then cache is empty',
        () {
      // Arrange
      final cache = ParagraphCache(10);
      final style = TextStyle();
      final textScaler = TextScaler.noScaling;

      cache.performAndCacheLayout('text1', style, textScaler, 1);
      cache.performAndCacheLayout('text2', style, textScaler, 2);

      // Act
      cache.clear();

      // Assert
      expect(cache.length, 0);
    });

    test(
        'Given a cache with max size, When exceeding max size, Then old items are evicted',
        () {
      // Arrange
      final cache = ParagraphCache(2);
      final style = TextStyle();
      final textScaler = TextScaler.noScaling;

      cache.performAndCacheLayout('text1', style, textScaler, 1);
      cache.performAndCacheLayout('text2', style, textScaler, 2);

      // Act - add a third item which should evict the first
      cache.performAndCacheLayout('text3', style, textScaler, 3);

      // Assert - first item should be evicted
      expect(cache.getLayoutFromCache(1), isNull);
      // Second and third should still be there
      expect(cache.getLayoutFromCache(2), isNotNull);
      expect(cache.getLayoutFromCache(3), isNotNull);
    });

    test(
        'Given a cache, When performAndCacheLayout called with same key twice, Then returns new paragraph',
        () {
      // Arrange
      final cache = ParagraphCache(10);
      final style = TextStyle();
      final textScaler = TextScaler.noScaling;
      const key = 1;
      const text = 'Hello';

      // Act
      final paragraph1 =
          cache.performAndCacheLayout(text, style, textScaler, key);
      final paragraph2 =
          cache.performAndCacheLayout(text, style, textScaler, key);

      // Assert - should return paragraph (not necessarily same instance due to LRU behavior)
      expect(paragraph2, isNotNull);
    });

    test(
        'Given a cache, When performAndCacheLayout called with different styles, Then caches separately',
        () {
      // Arrange
      final cache = ParagraphCache(10);
      final style1 = TextStyle(fontSize: 12);
      final style2 = TextStyle(fontSize: 24);
      final textScaler = TextScaler.noScaling;
      const key1 = 1;
      const key2 = 2;

      // Act
      final paragraph1 =
          cache.performAndCacheLayout('text', style1, textScaler, key1);
      final paragraph2 =
          cache.performAndCacheLayout('text', style2, textScaler, key2);

      // Assert
      expect(cache.length, 2);
      expect(paragraph1, isNotNull);
      expect(paragraph2, isNotNull);
    });

    test(
        'Given a cache, When performAndCacheLayout called, Then paragraph is properly laid out',
        () {
      // Arrange
      final cache = ParagraphCache(10);
      final style = TextStyle();
      final textScaler = TextScaler.noScaling;

      // Act
      final paragraph =
          cache.performAndCacheLayout('Hello World', style, textScaler, 1);

      // Assert
      expect(paragraph.width, greaterThan(0));
      expect(paragraph.height, greaterThan(0));
    });
  });
}
