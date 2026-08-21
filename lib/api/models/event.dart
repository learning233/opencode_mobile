import 'dart:convert';
import '../../utils/app_logger.dart';

// ── SSE Event types mirrored from the OpenCode SDK ──

/// Represents a single Server-Sent Event (SSE) received from the
/// OpenCode sidecar.  Contains the raw wire data and parsed fields
/// (id, type, properties) plus typed convenience accessors that align
/// with the SDK event schema.
class SseEvent {
  /// Unique event identifier (from the `id:` line or decoded JSON body).
  final String id;

  /// Event type string (e.g. "session.created", "message.part.delta").
  final String type;

  /// Parsed JSON properties map carried by the event.
  final Map<String, dynamic> properties;

  /// The raw, unparsed SSE text as received from the server.
  final String rawData;

  /// Reusable empty map to avoid allocations in typed getters.
  static const _emptyMap = <String, dynamic>{};

  /// Reusable empty list to avoid allocations in typed getters.
  static const _emptyList = <dynamic>[];

  SseEvent({
    required this.id,
    required this.type,
    required this.properties,
    required this.rawData,
  });

  /// Parses a raw SSE payload string into an [SseEvent].
  ///
  /// Handles the standard SSE wire format (`id:`, `event:`, `data:` lines)
  /// as well as a fallback JSON body inside the `data:` field.  If the JSON
  /// contains duplicate keys the last occurrence wins.
  factory SseEvent.parse(String data) {
    String id = '';
    String eventType = '';
    Map<String, dynamic> properties = {};
    String rawData = data;

    final lines = data.split('\n');
    final buf = StringBuffer();
    for (final line in lines) {
      if (line.startsWith('id:')) {
        id = line.substring(3).trim();
      } else if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        buf.writeln(line.substring(5).trim());
      }
    }

    final body = buf.toString().trim();
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          id = decoded['id'] as String? ?? id;
          eventType = decoded['type'] as String? ?? eventType;
          final props = decoded['properties'];
          properties = props is Map<String, dynamic> ? props : decoded;
        }
      } catch (_) {
        try {
          final decoded = _parseJsonWithDuplicates(body);
          if (decoded is Map<String, dynamic>) {
            id = decoded['id'] as String? ?? id;
            eventType = decoded['type'] as String? ?? eventType;
            final props = decoded['properties'];
            properties = props is Map<String, dynamic> ? props : decoded;
          }
        } catch (e) {
          AppLogger.e('SSE event JSON fallback parse failed: $e');
        }
      }
    }

    return SseEvent(
      id: id,
      type: eventType,
      properties: properties,
      rawData: rawData,
    );
  }

  // ── typed accessors matching SDK event properties ──

  /// The `info` field used by session.* and message.updated events.
  Map<String, dynamic> get info =>
      properties['info'] as Map<String, dynamic>? ?? _emptyMap;

  /// Session ID extracted from [properties], [info], or [part].
  ///
  /// Checks `sessionID` / `sessionId` at the top level, inside `info`,
  /// uses `info.id` for session.* events, and finally checks the `part` map.
  String get sessionID {
    final root = properties['sessionID'] ?? properties['sessionId'];
    if (root != null) return root.toString();
    final infoSid = info['sessionID'] ?? info['sessionId'];
    if (infoSid != null) return infoSid.toString();
    if (type.startsWith('session.') && info['id'] != null) {
      return info['id'].toString();
    }
    final partSid = part['sessionID'] ?? part['sessionId'];
    if (partSid != null) return partSid.toString();
    return '';
  }

  /// Message ID extracted from [properties], [info], or [part].
  ///
  /// Checks `messageID` / `messageId` at the top level, inside `info`,
  /// falls back to `info.id`, and finally checks the `part` map.
  String get messageID {
    final root = properties['messageID'] ?? properties['messageId'];
    if (root != null) return root.toString();
    final infoMid = info['messageID'] ?? info['messageId'] ?? info['id'];
    if (infoMid != null) return infoMid.toString();
    final partMid = part['messageID'] ?? part['messageId'];
    if (partMid != null) return partMid.toString();
    return '';
  }

  /// Part (sub-message) ID extracted from [properties].
  ///
  /// Checks `partID` / `partId` at the top level.
  String get partID {
    final root = properties['partID'] ?? properties['partId'];
    if (root != null) return root.toString();
    return '';
  }

  /// The Part map from `message.part.updated` events.
  Map<String, dynamic> get part =>
      properties['part'] as Map<String, dynamic>? ?? _emptyMap;

  /// Text delta for streaming part updates.
  String get delta => properties['delta'] as String? ?? '';

  /// Full text content from [properties].
  String get text => properties['text'] as String? ?? '';

  /// Tool call ID extracted from the [part] map (`callID`).
  String get callID {
    final p = part;
    return p['callID'] as String? ?? '';
  }

  /// Tool name extracted from the [part] map (`tool`).
  String get toolName {
    final p = part;
    return p['tool'] as String? ?? '';
  }

  /// Tool state map extracted from the [part] map (`state`).
  Map<String, dynamic> get toolState {
    final p = part;
    return p['state'] as Map<String, dynamic>? ?? _emptyMap;
  }

  /// Reasoning chunk ID extracted from the [part] map (`id`).
  String get reasoningID {
    final p = part;
    return p['id'] as String? ?? '';
  }

  /// The `status` map from [properties].
  Map<String, dynamic> get status =>
      properties['status'] as Map<String, dynamic>? ?? _emptyMap;

  /// The `type` field inside the [status] map.
  String get statusType => status['type'] as String? ?? '';

  /// The `error` map from [properties].
  Map<String, dynamic> get error =>
      properties['error'] as Map<String, dynamic>? ?? _emptyMap;

  /// Alias for [properties]; used for permission-related events.
  Map<String, dynamic> get permission => properties;

  /// The `todos` list from [properties].
  List<dynamic> get todos => properties['todos'] as List? ?? _emptyList;

  /// The `diff` list from [properties].
  List<dynamic> get diffs => properties['diff'] as List? ?? _emptyList;
}

