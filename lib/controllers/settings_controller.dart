import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:url_launcher/url_launcher.dart';
import '../api/endpoints.dart';
import '../api/mcp_registry_client.dart';
import '../api/models/registry_server.dart';
import '../api/models/settings.dart';
import '../api/opencode_client.dart';
import '../init.dart';
import '../models/model_info.dart';
import '../models/quick_phrase.dart';
import '../utils/app_logger.dart';
import '../utils/url_utils.dart';

class McpServerStatus {
  final String name;
  final String status;
  final String? error;
  final String type;
  final String? command;
  final String? url;
  final List<String> tools;
  final Map<String, String> env;
  final Map<String, String> headers;

  McpServerStatus({
    required this.name,
    required this.status,
    this.error,
    this.type = '',
    this.command,
    this.url,
    this.tools = const [],
    this.env = const {},
    this.headers = const {},
  });

  factory McpServerStatus.fromEntry(String name, dynamic raw) {
    if (raw is Map) {
      final statusField = raw['status'];
      String status;
      String? error;
      if (statusField is Map) {
        status = statusField['status']?.toString() ?? 'unknown';
        error = statusField['error']?.toString() ?? raw['error']?.toString();
      } else {
        status =
            statusField?.toString() ?? raw['state']?.toString() ?? 'unknown';
        error = raw['error']?.toString();
      }

      final cmdRaw = raw['command'];
      String? command;
      if (cmdRaw is List) {
        command = cmdRaw.map((e) => e.toString()).join(' ');
      } else if (cmdRaw != null) {
        command = cmdRaw.toString();
      }

      final toolsRaw = raw['tools'];
      final tools = <String>[];
      if (toolsRaw is List) {
        for (final t in toolsRaw) {
          if (t is Map) {
            final n = t['name']?.toString() ?? t['id']?.toString();
            if (n != null && n.isNotEmpty) tools.add(n);
          } else if (t != null) {
            tools.add(t.toString());
          }
        }
      }

      final envRaw = raw['env'] ?? raw['environment'];
      final env = <String, String>{};
      if (envRaw is Map) {
        envRaw.forEach((k, v) {
          if (v != null) env[k.toString()] = v.toString();
        });
      }

      final headersRaw = raw['headers'];
      final headers = <String, String>{};
      if (headersRaw is Map) {
        headersRaw.forEach((k, v) {
          if (v != null) headers[k.toString()] = v.toString();
        });
      }

      return McpServerStatus(
        name: raw['name']?.toString() ?? name,
        status: status,
        error: error,
        type: raw['type']?.toString() ?? raw['transport']?.toString() ?? '',
        command: command,
        url: raw['url']?.toString(),
        tools: tools,
        env: env,
        headers: headers,
      );
    }
    return McpServerStatus(name: name, status: raw?.toString() ?? 'unknown');
  }

  bool get isConnected =>
      status == 'connected' || status == 'enabled' || status == 'running';
}

class LspServerInfo {
  final String id;
  final String name;
  final String root;
  final String status;
  final List<String> extensions;
  final String? command;
  final String? error;
  final bool disabled;

  LspServerInfo({
    required this.id,
    required this.name,
    this.root = '',
    this.status = 'unknown',
    this.extensions = const [],
    this.command,
    this.error,
    this.disabled = false,
  });

  factory LspServerInfo.fromJson(Map<String, dynamic> json) {
    final rawExt = json['extensions'];
    final extensions = rawExt is List
        ? rawExt.map((e) => e.toString()).toList()
        : const <String>[];

    return LspServerInfo(
      id: json['id']?.toString() ?? '',
      name:
          json['name']?.toString() ??
          json['id']?.toString() ??
          json['language']?.toString() ??
          'lsp',
      root: json['root']?.toString() ?? '',
      status:
          json['status']?.toString() ?? json['state']?.toString() ?? 'unknown',
      extensions: extensions,
      command: json['command']?.toString() ?? json['executable']?.toString(),
      error: json['error']?.toString(),
      disabled: json['disabled'] == true,
    );
  }

  bool get isInstalled =>
      status == 'installed' || status == 'running' || status == 'connected';
}

class SettingsController extends GetxController {
  final OpenCodeClient _client = OpenCodeClient();

  final providers = <ProviderInfo>[].obs;
  final isLoadingProviders = false.obs;

  final healthOk = RxnBool();
  final healthVersion = ''.obs;
  final healthChecking = false.obs;

  final mcpServers = <McpServerStatus>[].obs;
  final mcpLoading = false.obs;
  final mcpError = ''.obs;
  final mcpActionInProgress = <String>{}.obs;

  final registryServers = <RegistryServerInfo>[].obs;
  final isLoadingRegistry = false.obs;
  final registryError = ''.obs;
  final registryNextCursor = Rxn<String>();
  final _registryClient = McpRegistryClient();
  String _lastRegistryQuery = '';
  int _registryRequestSeq = 0;

  final lspServers = <LspServerInfo>[].obs;
  final lspLoading = false.obs;
  final lspStatus = ''.obs;

  final formatters = <Map<String, dynamic>>[].obs;
  final formattersLoading = false.obs;
  final formattersError = ''.obs;

  final references = <Map<String, dynamic>>[].obs;
  final referencesLoading = false.obs;
  final referencesError = ''.obs;

  final skills = <Map<String, dynamic>>[].obs;
  final skillsLoading = false.obs;
  final skillsError = ''.obs;

  final availableAgents = <AgentDetailInfo>[].obs;
  final isLoadingAgents = false.obs;
  final agentsError = ''.obs;
  final savingStates = <String, bool>{}.obs;

  /// FIFO tail of in-flight `updateGlobalConfig` calls. Serializes PATCHes so
  /// rapid toggle changes don't race: each call waits for the previous one to
  /// finish (and refetch config) before issuing its own PATCH, preventing the
  /// later response from overwriting an earlier change.
  Future<bool>? _configPatchTail;
  static const agentModes = ['primary', 'subagent', 'all'];

  final defaultModelKey = ''.obs;

  final globalConfig = Rxn<Map<String, dynamic>>();
  final projectConfig = Rxn<Map<String, dynamic>>();
  final isLoadingGlobalConfig = false.obs;
  final isLoadingProjectConfig = false.obs;

  final globalRulesContent = ''.obs;
  final hasGlobalRules = false.obs;
  final isLoadingGlobalRules = false.obs;
  final globalAgentsPath = ''.obs;
  final globalRulesError = ''.obs;

  final availableShells = <String>[].obs;
  final isLoadingShells = false.obs;

  final notificationEnabled = true.obs;

  static const logLevels = ['DEBUG', 'INFO', 'WARN', 'ERROR'];
  static const shareModes = ['manual', 'auto', 'disabled'];

  static const _knownPermissions = [
    'read',
    'edit',
    'bash',
    'glob',
    'grep',
    'list',
    'task',
    'webfetch',
    'websearch',
    'todowrite',
    'question',
    'external_directory',
    'lsp',
    'skill',
    'doom_loop',
  ];

  List<String> get knownPermissions => _knownPermissions;

