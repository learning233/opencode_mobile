import 'dart:typed_data';
import 'package:get/get.dart';
import '../api/models/message.dart';
import '../api/models/permission.dart';
import '../api/models/session.dart';
import '../api/models/snapshot_file_diff.dart';

export '../api/models/permission.dart';

/// An image queued for sending, carrying the real bytes plus the MIME/extension
/// detected at pick time so the request can declare the correct content type.
typedef PickedImage = ({Uint8List bytes, String mime, String ext});

/// Which status section above the prompt input is expanded for a session.
/// Lifted out of `_SessionStatusStackState` so `sendPrompt` can auto-collapse
/// the changefiles panel and session-switch logic can read it.
enum SessionExpandedSection { todo, diff, none }

class SessionRuntimeState {
  final String sessionId;

  final messages = <MessageModel>[].obs;
  final childSessions = <SessionModel>[].obs;
  final isGenerating = false.obs;
  final isRetrying = false.obs;
  final isCompacting = false.obs;
  final wasAborted = false.obs;
  final generatingAgent = ''.obs;
  final showStartExecutionButton = false.obs;
  final selectedModel = ''.obs;
  final selectedAgent = 'plan'.obs;

  /// Last known server status type. Empty string = "no status received yet in
  /// this runtime" (e.g. freshly restored session after app restart), so the
  /// controller can still re-arm [isGenerating] on the first streaming deltas
  /// instead of treating the default as a settled "idle".
  final sessionStatus = ''.obs;
  final lastError = Rxn<String>();
  final pendingPermission = Rxn<PendingPermission>();
  final selectedThinkingLevel = ''.obs;
  final thinkingLevels = <String>[].obs;
  final attachedFiles = <String>[].obs;
  final attachedImages = <PickedImage>[].obs;

  /// True while the attached images are being converted to text by a vision
  /// model (frontend-only fallback for models that don't support image input).
  final isDescribingImages = false.obs;
  final todos = <Map<String, dynamic>>[].obs;
  bool hasFetchedTodos = false;

  /// True once [SessionController.loadMessages] has fetched the server history
  /// for this session. Guards the lazy re-fetch separately from [messages]
  /// being non-empty, because SSE can pre-populate messages for a not-yet-opened
  /// session and must not block the first history fetch.
  final hasLoadedHistory = false.obs;

  /// True when the last [SessionController.loadMessages] attempt for this
  /// session ended in an error. Lets the empty-session UI offer a retry
  /// instead of showing the misleading "start a conversation" empty state.
  final historyLoadFailed = false.obs;

  /// 重连后标记「历史可能过期」：SSE 自动重连的补偿只强刷当前激活页签，
  /// 其余打开页签置此标记，切到该页签时经 loadMessages 懒加载守卫重新拉取，
  /// 避免一次断线触发 N 个全量请求（见 _refreshAfterReconnect）。
  bool needsReloadAfterReconnect = false;
  final sessionDiffs = <SnapshotFileDiff>[].obs;

  /// Expanded status section (todo/diff/none). Written by the SessionStatusStack
  /// UI and collapsed by `SessionController.sendPrompt` when a new message is sent.
  /// Defaults to none so the resident panels don't eat screen space until the
  /// user explicitly expands them.
  final expandedSection = SessionExpandedSection.none.obs;

  /// Map of rootUserMessageId -> aggregated SnapshotFileDiffs produced by subtasks
  final messageSubtaskDiffs = <String, List<SnapshotFileDiff>>{}.obs;

  /// Part ids of legacy text-XML tool calls the user already answered
  /// (Allow/Deny). Survives widget rebuilds so a lazy-list scroll doesn't
  /// re-show the permission card and re-send the approval.
  final respondedToolCallIds = <String>{};

  /// Cache of per-message turn diff aggregation keyed by message id.
  /// Invalidated by a signature of the turn's messages / part counts /
  /// part statuses (see MessageBubble._turnDiffSignature).
  final turnDiffCache = <String, TurnDiffCacheEntry>{};

  /// 流式文本的细粒度通道，key 为 `$partId\u0000$field`。文本 delta 的
  /// 80ms flush 只更新这里的 RxString（订阅它的流式文本部件局部重建），
  /// 不再整列表替换 [messages] —— 否则每次 flush 都会广播给所有订阅者，
  /// 导致所有可见气泡级联重建。列表仅在关键节点同步：首次从空到有、
  /// 收到全量 part 更新（权威对齐）、回合结束 finalize（落库保完整）。
  final streamingPartText = <String, RxString>{};

  /// Cache of fetched server message diffs keyed by userMessageId.
  /// Used by message diff sheets and ReviewPage to avoid redundant network calls.
  final fetchedMessageDiffs = <String, List<SnapshotFileDiff>>{};