/// Parse JSON with support for duplicate keys (last wins).
dynamic _parseJsonWithDuplicates(String source) {
  final map = <String, dynamic>{};
  final regex = RegExp(r'"([^"\\]*(\\.[^"\\]*)*)"\s*:\s*');
  var pos = 0;
  while (pos < source.length) {
    final m = regex.matchAsPrefix(source, pos);
    if (m == null) {
      pos++;
      continue;
    }
    final key = m.group(1)!;
    pos = m.end;
    // find value
    final start = pos;
    var depth = 0;
    var inStr = false;
    var escaped = false;
    while (pos < source.length) {
      final ch = source[pos];
      if (escaped) {
        escaped = false;
        pos++;
        continue;
      }
      if (ch == '\\') {
        escaped = true;
        pos++;
        continue;
      }
      if (ch == '"') inStr = !inStr;
      if (!inStr) {
        if (ch == '{' || ch == '[') depth++;
        if (ch == '}' || ch == ']') depth--;
        if (depth == 0 && (ch == ',' || ch == '}' || ch == ']')) {
          final valStr = source.substring(
            start,
            depth == 0 && (ch == ',' || ch == '}' || ch == ']') ? pos : pos + 1,
          );
          try {
            map[key] = _parseJsonValue(valStr);
          } catch (_) {
            map[key] = valStr;
          }
          if (ch == ',' || ch == '}') {
            if (ch == '}') pos++;
            break;
          }
          pos++;
          break;
        }
      }
      pos++;
    }
  }
  return map;
}

dynamic _parseJsonValue(String s) {
  s = s.trim();
  if (s == 'null') return null;
  if (s == 'true') return true;
  if (s == 'false') return false;
  if (s.startsWith('"')) return s.substring(1, s.length - 1);
  if (s.startsWith('{') || s.startsWith('[')) {
    try {
      return _parseJsonWithDuplicates(s);
    } catch (_) {
      return s;
    }
  }
  final n = num.tryParse(s);
  if (n != null) return n;
  return s;
}

// ── Event type constants (aligned with @opencode-ai/sdk v2 types.gen.ts) ──

/// Constants for all known SSE event type strings.
///
/// These mirror the event types defined in the `@opencode-ai/sdk` type
/// definitions and cover server lifecycle, messaging, sessions,
/// permissions, file changes, PTY, VCS, installation, commands, LSP,
/// TUI, account, and session-v2 events.
class EventTypes {
  // Server

