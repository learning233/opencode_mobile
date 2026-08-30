import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';
import 'card_visibility.dart';

class AppSettingsStore {
  AppSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  /// 读-改-写类持久化的串行队列：两次写之间的 await 会把事件循环让给另一次
  /// RMW，导致后写覆盖先写（如快速连续操作两个项目的页签/预览端口）。
  Future<void> _prefsWriteQueue = Future.value();

  /// 把一次读-改-写任务串入队列。返回值保留原有错误语义（抛给调用方），
  /// 队列本身通过 catchError 吞掉失败继续排后续任务。
  Future<void> _enqueuePrefsWrite(Future<void> Function() task) {
    final result = _prefsWriteQueue.then((_) => task());
    _prefsWriteQueue = result.catchError((Object e) {
      AppLogger.e('AppSettingsStore queued write failed', e);
    });
    return result;
  }

  static const _themeIsLight = 'theme_is_light';
  static const _language = 'language';
  static const _serverUrl = 'server_url';
  static const _serverUsername = 'server_username';
  static const _serverPassword = 'server_password';
  static const _openedSessionIds = 'opened_session_ids';
  static const _projectOpenedSessionIds = 'project_opened_session_ids_map';
  static const _projectPreviewPorts = 'project_preview_ports_map';
  static const _lastProjectId = 'last_project_id';
  static const _terminalQuickCommands = 'terminal_quick_commands';
  static const _fontScale = 'font_scale';
  static const _messageDensity = 'message_density';
  static const _keywords = 'keywords';
  static const _keywordDetectionEnabled = 'keyword_detection_enabled';
  static const _quickPhrases = 'quick_phrases';
  static const _defaultModelKey = 'default_model_key';
  static const _savedModelId = 'saved_model_id';
  static const _visionModelKey = 'vision_model_key';
  static const _savedThinkingLevel = 'saved_thinking_level';
  static const _notificationEnabled = 'notification_enabled';
  static const _cardVisibility = 'card_visibility';
  static const _shownModels = 'shown_models';
  static const _hiddenModels = 'hidden_models';
  static const _hiddenProjects = 'hidden_projects';
  static const _disabledModels = 'disabled_models';
  static const _filterCurrentProjectOnly = 'pty_filter_current_project_only';
  static const _vadThreshold = 'vad_threshold';
  static const _vadMinSilenceDuration = 'vad_min_silence_duration';
  static const _vadMinSpeechDuration = 'vad_min_speech_duration';
  static const _vadMaxSpeechDuration = 'vad_max_speech_duration';
  static const _vadSpeechPadMs = 'vad_speech_pad_ms';
  static const _continuousVoiceInput = 'continuous_voice_input';
  static const _autoSendVoiceEnabled = 'auto_send_voice_enabled';
  static const _voiceSendCommand = 'voice_send_command';
  static const _editorFontSize = 'editor_font_size';
  static const _editorWordWrap = 'editor_word_wrap';
  static const _editorShowLineNumbers = 'editor_show_line_numbers';
  static const _showTerminalExtraKeys = 'terminal_show_extra_keys';
  static const _showTerminalQuickCommands = 'terminal_show_quick_commands';

  bool get ptyFilterCurrentProjectOnly =>
      _prefs.getBool(_filterCurrentProjectOnly) ?? true;
  Future<void> setPtyFilterCurrentProjectOnly(bool value) =>
      _prefs.setBool(_filterCurrentProjectOnly, value);

  bool get showTerminalExtraKeys =>
      _prefs.getBool(_showTerminalExtraKeys) ?? true;
  Future<void> setShowTerminalExtraKeys(bool value) =>
      _prefs.setBool(_showTerminalExtraKeys, value);

  bool get showTerminalQuickCommands =>
      _prefs.getBool(_showTerminalQuickCommands) ?? true;
  Future<void> setShowTerminalQuickCommands(bool value) =>
      _prefs.setBool(_showTerminalQuickCommands, value);

