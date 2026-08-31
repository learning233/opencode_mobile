import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:get/get.dart';
import '../api/endpoints.dart';
import '../api/models/event.dart';
import '../api/models/message.dart';
import '../api/models/session.dart';
import '../api/models/snapshot_file_diff.dart';
import '../api/models/tool_diff_parser.dart';
import '../api/opencode_client.dart';
import '../api/sidecar_manager.dart';
import '../api/sse_client.dart';
import '../controllers/project_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/tablet_tool_controller.dart';
import '../init.dart';
import '../models/model_info.dart';
import '../models/session_runtime_state.dart';
import '../services/app_feedback_service.dart';
import '../utils/app_logger.dart';
import '../utils/diff_paths.dart';
import '../utils/error_formatter.dart';
import '../utils/image_cache.dart';
import '../utils/image_compressor.dart';
import '../utils/session_cache_store.dart';
import '../utils/snackbar_utils.dart';
import '../utils/translations.dart';

class _SubtaskOwner {
  const _SubtaskOwner({required this.rootSessionId, this.rootUserMessageId});

  final String rootSessionId;
  final String? rootUserMessageId;
}

class SessionController extends GetxController with WidgetsBindingObserver {
  final OpenCodeClient _client = OpenCodeClient();

  final sessions = <SessionModel>[].obs;
  final activeSessionId = ''.obs;
  final openedSessionIds = <String>[].obs;

  /// Last `fetchSessions` failure (null = last fetch succeeded). Consumed by
  /// the session list error view; `fetchSessions` never rethrows so callers
  /// cannot rely on try/catch.
  final sessionsError = RxnString();

  /// 请求代际：切项目时自增，用于丢弃上一个项目的在途响应
  /// （`fetchSessions`/`loadMessages`/`fetchModels` 共享），避免旧目录的
  /// 会话/消息/模型列表覆盖新项目状态。
  int _sessionFetchSeq = 0;

  /// 最近一次已发出的 `fetchSessions` 所属代际；用于同一代际去重（在途则跳过），
  /// 切项目（代际变化）后允许新请求覆盖在途旧请求。
  int _lastSessionFetchIssuedSeq = -1;

  /// 最近一次已发出的 `fetchModels` 所属代际；作用同 [_lastSessionFetchIssuedSeq]，
  /// 避免切项目时在途旧请求阻塞新项目模型列表刷新。
  int _lastModelsFetchIssuedSeq = -1;

  /// H1：loadMessages 在途表（sessionId → 在途 Future）。同会话在途时非
  /// force 调用直接复用同一 Future——`hasLoadedHistory` 守卫在在途窗口内
  /// 不成立（进入即置 false），没有这张表时预取/切页签/重连强刷会并发叠
  /// 加多个全量 GET（实测单个约 4.4s，窗口很大）。force 到来时经
  /// [_messageLoadCancelTokens] 取消在途旧请求再发新，旧响应不再可能后到
  /// 覆盖新数据（代际守卫只防切项目，不防同项目内乱序）。
  final _messageLoadInFlight = <String, Future<void>>{};
  final _messageLoadCancelTokens = <String, CancelToken>{};

  /// H1：逐会话加载票据。force 取代在途加载时自增并覆盖；旧实现若尚未发
  /// 出 GET（如还在 SWR 缓存读取阶段，CancelToken 无从取消），在 GET 前的
  /// 检查点发现票据不符即放弃，杜绝并发双 GET。
  int _messageLoadTicketSeq = 0;
  final _messageLoadTickets = <String, int>{};

  final sessionRuntimeStates = <String, SessionRuntimeState>{};
  final _subtaskOwners = <String, _SubtaskOwner>{};
  final _parentSessionIds = <String, String>{};
  final _subtaskDirectUserMessageIds = <String, String>{};
  final _pendingSubtaskToolParts = <String, List<Part>>{};
  final _processedFileToolParts = <String>{};
  final availableAgents = <String>['plan', 'build'].obs;
  final isLoadingModels = false.obs;
  final showReasoning = true.obs;

  /// Per-tool auto-collapse prefs (desktop parity). Missing keys default true.
  final cardAutoCollapse = <String, bool>{'bash': true}.obs;

  /// Maps question request IDs → tool-part refs (desktop `_questionRequests`).
  final _questionRequests = <String, QuestionRequestRef>{};

  /// 本地发送在途的会话 ID 集合：从 sendPrompt 置位 `isGenerating=true` 到
  /// prompt POST 返回（成功或失败）之间该会话在集合内。用于两处竞态防护：
  /// ① sendPrompt 入口发现同会话在途时改为排队，避免 abort 网络往返窗口或
  /// stale 结束事件误复位 isGenerating 期间并发开出第二回合（双 POST、双乐观
  /// 消息）；② SSE 结束事件（session.idle / session.error / status idle）在
  /// 在途窗口内到达时视为上一回合的迟到事件跳过（详见各 handler 内守卫）。
  final _localSendInFlight = <String>{};

  /// Pending clarifying-question tool part in [sessionId] messages.
  Part? pendingQuestionPartFor(String sessionId) {
    if (sessionId.isEmpty) return null;
    for (final msg in stateOf(sessionId).messages) {
      for (final part in msg.parts) {
        if (part.type == PartType.tool &&
            part.toolName == 'question' &&
            (part.toolStatus == ToolStateStatus.running ||
                part.toolStatus == ToolStateStatus.pending)) {
          return part;
        }
      }
    }
    return null;
  }

  /// Question requestID (`que_...`) for a pending question tool call, resolved
  /// from the SSE-populated local index. `null` when unknown — caller should
  /// fall back to `GET /question`. Mirrors the server-side
  /// `tool.callID == part.callID` match without a network round trip.
  String? questionIDForCallID(String callId, {String? sessionId}) =>
      questionRequestIDForCallID(
        _questionRequests,
        callId,
        sessionId: sessionId,
      );

  /// Pure reverse lookup: first `que_...` requestID whose ref's [callId]
  /// matches, preferring the entry for [sessionId] when provided. callID is
  /// the primary key (globally unique tool call ID); sessionId only breaks
  /// ties between entries sharing a callID.
  static String? questionRequestIDForCallID(
    Map<String, QuestionRequestRef> requests,
    String callId, {
    String? sessionId,
  }) {
    if (callId.isEmpty) return null;
    String? sameSession;
    String? first;
    for (final entry in requests.entries) {
      final ref = entry.value;
      if (ref.callId.isEmpty || ref.callId != callId) continue;
      first ??= entry.key;
      if (sessionId != null &&
          sessionId.isNotEmpty &&
          ref.sessionId == sessionId) {
        sameSession = entry.key;
      }
    }
    return sameSession ?? first;
  }

  final _allModels = <ModelInfo>[];
  final availableModels = <ModelInfo>[].obs;

  List<ModelInfo> get allModels => List.unmodifiable(_allModels);

  SseClient? _sseClient;
  StreamSubscription<SseEvent>? _sseSub;

  /// 隐藏的内部临时会话 ID（如图片转文字的识图请求）。其 SSE 事件不进入
  /// 正常 UI 处理（不插入 session 列表、不触发反馈音/关键词检测），改走
  /// [_handleHiddenEvent] 收集识图文本，完成后由 [describeImagesToText] 删除。
  final _hiddenSessionIds = <String>{};

  /// 隐藏会话的识图结果完成器：key = 临时会话 ID。
  final _hiddenVisionCompleters = <String, Completer<String?>>{};

  /// The server URL the current [_sseClient] was created against, used by
  /// [_connectSse] to detect a redundant connect to the same target
  /// (e.g. startup `onProjectChanged` + `initializeAfterConnect` double call)
  /// and to force a fresh client when the server changed after a reconnect.
  String _sseServerUrl = '';

  /// True once the current [SseClient] has reached a successful connection.
  /// Used to distinguish a first connect (startup already fetched everything)
  /// from a reconnect after a drop (server does not replay missed events, so
  /// local state may be stale and needs a refresh).
  bool _sseHasConnected = false;
  final math.Random _idRandom = math.Random();
  int _lastIdTimestamp = 0;
  int _idCounter = 0;
  final _pendingPartDeltas = <String, _PendingPartDelta>{};
  Timer? _partDeltaFlushTimer;
  static const _partDeltaFlushInterval = Duration(milliseconds: 80);

  /// Sessions with an in-flight generation since the last idle/error, used to
  /// reliably emit completion feedback even when `_onSessionStatus` already
  /// reset `isGenerating` before `_onSessionIdle`.
  final _feedbackGeneratingSessions = <String>{};

  void _markFeedbackGenerating(String sessionId) {
    if (sessionId.isNotEmpty) _feedbackGeneratingSessions.add(sessionId);
  }

  SessionRuntimeState get activeState {
    final id = activeSessionId.value;
    return getOrCreateSessionState(id);
  }

  SessionRuntimeState stateOf(String sessionId) =>
      getOrCreateSessionState(sessionId);

  void initializeAfterConnect() {
    final dir = _resolveSseDirectory();
    final serverUrl = SidecarManager.instance.baseUrl;
    // 启动阶段 refreshAfterConnect 恢复项目会先经 onProjectChanged 拉取过同一目标的
    // 模型/会话；若 SSE 已指向该目标且健康，说明数据正由实时事件保持同步，无需重复拉取。
    if (!_hasLiveSseFor(serverUrl: serverUrl, directory: dir)) {
      fetchModels();
      fetchSessions();
      // 手动重连（连接页换服务器/修复凭据、或旧连接已断开）时，旧连接在本会话内
      // 曾建立过（_sseHasConnected），此时刷新已打开会话并纠正断线期间可能卡住的
      // 生成态 —— 与 SSE 自动重连的 _refreshAfterReconnect 走同一逻辑。
      if (_sseHasConnected && openedSessionIds.isNotEmpty) {
        _refreshAfterReconnect();
      }
    }
    _connectSse();
  }

  /// Called when the user switches projects.
  void onProjectChanged(String directory) {
    // 递增请求代际：丢弃切项目前仍在途的会话/消息/模型响应。
    _sessionFetchSeq++;
    // Clear previous session state
    sessions.clear();
    activeSessionId.value = '';
    openedSessionIds.clear();
    sessionRuntimeStates.clear();
    _feedbackGeneratingSessions.clear();
    _parentSessionIds.clear();
    _subtaskOwners.clear();
    _subtaskDirectUserMessageIds.clear();
    _pendingSubtaskToolParts.clear();
    _processedFileToolParts.clear();
    _questionRequests.clear();
    _discardPendingPartDeltas();
    _allModels.clear();
    availableModels.clear();

    // Re-fetch for new project
    fetchModels();
    fetchSessions();

    // Reconnect SSE with new directory scope
    _connectSse();
  }

  @override
  void onInit() {
    super.onInit();
    // 监听前后台切换，App 回到前台时按需恢复 SSE（见 didChangeAppLifecycleState）。
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _discardPendingPartDeltas();
    _sseSub?.cancel();
    _sseClient?.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // 允许后台联网时 SSE 可能仍保持连接，因此按实际状态判断是否恢复：
    // 只有确实断线才触发重连。
    final sse = _sseClient;
    if (sse == null || sse.isConnected) return;
    if (sse.isCredentialFailed) {
      // 凭据失败是实例级永久停摆，connect() 会拒绝；回前台时探测一次凭据
      // 是否已被用户修复（如服务端改回了密码），修复则重建 SSE。
      _reviveCredentialFailedSse();
      return;
    }
    AppLogger.i('App resumed — SSE not connected, reconnecting');
    sse.connect();
  }

  /// SSE 因 401/403 停摆后的恢复路径：用一次轻量 HTTP 请求验证当前凭据。
  /// 探测通过则重建 SSE 客户端（_connectSse 的守卫会把凭据失败的旧连接判定为
  /// 不健康，从而创建新实例），并按断线重连的逻辑刷新会话数据，补上停摆窗口
  /// 内丢失的事件。凭据仍无效时，这次 401 会经 OpenCodeClient.unauthorized
  /// 触发全局提示。
  Future<void> _reviveCredentialFailedSse() async {
    try {
      final response = await _client.get(
        ApiEndpoints.projects,
        skipDirectory: true,
      );
      if (response.statusCode != 200) return;
      AppLogger.i('Credentials recovered — rebuilding SSE connection');
      _connectSse();
      _refreshAfterReconnect();
    } catch (e) {
      AppLogger.d('Credential probe after SSE auth failure failed: $e');
    }
  }

  String getSessionName(String id) {
    final s = sessions.firstWhereOrNull((x) => x.id == id);
    if (s != null) {
      final name = s.displayName;
      if (name.isNotEmpty) return name;
      final prefix = s.id.length >= 4 ? s.id.substring(0, 4) : s.id;
      return 'Session #$prefix';
    }
    return 'Session #$id';
  }

  SessionRuntimeState getOrCreateSessionState(String sessionId) {
    if (sessionId.isEmpty) return SessionRuntimeState('');
    var state = sessionRuntimeStates[sessionId];
    if (state == null) {
      state = SessionRuntimeState(sessionId);
      final defaultKey = Global.settings.defaultModelKey;
      if (defaultKey != null && defaultKey.isNotEmpty) {
        state.selectedModel.value = defaultKey;
      }
      sessionRuntimeStates[sessionId] = state;
      _syncThinkingLevelsForSelection(state: state);
    }
    return state;
  }

  String selectedModelName(String key) {
    if (key.isEmpty && availableModels.isNotEmpty) {
      return availableModels.first.name.isNotEmpty
          ? availableModels.first.name
          : availableModels.first.id;
    }
    final m = availableModels.firstWhereOrNull(
      (m) => m.key == key || m.id == key,
    );
    if (m != null) return m.name.isNotEmpty ? m.name : m.id;
    return key.isNotEmpty ? key : 'Select model';
  }

  /// OpenCode ascending ID (desktop parity): `{prefix}_{12hex}{14rand}`.
  String _ascendingId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (timestamp != _lastIdTimestamp) {
      _lastIdTimestamp = timestamp;
      _idCounter = 0;
    }
    _idCounter++;