  static String permissionDescription(String tool) {
    switch (tool) {
      case 'read':
        return 'Read files from disk';
      case 'edit':
        return 'Create or modify files';
      case 'bash':
        return 'Execute shell commands';
      case 'glob':
        return 'Find files by glob pattern';
      case 'grep':
        return 'Search file contents';
      case 'list':
        return 'List directory contents';
      case 'task':
        return 'Spawn subagent tasks';
      case 'webfetch':
        return 'Fetch content from URLs';
      case 'websearch':
        return 'Search the web';
      case 'todowrite':
        return 'Create and update todo lists';
      case 'question':
        return 'Ask the user clarifying questions';
      case 'external_directory':
        return 'Access directories outside the project';
      case 'lsp':
        return 'Use language server features';
      case 'skill':
        return 'Load and run skills';
      case 'doom_loop':
        return 'Continue after repeated tool failures';
      default:
        return '';
    }
  }

  /// Sentinel when a tool permission is a path→action object (not a flat action).
  static const String permissionCustom = 'custom';

  /// Resolves a tool permission from [map], falling back to backend defaults.
  ///
  /// Returns [permissionCustom] when the value is a Map of path rules so the UI
  /// does not mis-display it as allow/ask/deny.
  static String permissionFor(Map<String, dynamic>? map, String tool) {
    final value = map?[tool];
    if (value is Map) return permissionCustom;
    if (value is String && value.isNotEmpty) {
      if (value == 'ask' || value == 'allow' || value == 'deny') return value;
    }
    switch (tool) {
      case 'doom_loop':
      case 'external_directory':
        return 'ask';
      default:
        return 'allow';
    }
  }

  Map<String, dynamic>? get permission =>
      globalConfig.value?['permission'] is Map
      ? Map<String, dynamic>.from(globalConfig.value!['permission'] as Map)
      : null;

  Map<String, dynamic>? get compaction =>
      globalConfig.value?['compaction'] is Map
      ? Map<String, dynamic>.from(globalConfig.value!['compaction'] as Map)
      : null;

  String? get shareMode => globalConfig.value?['share']?.toString();

  dynamic get autoupdate => globalConfig.value?['autoupdate'];

  bool? get snapshot => globalConfig.value?['snapshot'] as bool?;

  String? get username => globalConfig.value?['username']?.toString();

  String? get shell => globalConfig.value?['shell']?.toString();

  String? get logLevel => globalConfig.value?['logLevel']?.toString();

  String? get smallModel {
    final cfg = globalConfig.value;
    if (cfg == null) return null;
    return cfg['small_model']?.toString() ?? cfg['smallModel']?.toString();
  }

  /// Local client preference — same source as desktop `Global.settings`.
  final shownModelsRx = <String>[].obs;
  final hiddenModelsRx = <String>[].obs;
  final disabledModelsRx = <String>[].obs;

  List<String> get shownModels => shownModelsRx.toList();
  List<String> get hiddenModels => hiddenModelsRx.toList();
  List<String> get disabledModels => disabledModelsRx.toList();

  void _loadModelVisibilityPrefs() {
    shownModelsRx
      ..clear()
      ..addAll(Global.settings.shownModels);
    hiddenModelsRx
      ..clear()
      ..addAll(Global.settings.hiddenModels);
    disabledModelsRx
      ..clear()
      ..addAll(Global.settings.disabledModels);
  }

  Map<String, dynamic>? get experimental =>
      globalConfig.value?['experimental'] is Map
      ? Map<String, dynamic>.from(globalConfig.value!['experimental'] as Map)
      : null;

  Map<String, dynamic>? get skillsConfig {
    final global = globalConfig.value?['skills'];
    if (global is Map) {
      return Map<String, dynamic>.from(global);
    }
    return null;
  }