  /// Emitted when the sidecar server has started and is ready.
  static const serverConnected = 'server.connected';

  /// Emitted when a sidecar server instance has been disposed.
  static const serverInstanceDisposed = 'server.instance.disposed';

  // Message

  /// A conversation message was created or updated.
  static const messageUpdated = 'message.updated';

  /// A conversation message was removed.
  static const messageRemoved = 'message.removed';

  /// A part (sub-unit) of a message was updated.
  static const messagePartUpdated = 'message.part.updated';

  /// A streaming delta update for a message part.
  static const messagePartDelta = 'message.part.delta';

  /// A message part was removed.
  static const messagePartRemoved = 'message.part.removed';

  // Session

  /// A new session was created.
  static const sessionCreated = 'session.created';

  /// An existing session was updated.
  static const sessionUpdated = 'session.updated';

  /// A session was deleted.
  static const sessionDeleted = 'session.deleted';

  /// Session status changed (e.g. thinking, waiting, done).
  static const sessionStatus = 'session.status';

  /// Session became idle.
  static const sessionIdle = 'session.idle';

  /// File diffs were produced in the session.
  static const sessionDiff = 'session.diff';

  /// An error occurred in the session.
  static const sessionError = 'session.error';

  /// Session history was compacted.
  static const sessionCompacted = 'session.compacted';

  /// Current session runner started context compaction.
  static const sessionNextCompactionStarted = 'session.next.compaction.started';

  /// Current session runner finished context compaction.
  static const sessionNextCompactionEnded = 'session.next.compaction.ended';

  // Permission

  /// The agent is asking for a user permission.
  static const permissionAsked = 'permission.asked';

  /// The user replied to a pending permission request.
  static const permissionReplied = 'permission.replied';

  // Question

  /// The agent is asking one or more clarifying questions.
  static const questionAsked = 'question.asked';

  /// The user replied to a pending question request.
  static const questionReplied = 'question.replied';

  /// The user rejected a pending question request.
  static const questionRejected = 'question.rejected';

  // Todo

  /// A todo item was created or updated.
  static const todoUpdated = 'todo.updated';

  // File

  /// A file was edited (via the agent's diff/tool).
  static const fileEdited = 'file.edited';

  /// File watcher detected changes on disk.
  static const fileWatcherUpdated = 'file.watcher.updated';

  // PTY

  /// A pseudoterminal (PTY) process was created.
  static const ptyCreated = 'pty.created';

  /// PTY output or state was updated.
  static const ptyUpdated = 'pty.updated';

  /// A PTY process exited.
  static const ptyExited = 'pty.exited';

  /// A PTY was deleted / cleaned up.
  static const ptyDeleted = 'pty.deleted';

  // VCS

  /// The VCS branch changed in the workspace.
  static const vcsBranchUpdated = 'vcs.branch.updated';

  // Installation

  /// Installation metadata was updated.
  static const installationUpdated = 'installation.updated';

  /// A new update is available for installation.
  static const installationUpdateAvailable = 'installation.update-available';

  // Command

  /// A command was executed (e.g. via the agent).
  static const commandExecuted = 'command.executed';

  // LSP

  /// LSP server state was updated.
  static const lspUpdated = 'lsp.updated';

  /// Diagnostics published by an LSP client.
  static const lspClientDiagnostics = 'lsp.client.diagnostics';

  // TUI (terminal UI events)

  /// Append text to the terminal UI prompt.
  static const tuiPromptAppend = 'tui.prompt.append';

  /// Execute a command from the terminal UI.
  static const tuiCommandExecute = 'tui.command.execute';

  /// Show a toast notification in the terminal UI.
  static const tuiToastShow = 'tui.toast.show';

  // Account (v1.15.7+)

  /// A new account was added.
  static const accountAdded = 'account.added';

  /// An existing account was removed.
  static const accountRemoved = 'account.removed';

  /// The active account was switched.
  static const accountSwitched = 'account.switched';

  // Session v2 (v1.16.0+)

  /// The active session was moved to the next position.
  static const sessionMoved = 'session.next.moved';

  /// The session's agent was switched.
  static const sessionAgentSwitched = 'session.next.agent.switched';

  /// The session's model was switched.
  static const sessionModelSwitched = 'session.next.model.switched';
}
