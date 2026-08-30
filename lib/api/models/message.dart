import 'dart:convert';

import 'snapshot_file_diff.dart';
import 'tool_diff_parser.dart';

/// The role of a message sender — either the human user or the AI assistant.
enum MessageRole {
  /// Message from the human user.
  user,

  /// Message from the AI assistant.
  assistant,
}

/// Deserializes a JSON string to [MessageRole].
/// Returns [MessageRole.user] for `'user'`, otherwise [MessageRole.assistant].
MessageRole messageRoleFromJson(String v) =>
    v == 'user' ? MessageRole.user : MessageRole.assistant;

/// Serializes [MessageRole] to its JSON string representation.
String messageRoleToJson(MessageRole r) =>
    r == MessageRole.user ? 'user' : 'assistant';

/// Discriminated type tag for a message [Part].
enum PartType {
  /// Plain text content.
  text,

  /// AI reasoning / chain-of-thought text.
  reasoning,

  /// Tool call invocation or result.
  tool,

  /// Sub-task delegated to a sub-agent.
  subtask,

  /// File attachment (image, document, etc.).
  file,

  /// Marks the start of a processing step.
  stepStart,

  /// Marks the completion of a processing step.
  stepFinish,

  /// A point-in-time snapshot of the workspace.
  snapshot,

  /// A file patch or diff.
  patch,

  /// Agent designation block.
  agent,

  /// Retry attempt of a previous step.
  retry,

  /// Conversation compaction / summarization marker.
  compaction,
}

/// Deserializes a JSON string to [PartType].
/// Handles the kebab-case values `'step-start'` and `'step-finish'`.
/// Returns [PartType.text] for unknown values.
PartType partTypeFromJson(String v) {
  switch (v) {
    case 'text':
      return PartType.text;
    case 'reasoning':
      return PartType.reasoning;
    case 'tool':
      return PartType.tool;
    case 'subtask':
      return PartType.subtask;
    case 'file':
      return PartType.file;
    case 'step-start':
      return PartType.stepStart;
    case 'step-finish':
      return PartType.stepFinish;
    case 'snapshot':
      return PartType.snapshot;
    case 'patch':
      return PartType.patch;
    case 'agent':
      return PartType.agent;
    case 'retry':
      return PartType.retry;
    case 'compaction':
      return PartType.compaction;
    default:
      return PartType.text;
  }
}

/// Serializes [PartType] to its JSON string representation.
/// [PartType.stepStart] and [PartType.stepFinish] are converted to
/// `'step-start'` and `'step-finish'` respectively; all others use [name].
String partTypeToJson(PartType t) {
  switch (t) {
    case PartType.stepStart:
      return 'step-start';
    case PartType.stepFinish:
      return 'step-finish';
    default:
      return t.name;
  }
}

/// Execution status of a tool call.
enum ToolStateStatus {
  /// Tool call is queued and not yet started.
  pending,

  /// Tool is currently executing.
  running,

  /// Tool completed successfully.
  completed,

  /// Tool encountered an error.
  error,
}

/// Deserializes a JSON string to [ToolStateStatus].
/// Returns [ToolStateStatus.pending] for unknown values.
ToolStateStatus toolStatusFromJson(String v) {
  switch (v) {
    case 'pending':
      return ToolStateStatus.pending;
    case 'running':
      return ToolStateStatus.running;
    case 'completed':
      return ToolStateStatus.completed;
    case 'error':
      return ToolStateStatus.error;
    default:
      return ToolStateStatus.pending;
  }
}

/// A single part within a [MessageModel].
///
/// Each part has a [type] discriminator and carries the complete raw JSON
/// payload ([raw]). Typed accessors (e.g. [text], [toolName], [toolStatus])
/// read from [raw] and return safe defaults when the expected keys are absent.
class Part {
  /// Unique identifier for this part.
  final String id;

  /// The session this part belongs to.
  final String sessionID;

  /// The parent message this part belongs to.
  final String messageID;

  /// Discriminated type tag indicating what kind of payload this part holds.
  final PartType type;

  /// The complete raw JSON map for this part.
  ///
  /// All typed accessors read from this map and return safe defaults when
  /// the expected keys are missing.
  final Map<String, dynamic> raw;

  /// Creates a [Part] with the given fields.
  Part({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.type,
    required this.raw,
  });

