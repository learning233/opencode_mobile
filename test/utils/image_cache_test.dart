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

  test(
    'write overwrites previous file atomically without leaving tmp',
    () async {
      await cache.write('m1', 'prt_1', [1, 2, 3]);
      await cache.write('m1', 'prt_1', [4, 5, 6, 7]);

      final file = await cache.find('m1', 'prt_1');
      expect(file, isNotNull);
      expect(await file!.readAsBytes(), [4, 5, 6, 7]);

      final tmpFile = File('${file.path}.tmp');
      expect(tmpFile.existsSync(), isFalse);
    },
  );

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

  test('cleanup evicts oldest files when exceeding maxFiles limit', () async {
    for (var i = 0; i < 5; i++) {
      await cache.write('m$i', 'p$i', [i]);
    }
    for (var i = 0; i < 5; i++) {
      final f = await cache.find('m$i', 'p$i', touch: false);
      f!.setLastModifiedSync(
        DateTime.now().subtract(Duration(minutes: 50 - i * 10)),
      );
    }

    // 上限 3 个，淘汰最旧的 m0 和 m1
    await cache.cleanup(maxFiles: 3);

    expect(await cache.find('m0', 'p0', touch: false), isNull);
    expect(await cache.find('m1', 'p1', touch: false), isNull);
    expect(await cache.find('m2', 'p2', touch: false), isNotNull);
    expect(await cache.find('m3', 'p3', touch: false), isNotNull);
    expect(await cache.find('m4', 'p4', touch: false), isNotNull);
  });

  test(
    'cleanup evicts oldest files when exceeding maxTotalBytes limit',
    () async {
      // 写入 3 个文件，每个 10 字节
      for (var i = 0; i < 3; i++) {
        await cache.write('m$i', 'p$i', List.filled(10, i));
      }
      for (var i = 0; i < 3; i++) {
        final f = await cache.find('m$i', 'p$i', touch: false);
        f!.setLastModifiedSync(
          DateTime.now().subtract(Duration(minutes: 30 - i * 10)),
        );
      }

      // 预算 25 字节，30 字节会超出，淘汰最旧的 m0 (10 字节)，剩下 m1, m2 (20 字节)
      await cache.cleanup(maxTotalBytes: 25);

      expect(await cache.find('m0', 'p0', touch: false), isNull);
      expect(await cache.find('m1', 'p1', touch: false), isNotNull);
      expect(await cache.find('m2', 'p2', touch: false), isNotNull);
    },
  );

  test('write ignores empty bytes and does not create file', () async {
    await cache.write('m1', 'p_empty', []);
    expect(await cache.find('m1', 'p_empty'), isNull);
  });

  test('cleanup removes orphan tmp files and 0-byte corrupt files', () async {
    final orphanTmp = File('${temp.path}/image_cache/orphan.img.tmp')
      ..createSync(recursive: true);
    orphanTmp.writeAsBytesSync([1, 2, 3]);

    final zeroByteImg = File('${temp.path}/image_cache/m_zero_p_zero.img')
      ..createSync(recursive: true);
    zeroByteImg.writeAsBytesSync([]);

    expect(orphanTmp.existsSync(), isTrue);
    expect(zeroByteImg.existsSync(), isTrue);

    await cache.cleanup();

    expect(orphanTmp.existsSync(), isFalse);
    expect(zeroByteImg.existsSync(), isFalse);
  });
}
