import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/endpoints.dart';
import 'models/quick_phrase.dart';
import 'services/e2b_workspace_service.dart';
import 'utils/app_logger.dart';
import 'utils/app_settings_store.dart';
import 'utils/app_theme.dart';
import 'utils/card_visibility.dart';
import 'utils/image_cache.dart';
import 'package:opencode_app/src/rust/frb_generated.dart';

class Global {
  static late SharedPreferences _prefs;
  static late AppSettingsStore settings;

  static double iconSize = 18;
  static ThemeData themeData = dark;
  static Locale? language;

  /// Reactive display prefs for Obx widgets.
  static final themeIsLightRx = false.obs;
  static final languageRx = Rxn<Locale>();
  static final fontScaleRx = 1.0.obs;
  static final messageDensityRx = 'comfortable'.obs;
  static final keywordDetectionEnabledRx = true.obs;
  static final keywordsRx = <String>[].obs;
  static final quickPhrasesRx = <QuickPhraseItem>[].obs;
  static final terminalCommandsRx = <String>[].obs;
  static final showTerminalExtraKeysRx = true.obs;
  static final showTerminalQuickCommandsRx = true.obs;
  static final cardVisibilityRx = <String, bool>{}.obs;
  static final previewPortsRx = <String, String>{}.obs;

  static final vadThresholdRx = 0.5.obs;
  static final vadMinSilenceDurationRx = 0.5.obs;
  static final vadMinSpeechDurationRx = 0.25.obs;
  static final vadMaxSpeechDurationRx = 10.0.obs;
  static final vadSpeechPadMsRx = 300.obs;
  static final continuousVoiceInputRx = false.obs;
  static final autoSendVoiceEnabledRx = false.obs;
  static final voiceSendCommandRx = '发送'.obs;

  static Future<void>? _rustInitFuture;

  /// Rust 核心（语音 ASR/VAD）初始化 Future。dlopen 原生库 + FRB 注册是启动
  /// 链最重的一步且可降级（失败仅语音不可用，其余功能照常），因此 [init]
  /// 不等待它、首帧先行；语音入口在调用桥接前 `await [rustReady]` 就绪。
  static Future<void> get rustReady => _rustInitFuture ??= _initRust();

  static Future<void> init() async {
    if (kDebugMode) {
      SharedPreferences.setPrefix('flutter_debug.');
    }
    _prefs = await SharedPreferences.getInstance();
    settings = AppSettingsStore(_prefs);
    // 清理过期的消息图片本地缓存（发送时写入），避免无限膨胀。
    unawaited(defaultImageCache.cleanup());
    getTheme();
    getLanguage();
    _loadDisplayPrefs();
    // Rust 初始化移出首帧阻塞路径（见 [rustReady]），语音入口处惰性等待。
    unawaited(rustReady);
  }

  static Future<void> _initRust() async {
    try {
      await RustLib.init();
    } catch (e) {
      // Rust 核心（语音 ASR/VAD）初始化失败不阻塞启动：其余功能照常可用，
      // 仅语音相关能力降级。等待下次调用侧捕获或用户重启。
      AppLogger.e('RustLib.init failed, voice features degraded', e);
    }
  }

  static void _loadDisplayPrefs() {
    fontScaleRx.value = settings.fontScale;
    messageDensityRx.value = settings.messageDensity;
    keywordDetectionEnabledRx.value = settings.keywordDetectionEnabled;
    keywordsRx.assignAll(settings.keywords);
    quickPhrasesRx.assignAll(
      QuickPhraseItem.listFromRaw(settings.quickPhrasesRaw),
    );
    terminalCommandsRx.assignAll(settings.terminalQuickCommands);
    showTerminalExtraKeysRx.value = settings.showTerminalExtraKeys;
    showTerminalQuickCommandsRx.value = settings.showTerminalQuickCommands;
    cardVisibilityRx.assignAll(settings.cardVisibility);
    previewPortsRx.assignAll(settings.getPreviewPorts());

    vadThresholdRx.value = settings.vadThreshold;
    vadMinSilenceDurationRx.value = settings.vadMinSilenceDuration;
    vadMinSpeechDurationRx.value = settings.vadMinSpeechDuration;
    vadMaxSpeechDurationRx.value = settings.vadMaxSpeechDuration;
    vadSpeechPadMsRx.value = settings.vadSpeechPadMs;
    continuousVoiceInputRx.value = settings.continuousVoiceInput;
    autoSendVoiceEnabledRx.value = settings.autoSendVoiceEnabled;
    voiceSendCommandRx.value = settings.voiceSendCommand;
  }

