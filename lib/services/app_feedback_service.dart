import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../api/sidecar_manager.dart';
import '../controllers/session_controller.dart';
import '../init.dart';
import '../routes.dart';
import '../utils/app_logger.dart';
import 'voice_input_service.dart';

enum FeedbackType {
  generationCompleted,
  generationError,
  questionRequested,
  permissionRequested,
}

/// Unified foreground audio / background notification feedback service.
class AppFeedbackService extends GetxService {
  static AppFeedbackService get to => Get.find<AppFeedbackService>();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Memoized player creation future：并发 notify 会 await 同一个 future，
  /// 确保只创建、复用同一个 AudioPlayer（避免两个反馈事件各自创建导致
  /// 后覆盖前、前一个 player 永不被 dispose 泄漏）。
  Future<AudioPlayer>? _playerFuture;

  static const String _urgentChannelId = 'feedback_urgent';
  static const String _normalChannelId = 'feedback_normal';

  @override
  void onInit() {
    super.onInit();
    unawaited(init());
  }

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: darwin);
    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    if (GetPlatform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    await _handleLaunchDetails();
  }

  /// Cold-start path: app launched by tapping a notification.
  Future<void> _handleLaunchDetails() async {
    try {
      final details = await _notifications.getNotificationAppLaunchDetails();
      final didLaunch = details?.didNotificationLaunchApp ?? false;
      final response = details?.notificationResponse;
      if (didLaunch && response != null) {
        final sessionId = response.payload ?? '';
        if (sessionId.isNotEmpty) {
          await _openSessionWithRetry(sessionId);
        }
      }
    } catch (e) {
      AppLogger.e('AppFeedbackService: read launch details failed: $e');
    }
  }

  String _soundFor(FeedbackType type) {
    switch (type) {
      case FeedbackType.generationCompleted:
      case FeedbackType.generationError:
        return 'dang.mp3';
      case FeedbackType.questionRequested:
      case FeedbackType.permissionRequested:
        return 'pet_call.mp3';
    }
  }

  /// Foreground: play in-app audio. Background: show system notification.
  Future<void> notify({
    required FeedbackType type,
    required String title,
    required String message,
    required String sessionId,
  }) async {
    try {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await _playSound(type);
      } else {
        await _showNotification(title, message, sessionId, type);
      }
    } catch (e) {
      AppLogger.e('AppFeedbackService: notify failed: $e');
    }
  }

  double _feedbackVolume = 1.0;
  StreamSubscription<PlayerState>? _volumeStateSub;

  Future<AudioPlayer> _ensurePlayer() =>
      _playerFuture ??= _createSoundPoolPlayer();

  Future<void> _playSound(FeedbackType type) async {
    // 设置里"通知音效"开关关闭时，前台不再播放应用内提示音（后台系统通知不受影响）。
    if (!Global.settings.notificationEnabled) {
      return;
    }
    try {
      final player = await _ensurePlayer();
      // 录音进行中时把音量降为 0.1，避免提示音过响干扰识别。
      // 仅基于运行时录音状态判断；Global.continuousVoiceInput 是持久化设置项，
      // 开启后恒 true，即便当前完全没录音也会误压音量。
      _feedbackVolume = VoiceInputService.instance.isListening ? 0.1 : 1.0;
      await player.setVolume(_feedbackVolume);
      await player.stop();
      await player.play(AssetSource(_soundFor(type)));
      // SoundPool 只有在流存在（streamId 非空）时才响应 setVolume，播放后再设一次，
      // 确保实际响度被压住；play(volume:) 在 start 之前调用时对 SoundPool 是空操作。
      await player.setVolume(_feedbackVolume);
    } catch (e) {
      AppLogger.e('AppFeedbackService: play sound failed: $e');
    }
  }

  /// 统一用 SoundPool 低延迟通道播放提示音：不申请音频焦点（`audioFocus: none`）、
  /// 不切 audio mode，与连续语音输入/正在录音的 AudioRecord 可共存，避免 MediaPlayer
  /// 打断录音导致后续语音输入静默失效。
  ///
  /// 音频走通知/铃声流（Android `notificationRingtone`、iOS `ambient`），
  /// 因此跟随系统静音模式与通知音量。不能用 `AudioContextConfig` 构造，
  /// 否则 iOS 会因 `respectSilence` 与 `mixWithOthers` 组合触发断言。
  Future<AudioPlayer> _createSoundPoolPlayer() async {
    final player = AudioPlayer();
    await player.setPlayerMode(PlayerMode.lowLatency);
    await player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          usageType: AndroidUsageType.notificationRingtone,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      ),
    );
    // SoundPool 加载完成后才真正开播，状态流转到 playing 时重设音量，
    // 覆盖异步开播时序下初始音量未生效的情况。
    _volumeStateSub ??= player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        unawaited(player.setVolume(_feedbackVolume));
      }
    });
    return player;
  }

  Future<void> _showNotification(
    String title,
    String message,
    String sessionId,
    FeedbackType type,
  ) async {
    final bool isUrgent = (type != FeedbackType.generationCompleted);
    final android = AndroidNotificationDetails(
      isUrgent ? _urgentChannelId : _normalChannelId,
      isUrgent ? 'AI Urgent Feedback' : 'AI Generation Feedback',
      channelDescription: isUrgent
          ? 'AI questions, permission requests and errors'
          : 'AI generation completion notifications',
      // Both channels are high importance so completion notifications also
      // show a heads-up banner. Per-type sound/vibration/banner can still be
      // adjusted independently in the system's per-channel app settings.
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );
    await _notifications.show(
      id: (sessionId.hashCode ^ type.hashCode) & 0x7fffffff,
      title: title,
      body: message,
      notificationDetails: NotificationDetails(android: android, iOS: darwin),
      payload: sessionId,
    );
  }

  Future<void> _onNotificationTap(NotificationResponse response) async {
    final sessionId = response.payload ?? '';
    if (sessionId.isEmpty) return;
    await _openSessionWithRetry(sessionId);
  }

  /// Best-effort navigation with a bounded retry. The first attempt waits for
  /// the navigator/splash flow to be ready, and later attempts wait for the
  /// sidecar to connect and sessions to load.
  Future<void> _openSessionWithRetry(String sessionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    for (var i = 0; i < 10; i++) {
      if (await _openSession(sessionId)) return;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  /// Returns true when the session was opened & selected successfully.
  ///
  /// Read-only: it never triggers its own session fetch, so it cannot race
  /// with the app's own `fetchSessions`/`_restoreOpenedSessions` during boot.
  /// Navigation only happens after the target session is confirmed present in
  /// the already-loaded session list, guaranteeing the splash boot flow and the
  /// restored open-session list are never disturbed.
  Future<bool> _openSession(String sessionId) async {
    try {
      if (!SidecarManager.instance.isInitialized) return false;
      if (!Get.isRegistered<SessionController>()) return false;
      final controller = Get.find<SessionController>();
      if (controller.sessions.isEmpty) return false;
      final rootId = controller.resolveRootSessionId(sessionId);
      if (controller.sessions.any((s) => s.id == rootId)) {
        if (Get.currentRoute != AppRoutes.home) {
          await Get.offAllNamed(AppRoutes.home);
        }
        controller.selectSession(rootId);
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.e('AppFeedbackService: open session failed: $e');
      return false;
    }
  }

  @override
  void onClose() {
    _volumeStateSub?.cancel();
    _volumeStateSub = null;
    final future = _playerFuture;
    _playerFuture = null;
    if (future != null) {
      future.then((player) => player.dispose());
    }
    super.onClose();
  }
}
