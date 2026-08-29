/// Tolerant accessors used by the `fromJson` factories: a malformed field of
/// the wrong runtime type must yield null (or the fallback), never a `TypeError`
/// that aborts the whole `fetchSessions` parse.
Map<String, dynamic>? _asStringMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;
String? _asString(dynamic value) => value is String ? value : null;
double? _asDouble(dynamic value) => value is num ? value.toDouble() : null;
int? _asInt(dynamic value) => value is num ? value.toInt() : null;

/// Matches the SDK `Session` type. Represents a single conversation session
/// with its metadata, model configuration, token usage, and change summary.
class SessionModel {
  /// Unique identifier for this session.
  final String id;

  /// URL-friendly short identifier for the session.
  final String slug;

  /// The project that this session belongs to.
  final String projectID;

  /// Optional workspace within the project.
  final String? workspaceID;

  /// The working directory associated with the session.
  final String directory;

  /// Optional filesystem path for the session.
  final String? path;

  /// Optional parent session ID, used when a session is forked or branched
  /// from another session.
  final String? parentID;

  /// Human-readable title of the session.
  final String title;

  /// Version string indicating the session format version.
  final String version;

  /// Timestamps for creation, update, compacting, and archiving.
  final SessionTimeInfo time;

  /// Optional summary of file changes (additions, deletions, file count).
  final SessionSummary? summary;

  /// Optional share URL for this session.
  final SessionShare? share;

  /// Optional revert point referencing a message and its snapshot or diff.
  final SessionRevert? revert;

  /// Optional identifier of the agent that created this session.
  final String? agent;

  /// Optional reference to the AI model used (id, provider, variant).
  final SessionModelRef? model;

  /// Optional accumulated monetary cost of the session.
  final double? cost;

  /// Optional breakdown of token usage (input, output, reasoning, cache).
  final SessionTokens? tokens;

  /// Optional arbitrary metadata associated with the session.
  final Map<String, dynamic>? metadata;

  /// Optional list of permission entries for the session.
  final List<dynamic>? permission;

  SessionModel({
    required this.id,
    this.slug = '',
    this.projectID = '',
    this.workspaceID,
    this.directory = '',
    this.path,
    this.parentID,
    this.title = '',
    this.version = '',
    SessionTimeInfo? time,
    this.summary,
    this.share,
    this.revert,
    this.agent,
    this.model,
    this.cost,
    this.tokens,
    this.metadata,
    this.permission,
  }) : time = time ?? SessionTimeInfo();

  /// Creates a [SessionModel] from a JSON map. If the map contains an `info`
  /// key, the inner `info` map is used as the source; otherwise the map itself
  /// is treated as the source. The `directory` is read from the top-level
  /// `directory` field or, for V2 responses, from `location.directory`.
  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final info = _asStringMap(json['info']) ?? json;
    final location = _asStringMap(info['location']);
    final dir =
        _asString(info['directory']) ?? _asString(location?['directory']) ?? '';
    final summaryMap = _asStringMap(info['summary']);
    final shareMap = _asStringMap(info['share']);
    final revertMap = _asStringMap(info['revert']);
    final modelMap = _asStringMap(info['model']);
    final tokensMap = _asStringMap(info['tokens']);
    return SessionModel(
      id: _asString(info['id']) ?? '',
      slug: _asString(info['slug']) ?? '',
      projectID: _asString(info['projectID']) ?? '',
      workspaceID: _asString(info['workspaceID']),
      directory: dir,
      path: _asString(info['path']),
      parentID: _asString(info['parentID']),
      title: _asString(info['title']) ?? '',
      version: _asString(info['version']) ?? '',
      time: SessionTimeInfo.fromJson(_asStringMap(info['time']) ?? const {}),
      summary: summaryMap != null ? SessionSummary.fromJson(summaryMap) : null,
      share: shareMap != null ? SessionShare.fromJson(shareMap) : null,
      revert: revertMap != null ? SessionRevert.fromJson(revertMap) : null,
      agent: _asString(info['agent']),
      model: modelMap != null ? SessionModelRef.fromJson(modelMap) : null,
      cost: _asDouble(info['cost']),
      tokens: tokensMap != null ? SessionTokens.fromJson(tokensMap) : null,
      metadata: _asStringMap(info['metadata']),
      permission: info['permission'] is List
          ? info['permission'] as List
          : null,
    );
  }

  /// Serializes this session to a JSON-compatible map. Null values are omitted.
  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'projectID': projectID,
    if (workspaceID != null) 'workspaceID': workspaceID,
    'directory': directory,
    if (path != null) 'path': path,
    'parentID': parentID,
    'title': title,
    'version': version,
    'time': time.toJson(),
    if (agent != null) 'agent': agent,
    if (model != null) 'model': model!.toJson(),
    if (cost != null) 'cost': cost,
    if (tokens != null) 'tokens': tokens!.toJson(),
    if (metadata != null) 'metadata': metadata,
    if (permission != null) 'permission': permission,
  };

  /// Returns a human-readable display name. Uses [title] if non-empty;
  /// otherwise falls back to the last segment of [directory].
  String get displayName =>
      title.isNotEmpty ? title : directory.split(RegExp(r'[\\/]')).last;
}

/// Reference to the AI model used in a session, including provider info.
class SessionModelRef {
  /// Unique identifier for the model (e.g. `"claude-sonnet-4-20250514"`).
  final String id;

  /// Provider identifier (e.g. `"anthropic"`, `"openai"`).
  final String providerID;

  /// Optional model variant (e.g. `"extended-thinking"`).
  final String? variant;

  SessionModelRef({required this.id, required this.providerID, this.variant});