  static void getTheme() {
    bool? isLight = settings.themeIsLight;
    if (isLight != null) {
      themeData = isLight ? light : dark;
      themeIsLightRx.value = isLight;
    } else {
      themeData = Get.isDarkMode ? dark : light;
      themeIsLightRx.value = themeData.brightness == Brightness.light;
    }
  }

  static void getLanguage() {
    String? l = settings.language;
    if (l != null) {
      language = Locale(l.split('_').first, l.split('_').last);
    } else {
      Locale? locale = Get.deviceLocale;
      if (locale == null) {
        language = const Locale('en', 'US');
      } else if (locale.languageCode == 'zh') {
        language = const Locale('zh', 'CN');
      } else {
        language = const Locale('en', 'US');
      }
    }
    languageRx.value = language;
  }

  static Future<void> toggleTheme() async {
    bool currentlyLight = themeIsLightRx.value;
    bool nextIsLight = !currentlyLight;
    themeData = nextIsLight ? light : dark;
    themeIsLightRx.value = nextIsLight;
    await settings.setThemeIsLight(nextIsLight);
    Get.changeTheme(themeData);
    Get.changeThemeMode(nextIsLight ? ThemeMode.light : ThemeMode.dark);
  }

  static Future<void> setLanguage(Locale locale) async {
    language = locale;
    languageRx.value = locale;
    await settings.setLanguage('${locale.languageCode}_${locale.countryCode}');
    Get.updateLocale(locale);
  }

  static Future<void> setShowTerminalExtraKeys(bool value) async {
    showTerminalExtraKeysRx.value = value;
    await settings.setShowTerminalExtraKeys(value);
  }

  static Future<void> setShowTerminalQuickCommands(bool value) async {
    showTerminalQuickCommandsRx.value = value;
    await settings.setShowTerminalQuickCommands(value);
  }

  /// Whether the user has ever saved server settings.
  static bool get hasServerSettings => settings.serverUrl != null;

  /// Whether the user has ever saved self-hosted server settings.
  static bool get hasSelfHostedSettings =>
      settings.selfHostedServerUrl != null ||
      (settings.serverUrl != null &&
          !E2bWorkspaceService.isCloudUrl(settings.serverUrl));

  static String get serverUrl =>
      settings.serverUrl ?? ApiEndpoints.baseLocalUrl;
  static set serverUrl(String v) => settings.setServerUrl(v);

  static String get serverUsername => settings.serverUsername ?? 'opencode';
  static set serverUsername(String v) => settings.setServerUsername(v);

  static String get serverPassword => settings.serverPassword ?? '';
  static set serverPassword(String v) => settings.setServerPassword(v);

  /// 独立保存的自建服务器地址(不被 E2B 云端沙盒覆盖)
  static String get selfHostedServerUrl {
    final saved = settings.selfHostedServerUrl;
    if (saved != null && saved.isNotEmpty) return saved;
    final curr = settings.serverUrl;
    if (curr != null &&
        curr.isNotEmpty &&
        !E2bWorkspaceService.isCloudUrl(curr)) {
      return curr;
    }
    return ApiEndpoints.baseLocalUrl;
  }