  final pendingPromptText = ''.obs;
  final pendingPromptImages = <PickedImage>[].obs;
  final pendingPromptAttachedFiles = <String>[].obs;

  /// Agent/model override chosen on a quick phrase sent while generating.
  /// `_queuePendingPrompt` persists them so the queued send honors the user's
  /// selection instead of silently falling back to the session defaults.
  final pendingPromptAgent = ''.obs;
  final pendingPromptModel = ''.obs;
  final keywordDetectionAlert = false.obs;

  /// Cache of the aggregated [effectiveSessionDiffs] keyed by a signature of
  /// all assistant messages' tool parts + subtask diffs, so the 80ms streaming
  /// flush doesn't re-parse every patch while nothing relevant changed.
  List<SnapshotFileDiff>? _effectiveDiffsCache;
  String _effectiveDiffsSignature = '';

  /// Returns SSE-received diffs if available, otherwise dynamically aggregates tool diffs across all assistant messages and subtasks in the session.
  List<SnapshotFileDiff> get effectiveSessionDiffs {
    if (sessionDiffs.isNotEmpty) {
      _effectiveDiffsCache = null;
      _effectiveDiffsSignature = '';
      return sessionDiffs;
    }
    final sig = _effectiveDiffSignature();
    final cached = _effectiveDiffsCache;
    if (cached != null && sig == _effectiveDiffsSignature) return cached;
    final map = <String, SnapshotFileDiff>{};

    void mergeDiff(SnapshotFileDiff diff) {
      if (diff.file.isEmpty) return;
      if (map.containsKey(diff.file)) {
        map[diff.file] = SnapshotFileDiff.merge(map[diff.file]!, diff);
      } else {
        map[diff.file] = diff;
      }
    }

    for (final msg in messages) {
      if (msg.role != MessageRole.assistant) continue;
      for (final diff in msg.toolDiffs) {
        mergeDiff(diff);
      }
    }

    for (final subtaskDiffList in messageSubtaskDiffs.values) {
      for (final diff in subtaskDiffList) {
        mergeDiff(diff);
      }
    }

    final result = map.values.toList();
    _effectiveDiffsCache = result;
    _effectiveDiffsSignature = sig;
    return result;
  }

  /// Cheap signature over everything that can change the aggregated diffs:
  /// assistant messages' ids / part counts / tool part statuses, plus the
  /// subtask diff aggregation (files + +/- counts).
  String _effectiveDiffSignature() {
    final sb = StringBuffer();
    for (final msg in messages) {
      if (msg.role != MessageRole.assistant) continue;
      sb
        ..write(msg.id)
        ..write('#')
        ..write(msg.parts.length)
        ..write(';');
      for (final p in msg.parts) {
        if (p.type == PartType.tool) {
          sb
            ..write(p.id)
            ..write('=')
            ..write(p.toolStatus.name)
            ..write(',');
        }
      }
    }
    sb.write('S');
    for (final entry in messageSubtaskDiffs.entries) {
      sb
        ..write(entry.key)
        ..write('=');
      for (final d in entry.value) {
        sb
          ..write(d.file)
          ..write('+')
          ..write(d.additions)
          ..write('-')
          ..write(d.deletions)
          ..write(';');
      }
    }
    return sb.toString();
  }

  /// When set, timeline hides messages at/after this id (desktop revert UX).
  final revertMessageID = ''.obs;

  /// Epoch ms until which abort-related session.error should be suppressed.
  int suppressAbortErrorUntilMs = 0;

  /// Set while a user-triggered manual compaction awaits its completion SSE event.
  bool manualCompactionPending = false;

  SessionRuntimeState(this.sessionId);

  bool get hasPendingPrompt =>
      pendingPromptText.value.isNotEmpty ||
      pendingPromptImages.isNotEmpty ||
      pendingPromptAttachedFiles.isNotEmpty;

  void clearPendingPrompt() {
    pendingPromptText.value = '';
    pendingPromptImages.clear();
    pendingPromptAttachedFiles.clear();
    pendingPromptAgent.value = '';
    pendingPromptModel.value = '';
  }

  /// Waiting for user action (permission or pending clarifying question).
  /// Matches desktop [SessionRuntimeState.requiresAction].
  bool get requiresAction {
    if (pendingPermission.value != null) return true;
    for (final msg in messages) {
      for (final part in msg.parts) {
        if (part.type == PartType.tool &&
            part.toolName == 'question' &&
            (part.toolStatus == ToolStateStatus.running ||
                part.toolStatus == ToolStateStatus.pending)) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Cached turn-diff aggregation for a message, keyed by a signature of the
/// turn's messages so the cache is invalidated when parts stream in.
class TurnDiffCacheEntry {
  final String signature;
  final List<SnapshotFileDiff> diffs;

  TurnDiffCacheEntry({required this.signature, required this.diffs});
}