  bool? get themeIsLight => _prefs.getBool(_themeIsLight);
  Future<void> setThemeIsLight(bool value) =>
      _prefs.setBool(_themeIsLight, value);

  String? get language => _prefs.getString(_language);
  Future<void> setLanguage(String value) => _prefs.setString(_language, value);

  String? get serverUrl => _prefs.getString(_serverUrl);
  Future<void> setServerUrl(String value) =>
      _prefs.setString(_serverUrl, value);

  String? get serverUsername => _prefs.getString(_serverUsername);
  Future<void> setServerUsername(String value) =>
      _prefs.setString(_serverUsername, value);

  String? get serverPassword => _prefs.getString(_serverPassword);
  Future<void> setServerPassword(String value) =>
      _prefs.setString(_serverPassword, value);

  List<String> get openedSessionIds {
    final raw = _prefs.getStringList(_openedSessionIds);
    return raw ?? [];
  }

  Future<void> setOpenedSessionIds(List<String> ids) =>
      _prefs.setStringList(_openedSessionIds, ids);

  List<String> getOpenedSessionIdsForProject(String projectKey) {
    if (projectKey.isEmpty) return openedSessionIds;
    final raw = _prefs.getString(_projectOpenedSessionIds);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final list = map[projectKey];
        if (list is List) {
          return list.map((e) => e.toString()).toList();
        }
      } catch (e) {
        AppLogger.w(
          'AppSettingsStore: corrupted JSON in $_projectOpenedSessionIds, treating as empty: $e',
        );
      }
    }
    // 项目无记录时返回空列表，不回退到全局 openedSessionIds（=最近一次写入
    // 项目的页签），避免把 A 项目的页签当作 B 项目恢复造成跨项目污染。
    return const [];
  }

  Future<void> setOpenedSessionIdsForProject(
    String projectKey,
    List<String> ids,
  ) {
    return _enqueuePrefsWrite(() async {
      await setOpenedSessionIds(ids);
      if (projectKey.isEmpty) return;

      final raw = _prefs.getString(_projectOpenedSessionIds);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        try {
          map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        } catch (e) {
          AppLogger.w(
            'AppSettingsStore: corrupted JSON in $_projectOpenedSessionIds, resetting: $e',
          );
        }
      }
      map[projectKey] = ids;
      await _prefs.setString(_projectOpenedSessionIds, jsonEncode(map));
    });
  }

  String? get lastProjectId => _prefs.getString(_lastProjectId);
  Future<void> setLastProjectId(String? value) {
    if (value != null) {
      return _prefs.setString(_lastProjectId, value);
    }
    return _prefs.remove(_lastProjectId);
  }

  /// Returns the preview port bound to [projectKey], or null when unbound.
  String? getPreviewPort(String projectKey) {
    if (projectKey.isEmpty) return null;
    final raw = _prefs.getString(_projectPreviewPorts);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final port = map[projectKey];
        return port?.toString().trim().isNotEmpty == true
            ? port.toString().trim()
            : null;
      } catch (e) {
        AppLogger.w(
          'AppSettingsStore: corrupted JSON in $_projectPreviewPorts, treating as unbound: $e',
        );
      }
    }
    return null;
  }

  /// Returns all project → port bindings as a map (for reactive UI state).
  Map<String, String> getPreviewPorts() {
    final raw = _prefs.getString(_projectPreviewPorts);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final result = <String, String>{};
      map.forEach((key, value) {
        final port = value?.toString().trim();
        if (port != null && port.isNotEmpty) {
          result[key] = port;
        }
      });
      return result;
    } catch (e) {
      AppLogger.w(
        'AppSettingsStore: corrupted JSON in $_projectPreviewPorts, returning empty: $e',
      );
      return {};
    }
  }

  /// Binds the preview port to [projectKey]. Passing null/empty removes the binding.
  Future<void> setPreviewPort(String projectKey, String? port) {
    if (projectKey.isEmpty) return Future.value();
    return _enqueuePrefsWrite(() async {
      final cleaned = port?.trim() ?? '';
      final raw = _prefs.getString(_projectPreviewPorts);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        try {
          map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        } catch (e) {
          AppLogger.w(
            'AppSettingsStore: corrupted JSON in $_projectPreviewPorts, resetting: $e',
          );
        }
      }
      if (cleaned.isEmpty) {
        map.remove(projectKey);
      } else {
        map[projectKey] = cleaned;
      }
      await _prefs.setString(_projectPreviewPorts, jsonEncode(map));
    });
  }

  double get fontScale => _prefs.getDouble(_fontScale) ?? 1.0;
  Future<void> setFontScale(double value) =>
      _prefs.setDouble(_fontScale, value);

  /// compact | comfortable | spacious
  String get messageDensity =>
      _prefs.getString(_messageDensity) ?? 'comfortable';
  Future<void> setMessageDensity(String value) =>
      _prefs.setString(_messageDensity, value);

  List<String> get keywords => _prefs.getStringList(_keywords) ?? [];
  Future<void> setKeywords(List<String> value) =>
      _prefs.setStringList(_keywords, value);

  bool get keywordDetectionEnabled =>
      _prefs.getBool(_keywordDetectionEnabled) ?? true;
  Future<void> setKeywordDetectionEnabled(bool value) =>
      _prefs.setBool(_keywordDetectionEnabled, value);

  /// Stored as JSON-encoded strings. Backward-compatible with plain text.
  List<dynamic> get quickPhrasesRaw {
    final raw = _prefs.getStringList(_quickPhrases) ?? [];
    return raw.map((e) {
      if (!e.startsWith('{')) return e;
      try {
        return jsonDecode(e) as Map<String, dynamic>;
      } catch (_) {
        return e;
      }
    }).toList();
  }

  Future<void> setQuickPhrasesRaw(List<dynamic> value) async {
    final encoded = value.map((e) {
      if (e is Map) return jsonEncode(e);
      return e.toString();
    }).toList();
    await _prefs.setStringList(_quickPhrases, encoded);
  }

  List<String> get terminalQuickCommands =>
      _prefs.getStringList(_terminalQuickCommands) ?? const [];
  Future<void> setTerminalQuickCommands(List<String> value) =>
      _prefs.setStringList(_terminalQuickCommands, value);

  String? get defaultModelKey => _prefs.getString(_defaultModelKey);
  Future<void> setDefaultModelKey(String value) =>
      _prefs.setString(_defaultModelKey, value);

  String? get savedModelId => _prefs.getString(_savedModelId);
  Future<void> setSavedModelId(String? value) {
    if (value != null && value.isNotEmpty) {
      return _prefs.setString(_savedModelId, value);
    }
    return _prefs.remove(_savedModelId);
  }

  /// 图片转文字使用的识图模型 key（`providerId:id`）；null 表示自动从输入框
  /// 模型列表里选第一个支持识图的模型。
  String? get visionModelKey => _prefs.getString(_visionModelKey);
  Future<void> setVisionModelKey(String? value) {
    if (value != null && value.isNotEmpty) {
      return _prefs.setString(_visionModelKey, value);
    }
    return _prefs.remove(_visionModelKey);
  }

  String? get savedThinkingLevel => _prefs.getString(_savedThinkingLevel);
  Future<void> setSavedThinkingLevel(String? value) {
    if (value != null && value.isNotEmpty) {
      return _prefs.setString(_savedThinkingLevel, value);
    }
    return _prefs.remove(_savedThinkingLevel);
  }

  bool get notificationEnabled => _prefs.getBool(_notificationEnabled) ?? true;
  Future<void> setNotificationEnabled(bool value) =>
      _prefs.setBool(_notificationEnabled, value);

  /// Client-side model visibility (matches desktop prefs).
  List<String> get shownModels =>
      _prefs.getStringList(_shownModels) ?? const [];

  List<String> get hiddenModels =>
      _prefs.getStringList(_hiddenModels) ?? const [];

  /// 模型可见性切换涉及 shown/hidden 两个 key 的读-改-写，入队串行化，
  /// 避免快速连续切换两个模型时后写覆盖先写。
  Future<void> setModelVisibility(String modelKey, bool visible) {
    return _enqueuePrefsWrite(() async {
      final shown = _prefs.getStringList(_shownModels) ?? const [];
      final hidden = _prefs.getStringList(_hiddenModels) ?? const [];
      final shownNext = shown.where((m) => m != modelKey).toList();
      final hiddenNext = hidden.where((m) => m != modelKey).toList();
      if (visible) {
        shownNext.add(modelKey);
      } else {
        hiddenNext.add(modelKey);
      }
      await _prefs.setStringList(_shownModels, shownNext);
      await _prefs.setStringList(_hiddenModels, hiddenNext);
    });
  }

  /// Client-side hidden projects (normalized worktree paths, drawer-only).
  List<String> get hiddenProjects =>
      _prefs.getStringList(_hiddenProjects) ?? const [];
  Future<void> setHiddenProjects(List<String> keys) =>
      _prefs.setStringList(_hiddenProjects, keys);

  List<String> get disabledModels =>
      _prefs.getStringList(_disabledModels) ?? const [];
  Future<void> setDisabledModels(List<String> models) =>
      _prefs.setStringList(_disabledModels, models);

  Map<String, bool> get cardVisibility =>
      parseCardVisibilityJson(_prefs.getString(_cardVisibility));

  Future<void> setCardVisibility(Map<String, bool> value) =>
      _prefs.setString(_cardVisibility, encodeCardVisibilityJson(value));

  double get vadThreshold => _prefs.getDouble(_vadThreshold) ?? 0.5;
  Future<void> setVadThreshold(double value) =>
      _prefs.setDouble(_vadThreshold, value);

  double get vadMinSilenceDuration =>
      _prefs.getDouble(_vadMinSilenceDuration) ?? 0.5;
  Future<void> setVadMinSilenceDuration(double value) =>
      _prefs.setDouble(_vadMinSilenceDuration, value);

  double get vadMinSpeechDuration =>
      _prefs.getDouble(_vadMinSpeechDuration) ?? 0.25;
  Future<void> setVadMinSpeechDuration(double value) =>
      _prefs.setDouble(_vadMinSpeechDuration, value);

  double get vadMaxSpeechDuration =>
      _prefs.getDouble(_vadMaxSpeechDuration) ?? 10.0;
  Future<void> setVadMaxSpeechDuration(double value) =>
      _prefs.setDouble(_vadMaxSpeechDuration, value);

  int get vadSpeechPadMs => _prefs.getInt(_vadSpeechPadMs) ?? 300;
  Future<void> setVadSpeechPadMs(int value) =>
      _prefs.setInt(_vadSpeechPadMs, value);

  bool get continuousVoiceInput =>
      _prefs.getBool(_continuousVoiceInput) ?? false;
  Future<void> setContinuousVoiceInput(bool value) =>
      _prefs.setBool(_continuousVoiceInput, value);

  bool get autoSendVoiceEnabled =>
      _prefs.getBool(_autoSendVoiceEnabled) ?? false;
  Future<void> setAutoSendVoiceEnabled(bool value) =>
      _prefs.setBool(_autoSendVoiceEnabled, value);

  String get voiceSendCommand => _prefs.getString(_voiceSendCommand) ?? '发送';
  Future<void> setVoiceSendCommand(String value) =>
      _prefs.setString(_voiceSendCommand, value);

  double get editorFontSize => _prefs.getDouble(_editorFontSize) ?? 13.0;
  Future<void> setEditorFontSize(double value) =>
      _prefs.setDouble(_editorFontSize, value);

  bool get editorWordWrap => _prefs.getBool(_editorWordWrap) ?? false;
  Future<void> setEditorWordWrap(bool value) =>
      _prefs.setBool(_editorWordWrap, value);

  bool get editorShowLineNumbers =>
      _prefs.getBool(_editorShowLineNumbers) ?? true;
  Future<void> setEditorShowLineNumbers(bool value) =>
      _prefs.setBool(_editorShowLineNumbers, value);
}