  /// 独立保存的自建服务器用户名
  static String get selfHostedServerUsername {
    final saved = settings.selfHostedServerUsername;
    if (saved != null && saved.isNotEmpty) return saved;
    final curr = settings.serverUrl;
    if (curr != null &&
        curr.isNotEmpty &&
        !E2bWorkspaceService.isCloudUrl(curr)) {
      return settings.serverUsername ?? 'opencode';
    }
    return 'opencode';
  }

  /// 独立保存的自建服务器密码
  static String get selfHostedServerPassword {
    final saved = settings.selfHostedServerPassword;
    if (saved != null && saved.isNotEmpty) return saved;
    final curr = settings.serverUrl;
    if (curr != null &&
        curr.isNotEmpty &&
        !E2bWorkspaceService.isCloudUrl(curr)) {
      return settings.serverPassword ?? '';
    }
    return '';
  }

  /// 连接成功后持久化服务器配置：显式 Future 供 SidecarManager await，
  /// 写库失败记日志而非静默丢弃（fire-and-forget 会在连接后立刻被杀时丢配置）。
  static Future<void> persistServerConnection({
    required String url,
    required String username,
    required String password,
  }) async {
    try {
      await settings.setServerUrl(url);
      await settings.setServerUsername(username);
      await settings.setServerPassword(password);

      // 自建服务器连接时，独立同步持久化自建配置，绝不被云端沙盒覆盖
      if (!E2bWorkspaceService.isCloudUrl(url)) {
        await settings.setSelfHostedServerUrl(url);
        await settings.setSelfHostedServerUsername(username);
        await settings.setSelfHostedServerPassword(password);
      }
    } catch (e) {
      AppLogger.e('Failed to persist server connection settings', e);
    }
  }

  static List<String> get openedSessionIds => settings.openedSessionIds;
  static set openedSessionIds(List<String> v) =>
      settings.setOpenedSessionIds(v);

  static List<String> openedSessionIdsForProject(String projectKey) =>
      settings.getOpenedSessionIdsForProject(projectKey);

  static Future<void> setOpenedSessionIdsForProject(
    String projectKey,
    List<String> ids,
  ) => settings.setOpenedSessionIdsForProject(projectKey, ids);

  static String? get savedModelId => settings.savedModelId;
  static Future<void> setSavedModelId(String? id) =>
      settings.setSavedModelId(id);

  static String? get visionModelKey => settings.visionModelKey;
  static Future<void> setVisionModelKey(String? id) =>
      settings.setVisionModelKey(id);

  static String? get savedThinkingLevel => settings.savedThinkingLevel;
  static Future<void> setSavedThinkingLevel(String? level) =>
      settings.setSavedThinkingLevel(level);

  static String? get lastProjectId => settings.lastProjectId;
  static set lastProjectId(String? v) => settings.setLastProjectId(v);

  /// Preview port bound to [projectKey], or null when unbound.
  static String? previewPortForProject(String projectKey) {
    if (projectKey.isEmpty) return null;
    return previewPortsRx[projectKey];
  }

  /// Binds/removes the preview port for [projectKey] and persists it.
  /// Passing null/empty removes the binding.
  static Future<void> setPreviewPort(String projectKey, String? port) async {
    if (projectKey.isEmpty) return;
    await settings.setPreviewPort(projectKey, port);
    previewPortsRx.assignAll(settings.getPreviewPorts());
  }

  static double get fontScale => fontScaleRx.value;
  static set fontScale(double v) {
    fontScaleRx.value = v;
    settings.setFontScale(v);
  }

  static String get messageDensity => messageDensityRx.value;
  static set messageDensity(String v) {
    messageDensityRx.value = v;
    settings.setMessageDensity(v);
  }

  static bool isCardVisible(String key) =>
      isCardVisibleInMap(cardVisibilityRx, key);

  static Future<void> setCardVisible(String key, bool value) async {
    cardVisibilityRx[key] = value;
    await settings.setCardVisibility(Map<String, bool>.from(cardVisibilityRx));
  }