  List<String> _skillsStringList(String key) {
    final cfg = skillsConfig;
    final raw = cfg?[key];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  List<String> get skillsPaths => _skillsStringList('paths');

  List<String> get skillsUrls => _skillsStringList('urls');

  List<String> get instructionPaths => _configStringList('instructions');

  List<String> _configStringList(String key) {
    final raw = globalConfig.value?[key];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Future<bool> setInstructionPaths(List<String> paths) =>
      patchGlobalConfig({'instructions': paths});

  String _parseRemoteFileContent(dynamic data) {
    if (data is Map) {
      final nested = data['data'];
      if (nested is Map && nested['content'] != null) {
        return nested['content'].toString();
      }
      if (data['content'] != null) {
        return data['content'].toString();
      }
    }
    if (data is String) return data;
    return data?.toString() ?? '';
  }

  Future<void> _resolveGlobalAgentsPath() async {
    if (globalAgentsPath.value.isNotEmpty) return;
    try {
      final res = await _client.get(ApiEndpoints.path);
      if (res.statusCode == 200 && res.data is Map) {
        final map = Map<String, dynamic>.from(res.data as Map);
        final home = map['home']?.toString() ?? '';
        if (home.isNotEmpty) {
          final sep = home.contains('\\') ? '\\' : '/';
          globalAgentsPath.value = [
            home,
            '.config',
            'opencode',
            'AGENTS.md',
          ].join(sep);
        }
      }
    } catch (e) {
      AppLogger.e('resolveGlobalAgentsPath failed: $e');
    }
    if (globalAgentsPath.value.isEmpty) {
      globalAgentsPath.value = '~/.config/opencode/AGENTS.md';
    }
  }

  /// 404（全新安装尚无全局 AGENTS.md 的常态）返回 null，由调用方置空态；
  /// 其余错误原样抛出。
  Future<Response?> _getGlobalRulesFile(String filePath) async {
    try {
      return await _client.get(
        ApiEndpoints.fileContent,
        queryParameters: {'path': filePath},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> fetchGlobalRules() async {
    isLoadingGlobalRules.value = true;
    globalRulesError.value = '';
    try {
      await _resolveGlobalAgentsPath();
      final filePath = globalAgentsPath.value;
      if (filePath.isEmpty) return;

      Response? response;
      try {
        response = await _getGlobalRulesFile(filePath);
      } on DioException catch (e) {
        // 404 已转空态；其余多为瞬时网络/服务端错误，重试一次。
        AppLogger.e('fetchGlobalRules first attempt failed: $e');
        response = await _getGlobalRulesFile(filePath);
      }

      if (response != null && response.statusCode == 200) {
        final content = _parseRemoteFileContent(response.data);
        globalRulesContent.value = content;
        hasGlobalRules.value = content.trim().isNotEmpty;
      } else {
        // 404（response == null）= 无全局规则，空态而非错误。
        globalRulesError.value =
            response == null ? '' : 'HTTP ${response.statusCode}';
        globalRulesContent.value = '';
        hasGlobalRules.value = false;
      }
    } catch (e) {
      globalRulesContent.value = '';
      hasGlobalRules.value = false;
      globalRulesError.value = maskIpsInText(e.toString());
      AppLogger.e('fetchGlobalRules failed: $e');
    } finally {
      isLoadingGlobalRules.value = false;
    }
  }

  Map<String, dynamic>? _configMapFromResponse(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  Future<void> fetchGlobalConfig() async {
    isLoadingGlobalConfig.value = true;
    try {
      final res = await _client.get(ApiEndpoints.globalConfig);
      if (res.statusCode == 200) {
        globalConfig.value = _configMapFromResponse(res.data);
      }
    } catch (e) {
      AppLogger.e('fetchGlobalConfig failed: $e');
    } finally {
      isLoadingGlobalConfig.value = false;
    }
  }

  Future<void> fetchProjectConfig() async {
    isLoadingProjectConfig.value = true;
    try {
      final res = await _client.get(ApiEndpoints.projectConfig);
      if (res.statusCode == 200) {
        projectConfig.value = _configMapFromResponse(res.data);
      }
    } catch (e) {
      AppLogger.e('fetchProjectConfig failed: $e');
    } finally {
      isLoadingProjectConfig.value = false;
    }
  }

  Future<bool> updateGlobalConfig(Map<String, dynamic> patch) async {
    final key = patch.keys.firstOrNull ?? 'config';
    savingStates[key] = true;

    final prev = _configPatchTail ?? Future<bool>.value(true);
    final result = prev.then((_) => _doUpdateGlobalConfig(patch));
    _configPatchTail = result.then((ok) => ok, onError: (_) => false);
    final ok = await result;
    savingStates.remove(key);
    return ok;
  }

  Future<bool> _doUpdateGlobalConfig(Map<String, dynamic> patch) async {
    final originalConfig = globalConfig.value;
    if (originalConfig != null) {
      globalConfig.value = Map<String, dynamic>.from(originalConfig)
        ..addAll(patch);
    }

    try {
      final response = await _client.patch(
        ApiEndpoints.globalConfig,
        data: patch,
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.statusCode == 200 && response.data is Map) {
          globalConfig.value = Map<String, dynamic>.from(response.data as Map);
        } else {
          await fetchGlobalConfig();
        }
        return true;
      } else {
        globalConfig.value = originalConfig;
      }
    } catch (e) {
      globalConfig.value = originalConfig;
      AppLogger.e('SettingsController: updateGlobalConfig error $e');
    }
    return false;
  }

  /// 透传 [updateGlobalConfig] 的成功与否；内部已吞异常，调用方必须检查返回值
  /// 并在 false 时保留用户编辑、给出失败反馈（此前结果被丢弃，页面恒显示成功）。
  Future<bool> patchGlobalConfig(Map<String, dynamic> patch) =>
      updateGlobalConfig(patch);

  Future<void> patchProjectConfig(Map<String, dynamic> patch) async {
    final res = await _client.patch(ApiEndpoints.projectConfig, data: patch);
    if (res.statusCode == 200) {
      final updated = _configMapFromResponse(res.data);
      if (updated != null) {
        projectConfig.value = updated;
        return;
      }
    }
    await fetchProjectConfig();
  }

  List<String> _parseShellPaths(dynamic data) {
    dynamic list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      if (data['data'] is List) {
        list = data['data'];
      } else if (data['shells'] is List) {
        list = data['shells'];
      } else if (data['available'] is List) {
        list = data['available'];
      }
    }
    if (list is! List) return [];
    return list.map((e) {
      if (e is Map && e.containsKey('path')) {
        return e['path'].toString();
      }
      return e.toString();
    }).toList();
  }

  Future<void> fetchShells() async {
    isLoadingShells.value = true;
    try {
      final res = await _client.get(ApiEndpoints.shells);
      if (res.statusCode == 200) {
        availableShells.assignAll(_parseShellPaths(res.data));
      }
    } catch (e) {
      AppLogger.e('fetchShells failed: $e');
    } finally {
      isLoadingShells.value = false;
    }
  }

  Future<bool> setShell(String value) => patchGlobalConfig({'shell': value});

  Future<bool> setLogLevel(String value) =>
      patchGlobalConfig({'logLevel': value});

  Future<bool> setUsername(String value) =>
      patchGlobalConfig({'username': value});

  Future<bool> setShareMode(String value) =>
      patchGlobalConfig({'share': value});

  Future<bool> setAutoupdate(dynamic value) =>
      patchGlobalConfig({'autoupdate': value});

  Future<bool> setSnapshot(bool value) =>
      patchGlobalConfig({'snapshot': value});

  Future<bool> setCompaction(Map<String, dynamic> value) =>
      patchGlobalConfig({'compaction': value});

  Future<bool> setSmallModel(String value) =>
      patchGlobalConfig({'small_model': value});

  bool isModelVisible(ModelInfo model, List<ModelInfo> allModels) {
    // Touch reactive lists so Obx rebuilds.
    shownModelsRx.length;
    hiddenModelsRx.length;
    disabledModelsRx.length;
    if (shownModels.contains(model.key)) return true;
    if (hiddenModels.contains(model.key)) return false;
    if (disabledModels.contains(model.key) ||
        disabledModels.contains(model.id)) {
      return false;
    }
    if (_latestDefaultModelKeys(allModels).contains(model.key)) return true;
    final releaseDate = DateTime.tryParse(model.releaseDate);
    return releaseDate == null;
  }

  Future<void> setModelVisible(ModelInfo model, bool visible) async {
    // 两个 key 的读-改-写在存储层入队串行化，防快速连点互覆。
    await Global.settings.setModelVisibility(model.key, visible);
    shownModelsRx
      ..clear()
      ..addAll(Global.settings.shownModels);
    hiddenModelsRx
      ..clear()
      ..addAll(Global.settings.hiddenModels);
  }

  List<ModelInfo>? _defaultKeysCacheModels;
  Set<String> _defaultKeysCache = const {};
  DateTime? _defaultKeysCacheDate;

  Set<String> _latestDefaultModelKeys(List<ModelInfo> models) {
    final cachedModels = _defaultKeysCacheModels;
    if (cachedModels != null &&
        _defaultKeysCacheDate != null &&
        _sameModelList(cachedModels, models) &&
        DateTime.now().difference(_defaultKeysCacheDate!) <
            const Duration(hours: 1)) {
      return _defaultKeysCache;
    }
    final newestByFamily = <String, ModelInfo>{};
    final now = DateTime.now();
    for (final model in models) {
      final releaseDate = DateTime.tryParse(model.releaseDate);
      if (releaseDate == null) continue;
      if (now.difference(releaseDate).inDays.abs() > 183) continue;
      final family = model.family.isNotEmpty ? model.family : model.id;
      final groupKey = '${model.providerId}:$family';
      final current = newestByFamily[groupKey];
      if (current == null ||
          releaseDate.isAfter(
            DateTime.tryParse(current.releaseDate) ?? DateTime(0),
          )) {
        newestByFamily[groupKey] = model;
      }
    }
    _defaultKeysCache = newestByFamily.values.map((m) => m.key).toSet();
    _defaultKeysCacheModels = models;
    _defaultKeysCacheDate = DateTime.now();
    return _defaultKeysCache;
  }

  static bool _sameModelList(List<ModelInfo> a, List<ModelInfo> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  Future<void> setNotificationEnabled(bool value) async {
    notificationEnabled.value = value;
    await Global.settings.setNotificationEnabled(value);
  }

  @override
  void onInit() {
    super.onInit();
    defaultModelKey.value = Global.settings.defaultModelKey ?? '';
    notificationEnabled.value = Global.settings.notificationEnabled;
    _loadModelVisibilityPrefs();
  }

  @override
  void onClose() {
    _registryClient.dispose();
    super.onClose();
  }

  Future<void> setDefaultModel(String key) async {
    defaultModelKey.value = key;
    await Global.settings.setDefaultModelKey(key);
  }

  Future<void> checkHealth() async {
    healthChecking.value = true;
    try {
      final response = await _client.get(
        ApiEndpoints.health,
        skipDirectory: true,
      );
      if (response.statusCode == 200) {
        healthOk.value = true;
        final data = response.data;
        if (data is Map) {
          healthVersion.value = _extractHealthVersion(data);
        } else {
          healthVersion.value = 'ok';
        }
      } else {
        healthOk.value = false;
        healthVersion.value = 'HTTP ${response.statusCode}';
      }
    } catch (e) {
      healthOk.value = false;
      healthVersion.value = maskIpsInText(e.toString());
      AppLogger.e('checkHealth failed: ${maskIpsInText('$e')}');
    } finally {
      healthChecking.value = false;
    }
  }

  /// 兼容 health 直接带 `version` 与嵌套 `{data:{version}}` 两种响应结构。
  static String _extractHealthVersion(Map data) {
    final direct = data['version'];
    if (direct != null) return direct.toString();
    final nested = data['data'];
    if (nested is Map && nested['version'] != null) {
      return nested['version'].toString();
    }
    return 'ok';
  }

  Future<void> fetchSkills() async {
    skillsLoading.value = true;
    skillsError.value = '';
    try {
      final response = await _client.get(ApiEndpoints.skills);
      if (response.statusCode == 200) {
        final data = response.data;
        final list = <Map<String, dynamic>>[];

        dynamic rawList;
        if (data is Map && data['data'] is List) {
          rawList = data['data'];
        } else if (data is List) {
          rawList = data;
        }

        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map) {
              list.add(Map<String, dynamic>.from(item));
            }
          }
        }

        skills.assignAll(list);
      } else {
        skills.clear();
        skillsError.value = 'HTTP ${response.statusCode}';
      }
    } catch (e) {
      skills.clear();
      skillsError.value = maskIpsInText(e.toString());
      AppLogger.e('fetchSkills failed: $e');
    } finally {
      skillsLoading.value = false;
    }
  }

  Future<bool> setSkillsConfig(Map<String, dynamic> value) =>
      patchGlobalConfig({'skills': value});

  Future<void> fetchAgents() async {
    isLoadingAgents.value = true;
    agentsError.value = '';
    try {
      final response = await _client.get(ApiEndpoints.agents);
      if (response.statusCode == 200) {
        final data = response.data;
        final list = data is Map && data['data'] is List
            ? data['data'] as List
            : data is List
            ? data
            : <dynamic>[];
        if (list.isNotEmpty) {
          final agents = list
              .whereType<Map>()
              .map(
                (m) => AgentDetailInfo.fromJson(
                  m['name']?.toString() ?? m['id']?.toString() ?? '',
                  Map<String, dynamic>.from(m),
                ),
              )
              .where(
                (a) =>
                    a.name.isNotEmpty &&
                    a.raw['hidden'] != true &&
                    a.raw['native'] != true,
              )
              .toList();
          if (agents.isNotEmpty) {
            availableAgents.assignAll(agents);
            return;
          }
        }
      }
      final fallback = _agentsFromConfig();
      if (fallback.isNotEmpty) {
        availableAgents.assignAll(fallback);
      } else {
        availableAgents.clear();
      }
    } catch (e) {
      agentsError.value = maskIpsInText(e.toString());
      AppLogger.e('fetchAgents failed: $e');
      try {
        final fallback = _agentsFromConfig();
        if (fallback.isNotEmpty) {
          availableAgents.assignAll(fallback);
          agentsError.value = '';
        } else {
          availableAgents.clear();
        }
      } catch (inner) {
        AppLogger.e('fetchAgents config fallback failed: $inner');
        availableAgents.clear();
      }
    } finally {
      isLoadingAgents.value = false;
    }
  }

  List<AgentDetailInfo> _agentsFromConfig() {
    final agentData = globalConfig.value?['agent'];
    if (agentData is! Map) return [];
    final agents = <AgentDetailInfo>[];
    agentData.forEach((key, value) {
      if (value is Map && value['hidden'] != true && value['native'] != true) {
        agents.add(
          AgentDetailInfo.fromJson(
            key.toString(),
            Map<String, dynamic>.from(value),
          ),
        );
      }
    });
    return agents;
  }

  Future<bool> setAgentConfig(Map<String, dynamic> value) async {
    const key = 'agent';
    savingStates[key] = true;
    try {
      final ok = await patchGlobalConfig({'agent': value});
      await fetchAgents();
      return ok;
    } finally {
      savingStates.remove(key);
    }
  }

  /// 服务端 PATCH /global/config 是 mergeDeep 深度合并，无法删除 map 键
  /// （整键重建提交也只会保留缺失项）。Agent 配置支持 `hidden` 布尔字段，
  /// 客户端与 fetchAgents 均过滤 hidden，故删除 = 置 hidden:true。
  Future<bool> deleteAgent(String name) async {
    return setAgentConfig({
      name: {'hidden': true},
    });
  }

  // ── Permissions ───────────────────────────────────────────────

  final savedPermissions = <Map<String, dynamic>>[].obs;
  final savedPermissionsLoading = false.obs;

  Future<bool> setPermission(Map<String, dynamic> value) =>
      patchGlobalConfig({'permission': value});

  Future<void> fetchSavedPermissions() async {
    savedPermissionsLoading.value = true;
    try {
      final response = await _client.get(ApiEndpoints.permissionsSaved);
      if (response.statusCode == 200) {
        final data = response.data;
        final rawList = (data is Map && data['data'] is List)
            ? data['data'] as List
            : data is List
            ? data
            : [];
        savedPermissions.assignAll(
          rawList
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      }
    } catch (e) {
      AppLogger.e('fetchSavedPermissions failed: $e');
    } finally {
      savedPermissionsLoading.value = false;
    }
  }

  Future<bool> deleteSavedPermission(String id) async {
    try {
      final response = await _client.delete(
        ApiEndpoints.permissionSavedRemove(id),
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        await fetchSavedPermissions();
        return true;
      }
    } catch (e) {
      AppLogger.e('deleteSavedPermission failed: $e');
    }
    return false;
  }

  // ── Commands (Developer) ──────────────────────────────────────

  final commands = <Map<String, dynamic>>[].obs;
  final isLoadingCommands = false.obs;
  final commandsError = ''.obs;

  /// Convert backend commands to QuickPhraseItem list.
  List<QuickPhraseItem> get commandPhrases {
    return commands
        .map(
          (c) => QuickPhraseItem(
            name: c['name']?.toString() ?? '',
            template: c['template']?.toString() ?? '',
            description:
                c['description']?.toString() ?? c['name']?.toString() ?? '',
            agent: c['agent']?.toString() ?? '',
            model: modelRefToString(c['model']),
            isSystem: true,
          ),
        )
        .toList();
  }

  Map<String, dynamic>? get commandConfig {
    final global = globalConfig.value?['command'];
    if (global is Map) return Map<String, dynamic>.from(global);
    return null;
  }

  Future<void> fetchCommands() async {
    isLoadingCommands.value = true;
    commandsError.value = '';
    try {
      final response = await _client.get(ApiEndpoints.commands);
      if (response.statusCode == 200) {
        final data = response.data;
        final rawList = (data is Map && data['data'] is List)
            ? data['data'] as List
            : data is List
            ? data
            : [];
        final list = <Map<String, dynamic>>[];
        for (final item in rawList) {
          if (item is Map) {
            list.add(Map<String, dynamic>.from(item));
          }
        }
        if (list.isEmpty) {
          final cfg = commandConfig;
          if (cfg != null) {
            cfg.forEach((name, value) {
              if (value is Map) {
                list.add({'name': name, ...Map<String, dynamic>.from(value)});
              }
            });
          }
        }
        commands.assignAll(list);
      } else {
        commands.clear();
        commandsError.value = 'HTTP ${response.statusCode}';
      }
    } catch (e) {
      commands.clear();
      commandsError.value = maskIpsInText(e.toString());
      AppLogger.e('fetchCommands failed: $e');
    } finally {
      isLoadingCommands.value = false;
    }
  }

  Future<bool> setCommandConfig(Map<String, dynamic> value) async {
    final ok = await patchGlobalConfig({'command': value});
    await fetchCommands();
    return ok;
  }

  /// Built-in commands shipped by the server. Read-only in Settings because
  /// editing/deleting them would write a shadowing config entry.
  static const _builtinCommandNames = {'init', 'review'};

  /// User-defined commands (global or project config) are editable. Built-in
  /// commands (`init`/`review`) are read-only. MCP/skill-sourced commands
  /// cannot be distinguished client-side — the v2 `/api/command` schema strips
  /// the runtime `source` field — so they remain editable; editing one merely
  /// writes a shadowing config entry, matching pre-existing behavior.
  static bool isCommandEditable(Map<String, dynamic> cmd) {
    final name = cmd['name']?.toString() ?? '';
    return !_builtinCommandNames.contains(name);
  }

  /// Resolves a `Model.Ref` object (`{id, providerID, variant?}`) or a plain
  /// string to the config-style `provider/model` string.
  static String modelRefToString(dynamic value) {
    if (value is String) return value;
    if (value is Map) {
      final pid = value['providerID']?.toString() ?? '';
      final mid = value['id']?.toString() ?? value['modelID']?.toString() ?? '';
      if (pid.isNotEmpty && mid.isNotEmpty) return '$pid/$mid';
      if (mid.isNotEmpty) return mid;
    }
    return '';
  }

  /// Splits a shell command string into argv, respecting single/double quotes
  /// and backslash escapes so paths/args containing spaces stay one token.
  static List<String> shellSplit(String input) {
    final tokens = <String>[];
    final buf = StringBuffer();
    var inSingle = false;
    var inDouble = false;
    var escaping = false;
    for (final rune in input.runes) {
      final c = String.fromCharCode(rune);
      if (escaping) {
        buf.write(c);
        escaping = false;
      } else if (inSingle) {
        if (c == "'") {
          inSingle = false;
        } else {
          buf.write(c);
        }
      } else if (inDouble) {
        if (c == '"') {
          inDouble = false;
        } else if (c == r'\') {
          escaping = true;
        } else {
          buf.write(c);
        }
      } else if (c == "'") {
        inSingle = true;
      } else if (c == '"') {
        inDouble = true;
      } else if (c == r'\') {
        escaping = true;
      } else if (c == ' ' || c == '\t' || c == '\n') {
        if (buf.isNotEmpty) {
          tokens.add(buf.toString());
          buf.clear();
        }
      } else {
        buf.write(c);
      }
    }
    if (escaping) buf.write(r'\');
    if (buf.isNotEmpty) tokens.add(buf.toString());
    return tokens;
  }

  // ── Formatters / References ────────────────────────────────────

  /// `false` disables all formatters; otherwise enabled (true or map).
  bool get formattersEnabled {
    final raw = globalConfig.value?['formatter'];
    if (raw == false) return false;
    return true;
  }

  Future<bool> setFormattersEnabled(bool enabled) =>
      patchGlobalConfig({'formatter': enabled});

  Future<void> fetchFormatters() async {
    formattersLoading.value = true;
    formattersError.value = '';
    try {
      final response = await _client.get(ApiEndpoints.formatter);
      if (response.statusCode == 200) {
        final data = response.data;
        final rawList = (data is Map && data['formatters'] is List)
            ? data['formatters'] as List
            : data is List
            ? data
            : [];
        final list = <Map<String, dynamic>>[];
        for (final item in rawList) {
          if (item is Map) {
            list.add(Map<String, dynamic>.from(item));
          } else if (item != null) {
            list.add({'name': item.toString()});
          }
        }
        formatters.assignAll(list);
      } else {
        formatters.clear();
        formattersError.value = 'HTTP ${response.statusCode}';
      }
    } catch (e) {
      formatters.clear();
      formattersError.value = maskIpsInText(e.toString());
      AppLogger.e('fetchFormatters failed: $e');
    } finally {
      formattersLoading.value = false;
    }
  }

  /// ConfigV1 `reference`: `Record<name, string | {repository,branch?} | {path}>`.
  Map<String, dynamic>? get referenceConfig {
    final raw =
        globalConfig.value?['references'] ?? globalConfig.value?['reference'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// UI rows derived from [referenceConfig] (includes a `name` key).
  static List<Map<String, dynamic>> referenceEntriesFromConfig(
    Map<String, dynamic>? cfg,
  ) {
    if (cfg == null || cfg.isEmpty) return const [];
    final list = <Map<String, dynamic>>[];
    cfg.forEach((name, value) {
      if (value is String) {
        list.add({'name': name, 'type': 'string', 'value': value});
      } else if (value is Map) {
        if (value.containsKey('repository')) {
          list.add({
            'name': name,
            'type': 'git',
            'repository': value['repository'],
            if (value['branch'] != null) 'branch': value['branch'],
          });
        } else if (value.containsKey('path')) {
          list.add({'name': name, 'type': 'local', 'path': value['path']});
        }
      }
    });
    return list;
  }

  /// Serializes UI reference rows back to ConfigV1 map shape.
  static Map<String, dynamic> referenceConfigFromEntries(
    Iterable<Map<String, dynamic>> entries,
  ) {
    final map = <String, dynamic>{};
    for (final item in entries) {
      final name = item['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      final type = item['type']?.toString() ?? 'string';
      switch (type) {
        case 'git':
          final repo =
              item['repository']?.toString() ?? item['url']?.toString() ?? '';
          if (repo.isEmpty) continue;
          final branch = item['branch']?.toString() ?? '';
          map[name] = {
            'repository': repo,
            if (branch.isNotEmpty) 'branch': branch,
          };
        case 'local':
        case 'path':
          final path = item['path']?.toString() ?? '';
          if (path.isEmpty) continue;
          map[name] = {'path': path};
        default:
          map[name] = item['value']?.toString() ?? '';
      }
    }
    return map;
  }

  Future<void> fetchReferences() async {
    referencesLoading.value = true;
    referencesError.value = '';
    try {
      final response = await _client.get(ApiEndpoints.reference);
      if (response.statusCode == 200) {
        final data = response.data;
        final rawList = (data is Map && data['data'] is List)
            ? data['data'] as List
            : data is List
            ? data
            : [];
        final list = <Map<String, dynamic>>[];
        for (final item in rawList) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            // Normalize API rows that use id/name + repository/path.
            if (!m.containsKey('name') && m['id'] != null) {
              m['name'] = m['id'];
            }
            if (m.containsKey('repository') && m['type'] == null) {
              m['type'] = 'git';
            } else if (m.containsKey('path') && m['type'] == null) {
              m['type'] = 'local';
            }
            // v2 Reference.Info nests the descriptor inside `source`:
            // {name, path, ..., source: {type: 'local'|'git', repository|path, branch?}}.
            // Override the top-level heuristic with the authoritative source.
            final source = m['source'];
            if (source is Map) {
              final src = Map<String, dynamic>.from(source);
              final stype = src['type']?.toString() ?? '';
              if (stype == 'git') {
                m['type'] = 'git';
                m['repository'] = src['repository'] ?? m['path'];
                if (src['branch'] != null) m['branch'] = src['branch'];
              } else if (stype == 'local') {
                m['type'] = 'local';
                m['path'] = src['path'] ?? m['path'];
              }
            }
            list.add(m);
          } else if (item != null) {
            list.add({
              'name': item.toString(),
              'type': 'string',
              'value': item.toString(),
            });
          }
        }
        if (list.isEmpty) {
          list.addAll(referenceEntriesFromConfig(referenceConfig));
        }
        references.assignAll(list);
      } else {
        final list = referenceEntriesFromConfig(referenceConfig);
        references.assignAll(list);
        if (list.isEmpty) {
          referencesError.value = 'HTTP ${response.statusCode}';
        }
      }
    } catch (e) {
      final list = referenceEntriesFromConfig(referenceConfig);
      references.assignAll(list);
      if (list.isEmpty) {
        referencesError.value = maskIpsInText(e.toString());
      }
      AppLogger.e('fetchReferences failed: $e');
    } finally {
      referencesLoading.value = false;
    }
  }

  Future<bool> setReferenceConfig(Map<String, dynamic> value) async {
    final ok = await patchGlobalConfig({'references': value});
    await fetchReferences();
    return ok;
  }

  // ── Advanced / Experimental ───────────────────────────────────

  Map<String, dynamic>? get watcherConfig {
    final raw = globalConfig.value?['watcher'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  List<dynamic> get pluginConfig {
    final raw = globalConfig.value?['plugin'];
    return raw is List ? List<dynamic>.from(raw) : const [];
  }

  Map<String, dynamic>? get attachmentConfig {
    final raw = globalConfig.value?['attachment'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  Future<bool> setWatcherConfig(Map<String, dynamic> value) =>
      patchGlobalConfig({'watcher': value});

  Future<bool> setPluginConfig(List<dynamic> value) =>
      patchGlobalConfig({'plugin': value});

  Future<bool> setAttachmentConfig(Map<String, dynamic> value) =>
      patchGlobalConfig({'attachment': value});

  Future<bool> setExperimental(Map<String, dynamic> patch) async {
    final next = Map<String, dynamic>.from(experimental ?? {});
    patch.forEach((key, value) {
      if (value == null) {
        next.remove(key);
      } else {
        next[key] = value;
      }
    });
    return patchGlobalConfig({'experimental': next});
  }

  /// LSP master switch: `false` disables; map/true/null enables.
  bool get lspEnabled {
    final raw = globalConfig.value?['lsp'];
    if (raw == false) return false;
    return true;
  }

  Map<String, dynamic> get lspConfigMap {
    final raw = globalConfig.value?['lsp'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  bool isLspServerDisabled(String id) {
    final entry = lspConfigMap[id];
    if (entry is Map) return entry['disabled'] == true;
    if (entry == false) return true;
    return false;
  }

  Future<bool> setLspEnabled(bool enabled) {
    if (enabled) {
      final map = lspConfigMap;
      if (map.isEmpty) {
        return patchGlobalConfig({'lsp': true});
      }
      return patchGlobalConfig({'lsp': map});
    }
    return patchGlobalConfig({'lsp': false});
  }

  Future<bool> setLspServerDisabled(String id, bool disabled) {
    final map = Map<String, dynamic>.from(lspConfigMap);
    final existing = map[id];
    final entry = existing is Map
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    entry['disabled'] = disabled;
    map[id] = entry;
    return patchGlobalConfig({'lsp': map});
  }

  Future<void> fetchLsp() async {
    lspLoading.value = true;
    try {
      final response = await _client.get(ApiEndpoints.lsp);
      if (response.statusCode == 200) {
        final raw = response.data;
        final List<dynamic> rawList;
        if (raw is List) {
          rawList = raw;
        } else if (raw is Map && raw['data'] is List) {
          rawList = raw['data'] as List;
        } else {
          rawList = const [];
        }
        final list = <LspServerInfo>[];
        for (final item in rawList) {
          if (item is Map) {
            list.add(LspServerInfo.fromJson(Map<String, dynamic>.from(item)));
          }
        }

        lspServers.assignAll(list);
        if (list.isNotEmpty) {
          lspStatus.value = list.any((s) => s.status == 'error')
              ? 'error'
              : 'connected';
        } else {
          lspStatus.value = '';
        }
      }
    } catch (e) {
      AppLogger.e('fetchLsp failed: $e');
    } finally {
      lspLoading.value = false;
    }
  }

  Future<void> fetchMcpServers() async {
    mcpLoading.value = true;
    mcpError.value = '';
    try {
      final response = await _client.get(ApiEndpoints.mcp);
      if (response.statusCode == 200) {
        final data = response.data;
        final mcpConfig = globalConfig.value?['mcp'] is Map
            ? Map<String, dynamic>.from(globalConfig.value!['mcp'] as Map)
            : <String, dynamic>{};
        final list = <McpServerStatus>[];

        if (data is Map && data['data'] is List) {
          for (final item in data['data'] as List) {
            if (item is! Map) continue;
            final name =
                item['name']?.toString() ?? item['id']?.toString() ?? '';
            if (name.isEmpty) continue;
            if (_isMcpRemovedByDisable(item, mcpConfig[name])) continue;
            list.add(
              McpServerStatus.fromEntry(
                name,
                _mergeMcpConfig(item, mcpConfig[name]),
              ),
            );
          }
        } else if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          map.forEach((key, value) {
            if (key == 'data' || key == 'location') return;
            if (_isMcpRemovedByDisable(value, mcpConfig[key])) return;
            list.add(
              McpServerStatus.fromEntry(
                key,
                _mergeMcpConfig(value, mcpConfig[key]),
              ),
            );
          });
        }

        mcpServers.assignAll(list);
      } else {
        mcpError.value = 'HTTP ${response.statusCode}';
      }
    } catch (e) {
      mcpError.value = maskIpsInText(e.toString());
      AppLogger.e('fetchMcpServers failed: $e');
    } finally {
      mcpLoading.value = false;
    }
  }

  /// 删除 MCP 实际是置 enabled:false（服务端 PATCH 深合并无法删键），
  /// 服务端/配置任一侧标记禁用即从列表剔除。
  bool _isMcpRemovedByDisable(dynamic status, dynamic config) {
    if (status is Map && status['enabled'] == false) return true;
    if (config is Map && config['enabled'] == false) return true;
    return false;
  }

  dynamic _mergeMcpConfig(dynamic status, dynamic config) {
    if (status is! Map || config is! Map) return status;
    final merged = Map<String, dynamic>.from(status);
    if (merged['type'] == null && config['type'] != null) {
      merged['type'] = config['type'];
    }
    if (merged['command'] == null && config['command'] is List) {
      merged['command'] = config['command'];
    }
    if (merged['url'] == null && config['url'] != null) {
      merged['url'] = config['url'];
    }
    if (merged['env'] == null && config['environment'] is Map) {
      merged['env'] = config['environment'];
    }
    if (merged['headers'] == null && config['headers'] is Map) {
      merged['headers'] = config['headers'];
    }
    return merged;
  }

  Future<void> connectMcp(String name) async {
    mcpActionInProgress.add('connect_$name');
    try {
      await _client.post(ApiEndpoints.mcpConnect(name));
      await fetchMcpServers();
    } catch (e) {
      AppLogger.e('connectMcp failed: $e');
      rethrow;
    } finally {
      mcpActionInProgress.remove('connect_$name');
    }
  }

  Future<void> disconnectMcp(String name) async {
    mcpActionInProgress.add('disconnect_$name');
    try {
      await _client.post(ApiEndpoints.mcpDisconnect(name));
      await fetchMcpServers();
    } catch (e) {
      AppLogger.e('disconnectMcp failed: $e');
      rethrow;
    } finally {
      mcpActionInProgress.remove('disconnect_$name');
    }
  }

  Future<Map<String, dynamic>> startMcpAuth(String name) async {
    final res = await _client.post(ApiEndpoints.mcpAuthStart(name));
    if (res.statusCode == 200 && res.data is Map) {
      final data = res.data as Map;
      final body = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : Map<String, dynamic>.from(data);
      return body;
    }
    throw Exception('Start auth failed: HTTP ${res.statusCode}');
  }

  Future<void> completeMcpAuth(String name, String code) async {
    final res = await _client.post(
      ApiEndpoints.mcpAuthCallback(name),
      data: {'code': code},
    );
    if (res.statusCode != 200) {
      throw Exception('Complete auth failed: HTTP ${res.statusCode}');
    }
  }

  Future<void> removeMcpAuth(String name) async {
    final res = await _client.delete(ApiEndpoints.mcpAuthRemove(name));
    if (res.statusCode != 200) {
      throw Exception('Remove auth failed: HTTP ${res.statusCode}');
    }
  }

  Future<void> createMcpServer({
    required String name,
    required String transport,
    String? command,
    String? url,
    Map<String, String>? env,
    String? oauthClientId,
    String? oauthClientSecret,
  }) async {
    mcpActionInProgress.add('add_$name');
    try {
      final config = <String, dynamic>{};
      if (transport == 'stdio' || transport == 'local') {
        config['type'] = 'local';
        config['command'] = command != null && command.isNotEmpty
            ? shellSplit(command)
            : [];
        if (env != null && env.isNotEmpty) {
          config['environment'] = env;
        }
      } else {
        config['type'] = 'remote';
        config['url'] = url ?? '';
        if (env != null && env.isNotEmpty) {
          config['headers'] = env;
        }
        final oauth = <String, dynamic>{
          if (oauthClientId != null && oauthClientId.isNotEmpty)
            'clientId': oauthClientId,
          if (oauthClientSecret != null && oauthClientSecret.isNotEmpty)
            'clientSecret': oauthClientSecret,
        };
        if (oauth.isNotEmpty) {
          config['oauth'] = oauth;
        }
      }

      // enabled:true 显式带上：同名条目此前可能被「删除」（enabled:false）
      // 禁用过，PATCH 深合并下显式置 true 才能重新启用。
      final ok = await patchGlobalConfig({
        'mcp': {
          name: {...config, 'enabled': true},
        },
      });
      if (!ok) {
        throw Exception('update mcp config failed');
      }
      try {
        await _client.post(ApiEndpoints.mcpConnect(name));
      } catch (e) {
        AppLogger.w('createMcpServer: connect failed for $name: $e');
      }
      await fetchMcpServers();
    } catch (e) {
      AppLogger.e('createMcpServer failed: $e');
      rethrow;
    } finally {
      mcpActionInProgress.remove('add_$name');
    }
  }

  /// 服务端 PATCH 为 mergeDeep 深度合并，无法删除 mcp map 键：整键重建会保留
  /// 缺失项、置 null（{'mcp': null}）被 schema 拒绝整包 400。MCP 条目支持
  /// enabled 布尔字段，删除 = 断开 + 置 enabled:false，fetchMcpServers 过滤之。
  Future<bool> removeMcpServer(String name) async {
    mcpActionInProgress.add('remove_$name');
    try {
      try {
        await _client.post(ApiEndpoints.mcpDisconnect(name));
      } catch (_) {}
      final ok = await patchGlobalConfig({
        'mcp': {
          name: {'enabled': false},
        },
      });
      await fetchMcpServers();
      return ok;
    } catch (e) {
      AppLogger.e('removeMcpServer failed: $e');
      return false;
    } finally {
      mcpActionInProgress.remove('remove_$name');
    }
  }

  static String sanitizeServerName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  Future<void> searchRegistry(String query, {int limit = 15}) async {
    final seq = ++_registryRequestSeq;
    isLoadingRegistry.value = true;
    registryError.value = '';
    _lastRegistryQuery = query;
    try {
      final result = await _registryClient.listServers(
        search: query.isEmpty ? null : query,
        limit: limit,
      );
      if (seq != _registryRequestSeq) return; // 已有更新的请求，丢弃过期结果
      registryServers.assignAll(result.servers);
      registryNextCursor.value = result.nextCursor;
    } catch (e) {
      if (seq != _registryRequestSeq) return;
      registryError.value = maskIpsInText(e.toString());
      AppLogger.e('searchRegistry failed: $e');
    } finally {
      if (seq == _registryRequestSeq) isLoadingRegistry.value = false;
    }
  }

  Future<void> loadMoreRegistry() async {
    final cursor = registryNextCursor.value;
    if (cursor == null || cursor.isEmpty) return;
    final seq = _registryRequestSeq;
    isLoadingRegistry.value = true;
    try {
      final result = await _registryClient.listServers(
        search: _lastRegistryQuery.isEmpty ? null : _lastRegistryQuery,
        cursor: cursor,
      );
      if (seq != _registryRequestSeq) return;
      registryServers.addAll(result.servers);
      registryNextCursor.value = result.nextCursor;
    } catch (e) {
      if (seq == _registryRequestSeq) registryError.value = maskIpsInText(e.toString());
    } finally {
      if (seq == _registryRequestSeq) isLoadingRegistry.value = false;
    }
  }

  Future<bool> installFromRegistry(
    RegistryServerInfo server, {
    Map<String, String>? environment,
  }) async {
    if (server.remotes.isNotEmpty) {
      final remote = server.remotes.first;
      final name = sanitizeServerName(server.name);
      try {
        await createMcpServer(
          name: name.isEmpty ? 'mcp' : name,
          transport: 'remote',
          url: remote.url,
          env: environment,
        );
        return true;
      } catch (_) {
        return false;
      }
    }
    if (server.packages.isNotEmpty) {
      final pkg = server.packages.first;
      final name = sanitizeServerName(server.name);
      String command;
      final args = <String>[];
      if (pkg.runtimeHint == 'npx') {
        command = 'npx';
        args.addAll([
          '-y',
          ...?pkg.runtimeArgs,
          pkg.identifier,
          ...?pkg.packageArgs,
        ]);
      } else if (pkg.runtimeHint == 'uvx' || pkg.registryType == 'pypi') {
        command = 'uvx';
        args.addAll([...?pkg.runtimeArgs, pkg.identifier, ...?pkg.packageArgs]);
      } else if (pkg.registryType == 'oci') {
        command = 'docker';
        args.addAll([
          'run',
          '-i',
          '--rm',
          ...?pkg.runtimeArgs,
          pkg.identifier,
          ...?pkg.packageArgs,
        ]);
      } else {
        command = pkg.runtimeHint ?? 'npx';
        args.addAll([
          if (command == 'npx') '-y',
          ...?pkg.runtimeArgs,
          pkg.identifier,
          ...?pkg.packageArgs,
        ]);
      }
      final env = <String, String>{...?environment};
      if (pkg.environmentVariables != null) {
        for (final ev in pkg.environmentVariables!) {
          if (ev.defaultValue != null && !env.containsKey(ev.name)) {
            env[ev.name] = ev.defaultValue!;
          }
        }
      }
      try {
        final fullCommand = [command, ...args].join(' ');
        await createMcpServer(
          name: name.isEmpty ? 'mcp' : name,
          transport: 'stdio',
          command: fullCommand,
          env: env.isEmpty ? null : env,
        );
        return true;
      } catch (_) {
        return false;
      }
    }
    registryError.value =
        'Server "${server.displayName}" has no installable packages or remotes.';
    return false;
  }

  Future<void> fetchProviders() async {
    isLoadingProviders.value = true;
    try {
      final response = await _client.get(ApiEndpoints.providers);
      if (response.statusCode == 200) {
        final responseData = response.data;
        List<dynamic> all = [];
        Set<String> connectedIds = {};
        if (responseData is Map<String, dynamic> &&
            responseData['all'] is List) {
          all = responseData['all'] as List;
          connectedIds =
              (responseData['connected'] as List?)
                  ?.map((e) => e.toString())
                  .toSet() ??
              {};
        } else {
          final data = responseData is Map<String, dynamic>
              ? (responseData['data'] as List? ?? [])
              : (responseData is List ? responseData : []);
          all = data.whereType<Map<String, dynamic>>().toList();
          connectedIds = all
              .where((j) => (j as Map)['connected'] == true)
              .map((j) => (j as Map)['id'].toString())
              .toSet();
        }
        if (all.isNotEmpty) {
          providers.assignAll(
            all.map((j) {
              final json = Map<String, dynamic>.from(j as Map);
              final info = ProviderInfo.fromJson(json);
              return ProviderInfo(
                id: info.id,
                name: info.name,
                type: info.type,
                connected: connectedIds.contains(info.id) || info.connected,
                models: info.models,
              );
            }),
          );
        }
      }
    } catch (e) {
      AppLogger.e('fetchProviders failed: $e');
    } finally {
      isLoadingProviders.value = false;
    }
  }

  List<String> get disabledProviders {
    final raw = globalConfig.value?['disabled_providers'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  Future<void> enableProvider(String providerId) async {
    final currentDisabled = disabledProviders.toList();
    if (!currentDisabled.remove(providerId)) return;
    await updateGlobalConfig({'disabled_providers': currentDisabled});
    await _disposeBackendInstances();
    await fetchProviders();
  }

  /// Adds a custom provider using a raw configuration Map directly.
  Future<bool> addCustomProviderRaw({
    required String providerId,
    required Map<String, dynamic> config,
    String apiKey = '',
  }) async {
    try {
      final envMatch = RegExp(r'^\{env:([^}]+)\}$').firstMatch(apiKey.trim());
      final envName = envMatch?.group(1)?.trim();
      final rawKey = apiKey.trim();

      var authWritten = false;
      if (rawKey.isNotEmpty && envName == null) {
        final authResponse = await _client.put(
          ApiEndpoints.authSet(providerId),
          data: {'type': 'api', 'key': rawKey},
        );
        if (authResponse.statusCode != 200 &&
            authResponse.statusCode != 201 &&
            authResponse.statusCode != 204) {
          return false;
        }
        authWritten = true;
      }

      final currentProviders = globalConfig.value?['provider'] is Map
          ? Map<String, dynamic>.from(globalConfig.value!['provider'] as Map)
          : <String, dynamic>{};
      currentProviders[providerId] = config;

      final disabled = disabledProviders
          .where((id) => id != providerId)
          .toList();

      final ok = await updateGlobalConfig({
        'provider': currentProviders,
        'disabled_providers': disabled,
      });
      if (!ok) {
        // 回滚：PATCH 失败时删除本次 PUT 的凭据，避免留下没有 provider
        // 配置的无主 key（PUT 已覆盖旧 key，旧凭据本就不可恢复）。
        if (authWritten) {
          try {
            await _client.delete(ApiEndpoints.authRemove(providerId));
          } catch (e) {
            AppLogger.w(
              'addCustomProviderRaw: rollback auth for $providerId failed: $e',
            );
          }
        }
        return false;
      }
      await _disposeBackendInstances();
      return true;
    } catch (e) {
      AppLogger.e('SettingsController: addCustomProviderRaw error $e');
      return false;
    }
  }

  /// Disconnect a provider: remove credentials and suppress via config.
  /// 已知服务端限制：provider 条目从 config map 移除后经 mergeDeep 深合并仍会
  /// 保留（无法真正删除），此处靠 disabled_providers 数组抑制其生效。
  Future<void> disconnectProvider(String providerId) async {
    try {
      try {
        await _client.delete(ApiEndpoints.authRemove(providerId));
      } catch (_) {}

      final currentProviders = globalConfig.value?['provider'] is Map
          ? Map<String, dynamic>.from(globalConfig.value!['provider'] as Map)
          : <String, dynamic>{};
      currentProviders.remove(providerId);

      final currentDisabled = disabledProviders.toList();
      if (!currentDisabled.contains(providerId)) {
        currentDisabled.add(providerId);
      }

      await updateGlobalConfig({
        'provider': currentProviders,
        'disabled_providers': currentDisabled,
      });

      await _disposeBackendInstances();
    } catch (e) {
      AppLogger.e('disconnectProvider failed: $e');
      rethrow;
    }
  }

  Future<bool> saveProviderKey(String providerId, String apiKey) async {
    try {
      final response = await _client.put(
        ApiEndpoints.authSet(providerId),
        data: {'type': 'api', 'key': apiKey},
      );
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        await _disposeBackendInstances();
        await fetchProviders();
        return true;
      }
    } catch (e) {
      AppLogger.e('SettingsController: saveProviderKey error $e');
    }
    return false;
  }

  Future<void> connectProvider(String providerId) async {
    try {
      final methods = await fetchProviderAuthMethods(providerId);
      final methodIndex = methods.indexWhere((m) => m.type == 'oauth');
      if (methodIndex == -1) {
        AppLogger.w('no OAuth method for $providerId');
        return;
      }
      final auth = await authorizeProvider(providerId, method: methodIndex);
      final url = auth?.url;
      if (url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      await fetchProviders();
    } catch (e) {
      AppLogger.e('SettingsController: connectProvider error $e');
    }
  }

  Future<List<ProviderAuthMethod>> fetchProviderAuthMethods(
    String providerId,
  ) async {
    final response = await _client.get(ApiEndpoints.providerAuth);
    if (response.statusCode != 200) return const [];
    final data = response.data;
    final raw = data is Map ? data[providerId] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => ProviderAuthMethod.fromJson(item))
        .toList();
  }

  Future<ProviderAuthorization?> authorizeProvider(
    String providerId, {
    required int method,
    Map<String, String> inputs = const {},
  }) async {
    final response = await _client.post(
      ApiEndpoints.providerOauthAuthorize(providerId),
      data: <String, dynamic>{
        'method': method,
        if (inputs.isNotEmpty) 'inputs': inputs,
      },
    );
    if (response.statusCode != 200 || response.data == null) return null;
    if (response.data is! Map) return null;
    return ProviderAuthorization.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<bool> completeProviderOAuth(
    String providerId, {
    required int method,
    String? code,
  }) async {
    final response = await _client.post(
      ApiEndpoints.providerOauthCallback(providerId),
      data: <String, dynamic>{
        'method': method,
        if (code != null && code.isNotEmpty) 'code': code,
      },
    );
    final ok = response.statusCode == 200 || response.statusCode == 204;
    if (ok) {
      await _disposeBackendInstances();
      await fetchProviders();
    }
    return ok;
  }

  Future<void> _disposeBackendInstances() async {
    try {
      await _client.post(ApiEndpoints.instanceDispose);
    } catch (_) {}
    try {
      await _client.post(ApiEndpoints.globalDispose);
    } catch (_) {}
    await _waitForBackend();
  }

  Future<void> _waitForBackend({
    int maxRetries = 10,
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    for (var i = 0; i < maxRetries; i++) {
      try {
        final res = await _client.get(ApiEndpoints.health);
        if (res.statusCode == 200) return;
      } catch (_) {}
      await Future.delayed(interval);
    }
  }
}
