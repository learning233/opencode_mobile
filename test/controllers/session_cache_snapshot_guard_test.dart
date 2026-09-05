import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/api/models/event.dart';
import 'package:opencode_app/controllers/session_controller.dart';
import 'package:opencode_app/init.dart';
import 'package:opencode_app/utils/app_logger.dart';
import 'package:opencode_app/utils/app_settings_store.dart';
import 'package:opencode_app/utils/session_cache_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用固定 support 目录替代平台通道，使 SessionCacheStore.instance 在测试中
/// 落到临时目录（SessionController 内部硬引用 instance，无法注入 baseDir）。
class _FakePathProviderPlatform extends PathProviderPlatform {
  final String supportPath;

  _FakePathProviderPlatform(this.supportPath);

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory supportDir;
  late SessionController ctrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Global.settings = AppSettingsStore(prefs);
    await AppLogger.init(logDir: Directory.systemTemp.createTempSync().path);

    supportDir = Directory.systemTemp.createTempSync('sess_cache_guard');
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);

    ctrl = SessionController();
  });

  tearDown(() {
    supportDir.deleteSync(recursive: true);
  });

  File cacheFile(String sessionId) => File(
    p.join(supportDir.path, 'session_cache', '$sessionId.json'),
  );

  // persist 走 unawaited(_enqueue)，删除/保存均为异步：入队一个无害任务并
  // await 它，即可保证队列中先行任务（含被测的 delete）已全部执行完。
  Future<void> drainWriteQueue() => SessionCacheStore.instance.delete(
    '__drain__',
  );

  SseEvent idleEvent(String sessionId) => SseEvent(
    id: 'evt-$sessionId',
    type: EventTypes.sessionIdle,
    properties: {'sessionID': sessionId},
  );

  group('_persistSessionCacheSnapshot empty-messages guard', () {
    test(
      'idle for never-loaded background session keeps existing disk cache',
      () async {
        // 模拟 App 重启后内存无该会话状态：先落一份好缓存。
        final raw = {'id': 'm1', 'role': 'user', 'parts': []};
        await SessionCacheStore.instance.save('bg-sess', [raw]);
        expect(await SessionCacheStore.instance.load('bg-sess'), isNotNull);

        // 另一端（Web/CLI）的回合结束推来 session.idle：控制器为该会话
        // 凭空建出空状态（hasLoadedHistory=false），不得误删磁盘缓存。
        ctrl.handleEvent(idleEvent('bg-sess'));
        await drainWriteQueue();

        expect(await SessionCacheStore.instance.load('bg-sess'), isNotNull);
        expect(cacheFile('bg-sess').existsSync(), isTrue);
      },
    );

    test(
      'idle after history loaded with empty messages clears disk cache',
      () async {
        await SessionCacheStore.instance.save('empty-sess', [
          {'id': 'm1', 'role': 'user', 'parts': []},
        ]);
        expect(cacheFile('empty-sess').existsSync(), isTrue);

        // 权威空：历史已加载（hasLoadedHistory=true）且消息被清空，
        // 收尾落盘时应删除快照，防止清空/重置的会话冷启动幽灵复活。
        final state = ctrl.getOrCreateSessionState('empty-sess');
        state.hasLoadedHistory.value = true;

        ctrl.handleEvent(idleEvent('empty-sess'));
        await drainWriteQueue();

        expect(await SessionCacheStore.instance.load('empty-sess'), isNull);
        expect(cacheFile('empty-sess').existsSync(), isFalse);
      },
    );
  });
}