  /// Creates a [SessionModelRef] from a JSON map.
  factory SessionModelRef.fromJson(Map<String, dynamic> json) =>
      SessionModelRef(
        id: _asString(json['id']) ?? '',
        providerID: _asString(json['providerID']) ?? '',
        variant: _asString(json['variant']),
      );

  /// Serializes this model reference to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'providerID': providerID,
    if (variant != null) 'variant': variant,
  };
}

/// Breakdown of token usage for a session. The `cacheRead` and `cacheWrite`
/// fields are sourced from a nested `cache` object in the JSON payload.
class SessionTokens {
  /// Number of input (prompt) tokens consumed.
  final double input;

  /// Number of output (completion) tokens generated.
  final double output;

  /// Number of reasoning / chain-of-thought tokens consumed.
  final double reasoning;

  /// Number of tokens read from the context cache (from `cache.read`).
  final double cacheRead;

  /// Number of tokens written to the context cache (from `cache.write`).
  final double cacheWrite;

  SessionTokens({
    this.input = 0,
    this.output = 0,
    this.reasoning = 0,
    this.cacheRead = 0,
    this.cacheWrite = 0,
  });

  /// Creates [SessionTokens] from a JSON map. The `cache` field is expected to
  /// be a nested object with `read` and `write` keys.
  factory SessionTokens.fromJson(Map<String, dynamic> json) {
    final cache = _asStringMap(json['cache']) ?? const {};
    return SessionTokens(
      input: _asDouble(json['input']) ?? 0,
      output: _asDouble(json['output']) ?? 0,
      reasoning: _asDouble(json['reasoning']) ?? 0,
      cacheRead: _asDouble(cache['read']) ?? 0,
      cacheWrite: _asDouble(cache['write']) ?? 0,
    );
  }

  /// Serializes token usage to a JSON-compatible map. Cache values are nested
  /// under a `cache` key.
  Map<String, dynamic> toJson() => {
    'input': input,
    'output': output,
    'reasoning': reasoning,
    'cache': {'read': cacheRead, 'write': cacheWrite},
  };
}

/// Summary of file-level changes made during a session.
class SessionSummary {
  /// Number of added lines across all changed files.
  final int additions;

  /// Number of deleted lines across all changed files.
  final int deletions;

  /// Number of files that were modified.
  final int files;

  /// Optional list of individual diff entries.
  final List<dynamic>? diffs;

  SessionSummary({
    this.additions = 0,
    this.deletions = 0,
    this.files = 0,
    this.diffs,
  });

  /// Creates a [SessionSummary] from a JSON map.
  factory SessionSummary.fromJson(Map<String, dynamic> json) => SessionSummary(
    additions: _asInt(json['additions']) ?? 0,
    deletions: _asInt(json['deletions']) ?? 0,
    files: _asInt(json['files']) ?? 0,
    diffs: json['diffs'] is List ? json['diffs'] as List<dynamic> : null,
  );

  /// Serializes this summary to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'additions': additions,
    'deletions': deletions,
    'files': files,
    if (diffs != null) 'diffs': diffs,
  };
}

/// Information for sharing a session via a URL.
class SessionShare {
  /// The share URL for accessing this session.
  final String url;
  SessionShare({required this.url});

  /// Creates a [SessionShare] from a JSON map.
  factory SessionShare.fromJson(Map<String, dynamic> json) =>
      SessionShare(url: _asString(json['url']) ?? '');

  /// Serializes this share info to a JSON-compatible map.
  Map<String, dynamic> toJson() => {'url': url};
}

/// Points to a specific message within the session that can be reverted to.
/// Optionally carries a full [snapshot] or an incremental [diff] of the state
/// at that point.
class SessionRevert {
  /// The message ID that serves as the revert target.
  final String messageID;

  /// Optional part ID within the message for finer-grained revert.
  final String? partID;

  /// Optional snapshot content — the full state at the revert point.
  final String? snapshot;

  /// Optional diff content — incremental changes at the revert point.
  final String? diff;

  SessionRevert({
    required this.messageID,
    this.partID,
    this.snapshot,
    this.diff,
  });

  /// Creates a [SessionRevert] from a JSON map.
  factory SessionRevert.fromJson(Map<String, dynamic> json) => SessionRevert(
    messageID: _asString(json['messageID']) ?? '',
    partID: _asString(json['partID']),
    snapshot: _asString(json['snapshot']),
    diff: _asString(json['diff']),
  );
}

/// Timestamps related to a session's lifecycle: creation, update, compacting,
/// and archiving. All values are Unix epoch milliseconds.
class SessionTimeInfo {
  /// Creation timestamp in Unix milliseconds.
  final int created;

  /// Last-updated timestamp in Unix milliseconds.
  final int updated;

  /// Optional compacting timestamp in Unix milliseconds.
  final int? compacting;

  /// Optional archiving timestamp in Unix milliseconds.
  final int? archived;

  SessionTimeInfo({
    this.created = 0,
    this.updated = 0,
    this.compacting,
    this.archived,
  });

  /// Creates [SessionTimeInfo] from a JSON map.
  factory SessionTimeInfo.fromJson(Map<String, dynamic> json) =>
      SessionTimeInfo(
        created: _asInt(json['created']) ?? 0,
        updated: _asInt(json['updated']) ?? 0,
        compacting: _asInt(json['compacting']),
        archived: _asInt(json['archived']),
      );

  /// Serializes timestamps to a JSON-compatible map. Null values are omitted.
  Map<String, dynamic> toJson() => {
    'created': created,
    'updated': updated,
    if (compacting != null) 'compacting': compacting,
    if (archived != null) 'archived': archived,
  };
}