  static Future<void> setAllCardVisible(bool value) async {
    final next = {for (final k in CardVisibilityKeys.all) k: value};
    cardVisibilityRx
      ..clear()
      ..addAll(next);
    await settings.setCardVisibility(next);
  }

  static bool get keywordDetectionEnabled => keywordDetectionEnabledRx.value;
  static set keywordDetectionEnabled(bool v) {
    keywordDetectionEnabledRx.value = v;
    settings.setKeywordDetectionEnabled(v);
  }

  static Future<void> saveKeywords(List<String> keywords) async {
    keywordsRx.assignAll(keywords);
    await settings.setKeywords(keywords);
  }

  static Future<void> saveQuickPhrases(List<QuickPhraseItem> phrases) async {
    quickPhrasesRx.assignAll(phrases);
    await settings.setQuickPhrasesRaw(phrases.map((p) => p.toJson()).toList());
  }

  static Future<void> saveTerminalCommands(List<String> commands) async {
    // 去重（保持顺序），避免重复命令造成编辑/删除命中歧义。
    final deduped = <String>[];
    for (final c in commands) {
      if (!deduped.contains(c)) deduped.add(c);
    }
    terminalCommandsRx.assignAll(deduped);
    await settings.setTerminalQuickCommands(deduped);
  }

  static bool get ptyFilterCurrentProjectOnly =>
      settings.ptyFilterCurrentProjectOnly;
  static set ptyFilterCurrentProjectOnly(bool v) =>
      settings.setPtyFilterCurrentProjectOnly(v);

  /// Vertical padding multiplier from message density.
  static double get messagePaddingScale {
    switch (messageDensityRx.value) {
      case 'compact':
        return 0.6;
      case 'spacious':
        return 1.4;
      default:
        return 1.0;
    }
  }

  static double get vadThreshold => vadThresholdRx.value;
  static set vadThreshold(double v) {
    vadThresholdRx.value = v;
    settings.setVadThreshold(v);
  }

  static double get vadMinSilenceDuration => vadMinSilenceDurationRx.value;
  static set vadMinSilenceDuration(double v) {
    vadMinSilenceDurationRx.value = v;
    settings.setVadMinSilenceDuration(v);
  }

  static double get vadMinSpeechDuration => vadMinSpeechDurationRx.value;
  static set vadMinSpeechDuration(double v) {
    vadMinSpeechDurationRx.value = v;
    settings.setVadMinSpeechDuration(v);
  }

  static double get vadMaxSpeechDuration => vadMaxSpeechDurationRx.value;
  static set vadMaxSpeechDuration(double v) {
    vadMaxSpeechDurationRx.value = v;
    settings.setVadMaxSpeechDuration(v);
  }

  static int get vadSpeechPadMs => vadSpeechPadMsRx.value;
  static set vadSpeechPadMs(int v) {
    vadSpeechPadMsRx.value = v;
    settings.setVadSpeechPadMs(v);
  }

  static bool get continuousVoiceInput => continuousVoiceInputRx.value;
  static set continuousVoiceInput(bool v) {
    continuousVoiceInputRx.value = v;
    settings.setContinuousVoiceInput(v);
  }

  static bool get autoSendVoiceEnabled => autoSendVoiceEnabledRx.value;
  static set autoSendVoiceEnabled(bool v) {
    autoSendVoiceEnabledRx.value = v;
    settings.setAutoSendVoiceEnabled(v);
  }

  static String get voiceSendCommand => voiceSendCommandRx.value;
  static set voiceSendCommand(String v) {
    voiceSendCommandRx.value = v.trim();
    settings.setVoiceSendCommand(v.trim());
  }

  static void resetVadSettings() {
    vadThreshold = 0.5;
    vadMinSilenceDuration = 0.5;
    vadMinSpeechDuration = 0.25;
    vadMaxSpeechDuration = 10.0;
    vadSpeechPadMs = 300;
  }
}
