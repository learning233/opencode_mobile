import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/utils/image_cache.dart';

void main() {
  late Directory temp;
  late ImageCache cache;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('image_cache_test');
    cache = ImageCache(baseDir: temp);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('write then find returns the stored bytes', () async {
    await cache.write('m1', 'prt_1', [1, 2, 3]);

    final file = await cache.find('m1', 'prt_1');

    expect(file, isNotNull);
    expect(await file!.readAsBytes(), [1, 2, 3]);
  });

  test('find returns null when no entry exists', () async {
    expect(await cache.find('m1', 'nope'), isNull);
  });

  test('keys are isolated by message and part id', () async {
    await cache.write('m1', 'prt_a', [1]);
    await cache.write('m2', 'prt_a', [2]);

    expect(await cache.find('m1', 'prt_a'), isNotNull);
    expect(await cache.find('m2', 'prt_a'), isNotNull);
    expect(await cache.find('m1', 'prt_b'), isNull);
  });

  test('cleanup removes stale files and keeps recent ones', () async {
    await cache.write('m1', 'old', [1]);
    await cache.write('m1', 'new', [2]);

    final oldFile = await cache.find('m1', 'old');
    final newFile = await cache.find('m1', 'new');
    oldFile!.setLastModifiedSync(
      DateTime.now().subtract(const Duration(days: 30)),
    );
    newFile!.setLastModifiedSync(DateTime.now());

    await cache.cleanup(maxAge: const Duration(days: 7));

    expect(await cache.find('m1', 'old'), isNull);
    expect(await cache.find('m1', 'new'), isNotNull);
  });
}