  /// Constructs a [Part] from a JSON map.
  ///
  /// The [type] is parsed via [partTypeFromJson]. Missing string fields
  /// default to `''` and missing IDs default to `''`.
  factory Part.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type']?.toString() ?? 'text';
    final type = partTypeFromJson(typeStr);
    return Part(
      id: json['id']?.toString() ?? '',
      sessionID: json['sessionID']?.toString() ?? '',
      messageID: json['messageID']?.toString() ?? '',
      type: type,
      raw: Map<String, dynamic>.from(json),
    );
  }

  /// Returns the raw JSON map (compatible with the wire format).
  Map<String, dynamic> toJson() => raw;

  // ── typed accessors ──

  /// The text content of a [PartType.text] or generic part.
  /// Reads from `raw['text']`.
  String get text {
    final v = raw['text'];
    return v is String ? v : (v?.toString() ?? '');
  }

  // ── ToolPart accessors ──

  /// The name of the tool being called, from `raw['tool']`.
  String get toolName {
    final v = raw['tool'] ?? raw['name'];
    return v is String ? v : (v?.toString() ?? '');
  }

  /// The unique call identifier for this tool invocation, from `raw['callID']`.
  String get callID => raw['callID'] as String? ?? '';

  /// The execution status of the tool call, read from `raw['state']['status']`.
  /// Returns [ToolStateStatus.pending] when the state is absent or malformed.
  ToolStateStatus get toolStatus {
    final s = raw['state'];
    if (s is Map) return toolStatusFromJson(s['status'] as String? ?? '');
    return ToolStateStatus.pending;
  }

  /// The input arguments sent to the tool, from `raw['state']['input']`.
  Map<String, dynamic> get toolInput {
    final s = raw['state'];
    if (s is Map) {
      final input = s['input'];
      if (input is Map) return Map<String, dynamic>.from(input);
    }
    return {};
  }

  /// [toolOutput] 的 JSON 编码缓存（Part 不可变，更新即整体替换实例）。
  String? _toolOutputJson;

  /// The output produced by the tool, from `raw['state']['output']`.
  /// If the output is a [Map] it is JSON-encoded; a [String] is returned as-is.
  /// Map 输出的编码结果按实例缓存（Part 不可变，更新即整体替换），工具卡片
  /// 每次 build 访问大 output 时不再重复 jsonEncode。
  String get toolOutput {
    final s = raw['state'];
    if (s is Map) {
      final output = s['output'];
      if (output is String) return output;
      if (output is Map) return _toolOutputJson ??= jsonEncode(output);
    }
    return '';
  }

  /// The error message if the tool failed, from `raw['state']['error']`.
  String get toolError {
    final s = raw['state'];
    if (s is Map) return s['error'] as String? ?? '';
    return '';
  }

  // ── ReasoningPart accessors ──

  /// The raw reasoning / chain-of-thought text, from `raw['text']`.
  String get reasoningText => raw['text'] as String? ?? '';

  /// Whether the reasoning block has completed.
  /// Checks for a non-null `end` timestamp in `raw['time']`.
  bool get reasoningCompleted {
    final t = raw['time'];
    if (t is Map) return t['end'] != null;
    return false;
  }

  // ── StepStartPart accessors ──

  /// The snapshot identifier at the start of a step, from `raw['snapshot']`.
  String get snapshot => raw['snapshot'] as String? ?? '';

  // ── StepFinishPart accessors ──

  /// The reason the step finished, from `raw['reason']`.
  String get finishReason => raw['reason'] as String? ?? '';

  /// The total cost of the step, from `raw['cost']`.
  double get finishCost => (raw['cost'] as num?)?.toDouble() ?? 0;

  /// Token usage breakdown for the step, from `raw['tokens']`.
  Map<String, dynamic>? get finishTokens =>
      raw['tokens'] as Map<String, dynamic>?;

  /// The post-step snapshot, from `raw['snapshot']`.
  String? get finishSnapshot => raw['snapshot'] as String?;

  // ── SubtaskPart accessors ──

  /// The prompt passed to the sub-agent, from `raw['prompt']`.
  String get subtaskPrompt =>
      (raw['prompt'] ?? toolInput['prompt']) as String? ?? '';

  /// A human-readable description of the subtask, from `raw['description']`.
  String get subtaskDescription =>
      (raw['description'] ?? toolInput['description']) as String? ?? '';

  /// The name of the agent assigned to the subtask, from `raw['agent']`.
  String get subtaskAgent =>
      (raw['agent'] ?? toolInput['agent']) as String? ?? '';

  /// The model configuration used for the subtask, from `raw['model']`.
  Map<String, dynamic>? get subtaskModel =>
      (raw['model'] ?? toolInput['model']) as Map<String, dynamic>?;

  /// The command that triggered the subtask, from `raw['command']`.
  String get subtaskCommand =>
      (raw['command'] ?? toolInput['command']) as String? ?? '';

  // ── CompactionPart accessors ──

  /// Whether the compaction was triggered automatically, from `raw['auto']`.
  bool get compactionAuto => raw['auto'] as bool? ?? false;

  // ── AgentPart accessors ──

  /// The name of the agent, from `raw['name']`.
  String get agentName => raw['name'] as String? ?? '';

  // ── RetryPart accessors ──

  /// The attempt number of this retry, from `raw['attempt']`.
  int get retryAttempt => raw['attempt'] as int? ?? 0;

  // ── FilePart accessors ──

  /// The URL or path of the attached file, from `raw['url']`.
  String get fileUrl => raw['url'] as String? ?? '';

  /// The MIME type of the attached file, from `raw['mime']`.
  String get fileMime => raw['mime'] as String? ?? '';

  /// The display name of the attached file, from `raw['filename']`.
  String get fileName => raw['filename'] as String? ?? '';

  // ── PatchPart accessors ──

  /// The hash identifying this patch, from `raw['hash']`.
  String get patchHash => raw['hash'] as String? ?? '';

  /// The list of file paths affected by this patch, from `raw['files']`.
  /// 这个参数并发 session 会乱，他是按时间来的，不分session
  List<String> get patchFiles => (raw['files'] as List?)?.cast<String>() ?? [];

  // ── Provider metadata ──

  /// Provider-specific metadata (filediff, diagnostics, etc.)
  /// stored in `raw['state']['metadata']`.
  Map<String, dynamic>? get toolMetadata {
    final state = raw['state'];
    if (state is Map) {
      final m = state['metadata'];
      if (m is Map) return m as Map<String, dynamic>;
    }
    return null;
  }

  // ── Source Range (for inline file & agent highlights) ──

  /// The source range map from `raw['source']`, used for inline file and
  /// agent highlight annotations.
  Map<String, dynamic>? get source => raw['source'] as Map<String, dynamic>?;

  /// The start position of the source range.
  /// Supports two shapes: `source.start` (direct) and
  /// `source.text.start` (nested under a `text` key).
  int? get sourceStart {
    final s = source;
    if (s == null) return null;
    if (s['text'] is Map) {
      return s['text']['start'] as int?;
    }
    return s['start'] as int?;
  }

  /// The end position of the source range.
  /// Supports two shapes: `source.end` (direct) and
  /// `source.text.end` (nested under a `text` key).
  int? get sourceEnd {
    final s = source;
    if (s == null) return null;
    if (s['text'] is Map) {
      return s['text']['end'] as int?;
    }
    return s['end'] as int?;
  }
}