    final time =
        BigInt.from(timestamp) * BigInt.from(0x1000) + BigInt.from(_idCounter);
    final timeHex = (time & BigInt.parse('ffffffffffff', radix: 16))
        .toRadixString(16)
        .padLeft(12, '0');
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    final suffix = List.generate(
      14,
      (_) => chars[_idRandom.nextInt(chars.length)],
    ).join();
    return '${prefix}_$timeHex$suffix';
  }

  // ── Subtask Ownership & Tool Diffs ──

  bool _isRootSession(SessionModel session) =>
      session.parentID == null || session.parentID!.isEmpty;

  bool _isKnownRootSessionId(String sessionId) =>
      sessionId.isNotEmpty &&
      (sessionId == activeSessionId.value ||
          sessions.any((session) => session.id == sessionId));

  String? _ownerUserMessageId(String sessionId, String assistantMessageId) {
    final messages = sessionRuntimeStates[sessionId]?.messages;
    if (messages == null) return null;
    final assistantIndex = messages.indexWhere(
      (message) => message.id == assistantMessageId,
    );
    if (assistantIndex < 0) return null;
    final assistant = messages[assistantIndex];
    final parentId = assistant.parentID;
    if (parentId != null && parentId.isNotEmpty) {
      for (final message in messages) {
        if (message.id == parentId && message.role == MessageRole.user) {
          return message.id;
        }
      }
    }
    for (var i = assistantIndex - 1; i >= 0; i--) {
      if (messages[i].role == MessageRole.user) return messages[i].id;
    }
    return null;
  }

  bool _isRootUserMessage(String rootSessionId, String messageId) {
    if (rootSessionId.isEmpty || messageId.isEmpty) return false;
    final messages = sessionRuntimeStates[rootSessionId]?.messages;
    if (messages == null) return false;
    return messages.any(
      (message) => message.id == messageId && message.role == MessageRole.user,
    );
  }

  Future<void> _registerSubtaskOwner(String parentSessionId, Part part) async {
    if (part.type != PartType.tool || part.toolName != 'task') return;
    final metadata = part.toolMetadata;
    final childSessionId = metadata?['sessionId']?.toString() ?? '';
    if (childSessionId.isEmpty) return;
    final metadataParentId = metadata?['parentSessionId']?.toString() ?? '';
    final directParentId = metadataParentId.isNotEmpty
        ? metadataParentId
        : parentSessionId;
    if (directParentId.isEmpty || directParentId == childSessionId) return;
    _parentSessionIds[childSessionId] = directParentId;
    final directUserMessageId = _ownerUserMessageId(
      directParentId,
      part.messageID,
    );
    if (directUserMessageId != null) {
      _subtaskDirectUserMessageIds[childSessionId] = directUserMessageId;
    }
    await _refreshSubtaskOwners();
  }

  Future<void> _registerParentSession(
    String childSessionId,
    String parentSessionId,
  ) async {
    if (childSessionId.isEmpty ||
        parentSessionId.isEmpty ||
        childSessionId == parentSessionId) {
      return;
    }
    _parentSessionIds[childSessionId] = parentSessionId;
    await _refreshSubtaskOwners();
  }

  void clearSubtaskTracking(String sessionId) {
    _parentSessionIds.remove(sessionId);
    _subtaskOwners.remove(sessionId);
    _subtaskDirectUserMessageIds.remove(sessionId);
    _pendingSubtaskToolParts.remove(sessionId);
    _processedFileToolParts.removeWhere(
      (key) => key.startsWith('$sessionId:part:'),
    );
  }

  /// Resolve a (subtask) session ID to its ultimate root session ID.
  String resolveRootSessionId(String id) {
    if (id.isEmpty) return id;
    var current = id;
    final visited = <String>{current};
    while (_parentSessionIds.containsKey(current)) {
      final parent = _parentSessionIds[current];
      if (parent == null || parent.isEmpty || !visited.add(parent)) break;
      current = parent;
    }
    return current;
  }

  /// Session id (root or a descendant subtask) that currently holds a pending
  /// permission request within [rootId]'s session tree. Root's own request
  /// takes priority; deeper child sessions are scanned recursively via the
  /// reactive `childSessions` obs list. Returns null when nothing is pending.
  String? sessionIdWithPendingPermission(
    String rootId, [
    Set<String>? visited,
  ]) {
    if (rootId.isEmpty) return null;
    final set = visited ?? <String>{};
    if (!set.add(rootId)) return null;
    if (getOrCreateSessionState(rootId).pendingPermission.value != null) {
      return rootId;
    }
    for (final child in getOrCreateSessionState(rootId).childSessions) {
      final found = sessionIdWithPendingPermission(child.id, set);
      if (found != null) return found;
    }
    return null;
  }

  /// First pending `question` tool part within [rootId]'s session tree (root
  /// first, then descendant subtasks recursively). Returns null when none.
  ///
  /// E3：先读每层会话的 [SessionRuntimeState.hasPendingQuestion] 惰性布尔做
  /// 短路（Obx 调用时由此只注册布尔依赖，不再注册 messages），布尔为 true
  /// 才做该会话的 O(messages×parts) 全量扫描取 part。
  Part? pendingQuestionInTree(String rootId, [Set<String>? visited]) {
    if (rootId.isEmpty) return null;
    final set = visited ?? <String>{};
    if (!set.add(rootId)) return null;
    final state = getOrCreateSessionState(rootId);
    if (state.hasPendingQuestion.value) {
      final rootPending = pendingQuestionPartFor(rootId);
      if (rootPending != null) return rootPending;
    }
    for (final child in state.childSessions) {
      final childPending = pendingQuestionInTree(child.id, set);
      if (childPending != null) return childPending;
    }
    return null;
  }

  Future<void> _refreshSubtaskOwners() async {
    for (final childSessionId in _parentSessionIds.keys.toList()) {
      final visited = <String>{childSessionId};
      var current = childSessionId;
      String? rootUserMessageId;
      while (true) {
        final parent = _parentSessionIds[current];
        if (parent == null || parent.isEmpty || !visited.add(parent)) break;
        if (_isKnownRootSessionId(parent)) {
          final candidate = _subtaskDirectUserMessageIds[current];
          if (candidate != null &&
              candidate.isNotEmpty &&
              _isRootUserMessage(parent, candidate)) {
            rootUserMessageId = candidate;
          } else {
            rootUserMessageId = null;
          }
        }
        current = parent;
      }
      if (current == childSessionId) continue;
      if (!_isKnownRootSessionId(current)) {
        _subtaskOwners.remove(childSessionId);
        continue;
      }
      _subtaskOwners[childSessionId] = _SubtaskOwner(
        rootSessionId: current,
        rootUserMessageId: rootUserMessageId,
      );
    }

    for (final childSessionId in _pendingSubtaskToolParts.keys.toList()) {
      if (!_subtaskOwners.containsKey(childSessionId)) continue;
      final pending = _pendingSubtaskToolParts.remove(childSessionId);
      if (pending == null) continue;
      for (final pendingPart in pending) {
        await _processToolPart(childSessionId, pendingPart);
      }
    }
  }

  Future<void> _processToolPart(String sessionId, Part part) async {
    final tool = part.toolName;
    if (tool != 'edit' && tool != 'write' && tool != 'apply_patch') {
      return;
    }
    final partKey = '$sessionId:part:${part.id}';
    if (_processedFileToolParts.contains(partKey)) return;

    final subtaskOwner = _subtaskOwners[sessionId];
    final isKnownRoot = _isKnownRootSessionId(sessionId);
    final isKnownChild = _parentSessionIds.containsKey(sessionId);

    if (subtaskOwner == null && (isKnownChild || !isKnownRoot)) {
      final pending = _pendingSubtaskToolParts.putIfAbsent(sessionId, () => []);
      if (!pending.any((item) => item.id == part.id)) pending.add(part);
      return;
    }

    final ownerSessionId = subtaskOwner?.rootSessionId ?? sessionId;
    final ownerUserMessageId = subtaskOwner?.rootUserMessageId;

    if (ownerUserMessageId == null || ownerUserMessageId.isEmpty) return;
    if (!_processedFileToolParts.add(partKey)) return;

    final diffs = ToolDiffParser.parse(part);
    if (diffs.isEmpty) return;

    final rootState = getOrCreateSessionState(ownerSessionId);
    final list = rootState.messageSubtaskDiffs.putIfAbsent(
      ownerUserMessageId,
      () => <SnapshotFileDiff>[],
    );

    for (final d in diffs) {
      if (d.file.isEmpty) continue;
      final idx = list.indexWhere((x) => x.file == d.file);
      if (idx == -1) {
        list.add(d);
      } else {
        list[idx] = SnapshotFileDiff.merge(list[idx], d);
      }
    }
    rootState.messageSubtaskDiffs.refresh();
    rootState.partsVersion++;
  }

  // ── Persist openedSessionIds ──

  void _persistOpenedIds() {
    final projectKey = Get.isRegistered<ProjectController>()
        ? (Get.find<ProjectController>().activeProject.value?.worktree ?? '')
        : '';
    final list = openedSessionIds.toList();
    AppLogger.i('💾 [OpenedSessions] Saving for project [$projectKey]: $list');
    Global.setOpenedSessionIdsForProject(projectKey, list);
  }

  // ── Fetch Models ──

  Future<void> fetchModels() async {
    final seq = _sessionFetchSeq;
    // 同一代际已有在途请求则跳过；切项目（代际变化）后允许新请求覆盖在途旧请求，
    // 避免旧目录的在途 fetch 阻塞新项目的模型列表刷新（模型列表会一直为空）。
    if (_lastModelsFetchIssuedSeq == seq) return;
    _lastModelsFetchIssuedSeq = seq;
    isLoadingModels.value = true;
    try {
      final modelList = <ModelInfo>[];
      Map<String, dynamic> defaultModels = {};

      final response = await _client.get(
        ApiEndpoints.configProviders,
        skipDirectory: true,
      );
      // 切项目后丢弃过期模型列表，避免旧项目模型污染新项目选择。
      if (seq != _sessionFetchSeq) return;
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        defaultModels = data['default'] is Map
            ? Map<String, dynamic>.from(data['default'] as Map)
            : {};
        final providers = data['providers'] as List? ?? [];
        for (final p in providers) {
          if (p is! Map) continue;
          final pMap = Map<String, dynamic>.from(p);
          final providerId = pMap['id'] as String? ?? '';
          final models = pMap['models'] is Map
              ? Map<String, dynamic>.from(pMap['models'] as Map)
              : <String, dynamic>{};
          for (final entry in models.entries) {
            final m = entry.value;
            if (m is! Map) continue;
            final mMap = Map<String, dynamic>.from(m);
            mMap.putIfAbsent('id', () => entry.key.toString());
            modelList.add(
              ModelInfo.fromJson({...mMap, 'providerID': providerId}),
            );
          }
        }
      }

      if (modelList.isNotEmpty) {
        _allModels.clear();
        _allModels.addAll(modelList);
        updateAvailableModels();

        final state = activeState;
        if (state.selectedModel.value.isEmpty && availableModels.isNotEmpty) {
          final savedId = Global.savedModelId;
          if (savedId != null &&
              availableModels.any((m) => m.key == savedId || m.id == savedId)) {
            state.selectedModel.value = savedId;
          } else {
            final defaultKey = defaultModels.entries
                .map((e) => '${e.key}:${e.value}')
                .where((key) => availableModels.any((m) => m.key == key))
                .firstOrNull;
            state.selectedModel.value = defaultKey ?? availableModels.first.key;
          }
        }
        if (state.selectedModel.value.isNotEmpty) {
          Global.setSavedModelId(state.selectedModel.value);
        }
      }

      for (final entry in sessionRuntimeStates.entries) {
        _syncThinkingLevelsForSelection(state: entry.value);
      }
      _syncThinkingLevelsForSelection();
    } catch (e) {
      AppLogger.e('fetchModels failed: $e');
    } finally {
      isLoadingModels.value = false;
      // 仅最新代际完成后复位，允许后续同代际重试；过期请求不动该标记。
      if (seq == _sessionFetchSeq) {
        _lastModelsFetchIssuedSeq = -1;
      }
    }
  }

  // ── Session Management ──

  Future<void> fetchSessions({bool restoreOpened = true}) async {
    final seq = _sessionFetchSeq;
    // 同一代际已有在途请求则跳过；切项目（代际变化）后允许新请求覆盖在途旧请求，
    // 避免旧目录的在途 fetch 阻塞新项目的必要刷新。
    if (_lastSessionFetchIssuedSeq == seq) return;
    _lastSessionFetchIssuedSeq = seq;
    try {
      final response = await _client.get(ApiEndpoints.sessions);
      // 切项目后返回：丢弃旧目录的响应，不写入新项目状态。
      if (seq != _sessionFetchSeq) return;
      if (response.statusCode == 200) {
        final data = response.data;
        List<SessionModel> list;
        if (data is List) {
          list = data
              .map(
                (json) => SessionModel.fromJson(json as Map<String, dynamic>),
              )
              .toList();
        } else if (data is Map && data['data'] is List) {
          list = (data['data'] as List)
              .map(
                (json) => SessionModel.fromJson(json as Map<String, dynamic>),
              )
              .toList();
        } else {
          list = [];
        }
        sessionsError.value = null;
        final roots = list.where(_isRootSession).toList();
        sessions.assignAll(roots);

        for (final s in list.where((s) => !_isRootSession(s))) {
          if (s.parentID != null && s.parentID!.isNotEmpty) {
            _parentSessionIds[s.id] = s.parentID!;
            // 同步重建父会话的子会话树：重启/SSE 重连后 session.created 不会重放，
            // 仅回填 _parentSessionIds 无法被 sessionIdWithPendingPermission /
            // pendingQuestionInTree 遍历到，正在运行的子会话权限/提问卡会上浮失败。
            final parentState = getOrCreateSessionState(s.parentID!);
            final idx = parentState.childSessions.indexWhere(
              (c) => c.id == s.id,
            );
            if (idx != -1) {
              parentState.childSessions[idx] = s;
            } else {
              parentState.childSessions.add(s);
            }
          }
        }
        unawaited(_refreshSubtaskOwners());
        // 冷启动/切项目后补拉服务端仍挂起的权限请求（asked 不重放，见
        // _restorePendingPermissions）。重连路径由 _refreshAfterReconnect 单独
        // 调用（fetchSessions 可能被同代际去重跳过）。幂等，重复调用无害。
        unawaited(_restorePendingPermissions());

        if (restoreOpened) {
          // Restore opened sessions
          _restoreOpenedSessions();
        }
      } else {
        sessionsError.value = 'HTTP ${response.statusCode}';
      }
    } catch (e) {
      if (seq != _sessionFetchSeq) return;
      sessionsError.value = e.toString();
      AppLogger.e('fetchSessions failed: $e');
    } finally {
      // 仅最新代际完成后复位，允许后续同代际重试；过期请求不动该标记。
      if (seq == _sessionFetchSeq) {
        _lastSessionFetchIssuedSeq = -1;
      }
    }
  }

  void _restoreOpenedSessions() {
    final projectKey = Get.isRegistered<ProjectController>()
        ? (Get.find<ProjectController>().activeProject.value?.worktree ?? '')
        : '';
    final saved = Global.openedSessionIdsForProject(projectKey);
    AppLogger.i(
      '📂 [OpenedSessions] Reading for project [$projectKey]: saved=$saved',
    );
    if (saved.isNotEmpty) {
      // Only keep sessions that still exist on the server
      final valid = saved
          .where((id) => sessions.any((s) => s.id == id))
          .toList();
      AppLogger.i(
        '✅ [OpenedSessions] Restored valid sessions for [$projectKey]: $valid',
      );
      openedSessionIds.assignAll(valid);

      // Auto-select the first valid opened session
      if (valid.isNotEmpty && activeSessionId.value.isEmpty) {
        _activateSessionWithoutPersist(valid.first);
      }

      // Prefetch the remaining restored tabs in the background so switching to
      // them after restart is instant instead of a blocking full-history fetch
      // on each tab switch. 在途去重由 loadMessages 的 in-flight 表兜底
      // （H1）：selectSession / SSE 预填充在预取完成前到达时复用同一 Future，
      // 不会并发重复发全量 GET。
      for (final id in valid) {
        if (id != activeSessionId.value) {
          unawaited(loadMessages(id));
        }
      }
    }
  }

  Future<void> createNewSession() async {
    try {
      // Capture current active session's model and thinking level to inherit
      final currentModel = activeState.selectedModel.value;
      final currentLevel = activeState.selectedThinkingLevel.value;

      // v1 POST /session uses instance directory via x-opencode-directory.
      final response = await _client.post(
        ApiEndpoints.sessions,
        data: <String, dynamic>{},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final sessionJson = (data is Map && data['data'] is Map)
            ? Map<String, dynamic>.from(data['data'] as Map)
            : data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final session = SessionModel.fromJson(sessionJson);
        sessions.insert(0, session);

        // Inherit current session's model and thinking level for new session
        final newState = getOrCreateSessionState(session.id);
        if (currentModel.isNotEmpty) {
          newState.selectedModel.value = currentModel;
          newState.selectedThinkingLevel.value = currentLevel;
          _syncThinkingLevelsForSelection(state: newState);
        }

        selectSession(session.id);
      }
    } catch (e) {
      AppLogger.e('createNewSession failed: $e');
    }
  }

  /// Attach a screenshot (PNG bytes) to the active session's draft images so it
  /// appears in the input box. If no session is open, auto-creates one first.
  /// Returns false only when no active session could be obtained.
  Future<bool> attachScreenshotToActiveSession(Uint8List bytes) async {
    var sid = activeSessionId.value;
    if (sid.isEmpty) {
      await createNewSession();
      sid = activeSessionId.value;
    }
    if (sid.isEmpty) return false;
    stateOf(
      sid,
    ).attachedImages.add((bytes: bytes, mime: 'image/png', ext: 'png'));
    return true;
  }

  /// 找一个支持识图（`capabilities.input` 含 image）的模型，作为图片转文字
  /// 的后备模型。
  ///
  /// 优先级：
  /// 1. 用户在「识图设置」里选定的模型（[Global.visionModelKey]）；
  /// 2. 未设置时，从输入框模型列表 [availableModels] 里选第一个支持识图的模型。
  ModelInfo? _findVisionModel() {
    final configured = Global.visionModelKey;
    if (configured != null && configured.isNotEmpty) {
      final byKey = availableModels.firstWhereOrNull(
        (m) => m.key == configured || m.id == configured,
      );
      if (byKey != null) return byKey;
      final byKeyAll = _allModels.firstWhereOrNull(
        (m) => m.key == configured || m.id == configured,
      );
      if (byKeyAll != null) return byKeyAll;
    }
    return availableModels.firstWhereOrNull((m) => m.supportsImage);
  }

  /// 当前配置的识图模型 key（可能为 null = 自动）。
  String? get visionModelKey => Global.visionModelKey;

  /// 设置识图模型（key 为 `providerId:id`）。
  Future<void> setVisionModel(String key) => Global.setVisionModelKey(key);

  /// 是否存在可用的识图模型（已配置的，或输入框模型列表里第一个支持识图的）。
  bool get hasVisionModel => _findVisionModel() != null;

  /// 当前实际用于识图的模型名（已配置的，或输入框列表里第一个支持识图的）。
  String get visionModelName {
    final model = _findVisionModel();
    if (model == null) return '';
    return model.name.isNotEmpty ? model.name : model.id;
  }

  /// 把 [images] 发给一个支持识图的模型，返回其文本描述；失败或超时返回 null。
  ///
  /// 用一个隐藏的临时会话执行（SSE 事件被 [_hiddenSessionIds] 屏蔽，不会污染
  /// 聊天界面/触发反馈），结果通过轮询消息接口拿到，最后删除临时会话。返回后
  /// 调用方可用该文本替换输入框里的图片。
  Future<String?> describeImagesToText(
    List<PickedImage> images, {
    required String prompt,
  }) async {
    if (images.isEmpty) return null;
    final visionModel = _findVisionModel();
    if (visionModel == null) {
      AppLogger.w(
        'describeImagesToText: no vision-capable model found '
        '(availableModels=${availableModels.length}, total=${_allModels.length})',
      );
      return null;
    }
    AppLogger.i(
      'describeImagesToText: using vision model '
      '${visionModel.providerId}/${visionModel.id} (name=${visionModel.name}, '
      'availableModels=${availableModels.length}, total=${_allModels.length})',
    );

    String? tempId;
    try {
      final resp = await _client.post(
        ApiEndpoints.sessions,
        data: <String, dynamic>{},
      );
      if (resp.statusCode != 200 && resp.statusCode != 201) return null;
      final data = resp.data;
      final sessionJson = (data is Map && data['data'] is Map)
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      tempId = sessionJson['id']?.toString() ?? '';
      if (tempId.isEmpty) return null;

      _hiddenSessionIds.add(tempId);
      // 若 session.created SSE 已先于 HTTP 响应到达，把临时会话从可见列表里摘掉。
      sessions.removeWhere((s) => s.id == tempId);

      // 注册 SSE 驱动的完成器：idle 时由 _handleHiddenEvent 完成。
      final completer = Completer<String?>();
      _hiddenVisionCompleters[tempId] = completer;

      final messageId = _ascendingId('msg');
      final partsJson = <Map<String, dynamic>>[];
      partsJson.add({
        'id': _ascendingId('prt'),
        'type': 'text',
        'text': prompt,
      });
      // 识图前先压缩一次（与发送路径一致，1280px / JPEG 85）避免大图
      // 以原尺寸 base64 上传拖慢识图；编码与压缩同在后台隔离区完成。
      List<({PickedImage image, String base64})> sendEncoded = const [];
      if (images.isNotEmpty) {
        try {
          sendEncoded = await Isolate.run(
            () => compressAndEncodeImagesSync(images),
          );
        } catch (e) {
          AppLogger.e('compress images (vision) failed: $e');
          sendEncoded = [
            for (final img in images)
              (image: img, base64: base64Encode(img.bytes)),
          ];
        }
      }
      for (var i = 0; i < sendEncoded.length; i++) {
        final img = sendEncoded[i].image;
        partsJson.add({
          'id': _ascendingId('prt'),
          'type': 'file',
          'url': 'data:${img.mime};base64,${sendEncoded[i].base64}',
          'mime': img.mime,
          'filename': 'image_${i + 1}.${img.ext}',
        });
      }

      final body = <String, dynamic>{
        'messageID': messageId,
        'parts': partsJson,
        'agent': 'plan',
        'model': {
          'providerID': visionModel.providerId,
          'modelID': visionModel.id,
        },
      };
      await _client.post(ApiEndpoints.sessionPromptAsync(tempId), data: body);

      // SSE 已连接时等待 idle/error 事件驱动完成；否则或超时则回退到轮询。
      final sse = _sseClient;
      final sseAlive =
          sse != null &&
          sse.isConnected &&
          !sse.isCredentialFailed &&
          sse.queryParams['directory'] == _client.activeDirectory;
      if (sseAlive) {
        try {
          final result = await completer.future.timeout(_visionSseTimeout);
          return result;
        } on TimeoutException {
          AppLogger.w('describeImagesToText: SSE timed out, polling fallback');
        }
      } else {
        AppLogger.w(
          'describeImagesToText: SSE not connected, polling fallback',
        );
      }
      return await _pollVisionReply(tempId);
    } catch (e) {
      AppLogger.e('describeImagesToText failed: $e');
      return null;
    } finally {
      if (tempId != null && tempId.isNotEmpty) {
        _hiddenSessionIds.remove(tempId);
        _hiddenVisionCompleters.remove(tempId);
        sessionRuntimeStates.remove(tempId);
        try {
          await _client.delete(ApiEndpoints.sessionDelete(tempId));
        } catch (e) {
          AppLogger.e('describeImagesToText cleanup failed: $e');
        }
      }
    }
  }

  /// 轮询临时会话的消息，直到拿到非空 assistant 文本，超时返回 null。
  /// 仅在 SSE 未连接或 SSE 超时后作为兜底。
  static const _visionPollInterval = Duration(milliseconds: 400);
  static const _visionPollTimeout = Duration(seconds: 30);
  static const _visionSseTimeout = Duration(seconds: 20);

  /// 服务端 image.max_base64_bytes 默认上限（clone/.../image/image.ts）。
  static const _serverImageBase64Limit = 5 * 1024 * 1024;

  Future<String?> _pollVisionReply(String tempId) async {
    final deadline = DateTime.now().add(_visionPollTimeout);
    var lastText = '';
    var stableCount = 0;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_visionPollInterval);
      final (text, completed) = await _fetchVisionReply(tempId);
      if (text != null && text.isNotEmpty) {
        // 服务端 time.completed 标记消息流式结束后即可返回；
        // 响应缺该标志时退回「连续采样一致」启发式（4 次 = 约 1.2s 无变化，
        // 避免慢流式模型中途停顿 >400ms 即被误判为已完成而截断）。
        if (completed) return text;
        if (text == lastText) {
          stableCount++;
        } else {
          stableCount = 1;
          lastText = text;
        }
        if (stableCount >= 4) return text;
      }
    }
    return lastText.isNotEmpty ? lastText : null;
  }

  Future<bool> deleteSession(String id) async {
    try {
      await _client.delete(ApiEndpoints.sessionDelete(id));
      sessions.removeWhere((s) => s.id == id);
      sessionRuntimeStates.remove(id);
      openedSessionIds.remove(id);
      _feedbackGeneratingSessions.remove(id);
      clearSubtaskTracking(id);
      _forgetQuestionRequestsForSession(id);
      _discardPendingPartDeltas(sessionIds: {id});
      _persistOpenedIds();
      // 服务端删除成功才清缓存；失败保留（无害，下次删除/清空兜底）。
      unawaited(SessionCacheStore.instance.delete(id));
      if (activeSessionId.value == id) {
        activeSessionId.value = openedSessionIds.isNotEmpty
            ? openedSessionIds.last
            : '';
      }
      return true;
    } catch (e) {
      AppLogger.e('deleteSession failed: $e');
      return false;
    }
  }

  /// 恢复流程专用：仅设置 activeSessionId 并加载消息，不把会话加入
  /// openedSessionIds、也不持久化，避免启动/切项目恢复误写库导致
  /// 被清空的页签"复活"。用户主动操作仍走 [selectSession]。
  void _activateSessionWithoutPersist(String id) {
    if (id.isEmpty) return;
    if (_parentSessionIds.containsKey(id)) return;
    activeSessionId.value = id;
    final state = getOrCreateSessionState(id);
    _syncThinkingLevelsForSelection(state: state);
    loadMessages(id);
  }

  void selectSession(String id) {
    if (id.isEmpty) return;
    if (_parentSessionIds.containsKey(id)) return;
    activeSessionId.value = id;
    final state = getOrCreateSessionState(id);
    if (!openedSessionIds.contains(id)) {
      openedSessionIds.add(id);
      _persistOpenedIds();
    }
    _syncThinkingLevelsForSelection(state: state);
    loadMessages(id);
  }

  void closeSession(String id) {
    openedSessionIds.remove(id);
    _persistOpenedIds();
    if (activeSessionId.value == id) {
      activeSessionId.value = openedSessionIds.isNotEmpty
          ? openedSessionIds.last
          : '';
    }
    _releaseSessionState(id);
  }

  /// 释放已关闭页签的运行时状态（F2 定版方案）：
  /// - 普通会话：整个 remove，重开时 `hasLoadedHistory` 随新状态重置、走
  ///   正常懒加载；
  /// - 父会话：保留轻量外壳——`childSessions` 树是 pendingQuestionInTree /
  ///   权限遍历的依赖（fetchSessions 重建前的窗口不能为空），只清消息类
  ///   字段（messages / streamingPartText / turnDiffCache / messageSubtaskDiffs
  ///   / fetchedMessageDiffs）并重置 `hasLoadedHistory=false`；其子会话 state
  ///   逐个递归释放（多层嵌套同规则）；
  /// - 挂起权限的会话跳过：asked 不重放、loadMessages 也不恢复权限，释放会
  ///   让重开页签后的权限卡永久消失（agent 挂起在等待回复上）。回复/级联
  ///   replied 清槽后再关闭页签即可正常释放；
  /// - 生成中不额外设守卫：与既有普通页签释放语义一致，释放后事件到达由
  ///   getOrCreateSessionState 重建空壳，重开时 loadMessages 全量纠正。
  void _releaseSessionState(String id, {Set<String>? visited}) {
    if (id.isEmpty) return;
    final guard = visited ?? <String>{};
    if (!guard.add(id)) return;
    final state = sessionRuntimeStates[id];
    if (state == null) return;
    // 会话仍持有待回复的权限请求时保留状态（含其子树一并保留）。
    if (state.pendingPermission.value != null) return;
    final isParent =
        state.childSessions.isNotEmpty || _parentSessionIds.values.contains(id);
    if (isParent) {
      // 父会话：清消息类字段、保留 childSessions 树，子会话逐个释放。
      _discardPendingPartDeltas(sessionIds: {id});
      state.messages.clear();
      state.streamingPartText.clear();
      state.turnDiffCache.clear();
      state.messageSubtaskDiffs.clear();
      state.fetchedMessageDiffs.clear();
      state.hasLoadedHistory.value = false;
      state.partsVersion++;
      state.rescanHasPendingQuestion();
      for (final child in state.childSessions.toList()) {
        _releaseSessionState(child.id, visited: guard);
      }
      return;
    }
    _discardPendingPartDeltas(sessionIds: {id});
    sessionRuntimeStates.remove(id);
  }

  /// 清空所有页签（F2）：除清 openedSessionIds / activeSessionId 外，遍历
  /// 全部运行时状态逐个释放（含不在 openedSessionIds 里的后台子会话）——
  /// 父会话走 [_releaseSessionState] 的外壳级联，普通/子会话整个 remove，
  /// 挂起权限的会话沿用守卫跳过；最后统一清一次 delta 合并队列。
  void clearAllOpenedSessions() {
    openedSessionIds.clear();
    activeSessionId.value = '';
    _persistOpenedIds();
    for (final id in sessionRuntimeStates.keys.toList()) {
      _releaseSessionState(id);
    }
    _discardPendingPartDeltas();
    AppLogger.i('🧹 Cleared all opened sessions');
  }

  /// Fork the current session at [messageId] and switch to the new branch.
  Future<String?> forkSessionAt(String messageId) async {
    final sessionId = activeSessionId.value;
    if (sessionId.isEmpty || messageId.isEmpty) return null;
    final state = getOrCreateSessionState(sessionId);
    if (state.isGenerating.value) {
      Snack.warning(LocaleKeys.sessionWaitGenerationFinish.tr);
      return null;
    }
    try {
      final response = await _client
          .post(
            ApiEndpoints.sessionFork(sessionId),
            data: {'messageID': messageId},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final sessionJson = (data is Map && data['data'] is Map)
            ? Map<String, dynamic>.from(data['data'] as Map)
            : data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final newSession = SessionModel.fromJson(sessionJson);
        final index = sessions.indexWhere((s) => s.id == newSession.id);
        if (index != -1) {
          sessions[index] = newSession;
        } else {
          sessions.insert(0, newSession);
        }
        selectSession(newSession.id);
        return newSession.id;
      }
      Snack.error(LocaleKeys.sessionForkFailed.tr);
    } on TimeoutException {
      AppLogger.e('forkSessionAt timed out');
      Snack.error(LocaleKeys.sessionForkFailed.tr);
    } catch (e) {
      AppLogger.e('forkSessionAt failed: $e');
      Snack.error('${LocaleKeys.sessionForkFailed.tr}: $e');
    }
    return null;
  }

  /// Revert session timeline to [messageId] (hides later messages via
  /// [SessionRuntimeState.revertMessageID]).
  Future<void> revertMessage(String messageId) async {
    final sessionId = activeSessionId.value;
    if (sessionId.isEmpty || messageId.isEmpty) return;
    final state = getOrCreateSessionState(sessionId);
    if (state.isGenerating.value) {
      Snack.warning(LocaleKeys.shRevertBlockedGenerating.tr);
      return;
    }
    try {
      final response = await _client.post(
        ApiEndpoints.sessionRevert(sessionId),
        data: {'messageID': messageId},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final sessionJson = (data is Map && data['data'] is Map)
            ? Map<String, dynamic>.from(data['data'] as Map)
            : data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        if (sessionJson.isNotEmpty) {
          final updated = SessionModel.fromJson(sessionJson);
          final index = sessions.indexWhere((s) => s.id == updated.id);
          if (index != -1) sessions[index] = updated;
          getOrCreateSessionState(sessionId).revertMessageID.value =
              updated.revert?.messageID ?? messageId;
        } else {
          getOrCreateSessionState(sessionId).revertMessageID.value = messageId;
        }
      }
    } catch (e) {
      AppLogger.e('revertMessage failed: $e');
      Snack.error('${LocaleKeys.sessionRevertFailed.tr}: $e');
    }
  }

  // ── Messages ──

  /// 归一化服务端消息原始 JSON：过滤非聊天消息，并按 `time.created` 检测
  /// newest-first 返回翻转为时间正序。网络路径与缓存落盘共用，保证缓存
  /// 命中渲染与网络对齐后的渲染顺序、消息范围完全一致。
  static List<MessageModel> normalizeServerMessages(List rawMessages) {
    final msgs = rawMessages
        .whereType<Map>()
        .map((json) => MessageModel.fromJson(Map<String, dynamic>.from(json)))
        .where((m) => m.isChatMessage)
        .toList();
    // API may return newest-first; keep chronological for the timeline.
    if (msgs.length >= 2 &&
        (msgs.first.time?['created'] is num) &&
        (msgs.last.time?['created'] is num) &&
        (msgs.first.time!['created'] as num) >
            (msgs.last.time!['created'] as num)) {
      return msgs.reversed.toList();
    }
    return msgs;
  }

  /// Public entry（H1）：同会话在途去重 + force 取消旧请求。见
  /// [_messageLoadInFlight] 注释；实际加载逻辑在 [_loadMessagesImpl]。
  Future<void> loadMessages(
    String sessionId, {
    bool force = false,
    bool reconcileGenerating = false,
  }) {
    final inFlight = _messageLoadInFlight[sessionId];
    if (inFlight != null) {
      if (!force) return inFlight;
      _messageLoadCancelTokens[sessionId]?.cancel();
    }
    final ticket = ++_messageLoadTicketSeq;
    _messageLoadTickets[sessionId] = ticket;
    final future = _loadMessagesImpl(
      sessionId,
      force: force,
      reconcileGenerating: reconcileGenerating,
      ticket: ticket,
    );
    _messageLoadInFlight[sessionId] = future;
    // 完成后清理；仅当在途表项仍是本次 Future（未被更新的 force 请求替换）
    // 时才移除，避免误删新请求的表项。
    future.whenComplete(() {
      if (identical(_messageLoadInFlight[sessionId], future)) {
        _messageLoadInFlight.remove(sessionId);
      }
    });
    return future;
  }

  Future<void> _loadMessagesImpl(
    String sessionId, {
    bool force = false,
    bool reconcileGenerating = false,
    required int ticket,
  }) async {
    if (sessionId.isEmpty) return;
    final seq = _sessionFetchSeq;
    final reloadState = stateOf(sessionId);
    final flaggedReload = reloadState.needsReloadAfterReconnect;
    // Lazy guard: don't re-fetch sessions whose history is already loaded.
    // selectSession fires on every PageView swipe, so an unconditional reload
    // would both spam the server and clobber in-flight streaming / optimistic
    // messages with a stale snapshot (desktop parity: only fetch once). Uses a
    // dedicated flag instead of messages.isNotEmpty because SSE may pre-populate
    // messages for a not-yet-opened session, which must not skip the first fetch.
    // 重连标脏（needsReloadAfterReconnect）强制一次重拉并纠正生成态。
    // 上次拉取失败（historyLoadFailed）同样放行：切回页签时自动重试。
    if (!force &&
        reloadState.hasLoadedHistory.value &&
        !reloadState.historyLoadFailed.value &&
        !flaggedReload) {
      return;
    }
    // 重拉/重试前回到未加载态，空会话 UI 才能显示"正在加载消息..."而不是
    // 残留的失败提示；空态分支只在 msgs 为空时渲染，不影响已加载的会话。
    reloadState.historyLoadFailed.value = false;
    reloadState.hasLoadedHistory.value = false;
    // SWR 秒开：内存为空时先读本地缓存立即渲染历史，网络请求随后照常发出
    // 做静默对齐。串行读取（先缓存后发 GET）天然规避"缓存后到覆盖新数据"
    // 的乱序；缓存缺失/损坏时返回 null，无感降级为正常网络加载。
    // SSE 预填充或重连强刷场景消息非空，自动跳过走原路径。
    if (reloadState.messages.isEmpty) {
      final cached = await SessionCacheStore.instance.load(sessionId);
      // 读缓存期间可能已切项目：不重建/不写过期会话状态。
      if (seq != _sessionFetchSeq) return;
      if (cached != null) {
        reloadState.messages.assignAll(
          cached.map((json) => MessageModel.fromJson(json)).toList(),
        );
        reloadState.hasLoadedHistory.value = true;
        reloadState.partsVersion++;
        reloadState.rescanHasPendingQuestion();
      }
    }
    // Fire the todo fetch concurrently with the full-history GET below so its
    // ~one round-trip of latency is hidden behind the much slower message fetch
    // instead of running serially after it. SSE todoUpdated also populates
    // todos and sets hasFetchedTodos; this only fills the gap for sessions whose
    // in-flight todos never change again (e.g. paused mid-turn after restart).
    unawaited(_fetchTodosIfEmpty(sessionId, seq));
    // H1 票据检查点：本次加载已被更新的 loadMessages（force 重发）取代时
    // 放弃发出请求（取代者负责收尾，见 _messageLoadTickets）。
    if (_messageLoadTickets[sessionId] != ticket) return;
    try {
      // H1：注册 CancelToken，force 到来时可取消在途旧请求。
      final cancelToken = CancelToken();
      _messageLoadCancelTokens[sessionId] = cancelToken;
      final response = await _client.get(
        ApiEndpoints.sessionMessages(sessionId),
        cancelToken: cancelToken,
      );
      if (identical(_messageLoadCancelTokens[sessionId], cancelToken)) {
        _messageLoadCancelTokens.remove(sessionId);
      }
      // 切项目后返回：不重建/不写过期会话状态，避免污染新项目内存。
      if (seq != _sessionFetchSeq) return;
      if (response.statusCode == 200) {
        final data = response.data;
        final List rawMessages;
        if (data is List) {
          rawMessages = data;
        } else if (data is Map && data['data'] is List) {
          rawMessages = data['data'] as List;
        } else {
          rawMessages = [];
        }
        final msgs = normalizeServerMessages(rawMessages);
        final state = stateOf(sessionId);
        state.hasLoadedHistory.value = true;
        state.historyLoadFailed.value = false;
        state.needsReloadAfterReconnect = false;
        // SWR 对齐守卫：快照在途期间回合已开始（本地发送在途/正在生成/
        // 流式通道有内容）时，旧快照不得冲掉乐观消息与流式内容，落盘交由
        // idle 收尾兜底。重连强刷（force/flaggedReload）豁免：全量历史是
        // 权威数据，生成中也必须落快照以纠正断线期间的残留状态。
        final snapshotStale = !force &&
            !flaggedReload &&
            (state.isGenerating.value ||
                _localSendInFlight.contains(sessionId) ||
                state.streamingPartText.isNotEmpty);
        if (!snapshotStale) {
          // 全量历史是权威数据：清空流式通道，避免通道里的旧累计值在后续
          // 全量 part 对齐/落库时覆盖服务端历史。
          state.streamingPartText.clear();
          state.messages.assignAll(msgs);
          state.partsVersion++;
          state.rescanHasPendingQuestion();
          unawaited(
            SessionCacheStore.instance.save(
              sessionId,
              msgs.map((m) => m.raw).toList(),
            ),
          );
        }
        // 断网重连兜底：离线期间错过的 idle 事件会让 isGenerating 残留 true，
        // 依据刚拉取到的历史判定回合是否已收尾并纠正（详见 _reconcileGeneratingAfterReconnect）。
        // 重连标脏触发的重拉同样需要纠正（该页签没经过 _refreshAfterReconnect
        // 的强刷路径）。
        if (reconcileGenerating || flaggedReload) {
          _reconcileGeneratingAfterReconnect(state);
        }
        // Detect if the session is currently executing/generating on the server
        // Commented out to avoid incorrect thinking state when session was previously manually aborted.
        // if (state.messages.isNotEmpty) {
        //   final lastMsg = state.messages.last;
        //   if (lastMsg.role == MessageRole.assistant) {
        //     final hasStepFinish = lastMsg.parts.any(
        //       (p) => p.type == PartType.stepFinish,
        //     );
        //     final hasRunningTool = lastMsg.parts.any(
        //       (p) =>
        //           p.type == PartType.tool &&
        //           (p.toolStatus == ToolStateStatus.running ||
        //               p.toolStatus == ToolStateStatus.pending),
        //     );
        //     if (!hasStepFinish || hasRunningTool) {
        //       state.isGenerating.value = true;
        //     }
        //   }
        // }

        // Sync selectedModel and selectedThinkingLevel from last sent/used model in history
        if (state.messages.isNotEmpty) {
          final lastMsgWithModel = state.messages.reversed
              .cast<MessageModel?>()
              .firstWhere(
                (m) => m != null && (m.model != null || m.raw['model'] is Map),
                orElse: () => null,
              );
          if (lastMsgWithModel != null) {
            final modelMap = lastMsgWithModel.model;
            if (modelMap != null) {
              final providerID =
                  (modelMap['providerID'] ?? modelMap['provider_id'])
                      ?.toString() ??
                  '';
              final modelID =
                  (modelMap['id'] ??
                          modelMap['modelID'] ??
                          modelMap['model_id'])
                      ?.toString() ??
                  '';
              final variant = modelMap['variant']?.toString() ?? '';

              // Find if this model exists in availableModels
              final matched = availableModels.firstWhereOrNull((m) {
                if (providerID.isNotEmpty && modelID.isNotEmpty) {
                  return m.providerId == providerID && m.id == modelID;
                }
                return m.key == modelID || m.id == modelID;
              });

              if (matched != null) {
                state.selectedModel.value = matched.key;
                if (variant.isNotEmpty && matched.variants.contains(variant)) {
                  state.selectedThinkingLevel.value = variant;
                }
              } else if (availableModels.isNotEmpty) {
                // Fallback: pick one from availableModels if previous model is no longer available
                state.selectedModel.value = availableModels.first.key;
                state.selectedThinkingLevel.value = '';
              }
              _syncThinkingLevelsForSelection(state: state);
            }
          }
        }

        // Batch restore of idle sessions: leftover pending questions are stale
        // unless the server still has them pending (live question must survive
        // a cold start — see _markStaleQuestionsSkipped). Skip while generating
        // so a live question is not wiped mid-turn. 异步发起：GET /question 的
        // 一个 RTT 不必阻塞 loadMessages 返回（内部自带错误兜底，失败保守
        // 跳过清理）。
        if (!state.isGenerating.value) {
          unawaited(_markStaleQuestionsSkipped(state));
        }
      }
    } catch (e) {
      // H1：被 force 取消的在途请求不算失败——取代它的请求负责收尾，
      // 不能把 historyLoadFailed 置真让空会话 UI 误报重试。
      if (e is DioException && e.type == DioExceptionType.cancel) {
        AppLogger.i('loadMessages cancelled (superseded): $sessionId');
        return;
      }
      AppLogger.e('loadMessages failed: $e');
      // 失败同样终结加载态（见 finally），但标记失败：空会话 UI 提示重试
      // 而不是伪装成"开启对话"。seq 守卫避免切项目后写过期会话状态；票据
      // 守卫避免被 force 取代的旧请求把失败标记压到取代者头上。
      if (seq == _sessionFetchSeq &&
          _messageLoadTickets[sessionId] == ticket) {
        stateOf(sessionId).historyLoadFailed.value = true;
      }
    } finally {
      // 票据仍为本请求时才终结加载态：被取代的旧请求在取代者飞行期间置
      // true，会让空会话 UI 在"正在加载"与"开始对话"间闪跳。取代者自身的
      // finally 负责收尾。
      if (seq == _sessionFetchSeq &&
          _messageLoadTickets[sessionId] == ticket) {
        stateOf(sessionId).hasLoadedHistory.value = true;
      }
    }
  }

  /// 重建消息并把当前 [parts] 回写进 raw 副本。
  ///
  /// delta/finalize/工具状态标记等只更新解析后的 parts（高频 delta 甚至只进
  /// per-part 通道），而缓存落盘等消费的是 `MessageModel.raw` 的 parts 键
  /// ——不同步会让 Sync-on-Idle 快照停留在最后一次全量 message.updated 的
  /// 内容，冷启动读缓存渲染出截断文本。raw 按拷贝写入不污染原 map；
  /// legacy（`parts`）与 v2（`info.content` 等）两种形状都回写，均无列表键
  /// 且 parts 非空时补写 `parts`，并补齐 id/sessionID 供 fromJson 还原身份。
  static MessageModel messageWithSyncedParts(
    MessageModel message,
    List<Part> parts,
  ) {
    final raw = Map<String, dynamic>.from(message.raw);
    final partsJson = [for (final p in parts) p.raw];
    var wrote = false;
    final info = raw['info'];
    if (info is Map) {
      final infoCopy = Map<String, dynamic>.from(info);
      for (final key in const ['parts', 'content']) {
        if (infoCopy[key] is List) {
          infoCopy[key] = partsJson;
          wrote = true;
        }
      }
      if (wrote) raw['info'] = infoCopy;
    }
    for (final key in const ['parts', 'content']) {
      if (raw[key] is List) {
        raw[key] = partsJson;
        wrote = true;
      }
    }
    if (!wrote && partsJson.isNotEmpty) {
      raw['parts'] = partsJson;
    }
    if (message.id.isNotEmpty && raw['id'] == null) {
      raw['id'] = message.id;
    }
    if (message.sessionID.isNotEmpty && raw['sessionID'] == null) {
      raw['sessionID'] = message.sessionID;
    }
    return MessageModel(
      id: message.id,
      sessionID: message.sessionID,
      role: message.role,
      parts: parts,
      raw: raw,
    );
  }

  /// 回合收尾后把内存中的权威消息快照落盘（SWR 的 Sync-on-Idle 侧）。
  /// 必须在 `_finalizeStreamingText` 之后调用。生成中/本地发送在途/流式通道
  /// 未清空时跳过；revert 期间也跳过——revert 只隐藏不截断内存消息，照存会
  /// 把已撤销的消息带进缓存并在冷启动重新显示，缓存保留上一次网络快照、
  /// 由下次 revalidate 自愈。
  void _persistSessionCacheSnapshot(
    String sessionId,
    SessionRuntimeState state,
  ) {
    if (state.messages.isEmpty ||
        state.isGenerating.value ||
        _localSendInFlight.contains(sessionId) ||
        state.streamingPartText.isNotEmpty ||
        state.revertMessageID.value.isNotEmpty) {
      return;
    }
    unawaited(
      SessionCacheStore.instance.save(
        sessionId,
        // 落盘前统一把当前 parts 回写 raw 副本：即便某个消息变更点漏调
        // messageWithSyncedParts，快照也不会缺流式内容。
        [
          for (final m in state.messages) messageWithSyncedParts(m, m.parts).raw,
        ],
      ),
    );
  }

  Future<void> _fetchTodosIfEmpty(String sessionId, int seq) async {
    final state = stateOf(sessionId);
    if (state.hasFetchedTodos || state.todos.isNotEmpty) return;
    state.hasFetchedTodos = true;
    try {
      final response = await _client.get(ApiEndpoints.sessionTodo(sessionId));
      // 切项目后丢弃过期 todo 响应，不污染新项目状态。
      if (seq != _sessionFetchSeq) return;
      if (response.statusCode == 200) {
        final responseData = response.data;
        final data = responseData is Map<String, dynamic>
            ? (responseData['data'] as List? ?? [])
            : (responseData is List ? responseData : []);
        if (data.isNotEmpty) {
          final parsed = data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (parsed.isNotEmpty &&
              parsed.every((t) => t['status']?.toString() == 'completed')) {
            state.todos.clear();
          } else {
            state.todos.assignAll(parsed);
          }
        }
      }
    } catch (e) {
      // Allow a retry on a transient failure; otherwise the flag would stay
      // set and the todo panel would be permanently hidden for this session.
      state.hasFetchedTodos = false;
      AppLogger.e('fetchTodos failed: $e');
    }
  }

  void clearPendingPrompt([String? sessionId]) {
    final id = sessionId ?? activeSessionId.value;
    if (id.isEmpty) return;
    stateOf(id).clearPendingPrompt();
  }

  Future<void> sendPendingPromptImmediately([String? sessionId]) async {
    final id = sessionId ?? activeSessionId.value;
    if (id.isEmpty) return;
    final state = stateOf(id);
    if (!state.hasPendingPrompt) return;
    final text = state.pendingPromptText.value;
    final images = state.pendingPromptImages.toList();
    final files = state.pendingPromptAttachedFiles.toList();
    state.clearPendingPrompt();
    if (activeSessionId.value != id) {
      selectSession(id);
    }
    await abortGeneration(sessionId: id);
    await sendPrompt(
      text,
      images: images,
      overrideFiles: files,
      force: true,
      targetSessionId: id,
    );
  }

  void _checkAndSendPendingPrompt([String? sessionId]) {
    final id = sessionId ?? activeSessionId.value;
    if (id.isEmpty) return;
    final state = stateOf(id);
    if (!state.hasPendingPrompt) return;
    final text = state.pendingPromptText.value;
    final images = state.pendingPromptImages.toList();
    final files = state.pendingPromptAttachedFiles.toList();
    final overrideAgent = state.pendingPromptAgent.value.isNotEmpty
        ? state.pendingPromptAgent.value
        : null;
    final overrideModel = state.pendingPromptModel.value.isNotEmpty
        ? state.pendingPromptModel.value
        : null;
    state.clearPendingPrompt();
    unawaited(
      sendPrompt(
        text,
        images: images,
        overrideFiles: files,
        overrideAgent: overrideAgent,
        overrideModel: overrideModel,
        force: true,
        targetSessionId: id,
      ),
    );
  }

  void _queuePendingPrompt(
    SessionRuntimeState state,
    String text,
    List<PickedImage> images,
    List<String> files, {
    String? overrideAgent,
    String? overrideModel,
  }) {
    if (state.pendingPromptText.value.isEmpty) {
      state.pendingPromptText.value = text;
    } else if (text.isNotEmpty) {
      state.pendingPromptText.value = '${state.pendingPromptText.value}\n$text';
    }
    state.pendingPromptImages.addAll(images);
    for (final f in files) {
      if (!state.pendingPromptAttachedFiles.contains(f)) {
        state.pendingPromptAttachedFiles.add(f);
      }
    }
    if (overrideAgent != null && overrideAgent.isNotEmpty) {
      state.pendingPromptAgent.value = overrideAgent;
    }
    if (overrideModel != null && overrideModel.isNotEmpty) {
      state.pendingPromptModel.value = overrideModel;
    }
  }

  // ── Send Prompt ──

  /// 返回 false 表示 POST 失败（非排队/空内容场景），调用方可据此把
  /// 文本与附件回填到输入区，避免发送失败时内容静默丢失。
  Future<bool> sendPrompt(
    String text, {
    List<PickedImage> images = const [],
    List<String>? overrideFiles,
    bool force = false,
    String? targetSessionId,
    String? overrideModel,
    String? overrideAgent,
  }) async {
    final sessionId = targetSessionId ?? activeSessionId.value;
    if (sessionId.isEmpty) return true;
    final state = getOrCreateSessionState(sessionId);
    final filesToSend = overrideFiles ?? state.attachedFiles.toList();
    if (text.trim().isEmpty && images.isEmpty && filesToSend.isEmpty) {
      return true;
    }

    // 回合互斥：同会话已有本地发送在途（POST 未返回）时，本次发送转为排队，
    // 待回合结束由 _checkAndSendPendingPrompt 发出。覆盖两类双回合窗口：
    // sendPendingPromptImmediately 的 abort 网络往返期间（isGenerating 已被
    // abort 置 false）的用户并发发送、stale 结束事件误复位 isGenerating 后
    // 的用户发送（后者在途期间 SSE 结束事件被 handler 守卫跳过）。
    if (_localSendInFlight.contains(sessionId)) {
      _queuePendingPrompt(
        state,
        text,
        images,
        filesToSend,
        overrideAgent: overrideAgent,
        overrideModel: overrideModel,
      );
      if (overrideFiles == null) {
        state.attachedFiles.clear();
        state.attachedImages.clear();
      }
      return true;
    }

    // 发送新消息时自动折叠 changefiles：新回合文件变化不再触发右侧持续刷新，
    // 用户重新展开时（现有 onToggle 会 openReviewSession）再刷新右侧。
    if (state.expandedSection.value == SessionExpandedSection.diff) {
      state.expandedSection.value = SessionExpandedSection.none;
    }

    // 回滚后继续发新消息 = 会话继续：镜像服务端 prompt 时的 revert.cleanup，
    // 丢弃回滚点之后的消息并清除本地截断，否则新消息会被 revertMessageID 隐藏。
    var didRevertTrim = false;
    if (state.revertMessageID.value.isNotEmpty) {
      final revertIdx = state.messages.indexWhere(
        (m) => m.id == state.revertMessageID.value,
      );
      if (revertIdx != -1) {
        state.messages.removeRange(revertIdx, state.messages.length);
        didRevertTrim = true;
      }
      state.revertMessageID.value = '';
    }

    state.showStartExecutionButton.value = false;

    // 如果发送新消息时，先前的 TODO 已全部完成，则清空旧 TODO，隐去 TodoPanel，等待后续新 TODO 触发
    if (state.todos.isNotEmpty &&
        state.todos.every((t) => t['status']?.toString() == 'completed')) {
      state.todos.clear();
    }

    if (state.isGenerating.value && state.isRetrying.value && !force) {
      await abortGeneration(sessionId: sessionId);
      state.clearPendingPrompt();
      state.isRetrying.value = false;
      state.isCompacting.value = false;
      state.isGenerating.value = false;
      state.generatingAgent.value = '';
      state.lastError.value = null;
    }

    if (state.isGenerating.value && !force) {
      _queuePendingPrompt(
        state,
        text,
        images,
        filesToSend,
        overrideAgent: overrideAgent,
        overrideModel: overrideModel,
      );
      if (overrideFiles == null) {
        state.attachedFiles.clear();
        state.attachedImages.clear();
      }
      return true;
    }

    if (text.trim().isEmpty && images.isEmpty && filesToSend.isEmpty) {
      return true;
    }

    final selectedModelKey = overrideModel ?? state.selectedModel.value;
    final selectedAgentName = overrideAgent ?? state.selectedAgent.value;

    _localSendInFlight.add(sessionId);
    state.isGenerating.value = true;
    _markFeedbackGenerating(sessionId);
    state.generatingAgent.value = selectedAgentName;
    state.sessionStatus.value = 'running';
    state.wasAborted.value = false;
    state.isCompacting.value = false;
    state.isRetrying.value = false;
    state.keywordDetectionAlert.value = false;
    state.lastError.value = null;

    if (overrideFiles == null) {
      state.attachedFiles.clear();
      state.attachedImages.clear();
    }

    final messageId = _ascendingId('msg');
    final partsJson = <Map<String, dynamic>>[];
    final partModels = <Part>[];

    if (text.trim().isNotEmpty) {
      final partId = _ascendingId('prt');
      final textRaw = {'id': partId, 'type': 'text', 'text': text};
      partsJson.add(textRaw);
      partModels.add(
        Part(
          id: partId,
          sessionID: sessionId,
          messageID: messageId,
          type: PartType.text,
          raw: textRaw,
        ),
      );
    }

    // Image parts — downscale/compress first (keeps the server-stored history
    // payload small), cache the bytes locally for fast re-render, then send as
    // a base64 data URL so a remote server never has to read a client-local
    // file path (server handles `data:` at prompt.ts). The real MIME is
    // declared so the model receives the correct mediaType; the backend
    // image.normalize will still downscale/re-encode if needed.
    // 压缩与 base64 编码一起放进后台隔离区：数 MB 的编码在主 isolate 会卡 UI。
    var sendImages = images;
    var encoded = const <String>[];
    if (images.isNotEmpty) {
      try {
        final results = await Isolate.run(
          () => compressAndEncodeImagesSync(images),
        );
        sendImages = [for (final r in results) r.image];
        encoded = [for (final r in results) r.base64];
      } catch (e) {
        AppLogger.e('compress images failed: $e');
        // 隔离区失败兜底：主 isolate 用原图原样编码。
        sendImages = images;
        encoded = [for (final img in images) base64Encode(img.bytes)];
      }
      for (final b64 in encoded) {
        // 服务端 image.max_base64_bytes 默认 5MB（image/image.ts），超限整条
        // 消息会被服务端拒绝；此处仅告警留痕，实际阈值以服务端配置为准。
        if (b64.length > _serverImageBase64Limit) {
          AppLogger.w(
            'image attachment base64 size ${b64.length} exceeds server '
            'default limit (5MB), message may be rejected',
          );
        }
      }
    }

    for (var i = 0; i < sendImages.length; i++) {
      final img = sendImages[i];
      final partId = _ascendingId('prt');
      unawaited(defaultImageCache.write(messageId, partId, img.bytes));
      final imgRaw = {
        'id': partId,
        'type': 'file',
        'url': 'data:${img.mime};base64,${encoded[i]}',
        'mime': img.mime,
        'filename': 'image_${i + 1}.${img.ext}',
      };
      partsJson.add(imgRaw);
      partModels.add(
        Part(
          id: partId,
          sessionID: sessionId,
          messageID: messageId,
          type: PartType.file,
          raw: imgRaw,
        ),
      );
    }

    // File attachments — absolute file:// URL with optional line range.
    for (final fileRef in filesToSend) {
      final partId = _ascendingId('prt');
      final refParts = fileRef.split(' #');
      final filePath = refParts[0];
      final filename = filePath.split('/').last.split('\\').last;

      var lineRange = '';
      if (refParts.length > 1) {
        lineRange = refParts[1];
      }

      final absolutePath = _toAbsolutePath(filePath);
      var queryParams = '';
      if (lineRange.isNotEmpty) {
        final rangeStr = lineRange.startsWith('L')
            ? lineRange.substring(1)
            : lineRange;
        final rangeParts = rangeStr.split('-');
        final startLine = int.tryParse(rangeParts[0]);
        if (startLine != null) {
          final endLine = rangeParts.length > 1
              ? int.tryParse(rangeParts[1])
              : startLine;
          queryParams = '?start=$startLine&end=$endLine';
        }
      }

      final filePartRaw = {
        'id': partId,
        'type': 'file',
        'url': '${Uri.file(absolutePath)}$queryParams',
        'mime': 'text/plain',
        'filename': filename,
        if (lineRange.isNotEmpty) 'lineRange': lineRange,
      };
      partsJson.add(filePartRaw);
      partModels.add(
        Part(
          id: partId,
          sessionID: sessionId,
          messageID: messageId,
          type: PartType.file,
          raw: filePartRaw,
        ),
      );
    }

    final optimisticMessage = MessageModel(
      id: messageId,
      sessionID: sessionId,
      role: MessageRole.user,
      parts: partModels,
      raw: {
        'id': messageId,
        'sessionID': sessionId,
        'role': 'user',
        'parts': partsJson,
      },
    );
    state.messages.add(optimisticMessage);

    // v1 prompt_async body (desktop parity):
    // { messageID?, parts, model?: {providerID, modelID}, agent?, variant? }
    final body = <String, dynamic>{'messageID': messageId, 'parts': partsJson};

    if (selectedModelKey.isNotEmpty) {
      final info =
          _findModel(selectedModelKey) ??
          _allModels.firstWhereOrNull(
            (m) => m.key == selectedModelKey || m.id == selectedModelKey,
          );
      if (info != null) {
        body['model'] = {'providerID': info.providerId, 'modelID': info.id};
      }
    }
    if (selectedAgentName.isNotEmpty) {
      body['agent'] = selectedAgentName;
    }
    final variant = state.selectedThinkingLevel.value;
    if (variant.isNotEmpty) {
      body['variant'] = variant;
    }

    try {
      await _client.post(
        ApiEndpoints.sessionPromptAsync(sessionId),
        data: body,
      );
      _localSendInFlight.remove(sessionId);
      return true;
    } catch (e) {
      _localSendInFlight.remove(sessionId);
      AppLogger.e('sendPrompt failed: $e');
      state.isGenerating.value = false;
      state.isRetrying.value = false;
      state.generatingAgent.value = '';
      state.sessionStatus.value = 'error';
      state.messages.removeWhere((m) => m.id == messageId);
      final errMsg = ErrorFormatter.format(e);
      state.lastError.value = errMsg.isNotEmpty ? errMsg : e.toString();
      if (force) {
        if (state.pendingPromptText.value.isEmpty) {
          state.pendingPromptText.value = text;
        } else {
          state.pendingPromptText.value =
              '$text\n${state.pendingPromptText.value}';
        }
        state.pendingPromptImages.addAll(images);
        for (final f in filesToSend) {
          if (!state.pendingPromptAttachedFiles.contains(f)) {
            state.pendingPromptAttachedFiles.add(f);
          }
        }
      }
      if (didRevertTrim) {
        // 本地截断已发生但服务端 prompt 失败：服务端的 revert 状态与被截断的
        // 消息仍在，强刷历史恢复一致，避免本地与服务端 diverge 到下次 reload。
        unawaited(loadMessages(sessionId, force: true));
      }
      return false;
    }
  }

  /// Resolve workspace-relative paths against active project worktree.
  String _toAbsolutePath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final isAbsolute =
        normalized.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:/').hasMatch(normalized);
    if (isAbsolute) {
      return File(path).absolute.path;
    }
    String worktree = '';
    try {
      worktree =
          Get.find<ProjectController>().activeProject.value?.worktree ?? '';
    } catch (_) {}
    if (worktree.isEmpty) {
      worktree = _client.activeDirectory ?? '';
    }
    if (worktree.isEmpty) return File(path).absolute.path;
    final joined = worktree.endsWith('/') || worktree.endsWith('\\')
        ? '$worktree$path'
        : '$worktree${Platform.pathSeparator}$path';
    return File(joined).absolute.path;
  }

  Future<void> abortGeneration({String? sessionId}) async {
    final id = sessionId ?? activeSessionId.value;
    if (id.isEmpty) return;
    final state = getOrCreateSessionState(id);
    state.wasAborted.value = true;
    // 中止即回合终止：先把流式通道累计文本落回列表（保留已生成的部分内容），
    // 再丢弃未冲刷的 pending delta。
    _finalizeStreamingText(state);
    state.suppressAbortErrorUntilMs =
        DateTime.now().millisecondsSinceEpoch + 10000;
    state.isGenerating.value = false;
    state.isRetrying.value = false;
    state.generatingAgent.value = '';
    state.lastError.value = null;
    state.sessionStatus.value = 'idle';
    // 中止即收尾：保存已生成的部分内容（finalize 已在上方落回列表）。
    _persistSessionCacheSnapshot(id, state);

    final abortedIds = <String>{
      id,
      ...state.childSessions.map((child) => child.id),
    };
    _discardPendingPartDeltas(sessionIds: abortedIds);

    // Cascade abort suppression and termination to active child sessions
    for (final child in state.childSessions) {
      final childState = sessionRuntimeStates[child.id];
      if (childState != null) {
        childState.wasAborted.value = true;
        _finalizeStreamingText(childState);
        childState.suppressAbortErrorUntilMs =
            DateTime.now().millisecondsSinceEpoch + 10000;
        childState.isGenerating.value = false;
        childState.isRetrying.value = false;
        childState.generatingAgent.value = '';
        childState.lastError.value = null;
        childState.sessionStatus.value = 'idle';
        unawaited(
          Future(() async {
            try {
              await _client.post(ApiEndpoints.sessionAbort(child.id));
              _markRunningToolPartsAborted(childState);
            } catch (e) {
              // 吞掉异常但留痕：否则 UI 已显示停止而子会话实际仍在运行时无迹可查。
              AppLogger.e('child abort failed (${child.id}): $e');
            }
          }),
        );
      }
    }

    try {
      await _client.post(ApiEndpoints.sessionAbort(id));
      // Belt-and-suspenders: the backend normally finalizes in-flight tool
      // parts via `message.part.updated` (interrupted => error), but that event
      // can be lost to an SSE reconnect race. Finalize them locally so the card
      // spinner always stops. Scoped strictly to the aborted session only.
      _markRunningToolPartsAborted(state);
    } catch (e) {
      AppLogger.e('abortGeneration failed: $e');
      // 回滚本地假 idle：POST 失败多半意味着服务端仍在运行。不回滚会让
      // wasAborted 在 _onSessionStatus 早退吞掉后续所有 running 状态事件，
      // UI 显示已停止且 stop 按钮消失、无法再次停止。保留抑制窗：若服务端
      // 其实已中止，随后的 idle / abort error 事件会把状态再次纠正。
      state.wasAborted.value = false;
      state.isGenerating.value = true;
      state.sessionStatus.value = 'running';
    }
  }

  /// Locally marks still-running/pending tool parts in [state] as aborted.
  ///
  /// Only the **last assistant message** is scanned: the in-flight tool parts
  /// of an active turn always live on the current assistant message, and
  /// scanning history risks mis-marking stale parts. Callers choose the scope
  /// (the aborted session itself or its related child sessions). No other
  /// session is ever touched. The backend's own later `message.part.updated`
  /// event (same terminal shape) simply replaces the local mark.
  void _markRunningToolPartsAborted(SessionRuntimeState state) {
    if (state.messages.isEmpty) return;
    final idx = state.messages.lastIndexWhere(
      (m) => m.role == MessageRole.assistant,
    );
    if (idx == -1) return;
    final msg = state.messages[idx];
    final isZh = Get.locale?.languageCode.startsWith('zh') ?? true;
    final abortText = isZh
        ? '消息已被用户或系统中断。'
        : 'Message was aborted by user or system.';
    final now = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    final newParts = <Part>[];
    for (final part in msg.parts) {
      if (part.type == PartType.tool &&
          (part.toolStatus == ToolStateStatus.running ||
              part.toolStatus == ToolStateStatus.pending)) {
        final raw = Map<String, dynamic>.from(part.raw);
        final toolState = Map<String, dynamic>.from(
          (part.raw['state'] as Map?) ?? const {},
        );
        final metadata = toolState['metadata'] is Map
            ? Map<String, dynamic>.from(toolState['metadata'] as Map)
            : <String, dynamic>{};
        final start = toolState['time'] is Map
            ? (toolState['time'] as Map)['start']
            : null;
        metadata['interrupted'] = true;
        toolState
          ..['status'] = 'error'
          ..['error'] = abortText
          ..['metadata'] = metadata
          ..['time'] = <String, dynamic>{'start': start, 'end': now};
        raw['state'] = toolState;
        newParts.add(
          Part(
            id: part.id,
            sessionID: part.sessionID,
            messageID: part.messageID,
            type: part.type,
            raw: raw,
          ),
        );
        changed = true;
      } else {
        newParts.add(part);
      }
    }
    if (changed) {
      state.messages[idx] = messageWithSyncedParts(msg, newParts);
      state.partsVersion++;
      // 运行中的 tool part（可能是挂起 question）被标记 error：布尔为 true
      // 时重扫兜底。
      if (state.hasPendingQuestion.value) state.rescanHasPendingQuestion();
    }
  }

  Future<bool> compactActiveSession() async {
    final sessionId = activeSessionId.value;
    if (sessionId.isEmpty) {
      Snack.warning(
        LocaleKeys.chatSelectSessionFirst.tr,
        title: LocaleKeys.chatContextCompaction.tr,
      );
      return false;
    }
    final state = getOrCreateSessionState(sessionId);
    if (state.isGenerating.value) {
      Snack.warning(
        LocaleKeys.chatWaitGenerationToCompact.tr,
        title: LocaleKeys.chatContextCompaction.tr,
      );
      return false;
    }

    final info = _findModel(state.selectedModel.value);
    if (info == null) {
      Snack.warning(
        LocaleKeys.chatSelectSessionFirst.tr,
        title: LocaleKeys.chatContextCompaction.tr,
      );
      return false;
    }

    state.isCompacting.value = true;
    state.manualCompactionPending = true;
    state.lastError.value = null;

    try {
      await _client.post(
        ApiEndpoints.sessionSummarize(sessionId),
        data: <String, dynamic>{
          'providerID': info.providerId,
          'modelID': info.id,
        },
      );
      return true;
    } catch (e) {
      state.isCompacting.value = false;
      state.manualCompactionPending = false;
      AppLogger.e('compactActiveSession failed: $e');
      Snack.error(LocaleKeys.chatCompactionFailed.tr);
      return false;
    }
  }

  // ── Model / Agent Selection ──

  void updateAvailableModels() {
    if (_allModels.isEmpty) {
      availableModels.clear();
      return;
    }
    if (!Get.isRegistered<SettingsController>()) {
      availableModels.assignAll(_allModels);
      _syncThinkingLevelsForSelection();
      return;
    }
    final settings = Get.find<SettingsController>();
    final visible = _allModels
        .where((m) => settings.isModelVisible(m, _allModels))
        .toList();
    // Visibility filter can hide everything (e.g. all release dates > 6 months).
    // Fall back so the prompt bar always has a model picker.
    availableModels.assignAll(visible.isNotEmpty ? visible : _allModels);
    _syncThinkingLevelsForSelection();
  }

  void _syncThinkingLevelsForSelection({SessionRuntimeState? state}) {
    final target = state ?? activeState;
    var key = target.selectedModel.value;
    if (key.isEmpty && availableModels.isNotEmpty) {
      key = availableModels.first.key;
      target.selectedModel.value = key;
    }
    if (key.isEmpty) {
      target.thinkingLevels.clear();
      target.selectedThinkingLevel.value = '';
      return;
    }
    // Prefer visible list; fall back to full catalog for variants.
    final model =
        _findModel(key) ??
        _allModels.firstWhereOrNull((m) => m.key == key || m.id == key);
    final levels = model?.variants ?? const <String>[];
    target.thinkingLevels.assignAll(levels);
    if (target.selectedThinkingLevel.value.isNotEmpty &&
        !levels.contains(target.selectedThinkingLevel.value)) {
      target.selectedThinkingLevel.value = '';
    }
  }

  ModelInfo? _findModel(String key) {
    return availableModels.firstWhereOrNull((m) => m.key == key || m.id == key);
  }

  /// 公开的模型解析入口，供 UI（输入框识图判断）按 key/id 查找模型。
  /// 优先查可见模型列表，其次回退全量目录。
  ModelInfo? resolveModel(String key) {
    if (key.isEmpty) return null;
    return _findModel(key) ??
        _allModels.firstWhereOrNull((m) => m.key == key || m.id == key);
  }

  void selectModel(String modelKey) {
    final state = activeState;
    state.selectedModel.value = modelKey;
    _syncThinkingLevelsForSelection(state: state);
    state.selectedThinkingLevel.value = '';
  }

  void selectThinkingLevel(String level) {
    final state = activeState;
    state.selectedThinkingLevel.value = level;
  }

  void selectAgent(String agentName) {
    // v1 has no dedicated session agent switch endpoint; agent is sent
    // with the next prompt_async body.
    activeState.selectedAgent.value = agentName;
  }

  // ── Context Token Calculation ──

  /// Extract active context token total from a message raw structure,
  /// accounting for input, output, reasoning, and prompt cache (read & write).
  int _extractContextTokens(MessageModel msg) {
    final raw = msg.raw;
    final info = raw['info'];
    final dynamic tokensMap =
        (info is Map ? info['tokens'] : null) ??
        raw['tokens'] ??
        msg.model?['usage'] ??
        msg.model?['tokens'];

    int asInt(dynamic v) => v is num ? v.toInt() : 0;

    if (tokensMap is Map) {
      final cache = tokensMap['cache'];
      final cacheRead = cache is Map ? asInt(cache['read']) : 0;
      final cacheWrite = cache is Map ? asInt(cache['write']) : 0;
      final sum =
          asInt(tokensMap['input']) +
          asInt(tokensMap['output']) +
          asInt(tokensMap['reasoning']) +
          cacheRead +
          cacheWrite;
      if (sum > 0) return sum;
    }

    // Check stepFinish parts fallback
    for (final part in msg.parts.reversed) {
      final ft = part.finishTokens;
      if (ft != null) {
        final cache = ft['cache'];
        final cacheRead = cache is Map ? asInt(cache['read']) : 0;
        final cacheWrite = cache is Map ? asInt(cache['write']) : 0;
        final sum =
            asInt(ft['input']) +
            asInt(ft['output']) +
            asInt(ft['reasoning']) +
            cacheRead +
            cacheWrite;
        if (sum > 0) return sum;
      }
    }
    return 0;
  }

  /// Active context token usage obtained from the latest assistant session message.
  int activeSessionMessageTokens(String sessionId) {
    final state = stateOf(sessionId);
    for (final msg in state.messages.reversed) {
      if (msg.role != MessageRole.assistant) continue;
      final tokens = _extractContextTokens(msg);
      if (tokens > 0) return tokens;
    }
    return 0;
  }

  /// Get the maximum context limit (in tokens) for the selected model.
  int modelContextLimitFor(String sessionId) {
    final modelKey = stateOf(sessionId).selectedModel.value;
    if (modelKey.isEmpty) return 0;
    final info =
        _findModel(modelKey) ??
        _allModels.firstWhereOrNull(
          (m) => m.key == modelKey || m.id == modelKey,
        );
    return info?.contextLimit ?? 0;
  }

  /// Helper to format large token numbers (e.g. 1.2k, 128k, 1M).
  String formatTokenCount(int count) {
    if (count >= 1000000) {
      final v = count / 1000000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
    } else if (count >= 1000) {
      final v = count / 1000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}k';
    }
    return '$count';
  }

  // ── Permission ──

  /// 拉取服务端仍在等待回复的权限请求并回填本地卡片状态。
  ///
  /// `permission.asked` 只在请求产生时发布一次（服务端 pending 挂起期间不重发），
  /// 冷启动或 SSE 断线窗口内到达的请求若不主动拉取将永远不可见 —— agent 会
  /// 一直挂起在等待回复上。服务端 `GET /permission` 返回的 item 结构与 asked
  /// payload 一致，可直接交给 [PendingPermission.fromEvent]。带代际守卫，
  /// 切项目后丢弃旧目录的响应。
  Future<void> _restorePendingPermissions() async {
    final seq = _sessionFetchSeq;
    try {
      final response = await _client.get(ApiEndpoints.permissions);
      if (seq != _sessionFetchSeq) return;
      if (response.statusCode != 200) return;
      final data = response.data;
      final List rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map && data['data'] is List) {
        rawList = data['data'] as List;
      } else {
        rawList = [];
      }
      for (final item in rawList) {
        if (item is! Map) continue;
        final pending = PendingPermission.fromEvent(
          Map<String, dynamic>.from(item),
        );
        if (pending.id.isEmpty || pending.sessionID.isEmpty) continue;
        // 未打开页签的会话（如后台子会话）也可能持有请求：按需建最小状态，
        // 让 sessionIdWithPendingPermission 能把卡片上浮到根会话输入区。
        // pending 数量有界（服务端 pending Map），不会造成状态膨胀。
        final state = getOrCreateSessionState(pending.sessionID);
        if (state.pendingPermission.value?.id != pending.id) {
          state.pendingPermission.value = pending;
        }
      }
    } catch (e) {
      AppLogger.w('restore pending permissions failed: $e');
    }
  }

  Future<void> respondPermission(
    String id,
    String action, {
    String? sessionId,
  }) async {
    final sid = sessionId ?? activeSessionId.value;
    if (sid.isEmpty) return;
    try {
      final reply = switch (action) {
        'allow' => 'once',
        'deny' => 'reject',
        _ => action,
      };
      await _client.post(
        ApiEndpoints.permissionReply(id),
        data: {'reply': reply},
      );
      // 仅清已存在的状态：在途回复期间状态可能已被释放（页签关闭/切项目），
      // getOrCreateSessionState 会把它以空壳形式复活（违背代际丢弃设计）。
      sessionRuntimeStates[sid]?.pendingPermission.value = null;
    } catch (e) {
      AppLogger.e('respondPermission failed: $e');
    }
  }

  // ── Questions ──

  /// Reply via v1 flat question API. [answers] is list-of-lists of selected labels.
  Future<void> respondQuestion(
    String requestId,
    dynamic reply, {
    String? sessionId,
  }) async {
    final sid = sessionId ?? activeSessionId.value;
    if (sid.isEmpty || requestId.isEmpty) return;
    final Map<String, dynamic> body;
    if (reply is Map<String, dynamic>) {
      body = reply;
    } else if (reply is List) {
      body = {
        'answers': reply
            .map(
              (e) => e is List
                  ? e.map((x) => x.toString()).toList()
                  : [e.toString()],
            )
            .toList(),
      };
    } else {
      body = {
        'answers': [
          [reply.toString()],
        ],
      };
    }
    try {
      final response = await _client.post(
        ApiEndpoints.questionReply(requestId),
        data: body,
      );
      final code = response.statusCode ?? 0;
      if (code == 200 || code == 201 || code == 204) {
        noteQuestionResolved(
          requestId,
          sessionId: sid,
          rejected: false,
          answers: body['answers'],
        );
      }
    } catch (e) {
      AppLogger.e('respondQuestion failed: $e');
    }
  }

  Future<void> rejectQuestion(String requestId, {String? sessionId}) async {
    final sid = sessionId ?? activeSessionId.value;
    if (sid.isEmpty || requestId.isEmpty) return;
    try {
      final response = await _client.post(
        ApiEndpoints.questionReject(requestId),
      );
      final code = response.statusCode ?? 0;
      if (code == 200 || code == 201 || code == 204) {
        noteQuestionResolved(requestId, sessionId: sid, rejected: true);
      }
    } catch (e) {
      AppLogger.e('rejectQuestion failed: $e');
    }
  }

  /// Optimistic / post-HTTP local sync after QuestionCard replies via v1 API.
  void noteQuestionResolved(
    String requestId, {
    required String sessionId,
    required bool rejected,
    dynamic answers,
  }) {
    if (requestId.isEmpty || sessionId.isEmpty) return;
    _applyQuestionResolved(
      sessionId: sessionId,
      requestId: requestId,
      rejected: rejected,
      answers: answers,
    );
  }

  // ── SSE ──

  String? _resolveSseDirectory() {
    try {
      return _client.activeDirectory ??
          (Get.isRegistered<ProjectController>()
              ? Get.find<ProjectController>().activeProject.value?.worktree
              : null);
    } catch (e) {
      AppLogger.e('SSE directory resolve failed: $e');
      return null;
    }
  }

  /// 是否已有一个指向相同服务器+目录、且连接中/已连接、非凭据失效的 SSE 客户端。
  /// `initializeAfterConnect` 与 `_connectSse` 共用此判定：目标相同且 SSE 健康时，
  /// 模型/会话数据正由实时事件保持同步，重复拉取与重复连接都无意义。
  bool _hasLiveSseFor({required String serverUrl, required String? directory}) {
    final sse = _sseClient;
    return sse != null &&
        !sse.isCredentialFailed &&
        (sse.isConnected || sse.isConnecting) &&
        _sseServerUrl == serverUrl &&
        sse.queryParams['directory'] == directory;
  }

  /// 主动断开当前 SSE 连接并丢弃客户端（连接页取消/停止连接时配合
  /// SidecarManager.stop() 使用）。不重建，需要时由 _connectSse 重新建立。
  void disconnectSse() {
    _sseSub?.cancel();
    _sseSub = null;
    _sseClient?.dispose();
    _sseClient = null;
    _sseServerUrl = '';
    _sseHasConnected = false;
  }

  void _connectSse() {
    final dir = _resolveSseDirectory();
    final serverUrl = SidecarManager.instance.baseUrl;
    // 幂等守卫：已有一个指向相同服务器与目录、且正在连接/已连接的客户端时直接复用，
    // 避免启动阶段 onProjectChanged 与 initializeAfterConnect 各建一条 SSE 连接
    // （日志里 "SSE connecting" 重复出现，并多一次被立即销毁的 HTTP 请求）。
    if (_hasLiveSseFor(serverUrl: serverUrl, directory: dir)) {
      AppLogger.d('SSE already connecting to same target, reusing client');
      return;
    }
    _sseSub?.cancel();
    _sseClient?.dispose();
    _sseHasConnected = false;
    AppLogger.i('SSE connecting to ${ApiEndpoints.sseEvent}');
    _sseServerUrl = serverUrl;
    _sseClient = SseClient(_client, ApiEndpoints.sseEvent);
    if (dir != null && dir.isNotEmpty) {
      _sseClient!.queryParams['directory'] = dir;
    }
    _sseClient!.onStatusChange = (connected) {
      if (connected) {
        AppLogger.i('SSE connected');
        // Server never replays missed events on (re)connect, so a reconnect
        // after a drop can leave local sessions stale/truncated. Refresh them.
        if (_sseHasConnected) {
          _refreshAfterReconnect();
        }
        _sseHasConnected = true;
      } else {
        AppLogger.w('SSE disconnected, reconnecting…');
        // Soft toast — avoid spam by only showing when user has a project.
        if (Get.isRegistered<ProjectController>() &&
            Get.find<ProjectController>().activeProject.value != null) {
          Snack.warning(
            LocaleKeys.mobileSseReconnecting.tr,
            title: 'Connection',
            duration: const Duration(seconds: 2),
          );
        }
      }
    };
    _sseClient!.onError = (e) {
      AppLogger.e('SSE error: $e');
      // 凭据失效时 SseClient 已停止重连，这里给用户可操作的提示。
      if (_sseClient?.isCredentialFailed ?? false) {
        Snack.error(LocaleKeys.mobileSseAuthFailed.tr);
      }
    };
    _sseSub = _sseClient!.stream.listen(
      _handleEvent,
      onError: (e) {
        AppLogger.e('SSE stream error: $e');
      },
    );
    _sseClient!.connect();
  }

  /// Refresh local state after an SSE reconnect. Only the ACTIVE session is
  /// force-reloaded (it is on screen); other opened tabs are marked stale
  /// ([SessionRuntimeState.needsReloadAfterReconnect]) and re-fetched lazily
  /// when the user switches to them, so one drop no longer triggers a burst of
  /// N full-history requests. The session list refresh and pending-permission
  /// restore stay eager (correctness compensation, cheap).
  void _refreshAfterReconnect() {
    AppLogger.i('SSE reconnected — refreshing opened sessions');
    unawaited(fetchSessions(restoreOpened: false));
    // 断线窗口内服务端产生的权限请求不会重发 asked，主动补拉挂起列表。
    unawaited(_restorePendingPermissions());
    final activeId = activeSessionId.value;
    for (final id in openedSessionIds.toList()) {
      if (id == activeId) {
        unawaited(loadMessages(id, force: true, reconcileGenerating: true));
        continue;
      }
      final st = sessionRuntimeStates[id];
      if (st != null) {
        // 先按本地已有消息纠正卡住的生成态（离线窗口内错过的 idle），
        // 再标脏：切到该页签时 loadMessages 拉全量并再次纠正。
        _reconcileGeneratingAfterReconnect(st);
        st.needsReloadAfterReconnect = true;
      }
    }
    // 文件侧补偿：断线窗口内的 file.edited / file.watcher.updated 不会补发，
    // 无法枚举哪些文件变了，只能整体失效缓存并广播重载，让文件树与已打开
    // 的编辑器重新拉取（失效本身廉价，重载按需发生）。
    if (Get.isRegistered<ProjectController>()) {
      Get.find<ProjectController>().invalidateDirectoryCache();
    }
    if (Get.isRegistered<TabletToolController>()) {
      Get.find<TabletToolController>().invalidateAllFileContent();
      Get.find<TabletToolController>().fileReconnectTick.value++;
    }
  }

  /// 断网重连后纠正"卡住"的生成态：离线窗口内服务端已跑完但 idle 事件丢失，
  /// 导致 [SessionRuntimeState.isGenerating] 残留 true（输入框一直显示"停止"）。
  ///
  /// 只在 `isGenerating` 已为 true 时动作，且仅在证据充分（回合已收尾）时清理，
  /// 绝不从 false 反置 true —— 避免误判"此前手动中止的会话仍在生成"。
  /// 不置 `sessionStatus='idle'`：保留 delta 冲刷的 turnEnded 守卫（见
  /// `_flushPendingPartDeltas`），万一回合仍在进行，后续事件仍可重新拉起。
  void _reconcileGeneratingAfterReconnect(SessionRuntimeState state) {
    if (!state.isGenerating.value) return;
    if (turnAppearsFinished(
      messages: state.messages,
      wasAborted: state.wasAborted.value,
    )) {
      // 判定回合已收尾：落回流式通道累计文本后再复位生成态。
      _finalizeStreamingText(state);
      state.isGenerating.value = false;
      state.generatingAgent.value = '';
    }
  }

  /// 依据拉取到的历史判定某会话的回合是否已收尾（供断网重连兜底与单测复用）。
  /// 规则：手动中止过 → 视为已结束；否则看最后一条 assistant 消息 ——
  /// 以 `stepFinish` 收尾且无运行/挂起中的 tool，即为回合完成。
  @visibleForTesting
  static bool turnAppearsFinished({
    required List<MessageModel> messages,
    required bool wasAborted,
  }) {
    if (wasAborted) return true;
    final idx = messages.lastIndexWhere((m) => m.role == MessageRole.assistant);
    if (idx == -1) return false;
    final last = messages[idx];
    final hasStepFinish = last.parts.any((p) => p.type == PartType.stepFinish);
    final hasActiveTool = last.parts.any(
      (p) =>
          p.type == PartType.tool &&
          (p.toolStatus == ToolStateStatus.running ||
              p.toolStatus == ToolStateStatus.pending),
    );
    return hasStepFinish && !hasActiveTool;
  }

  /// 处理隐藏临时会话（如图片转文字）的 SSE 事件：不触碰任何 UI 状态。
  /// idle 时用一次权威的 GET 拉取最终文本并完成完成器；error 直接失败。
  void _handleHiddenEvent(String sessionId, SseEvent event) {
    final completer = _hiddenVisionCompleters[sessionId];
    if (completer == null || completer.isCompleted) return;

    switch (event.type) {
      case EventTypes.sessionIdle:
        unawaited(_resolveHiddenVisionText(sessionId));
      case EventTypes.sessionError:
        _finishHiddenVision(sessionId, null);
    }
  }

  /// idle 事件后拉取临时会话的最终 assistant 文本（可能恰好落后于持久化，
  /// 故短暂重试几次），然后完成完成器。
  Future<void> _resolveHiddenVisionText(String sessionId) async {
    String? text;
    for (var i = 0; i < 3; i++) {
      text = await _fetchVisionReplyText(sessionId);
      if (text != null && text.isNotEmpty) break;
      await Future<void>.delayed(_visionPollInterval);
    }
    _finishHiddenVision(sessionId, text);
  }

  /// 单次 GET 临时会话消息，取最后一个非空 assistant 文本及其完成标志。
  Future<(String?, bool)> _fetchVisionReply(String tempId) async {
    try {
      final resp = await _client.get(ApiEndpoints.sessionMessages(tempId));
      final List rawMessages;
      if (resp.statusCode == 200) {
        final data = resp.data;
        if (data is List) {
          rawMessages = data;
        } else if (data is Map && data['data'] is List) {
          rawMessages = data['data'] as List;
        } else {
          rawMessages = [];
        }
        final msgs = rawMessages
            .whereType<Map>()
            .map((m) => MessageModel.fromJson(Map<String, dynamic>.from(m)))
            .where((m) => m.isChatMessage)
            .toList();
        for (final m in msgs.reversed) {
          if (m.role != MessageRole.assistant) continue;
          final text = m.content;
          if (text.trim().isEmpty) continue;
          // v2 形状消息体在 info 子对象内；time.completed 存在 = 流式已结束。
          final info = m.raw['info'] is Map ? m.raw['info'] as Map : m.raw;
          final time = info['time'];
          final completed = time is Map && time['completed'] != null;
          return (text.trim(), completed);
        }
      }
    } catch (e) {
      AppLogger.e('_fetchVisionReplyText error: $e');
    }
    return (null, false);
  }

  Future<String?> _fetchVisionReplyText(String tempId) async {
    return (await _fetchVisionReply(tempId)).$1;
  }

  void _finishHiddenVision(String sessionId, String? text) {
    final completer = _hiddenVisionCompleters.remove(sessionId);
    if (completer == null || completer.isCompleted) return;
    final trimmed = text?.trim();
    completer.complete(trimmed != null && trimmed.isNotEmpty ? trimmed : null);
  }

  void _handleEvent(SseEvent event) {
    final sid = event.sessionID;
    if (sid.isNotEmpty && _hiddenSessionIds.contains(sid)) {
      _handleHiddenEvent(sid, event);
      return;
    }
    switch (event.type) {
      case EventTypes.sessionCreated:
        _onSessionCreated(event);
      case EventTypes.sessionUpdated:
        _onSessionUpdated(event);
      case EventTypes.sessionDeleted:
        _onSessionDeleted(event);
      case EventTypes.sessionStatus:
        _onSessionStatus(event);
      case EventTypes.sessionIdle:
        _flushPendingPartDeltas();
        _onSessionIdle(event);
      case EventTypes.sessionError:
        _flushPendingPartDeltas();
        _onSessionError(event);
      case EventTypes.messagePartDelta:
        _onPartDelta(event);
      case EventTypes.messagePartUpdated:
        _flushPendingPartDeltas();
        _onPartUpdated(event);
      case EventTypes.messageUpdated:
        _flushPendingPartDeltas();
        _onMessageUpdated(event);
      case EventTypes.messageRemoved:
        _flushPendingPartDeltas();
        _onMessageRemoved(event);
      case EventTypes.messagePartRemoved:
        _flushPendingPartDeltas();
        _onPartRemoved(event);
      case EventTypes.sessionDiff:
        _onSessionDiff(event);
        break;
      case EventTypes.sessionCompacted:
        _onSessionCompacted(event);
      case EventTypes.sessionNextCompactionStarted:
        _onSessionNextCompactionStarted(event);
      case EventTypes.sessionNextCompactionEnded:
        _onSessionNextCompactionEnded(event);
      case EventTypes.permissionAsked:
        _onPermissionAsked(event);
      case EventTypes.permissionReplied:
        _onPermissionReplied(event);
      case EventTypes.questionAsked:
        _onQuestionAsked(event);
      case EventTypes.questionReplied:
        _onQuestionResolved(event, rejected: false);
      case EventTypes.questionRejected:
        _onQuestionResolved(event, rejected: true);
      case EventTypes.todoUpdated:
        _onTodoUpdated(event);
      case EventTypes.fileEdited:
        _onFileChanged(event);
      case EventTypes.fileWatcherUpdated:
        _onFileChanged(event);
      case EventTypes.sessionMoved:
      case EventTypes.sessionAgentSwitched:
      case EventTypes.sessionModelSwitched:
        break;
    }
  }

  /// Consumes `file.edited` / `file.watcher.updated` SSE events and notifies
  /// the file-tree cache + opened editors so they stay in sync with the agent's
  /// changes. The SSE stream is scoped to the active directory, so any file
  /// event reaching here belongs to the current worktree; listeners debounce
  /// the actual refresh themselves.
  void _onFileChanged(SseEvent event) {
    final raw = event.properties['file']?.toString() ?? '';
    if (raw.isEmpty) return;
    if (Get.isRegistered<TabletToolController>()) {
      final ctrl = Get.find<TabletToolController>();
      ctrl.recordFileChange(raw);
      // 失效对应已打开页签的缓存，避免惰性重建时展示过期内容。SSE 事件作用域
      // 是当前活动目录，故只失效匹配当前 worktree 的页签（同相对路径的其它
      // worktree 页签内容未变，不应被波及）。
      final currentWorktree = _client.activeDirectory;
      for (final f in ctrl.openedFiles.toList()) {
        if (diffPathsEqual(f.path, raw) &&
            (f.worktree == null || f.worktree == currentWorktree)) {
          ctrl.invalidateFileContent(f.path, worktree: f.worktree);
        }
      }
      ctrl.invalidateFileContent(raw, worktree: currentWorktree);
      ctrl.fileChangeTick.value++;
    }
  }

  void _onSessionCreated(SseEvent event) {
    final info = event.info;
    if (info.isNotEmpty) {
      final newSession = SessionModel.fromJson(info);
      if (!_isRootSession(newSession)) {
        unawaited(_registerParentSession(newSession.id, newSession.parentID!));
      }
      if (_isRootSession(newSession)) {
        final index = sessions.indexWhere((s) => s.id == newSession.id);
        if (index != -1) {
          sessions[index] = newSession;
        } else {
          sessions.insert(0, newSession);
        }
        unawaited(_refreshSubtaskOwners());
      } else {
        sessions.removeWhere((s) => s.id == newSession.id);
        final parentState = getOrCreateSessionState(newSession.parentID!);
        final idx = parentState.childSessions.indexWhere(
          (s) => s.id == newSession.id,
        );
        if (idx != -1) {
          parentState.childSessions[idx] = newSession;
        } else {
          parentState.childSessions.add(newSession);
        }
      }
    }
  }

  void _onSessionUpdated(SseEvent event) {
    final info = event.info;
    if (info.isNotEmpty) {
      final updated = SessionModel.fromJson(info);
      if (!_isRootSession(updated)) {
        unawaited(_registerParentSession(updated.id, updated.parentID!));
      }
      if (_isRootSession(updated)) {
        final index = sessions.indexWhere((s) => s.id == updated.id);
        if (index != -1) {
          sessions[index] = updated;
        }
        unawaited(_refreshSubtaskOwners());
      } else {
        sessions.removeWhere((s) => s.id == updated.id);
        final parentState = getOrCreateSessionState(updated.parentID!);
        final idx = parentState.childSessions.indexWhere(
          (s) => s.id == updated.id,
        );
        if (idx != -1) {
          parentState.childSessions[idx] = updated;
        } else {
          parentState.childSessions.add(updated);
        }
      }
    }
  }

  void _onSessionDeleted(SseEvent event) {
    final sid = event.sessionID;
    final parent = _parentSessionIds[sid];
    if (parent != null) {
      sessionRuntimeStates[parent]?.childSessions.removeWhere(
        (s) => s.id == sid,
      );
    }
    sessions.removeWhere((s) => s.id == sid);
    sessionRuntimeStates.remove(sid);
    _feedbackGeneratingSessions.remove(sid);
    openedSessionIds.remove(sid);
    // 他端删除走 SSE 不经过 deleteSession，同步清缓存避免孤儿文件。
    unawaited(SessionCacheStore.instance.delete(sid));
    clearSubtaskTracking(sid);
    _forgetQuestionRequestsForSession(sid);
    // The active session was deleted on the server: re-point to another open
    // session, mirroring the fallback in deleteSession (which the SSE path
    // previously lacked). 没有已打开页签时置空，避免标题/内容错位。
    if (activeSessionId.value == sid) {
      activeSessionId.value = openedSessionIds.isNotEmpty
          ? openedSessionIds.last
          : '';
    }
  }

  void _onSessionStatus(SseEvent event) {
    final sid = event.sessionID;
    if (sid.isEmpty) return;
    final state = getOrCreateSessionState(sid);
    final st = event.statusType;
    final isIdle = st == 'idle' || st.isEmpty;
    final wasRetrying = state.isRetrying.value;
    final retryError = _formatRetryStatusError(event.status);

    if (isIdle && _localSendInFlight.contains(sid)) {
      // 本地发送在途（POST 未返回）：idle 只能是上一回合的迟到事件，放行会
      // 误复位 isGenerating 并把队列提前 flush 成并发第二回合。
      AppLogger.d('skip stale idle status while local send in flight: $sid');
      return;
    }

    if (state.wasAborted.value && !isIdle) {
      return;
    }

    state.isGenerating.value = !isIdle;
    state.sessionStatus.value = st.isNotEmpty
        ? st
        : (isIdle ? 'idle' : 'running');

    if (!isIdle && !state.wasAborted.value) {
      _markFeedbackGenerating(sid);
    }

    if (st == 'retry') {
      state.isRetrying.value = true;
    } else if (wasRetrying) {
      state.isRetrying.value = false;
      state.lastError.value = null;
    }

    if (retryError != null) state.lastError.value = retryError;

    if (isIdle) {
      state.generatingAgent.value = '';
      state.isCompacting.value = false;
      state.manualCompactionPending = false;
      state.isRetrying.value = false;
      // Do NOT clear wasAborted here: the abort flag must survive the trailing
      // status/idle events so _onSessionIdle can still detect a manual abort
      // and suppress the "start execution" button + completion feedback. It is
      // only reset in sendPrompt when the next turn starts.
    }
  }

  void _onSessionIdle(SseEvent event) {
    final sid = event.sessionID.isNotEmpty
        ? event.sessionID
        : activeSessionId.value;
    if (sid.isEmpty) return;
    if (_localSendInFlight.contains(sid)) {
      // 本地发送在途：idle 只能是上一回合的迟到事件，跳过以免误复位生成态、
      // 并把队列提前 flush 成与在途 POST 并发的第二回合。
      AppLogger.d('skip stale session.idle while local send in flight: $sid');
      return;
    }
    final state = getOrCreateSessionState(sid);
    final wasRetrying = state.isRetrying.value;
    // 先把流式通道的累计文本落回列表再复位生成态：同一帧内完成，气泡切换
    // 到列表文本渲染时数据已完整（见 _finalizeStreamingText）。
    _finalizeStreamingText(state);
    final wasGenerating =
        _feedbackGeneratingSessions.remove(sid) || state.isGenerating.value;
    final agentBeforeClear = state.generatingAgent.value.isNotEmpty
        ? state.generatingAgent.value
        : state.selectedAgent.value;
    final isManualAborted = state.wasAborted.value;

    state.isGenerating.value = false;
    state.isCompacting.value = false;
    state.manualCompactionPending = false;
    state.isRetrying.value = false;
    state.generatingAgent.value = '';
    state.sessionStatus.value = 'idle';
    if (wasRetrying) state.lastError.value = null;

    if (agentBeforeClear == 'plan' && !isManualAborted) {
      state.showStartExecutionButton.value = true;
    }

    // Completion feedback: only for real generations, skip manual aborts,
    // queued follow-ups and subtask (child) sessions.
    if (wasGenerating &&
        !isManualAborted &&
        !state.hasPendingPrompt &&
        !_parentSessionIds.containsKey(sid)) {
      _notifyFeedback(
        type: FeedbackType.generationCompleted,
        title: LocaleKeys.feedbackCompleted.tr,
        message: LocaleKeys.feedbackCompletedMsg.trParams({
          'session': getSessionName(sid),
        }),
        sessionId: sid,
      );
    }

    _updateKeywordDetectionAlert(sid);
    // 快照取队列 flush 前的收尾状态：_checkAndSendPendingPrompt 可能立刻
    // 开出下一回合（加乐观消息/置生成态），下一回合收尾有自己的 idle 再落盘。
    _persistSessionCacheSnapshot(sid, state);
    _checkAndSendPendingPrompt(sid);
  }

  void _updateKeywordDetectionAlert(String sessionId) {
    if (sessionId.isEmpty) return;
    final state = sessionRuntimeStates[sessionId];
    if (state == null) return;
    final keywords = Global.keywordsRx
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    if (keywords.isEmpty) {
      state.keywordDetectionAlert.value = false;
      return;
    }
    final lastUserIndex = state.messages.lastIndexWhere(
      (m) => m.role == MessageRole.user,
    );
    if (lastUserIndex == -1) {
      state.keywordDetectionAlert.value = false;
      return;
    }
    final hasKeyword = state.messages.skip(lastUserIndex + 1).any((m) {
      if (m.role != MessageRole.assistant) return false;
      return m.parts.any((p) {
        if (p.type != PartType.text) return false;
        return keywords.any(p.text.contains);
      });
    });
    state.keywordDetectionAlert.value = hasKeyword;
  }

  void _onSessionError(SseEvent event) {
    final errorSessionId = event.sessionID;
    final effectiveErrorId = errorSessionId.isNotEmpty
        ? errorSessionId
        : activeSessionId.value;
    if (effectiveErrorId.isNotEmpty &&
        _localSendInFlight.contains(effectiveErrorId)) {
      // 本地发送在途：error 只能是上一回合的迟到事件（或失败 prompt 的回声），
      // 跳过以免误复位生成态、并把队列提前 flush 成并发第二回合。
      AppLogger.d(
        'skip stale session.error while local send in flight: '
        '$effectiveErrorId',
      );
      return;
    }
    final isAbortError = _isAbortError(event.error);
    final isContextOverflowWithAutoCompaction =
        _isContextOverflowError(event.error) && _isAutoCompactionEnabled();
    var suppressedAutoCompactionError = false;

    if (errorSessionId.isNotEmpty) {
      final state = getOrCreateSessionState(errorSessionId);
      _finalizeStreamingText(state);
      final shouldWaitForAutoCompaction =
          isContextOverflowWithAutoCompaction &&
          !state.isCompacting.value &&
          !state.wasAborted.value;
      if (isAbortError && _shouldSuppressAbortError(state)) {
        state.suppressAbortErrorUntilMs = 0;
      } else if (shouldWaitForAutoCompaction) {
        suppressedAutoCompactionError = true;
        state.suppressAbortErrorUntilMs = 0;
        state.isGenerating.value = true;
        _markFeedbackGenerating(errorSessionId);
        state.isCompacting.value = true;
        state.isRetrying.value = false;
        state.lastError.value = null;
      } else {
        state.suppressAbortErrorUntilMs = 0;
        state.isGenerating.value = false;
        state.isCompacting.value = false;
        state.manualCompactionPending = false;
        state.isRetrying.value = false;
        state.generatingAgent.value = '';
        state.sessionStatus.value = 'error';
        state.lastError.value = ErrorFormatter.format(event.error);
        _persistSessionCacheSnapshot(errorSessionId, state);
      }
    } else {
      final activeState = getOrCreateSessionState(activeSessionId.value);
      _finalizeStreamingText(activeState);
      final shouldWaitForAutoCompaction =
          isContextOverflowWithAutoCompaction &&
          !activeState.isCompacting.value &&
          !activeState.wasAborted.value;
      if (isAbortError && _shouldSuppressAbortError(activeState)) {
        activeState.suppressAbortErrorUntilMs = 0;
      } else if (shouldWaitForAutoCompaction) {
        suppressedAutoCompactionError = true;
        activeState.suppressAbortErrorUntilMs = 0;
        activeState.isGenerating.value = true;
        _markFeedbackGenerating(activeSessionId.value);
        activeState.isCompacting.value = true;
        activeState.isRetrying.value = false;
        activeState.lastError.value = null;
      } else {
        activeState.suppressAbortErrorUntilMs = 0;
        activeState.isGenerating.value = false;
        activeState.isCompacting.value = false;
        activeState.manualCompactionPending = false;
        activeState.isRetrying.value = false;
        activeState.generatingAgent.value = '';
        activeState.sessionStatus.value = 'error';
        activeState.lastError.value = ErrorFormatter.format(event.error);
        _persistSessionCacheSnapshot(activeSessionId.value, activeState);
      }
    }

    // Error feedback: skip abort errors (manual abort) and auto-compaction.
    if (!isAbortError && !suppressedAutoCompactionError) {
      _feedbackGeneratingSessions.remove(effectiveErrorId);
      final errState = sessionRuntimeStates[effectiveErrorId];
      if (errState != null && !errState.wasAborted.value) {
        _notifyFeedback(
          type: FeedbackType.generationError,
          title: LocaleKeys.feedbackError.tr,
          message: LocaleKeys.feedbackErrorMsg.trParams({
            'session': getSessionName(effectiveErrorId),
            'error': ErrorFormatter.format(event.error),
          }),
          sessionId: effectiveErrorId,
        );
      }
    }
    if (!suppressedAutoCompactionError) {
      _checkAndSendPendingPrompt(effectiveErrorId);
    }
  }

  bool _isAbortError(Map<String, dynamic> error) {
    final name = error['name']?.toString() ?? '';
    return name == 'MessageAbortedError' || name == 'AbortedError';
  }

  bool _isContextOverflowError(Map<String, dynamic> error) {
    return error['name']?.toString() == 'ContextOverflowError';
  }

  bool _isAutoCompactionEnabled() {
    try {
      final compaction = Get.find<SettingsController>().compaction;
      return compaction?['auto'] as bool? ?? true;
    } catch (e) {
      AppLogger.e('SessionController: read compaction setting failed $e');
      return true;
    }
  }

  bool _shouldSuppressAbortError(SessionRuntimeState state) {
    return state.suppressAbortErrorUntilMs >
        DateTime.now().millisecondsSinceEpoch;
  }

  String? _formatRetryStatusError(Map<String, dynamic> status) {
    if (status['type']?.toString() != 'retry') return null;
    final statusMessage = status['message']?.toString().trim() ?? '';
    final action = status['action'];
    if (action is! Map) {
      if (statusMessage.isNotEmpty) return statusMessage;
      return LocaleKeys.retryLimited.tr;
    }

    final title = action['title']?.toString().trim() ?? '';
    final message = action['message']?.toString().trim() ?? '';
    final reason = action['reason']?.toString().trim() ?? '';

    if (title.isNotEmpty && message.isNotEmpty) {
      return '$title\n$message';
    }
    if (message.isNotEmpty) return message;
    if (title.isNotEmpty) return title;
    if (reason.isNotEmpty) {
      return LocaleKeys.retryLimitedReason.trParams({'reason': reason});
    }
    if (statusMessage.isNotEmpty) return statusMessage;
    return LocaleKeys.retryLimited.tr;
  }

  void _onPartDelta(SseEvent event) {
    final msgId = event.messageID;
    final partId = event.partID;
    final delta = event.delta;
    final field = event.properties['field']?.toString() ?? 'text';
    if (msgId.isEmpty || partId.isEmpty || delta.isEmpty) return;

    final sessionId = event.sessionID.isNotEmpty
        ? event.sessionID
        : (event.part['sessionID']?.toString() ?? '');
    if (sessionId.isEmpty) return;

    final deltaState = sessionRuntimeStates[sessionId];
    if (deltaState != null && deltaState.wasAborted.value) return;

    final key = '$sessionId\u0000$msgId\u0000$partId\u0000$field';
    final pending = _pendingPartDeltas[key];
    if (pending == null) {
      _pendingPartDeltas[key] = _PendingPartDelta(
        sessionId: sessionId,
        messageId: msgId,
        partId: partId,
        field: field,
        delta: delta,
      );
    } else {
      pending.delta += delta;
    }

    _partDeltaFlushTimer ??= Timer(
      _partDeltaFlushInterval,
      _flushPendingPartDeltas,
    );
  }

  void _flushPendingPartDeltas() {
    if (_pendingPartDeltas.isEmpty) {
      _partDeltaFlushTimer?.cancel();
      _partDeltaFlushTimer = null;
      return;
    }

    _partDeltaFlushTimer?.cancel();
    _partDeltaFlushTimer = null;

    final pending = _pendingPartDeltas.values.toList(growable: false);
    _pendingPartDeltas.clear();

    final bySession = <String, List<_PendingPartDelta>>{};
    for (final item in pending) {
      bySession.putIfAbsent(item.sessionId, () => []).add(item);
    }

    for (final entry in bySession.entries) {
      final state = getOrCreateSessionState(entry.key);
      var changed = false;
      for (final item in entry.value) {
        changed = _applyPartDelta(state, item) || changed;
      }
      // A late delta flush must not re-arm isGenerating once the server has
      // told us the turn ended (idle/error), or the UI would stick spinning.
      final turnEnded =
          state.sessionStatus.value == 'idle' ||
          state.sessionStatus.value == 'error';
      if (changed &&
          !state.isGenerating.value &&
          !state.wasAborted.value &&
          !turnEnded) {
        state.isGenerating.value = true;
        _markFeedbackGenerating(entry.key);
      }
      if (changed && state.isRetrying.value) {
        state.isRetrying.value = false;
        state.lastError.value = null;
      }
    }
  }

  void _discardPendingPartDeltas({Set<String>? sessionIds}) {
    if (sessionIds == null) {
      _partDeltaFlushTimer?.cancel();
      _partDeltaFlushTimer = null;
      _pendingPartDeltas.clear();
      return;
    }
    if (sessionIds.isEmpty) return;
    _pendingPartDeltas.removeWhere(
      (key, v) => sessionIds.contains(v.sessionId),
    );
    if (_pendingPartDeltas.isEmpty) {
      _partDeltaFlushTimer?.cancel();
      _partDeltaFlushTimer = null;
    }
  }

  bool _applyPartDelta(SessionRuntimeState state, _PendingPartDelta item) {
    final msgIdx = state.messages.indexWhere((m) => m.id == item.messageId);
    if (msgIdx == -1) return false;

    final message = state.messages[msgIdx];
    final partIdx = message.parts.indexWhere((p) => p.id == item.partId);
    if (partIdx == -1) return false;

    final existing = message.parts[partIdx];
    // 工具 part 的流式字段挂在 raw['state'][field]（与 toolOutput 等类型化
    // 读取一致），文本/推理 part 直接挂 raw[field]。
    final isTool = existing.type == PartType.tool;
    final currentRaw = isTool
        ? ((existing.raw['state'] as Map?)?[item.field])
        : existing.raw[item.field];
    final currentText = currentRaw is String
        ? currentRaw
        : (currentRaw?.toString() ?? '');

    // 流式 delta 走细粒度通道：只更新 per-part RxString（key
    // `$partId\u0000$field`，订阅它的部件局部重建），不整列表替换——否则
    // 每次 flush 都会广播给所有订阅 messages 的组件，让所有可见气泡级联
    // 重建。E1：非 text 字段（bash 输出等）flush 同样只走通道。列表仅在
    // 「从空到有」的首次 delta 时同步一次（驱动占位 → 正式气泡/卡片的切换）。
    final rx = state.streamingPartText.putIfAbsent(
      '${item.partId}\u0000${item.field}',
      () => currentText.obs,
    );
    rx.value += item.delta;
    if (currentText.isNotEmpty) return true;

    final deltaText = '$currentText${item.delta}';
    final raw = Map<String, dynamic>.from(existing.raw);
    if (isTool) {
      final toolState = Map<String, dynamic>.from(
        (existing.raw['state'] as Map?) ?? const {},
      );
      toolState[item.field] = deltaText;
      raw['state'] = toolState;
    } else {
      raw[item.field] = deltaText;
    }
    final existingParts = [...message.parts];
    existingParts[partIdx] = Part(
      id: existing.id,
      sessionID: existing.sessionID,
      messageID: existing.messageID,
      type: existing.type,
      raw: raw,
    );

    state.messages[msgIdx] = messageWithSyncedParts(message, existingParts);
    return true;
  }

  /// 全量 part 更新（part.updated / message.updated）是权威数据：把流式通道
  /// 的累计值对齐到服务端全量内容，避免 delta 累计与服务端内容分叉。
  /// 工具 part 的字段从 raw['state'][field] 取（与类型化读取一致）。
  void _syncStreamingPartText(SessionRuntimeState state, Part part) {
    if (state.streamingPartText.isEmpty) return;
    for (final key in List.of(state.streamingPartText.keys)) {
      final sep = key.indexOf('\u0000');
      if (sep == -1 || key.substring(0, sep) != part.id) continue;
      final field = key.substring(sep + 1);
      final v = part.type == PartType.tool
          ? ((part.raw['state'] as Map?)?[field])
          : part.raw[field];
      state.streamingPartText[key]!.value = v is String
          ? v
          : (v?.toString() ?? '');
    }
  }

  /// 回合收尾（idle / error / abort / 重连纠正）时把流式通道里的累计文本
  /// 落回列表并清空通道：服务端不保证补发最终全量 part，落库保证流结束后
  /// 列表数据完整（isGenerating 翻转后部件改读列表文本，不再订阅通道）。
  void _finalizeStreamingText(SessionRuntimeState state) {
    if (state.streamingPartText.isEmpty) return;
    for (final key in List.of(state.streamingPartText.keys)) {
      final sep = key.indexOf('\u0000');
      if (sep == -1) continue;
      final partId = key.substring(0, sep);
      final field = key.substring(sep + 1);
      final value = state.streamingPartText.remove(key)!.value;
      final msgIdx = state.messages.indexWhere(
        (m) => m.parts.any((p) => p.id == partId),
      );
      if (msgIdx == -1) continue;
      final message = state.messages[msgIdx];
      final parts = [...message.parts];
      final pIdx = parts.indexWhere((p) => p.id == partId);
      final existing = parts[pIdx];
      // 工具 part 的流式字段落回 raw['state'][field]（与 delta 写入、
      // toolOutput 读取位置一致）。
      final isTool = existing.type == PartType.tool;
      final cur = isTool
          ? ((existing.raw['state'] as Map?)?[field])
          : existing.raw[field];
      final curText = cur is String ? cur : (cur?.toString() ?? '');
      if (value == curText) continue;
      final raw = Map<String, dynamic>.from(existing.raw);
      if (isTool) {
        final toolState = Map<String, dynamic>.from(
          (existing.raw['state'] as Map?) ?? const {},
        );
        toolState[field] = value;
        raw['state'] = toolState;
      } else {
        raw[field] = value;
      }
      parts[pIdx] = Part(
        id: existing.id,
        sessionID: existing.sessionID,
        messageID: existing.messageID,
        type: existing.type,
        raw: raw,
      );
      state.messages[msgIdx] = messageWithSyncedParts(message, parts);
    }
  }

  void _onPartRemoved(SseEvent event) {
    final msgId = event.messageID;
    final partId = event.partID;
    if (msgId.isEmpty || partId.isEmpty) return;
    final sessionId = event.sessionID;
    if (sessionId.isEmpty) return;

    final state = sessionRuntimeStates[sessionId];
    if (state == null) return;
    final idx = state.messages.indexWhere((m) => m.id == msgId);
    if (idx == -1) return;
    state.streamingPartText.removeWhere(
      (k, _) => k.startsWith('$partId\u0000'),
    );
    final newParts = state.messages[idx].parts
        .where((p) => p.id != partId)
        .toList();
    state.messages[idx] = messageWithSyncedParts(
      state.messages[idx],
      newParts,
    );
    state.partsVersion++;
    // 删除的可能是挂起的 question part：布尔为 true 时重扫兜底。
    if (state.hasPendingQuestion.value) state.rescanHasPendingQuestion();
  }

  void _onSessionCompacted(SseEvent event) {
    final sid = event.sessionID.isNotEmpty
        ? event.sessionID
        : activeSessionId.value;
    if (sid.isEmpty) return;
    final state = getOrCreateSessionState(sid);
    state.isCompacting.value = false;
    state.lastError.value = null;
    if (state.manualCompactionPending) {
      state.manualCompactionPending = false;
      Snack.success(
        LocaleKeys.chatManualCompactCompleted.tr,
        title: LocaleKeys.chatContextCompaction.tr,
      );
    }
    if (sid == activeSessionId.value) {
      loadMessages(sid, force: true);
    }
  }

  void _onSessionNextCompactionStarted(SseEvent event) {
    final sid = event.sessionID.isNotEmpty
        ? event.sessionID
        : activeSessionId.value;
    if (sid.isEmpty) return;
    final state = getOrCreateSessionState(sid);
    state.isCompacting.value = true;
    state.lastError.value = null;
  }

  void _onSessionNextCompactionEnded(SseEvent event) {
    final sid = event.sessionID.isNotEmpty
        ? event.sessionID
        : activeSessionId.value;
    if (sid.isEmpty) return;
    final state = getOrCreateSessionState(sid);
    state.isCompacting.value = false;
    state.lastError.value = null;
    if (state.manualCompactionPending) {
      state.manualCompactionPending = false;
      Snack.success(
        LocaleKeys.chatManualCompactCompleted.tr,
        title: LocaleKeys.chatContextCompaction.tr,
      );
    }
    if (sid == activeSessionId.value) {
      loadMessages(sid, force: true);
    }
  }

  void _onPartUpdated(SseEvent event) {
    // Desktop: message.part.updated carries the part under `properties.part`.
    final partJson = event.part.isNotEmpty
        ? event.part
        : (event.info.isNotEmpty ? event.info : const <String, dynamic>{});
    if (partJson.isEmpty) return;

    try {
      final part = Part.fromJson(partJson);
      final sid = event.sessionID.isNotEmpty ? event.sessionID : part.sessionID;
      if (sid.isEmpty) return;
      final state = getOrCreateSessionState(sid);

      if (part.type == PartType.text && state.isRetrying.value) {
        state.isRetrying.value = false;
        state.lastError.value = null;
      }

      _upsertPartInState(state, part);

      if (part.type == PartType.tool && part.toolName == 'question') {
        _rememberQuestionToolPart(part, sid);
        _refreshPendingQuestionOnPartUpdate(state, part);
      }

      unawaited(_registerSubtaskOwner(sid, part));

      if (part.type == PartType.tool &&
          part.toolStatus == ToolStateStatus.completed) {
        unawaited(_processToolPart(sid, part));
      }
    } catch (e) {
      AppLogger.e('_onPartUpdated failed: $e');
    }
  }

  /// Insert or replace a part on its message (desktop `_upsertPartInState`).
  /// New tool/reasoning cards arrive this way during streaming.
  void _upsertPartInState(SessionRuntimeState state, Part part) {
    final msgId = part.messageID;
    final partId = part.id;
    if (msgId.isEmpty || partId.isEmpty) return;

    var idx = state.messages.indexWhere((m) => m.id == msgId);
    if (idx == -1) {
      if (part.sessionID.isNotEmpty &&
          state.sessionId.isNotEmpty &&
          part.sessionID != state.sessionId) {
        return;
      }
      state.messages.add(
        messageWithSyncedParts(
          MessageModel(
            id: msgId,
            sessionID: part.sessionID.isNotEmpty
                ? part.sessionID
                : state.sessionId,
            role: MessageRole.assistant,
            parts: [part],
            raw: const {'role': 'assistant'},
          ),
          [part],
        ),
      );
      state.partsVersion++;
      _syncStreamingPartText(state, part);
      return;
    }

    final existingParts = [...state.messages[idx].parts];
    final pIdx = existingParts.indexWhere((p) => p.id == partId);
    if (pIdx == -1) {
      existingParts.add(part);
    } else {
      final existing = existingParts[pIdx];
      if (_partContentUnchanged(existing, part)) {
        // E1 no-op 守卫：part.updated 高频重发相同载荷（全量快照对齐、状态
        // 未变的重复刷新）时直接跳过，不整列表广播。通道已与该内容对齐，
        // 跳过同步也避免把通道里尚未落列表的 delta 累计值回卷。
        return;
      }
      if (_isToolOutputGrowth(existing, part)) {
        // E1 输出增长：工具输出（bash 等）流式增长时只推进 per-part 通道
        // （订阅通道的卡片/弹窗局部重建），不整列表替换——列表留给状态
        // 变化（会改卡片的更新）与回合收尾 finalize 同步。
        final output = part.toolOutput;
        final rx = state.streamingPartText.putIfAbsent(
          '$partId\u0000output',
          () => output.obs,
        );
        if (rx.value != output) rx.value = output;
        return;
      }
      existingParts[pIdx] = part;
    }

    state.messages[idx] = messageWithSyncedParts(
      state.messages[idx],
      existingParts,
    );
    state.partsVersion++;
    _syncStreamingPartText(state, part);
  }

  /// E1：part 内容与列表中现有实例是否完全一致（实例/ raw 引用相等或深相等）。
  bool _partContentUnchanged(Part existing, Part part) {
    if (identical(existing, part)) return true;
    if (identical(existing.raw, part.raw)) return true;
    return _deepEquals(existing.raw, part.raw);
  }

  /// E1：工具 part 非终态（pending/running）且除 `state.output` 外全部内容
  /// 与现有实例一致 —— 判定为输出流式增长（服务端重发累积输出快照），
  /// 只推进 per-part 通道、不整列表替换。
  bool _isToolOutputGrowth(Part existing, Part part) {
    if (part.type != PartType.tool || existing.type != PartType.tool) {
      return false;
    }
    final status = part.toolStatus;
    if (status != ToolStateStatus.running &&
        status != ToolStateStatus.pending) {
      return false;
    }
    final sa = existing.raw['state'];
    final sb = part.raw['state'];
    if (sa is! Map || sb is! Map) return false;
    final ra = Map<String, dynamic>.from(existing.raw)..remove('state');
    final rb = Map<String, dynamic>.from(part.raw)..remove('state');
    if (!_deepEquals(ra, rb)) return false;
    final sa2 = Map<String, dynamic>.from(sa)..remove('output');
    final sb2 = Map<String, dynamic>.from(sb)..remove('output');
    return _deepEquals(sa2, sb2);
  }

  /// 递归深比较（JSON 值域：Map/List/String/num/bool/null），key 顺序无关。
  /// 仅用于 E1 守卫的短路径判定，避免为比较分配中间结构。
  static bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  /// E3：question part 更新后增量维护 [SessionRuntimeState.hasPendingQuestion]，
  /// 让输入区/指示点只 touch 布尔而非全量扫描 messages。
  void _refreshPendingQuestionOnPartUpdate(
    SessionRuntimeState state,
    Part part,
  ) {
    final status = part.toolStatus;
    if (status == ToolStateStatus.running ||
        status == ToolStateStatus.pending) {
      if (!state.hasPendingQuestion.value) {
        state.hasPendingQuestion.value = true;
      }
      return;
    }
    // 终态：树内可能还有其他挂起的 question part，仅在布尔为 true 时重扫。
    if (state.hasPendingQuestion.value) state.rescanHasPendingQuestion();
  }

  /// E3：消息整表替换/新增后的公共维护 —— bump diff 版本号 + pending
  /// question 布尔增量更新（新消息带挂起 question 置 true；否则布尔为 true
  /// 时重扫兜底，替换可能终止了原先挂起的 part）。
  void _afterMessageUpsert(SessionRuntimeState state, MessageModel msg) {
    state.partsVersion++;
    if (_messageHasPendingQuestion(msg)) {
      state.hasPendingQuestion.value = true;
    } else if (state.hasPendingQuestion.value) {
      state.rescanHasPendingQuestion();
    }
  }

  static bool _messageHasPendingQuestion(MessageModel msg) {
    for (final part in msg.parts) {
      if (part.type == PartType.tool &&
          part.toolName == 'question' &&
          (part.toolStatus == ToolStateStatus.running ||
              part.toolStatus == ToolStateStatus.pending)) {
        return true;
      }
    }
    return false;
  }

  void _onMessageUpdated(SseEvent event) {
    final sid = event.sessionID;
    if (sid.isEmpty) return;
    final state = sessionRuntimeStates[sid];
    if (state == null) return;
    final info = event.info;
    if (info.isEmpty) return;
    try {
      final msg = MessageModel.fromJson(info);
      final idx = state.messages.indexWhere((m) => m.id == msg.id);
      if (idx != -1) {
        final existing = state.messages[idx];
        // summarize() may update info.summary without resending parts.
        if (msg.parts.isEmpty && existing.parts.isNotEmpty) {
          final raw = Map<String, dynamic>.from(existing.raw);
          if (msg.raw.containsKey('summary')) {
            raw['summary'] = msg.raw['summary'];
          }
          if (msg.raw['info'] is Map) {
            final infoMap = Map<String, dynamic>.from(
              (raw['info'] is Map)
                  ? Map<String, dynamic>.from(raw['info'] as Map)
                  : const <String, dynamic>{},
            );
            final incomingInfo = Map<String, dynamic>.from(
              msg.raw['info'] as Map,
            );
            if (incomingInfo.containsKey('summary')) {
              infoMap['summary'] = incomingInfo['summary'];
            }
            raw['info'] = infoMap;
          }
          state.messages[idx] = MessageModel(
            id: existing.id,
            sessionID: existing.sessionID,
            role: existing.role,
            parts: existing.parts,
            raw: raw,
          );
        } else {
          state.messages[idx] = msg;
          // 全量消息替换是权威数据，逐 part 对齐流式通道，防止分叉。
          if (state.streamingPartText.isNotEmpty) {
            for (final p in msg.parts) {
              _syncStreamingPartText(state, p);
            }
          }
          _afterMessageUpsert(state, msg);
        }
      } else {
        state.messages.add(msg);
        _afterMessageUpsert(state, msg);
      }
    } catch (e) {
      AppLogger.e('_onMessageUpdated failed: $e');
    }
  }

  void _onMessageRemoved(SseEvent event) {
    final sid = event.sessionID;
    if (sid.isEmpty) return;
    final state = sessionRuntimeStates[sid];
    if (state == null) return;
    final mid = event.properties['messageID']?.toString() ?? '';
    if (mid.isNotEmpty) {
      state.messages.removeWhere((m) => m.id == mid);
      state.partsVersion++;
      // 删除可能移除了挂起的 question part：布尔为 true 时重扫兜底。
      if (state.hasPendingQuestion.value) state.rescanHasPendingQuestion();
    }
  }

  void _onPermissionAsked(SseEvent event) {
    final props = event.properties;
    if (props['id'] == null) return;
    final pending = PendingPermission.fromEvent(props);
    final sid = pending.sessionID.isNotEmpty
        ? pending.sessionID
        : event.sessionID;
    if (sid.isEmpty) return;
    final targetState = getOrCreateSessionState(sid);
    final existing = targetState.pendingPermission.value;
    if (existing != null && existing.id != pending.id) {
      // 客户端每会话只保留一个待决权限（服务端 pending 是 Map，可同时挂多个），
      // 覆盖后旧请求不可见不可答。留痕便于排查「卡片少了」类反馈；
      // 完整多请求队列化见 docs/代码审查.md 遗留问题。
      AppLogger.w(
        'permission.asked overwrites pending ${existing.id} '
        'with ${pending.id} in session $sid',
      );
    }
    targetState.pendingPermission.value = pending;

    _notifyFeedback(
      type: FeedbackType.permissionRequested,
      title: LocaleKeys.feedbackPermission.tr,
      message: LocaleKeys.feedbackPermissionMsg.trParams({
        'session': getSessionName(sid),
      }),
      sessionId: sid,
    );
  }

  void _onQuestionAsked(SseEvent event) {
    final requestId = event.properties['id']?.toString() ?? '';
    final sessionId = event.sessionID;
    if (requestId.isEmpty || sessionId.isEmpty) return;

    final tool = event.properties['tool'];
    if (tool is Map) {
      final messageId = tool['messageID']?.toString() ?? '';
      final callId = tool['callID']?.toString() ?? '';
      if (messageId.isNotEmpty || callId.isNotEmpty) {
        _questionRequests[requestId] = QuestionRequestRef(
          sessionId: sessionId,
          messageId: messageId,
          callId: callId,
        );
      }
    }

    _notifyFeedback(
      type: FeedbackType.questionRequested,
      title: LocaleKeys.feedbackQuestion.tr,
      message: LocaleKeys.feedbackQuestionMsg.trParams({
        'session': getSessionName(sessionId),
      }),
      sessionId: sessionId,
    );
  }

  void _notifyFeedback({
    required FeedbackType type,
    required String title,
    required String message,
    required String sessionId,
  }) {
    if (Get.isRegistered<AppFeedbackService>()) {
      unawaited(
        AppFeedbackService.to.notify(
          type: type,
          title: title,
          message: message,
          sessionId: sessionId,
        ),
      );
    }
  }

  void _rememberQuestionToolPart(Part part, String fallbackSessionId) {
    final sessionId = part.sessionID.isNotEmpty
        ? part.sessionID
        : fallbackSessionId;
    if (sessionId.isEmpty) return;
    MapEntry<String, QuestionRequestRef>? existing;
    for (final entry in _questionRequests.entries) {
      final ref = entry.value;
      if (ref.sessionId != sessionId) continue;
      if (ref.messageId.isNotEmpty && ref.messageId != part.messageID) {
        continue;
      }
      if (ref.callId.isNotEmpty && ref.callId == part.callID) {
        existing = entry;
        break;
      }
    }
    if (existing == null) return;
    _questionRequests[existing.key] = existing.value.copyWith(partId: part.id);
  }

  /// 丢弃某会话名下的提问引用。会话被删除后这些引用永久失效，残留会导致
  /// `questionRequestIDForCallID` 命中已删会话的 requestID 且内存只增不减。
  void _forgetQuestionRequestsForSession(String sessionId) {
    if (sessionId.isEmpty) return;
    _questionRequests.removeWhere((_, ref) => ref.sessionId == sessionId);
  }

  void _onQuestionResolved(SseEvent event, {required bool rejected}) {
    final requestId =
        event.properties['requestID']?.toString() ??
        event.properties['id']?.toString() ??
        '';
    if (requestId.isEmpty) return;
    final ref = _questionRequests[requestId];
    final sessionId = event.sessionID.isNotEmpty
        ? event.sessionID
        : (ref?.sessionId ?? '');
    if (sessionId.isEmpty) return;
    _applyQuestionResolved(
      sessionId: sessionId,
      requestId: requestId,
      rejected: rejected,
      answers: event.properties['answers'],
    );
  }

  /// Update the matching question tool part after reply/reject (SSE or local).
  void _applyQuestionResolved({
    required String sessionId,
    required String requestId,
    required bool rejected,
    dynamic answers,
  }) {
    final ref = _questionRequests.remove(requestId);
    final state = sessionRuntimeStates[sessionId];
    if (state == null) return;

    for (var mi = 0; mi < state.messages.length; mi++) {
      final msg = state.messages[mi];
      final parts = [...msg.parts];
      final partIndex = parts.indexWhere((part) {
        if (part.type != PartType.tool || part.toolName != 'question') {
          return false;
        }
        if (ref?.partId?.isNotEmpty == true && part.id == ref!.partId) {
          return true;
        }
        if (ref?.callId.isNotEmpty == true && part.callID == ref!.callId) {
          return true;
        }
        // Fallback: only one pending question in this session.
        return part.toolStatus == ToolStateStatus.running ||
            part.toolStatus == ToolStateStatus.pending;
      });
      if (partIndex == -1) continue;

      final part = parts[partIndex];
      if (part.toolStatus != ToolStateStatus.running &&
          part.toolStatus != ToolStateStatus.pending) {
        return;
      }
      parts[partIndex] = _questionPartWithStatus(
        part,
        rejected ? ToolStateStatus.error : ToolStateStatus.completed,
        output: rejected
            ? null
            : <String, dynamic>{'answers': answers ?? const []},
        error: rejected ? 'Question rejected' : null,
      );
      state.messages[mi] = messageWithSyncedParts(msg, parts);
      state.partsVersion++;
      // 本地已把该 question 置终态：布尔为 true 时重扫（可能还有其他挂起）。
      if (state.hasPendingQuestion.value) state.rescanHasPendingQuestion();
      return;
    }
  }

  Part _questionPartWithStatus(
    Part part,
    ToolStateStatus status, {
    dynamic output,
    String? error,
  }) {
    final raw = Map<String, dynamic>.from(part.raw);
    final toolState = Map<String, dynamic>.from(
      (part.raw['state'] as Map?) ?? const {},
    );
    toolState['status'] = switch (status) {
      ToolStateStatus.pending => 'pending',
      ToolStateStatus.running => 'running',
      ToolStateStatus.completed => 'completed',
      ToolStateStatus.error => 'error',
    };
    if (output != null) toolState['output'] = output;
    if (error != null) toolState['error'] = error;
    raw['state'] = toolState;
    return Part(
      id: part.id,
      sessionID: part.sessionID,
      messageID: part.messageID,
      type: part.type,
      raw: raw,
    );
  }

  /// After batch message load, mark leftover pending questions as skipped.
  ///
  /// 历史 batch load 后 running/pending 的 question part 有两种可能：(a) 服务端
  /// 仍在等待回答的活跃提问（冷启动时 isGenerating 恒为 false，原有守卫拦不住）
  /// —— 必须保留，否则提问卡消失、agent 永久挂起；(b) 服务端已无对应 pending
  /// 的遗留脏数据（如服务端实例重启 finalizer 统一失败后未回写 part）—— 标记
  /// skipped 让卡片退场。以 `GET /question` 的服务端 pending 列表为准校准
  /// （按 part.id ↔ 请求 id、part.callID ↔ tool.callID 双路匹配）；拉取失败时
  /// 保守跳过清理：宁可卡片多留（可手动拒绝），不可误杀活跃提问。
  Future<void> _markStaleQuestionsSkipped(SessionRuntimeState state) async {
    final liveRequestIds = <String>{};
    final liveCallIds = <String>{};
    try {
      final response = await _client.get(ApiEndpoints.questions);
      if (response.statusCode != 200) {
        AppLogger.w(
          'mark stale questions: GET /question returned '
          '${response.statusCode}, skip cleanup',
        );
        return;
      }
      final data = response.data;
      final List rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map && data['data'] is List) {
        rawList = data['data'] as List;
      } else {
        rawList = [];
      }
      for (final item in rawList) {
        if (item is! Map) continue;
        // 只关心本会话的 pending；callID 全局唯一，跨会话不会误保。
        final itemSession = item['sessionID']?.toString() ?? '';
        if (itemSession.isNotEmpty && itemSession != state.sessionId) continue;
        final id = item['id']?.toString() ?? '';
        if (id.isNotEmpty) liveRequestIds.add(id);
        final tool = item['tool'];
        if (tool is Map) {
          final callId = tool['callID']?.toString() ?? '';
          if (callId.isNotEmpty) liveCallIds.add(callId);
        }
      }
    } catch (e) {
      AppLogger.w(
        'mark stale questions: GET /question failed: $e, skip cleanup',
      );
      return;
    }

    for (int mi = 0; mi < state.messages.length; mi++) {
      final msg = state.messages[mi];
      var changed = false;
      final newParts = <Part>[];
      for (final part in msg.parts) {
        final isLiveQuestion =
            liveRequestIds.contains(part.id) ||
            liveCallIds.contains(part.callID);
        if (part.type == PartType.tool &&
            part.toolName == 'question' &&
            (part.toolStatus == ToolStateStatus.running ||
                part.toolStatus == ToolStateStatus.pending) &&
            !isLiveQuestion) {
          final modifiedRaw = Map<String, dynamic>.from(part.raw);
          final modifiedState = Map<String, dynamic>.from(
            (part.raw['state'] as Map?) ?? const {},
          );
          modifiedState['status'] = 'completed';
          modifiedState['output'] = <String, dynamic>{'skipped': true};
          modifiedRaw['state'] = modifiedState;
          newParts.add(
            Part(
              id: part.id,
              sessionID: part.sessionID,
              messageID: part.messageID,
              type: part.type,
              raw: modifiedRaw,
            ),
          );
          changed = true;
        } else {
          newParts.add(part);
        }
      }
      if (changed) {
        state.messages[mi] = messageWithSyncedParts(msg, newParts);
        state.partsVersion++;
        // 挂起 question 被标记 skipped（终态）：布尔为 true 时重扫兜底。
        if (state.hasPendingQuestion.value) state.rescanHasPendingQuestion();
      }
    }
  }

  void _onPermissionReplied(SseEvent event) {
    final sid = event.sessionID;
    final requestId =
        event.properties['id']?.toString() ??
        event.properties['requestID']?.toString() ??
        '';
    if (sid.isEmpty) {
      // 事件缺 sessionID 时按 requestID 全局匹配清槽，避免卡片残留。
      if (requestId.isEmpty) return;
      for (final state in sessionRuntimeStates.values) {
        if (state.pendingPermission.value?.id == requestId) {
          state.pendingPermission.value = null;
        }
      }
      return;
    }
    // 不用 getOrCreateSessionState：状态已被释放（页签关闭）时无需为一条
    // replied 事件重建空壳；槽位随状态一起消失，本地无需再清。
    final state = sessionRuntimeStates[sid];
    if (state == null) return;
    final pending = state.pendingPermission.value;
    if (pending == null) return;
    if (requestId.isEmpty || pending.id == requestId) {
      state.pendingPermission.value = null;
    }
  }

  void _onTodoUpdated(SseEvent event) {
    final sid = event.sessionID;
    if (sid.isEmpty) return;
    final parsed = <Map<String, dynamic>>[];
    for (final item in event.todos) {
      if (item is Map) {
        parsed.add(Map<String, dynamic>.from(item));
      }
    }
    final state = getOrCreateSessionState(sid);
    state.hasFetchedTodos = true;
    state.todos.assignAll(parsed);
  }

  void _onSessionDiff(SseEvent event) {
    final sid = event.sessionID;
    if (sid.isEmpty) return;
    final rawList = event.diffs;
    if (rawList.isEmpty) {
      // 服务端两种路径都会发布空 diff（事件载荷为 {sessionID, diff}，见
      // event-v2-bridge.ts 的 properties 包装）：summarize 在每回合开始
      // （prompt.ts step===1）与结束（processor.ts）发布空 diff 作为重置
      // 信号，revert（revert.ts）发布剩余范围的实际 diff（也可能为空）。
      // 客户端若忽略空事件，一次 revert 写入的快照将永久非空，
      // effectiveSessionDiffs 会一直优先命中它，遮蔽后续回合的本地聚合。
      // 空载荷意味着 SSE 侧快照应清空，回落聚合源；sendPrompt 镜像
      // cleanup 已先截断 revert 点之后的消息，聚合结果此时是正确的。
      // 仅在事件确实携带 diff 键时清空（畸形缺键事件维持忽略防误清），
      // 且只清已存在的 state，不为空事件创建运行时状态。
      if (event.properties.containsKey('diff')) {
        sessionRuntimeStates[sid]?.sessionDiffs.clear();
      }
      return;
    }
    final list = rawList
        .whereType<Map>()
        .map((e) => SnapshotFileDiff.fromJson(Map<String, dynamic>.from(e)))
        .where((d) => d.file.isNotEmpty)
        .toList();
    final state = getOrCreateSessionState(sid);
    state.sessionDiffs.assignAll(list);
  }

  /// 获取指定消息的文件变动 Diff（带内存缓存）。
  /// 当 [force] 为 false 时，优先从 [SessionRuntimeState.fetchedMessageDiffs] 返回已缓存数据。
  /// 对于已完成的历史回合，消息 Diff 确定不可变，无需重复发起网络请求。
  /// [throwOnError] 为 true 时请求失败向上抛出（Review 页需要区分
  /// 「失败可重试」与「确实无 diff」）；默认 false 维持吞错返回缓存的旧语义。
  Future<List<SnapshotFileDiff>> fetchMessageDiff(
    String sessionId,
    String messageId, {
    bool force = false,
    bool throwOnError = false,
  }) async {
    if (sessionId.isEmpty || messageId.isEmpty) return const [];
    final state = stateOf(sessionId);

    // 生成期间判断：仅针对正在生成的当前最新回合跳过缓存；
    // 历史已完成的回合 diff 永远不可变，始终允许命中缓存，避免新回合生成时
    // 导致查看历史卡片 Diff 重复请求。
    String? activeGeneratingUserMsgId;
    if (state.isGenerating.value) {
      for (var i = state.messages.length - 1; i >= 0; i--) {
        if (state.messages[i].role == MessageRole.user) {
          activeGeneratingUserMsgId = state.messages[i].id;
          break;
        }
      }
    }
    final isGeneratingThisTurn =
        activeGeneratingUserMsgId != null &&
        (activeGeneratingUserMsgId == messageId);

    if (!force &&
        !isGeneratingThisTurn &&
        state.fetchedMessageDiffs.containsKey(messageId)) {
      return state.fetchedMessageDiffs[messageId]!;
    }

    try {
      final response = await _client.get(
        ApiEndpoints.sessionDiff(sessionId),
        queryParameters: {'messageID': messageId},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final rawList = (data is Map && data['data'] is List)
            ? data['data'] as List
            : (data is List ? data : const []);
        final parsed = rawList
            .whereType<Map>()
            .map((e) => SnapshotFileDiff.fromJson(Map<String, dynamic>.from(e)))
            .where((d) => d.file.isNotEmpty)
            .toList();

        if (!isGeneratingThisTurn) {
          state.fetchedMessageDiffs[messageId] = parsed;
        }
        return parsed;
      }
    } catch (e) {
      AppLogger.e('fetchMessageDiff failed: $e');
      if (throwOnError) rethrow;
    }

    return state.fetchedMessageDiffs[messageId] ?? const [];
  }

  /// 根据滑动手势方向（[isForward] 为 true 表示在 PageView 中向后/向右切至下一个 Card），
  /// 寻找后续 opened 卡片中是否有需要用户优先响应的待办事件（如待审批权限、待回答提问）。
  /// 若存在待办卡片，返回智能跳跃的目标索引；若不存在，退回降级为相邻切页。
  int getNextAttentionPageIndex({
    required int currentIndex,
    required List<String> openedIds,
    required bool isForward,
  }) {
    if (openedIds.isEmpty) return 0;
    if (currentIndex < 0 || currentIndex >= openedIds.length) return 0;

    if (isForward) {
      // 前向搜寻：currentIndex + 1 到 openedIds.length - 1
      for (int i = currentIndex + 1; i < openedIds.length; i++) {
        final id = openedIds[i];
        final state = stateOf(id);
        if (state.requiresAction) {
          return i;
        }
      }
      return (currentIndex + 1).clamp(0, openedIds.length - 1);
    } else {
      // 后向搜寻：currentIndex - 1 到 0
      for (int i = currentIndex - 1; i >= 0; i--) {
        final id = openedIds[i];
        final state = stateOf(id);
        if (state.requiresAction) {
          return i;
        }
      }
      return (currentIndex - 1).clamp(0, openedIds.length - 1);
    }
  }
}

class _PendingPartDelta {
  final String sessionId;
  final String messageId;
  final String partId;
  final String field;
  String delta;

  _PendingPartDelta({
    required this.sessionId,
    required this.messageId,
    required this.partId,
    required this.field,
    required this.delta,
  });
}

class QuestionRequestRef {
  final String sessionId;
  final String messageId;
  final String callId;
  final String? partId;

  const QuestionRequestRef({
    required this.sessionId,
    required this.messageId,
    required this.callId,
    this.partId,
  });

  QuestionRequestRef copyWith({String? partId}) => QuestionRequestRef(
    sessionId: sessionId,
    messageId: messageId,
    callId: callId,
    partId: partId ?? this.partId,
  );
}