/// A message in a conversation, consisting of a [role] and a list of [Part]s.
///
/// Parsed from the wire format where top-level fields (`role`, `parts`) may
/// be nested under an `info` sub-object. The full original JSON is preserved
/// in [raw].
class MessageModel {
  /// Unique identifier for this message.
  final String id;

  /// The session this message belongs to.
  final String sessionID;

  /// Whether this message was sent by the user or the assistant.
  final MessageRole role;

  /// The ordered list of content parts that make up this message.
  final List<Part> parts;

  /// The complete raw JSON map for this message.
  ///
  /// All metadata accessors read from this map, falling back to the `info`
  /// sub-object when a top-level key is absent.
  final Map<String, dynamic> raw;

  /// Creates a [MessageModel] with the given fields.
  MessageModel({
    required this.id,
    this.sessionID = '',
    required this.role,
    List<Part>? parts,
    this.raw = const {},
  }) : parts = parts ?? [];

  /// Constructs a [MessageModel] from a JSON map.
  ///
  /// Supports both legacy (`role` + `parts`) and v2 (`type` + `content`)
  /// message shapes returned by `/api/session/:id/message`.
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final info = json['info'] is Map
        ? Map<String, dynamic>.from(json['info'] as Map)
        : null;
    final effective = info ?? json;

    // role: legacy `role`, or v2 `type` when it is user/assistant
    final typeStr = effective['type']?.toString() ?? json['type']?.toString();
    final roleStr =
        effective['role']?.toString() ??
        json['role']?.toString() ??
        (typeStr == 'user' || typeStr == 'assistant' ? typeStr : null) ??
        'user';
    final actualRole = messageRoleFromJson(roleStr);

    // parts: legacy `parts`, or v2 `content` array
    final partsRaw =
        effective['parts'] ??
        json['parts'] ??
        effective['content'] ??
        json['content'];
    final parts = <Part>[];
    if (partsRaw is List) {
      for (final p in partsRaw) {
        if (p is Map) {
          parts.add(Part.fromJson(Map<String, dynamic>.from(p)));
        }
      }
    }

    // User messages may only have top-level `text`
    if (parts.isEmpty) {
      final textVal = effective['text'] ?? json['text'];
      if (textVal is String && textVal.isNotEmpty) {
        final partId = 'text-0';
        parts.add(
          Part(
            id: partId,
            sessionID: json['sessionID']?.toString() ?? '',
            messageID: json['id']?.toString() ?? '',
            type: PartType.text,
            raw: {'id': partId, 'type': 'text', 'text': textVal},
          ),
        );
      }
    }

    final id = json['id']?.toString() ?? info?['id']?.toString() ?? '';
    final sessionID =
        json['sessionID']?.toString() ?? info?['sessionID']?.toString() ?? '';

    return MessageModel(
      id: id,
      sessionID: sessionID,
      role: actualRole,
      parts: parts,
      raw: Map<String, dynamic>.from(json),
    );
  }

  /// Returns the raw JSON map (compatible with the wire format).
  Map<String, dynamic> toJson() => raw;

  // ── Metadata accessors ──

  /// Model metadata used for this message, from `raw['model']` or
  /// `raw['info']['model']`.
  Map<String, dynamic>? get model =>
      (raw['model'] ?? raw['info']?['model']) as Map<String, dynamic>?;

  /// Timing information for this message, from `raw['time']` or
  /// `raw['info']['time']`.
  Map<String, dynamic>? get time =>
      (raw['time'] ?? raw['info']?['time']) as Map<String, dynamic>?;

  /// The agent name associated with this message, from `raw['agent']` or
  /// `raw['info']['agent']`. Also accepts v2 `agents: [{name}]`.
  String get agent {
    final a = raw['agent'] ?? raw['info']?['agent'];
    if (a is String && a.isNotEmpty) return a;
    final agents = raw['agents'];
    if (agents is List && agents.isNotEmpty) {
      final first = agents.first;
      if (first is Map && first['name'] != null) {
        return first['name'].toString();
      }
      return first.toString();
    }
    return '';
  }

  /// Parent message id (assistant → user), from `raw['parentID']` or
  /// `raw['info']['parentID']`.
  String? get parentID {
    final value = raw['parentID'] ?? raw['info']?['parentID'];
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  /// Per-message file change summary (user messages only).
  ///
  /// From `summary.diffs` / `info.summary.diffs` produced by OpenCode
  /// `SessionSummary.summarize`.
  List<SnapshotFileDiff> get summaryDiffs {
    final summary = raw['summary'] ?? raw['info']?['summary'];
    if (summary is! Map) return const [];
    final diffs = summary['diffs'];
    if (diffs is! List || diffs.isEmpty) return const [];
    return diffs
        .whereType<Map>()
        .map((e) => SnapshotFileDiff.fromJson(Map<String, dynamic>.from(e)))
        .where((d) => d.file.isNotEmpty)
        .toList();
  }

  /// Compute file diffs from tool parts (edit / write / apply_patch / patch).
  ///
  /// Uses [ToolDiffParser] model to parse tool metadata/input by tool type,
  /// and merges file diffs across all tool parts in this message.
  List<SnapshotFileDiff> get toolDiffs {
    final diffMap = <String, SnapshotFileDiff>{};
    for (final part in parts) {
      final partDiffs = ToolDiffParser.parse(part);
      for (final d in partDiffs) {
        if (d.file.isEmpty) continue;
        if (diffMap.containsKey(d.file)) {
          diffMap[d.file] = SnapshotFileDiff.merge(diffMap[d.file]!, d);
        } else {
          diffMap[d.file] = d;
        }
      }
    }
    return diffMap.values.toList();
  }

  /// The combined text content of this message.
  ///
  /// First attempts to join the [text] of all [PartType.text] parts.
  /// Falls back to string `text` / `content` fields (never casts a List).
  String get content {
    final partsContent = parts
        .where((p) => p.type == PartType.text)
        .map((p) => p.text)
        .join('\n');
    if (partsContent.isNotEmpty) return partsContent;

    final effective = raw['info'] is Map
        ? Map<String, dynamic>.from(raw['info'] as Map)
        : raw;
    final textVal = effective['text'];
    if (textVal is String && textVal.isNotEmpty) return textVal;

    final contentVal = effective['content'];
    if (contentVal is String && contentVal.isNotEmpty) return contentVal;
    if (contentVal is List) {
      final buf = StringBuffer();
      for (final item in contentVal) {
        if (item is Map) {
          final t = item['text'];
          if (t is String && t.isNotEmpty) {
            if (buf.isNotEmpty) buf.writeln();
            buf.write(t);
          }
        } else if (item is String && item.isNotEmpty) {
          if (buf.isNotEmpty) buf.writeln();
          buf.write(item);
        }
      }
      return buf.toString();
    }

    return '';
  }

  /// Whether this entry is a chat message (user/assistant), not metadata
  /// events like `agent-switched`.
  bool get isChatMessage {
    final t = raw['type']?.toString();
    if (t == null || t.isEmpty) return true;
    return t == 'user' || t == 'assistant' || raw.containsKey('role');
  }
}
