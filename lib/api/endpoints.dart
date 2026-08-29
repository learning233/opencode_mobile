/// OpenCode HTTP API endpoints used by this Flutter client.
///
/// Chat / session / SSE / permission / question use v1 flat paths (desktop
/// parity). Some settings surfaces still use `/api/*` (Integration, PTY,
/// permission.saved, reference). This app does not implement dual-protocol
/// detection within the chat pipeline.
class ApiEndpoints {
  static const String baseLocalUrl = 'http://localhost:4096';

  // ── Health / Events ──────────────────────────────────────────

  /// GET server health (current protocol probe).
  static const String health = '/api/health';

  /// GET instance SSE event stream (v1).
  static const String sseEvent = '/event';

  // ── Session ───────────────────────────────────────────────────

  /// GET list sessions | POST create session.
  static const String sessions = '/session';

  /// GET global session status map.
  static const String sessionStatus = '/session/status';

  /// GET session detail.
  static String sessionDetail(String id) => '/session/$id';

  /// DELETE session and all data.
  static String sessionDelete(String id) => '/session/$id';

  /// GET session messages.
  static String sessionMessages(String id) => '/session/$id/message';

  /// POST create and async-send a prompt (v1).
  static String sessionPromptAsync(String id) => '/session/$id/prompt_async';

  /// GET a single message.
  static String sessionMessage(String sid, String mid) =>
      '/session/$sid/message/$mid';

  /// POST abort active execution (v1).
  static String sessionAbort(String id) => '/session/$id/abort';

  /// POST compact / summarize session context (v1).
  static String sessionSummarize(String id) => '/session/$id/summarize';

  /// GET session todo list (legacy v1; desktop parity).
  static String sessionTodo(String id) => '/session/$id/todo';

  /// GET 指定消息的文件变动 Diff（v1 接口）。
  /// 注意：OpenCode 后端无全局 Session 级别的 Diff 接口，此接口为 Message 级别，
  /// 必须在 queryParameters 中传入 `messageID`，不传则后端直接返回 `[]`。
  static String sessionDiff(String id) => '/session/$id/diff';

  /// POST fork session at a message (legacy v1, desktop parity).
  static String sessionFork(String id) => '/session/$id/fork';

  /// POST revert to a message (legacy v1, desktop parity).
  static String sessionRevert(String id) => '/session/$id/revert';

  /// POST unrevert (legacy v1, desktop parity).
  static String sessionUnrevert(String id) => '/session/$id/unrevert';

  // ── Provider / Model ──────────────────────────────────────────

  /// GET providers with nested models (v1; used by chat model picker).
  static const String configProviders = '/config/providers';

  /// GET list providers.
  static const String providers = '/provider';

  /// GET auth methods for all providers.
  static const String providerAuth = '/provider/auth';

  /// PUT set provider auth credentials | DELETE remove provider auth credentials.
  static String authSet(String providerId) => '/auth/$providerId';

  static String authRemove(String providerId) => '/auth/$providerId';

  /// POST start OAuth connect.
  static String providerOauthAuthorize(String id) =>
      '/provider/$id/oauth/authorize';

  /// POST complete OAuth callback.
  static String providerOauthCallback(String id) =>
      '/provider/$id/oauth/callback';

  // ── Project ───────────────────────────────────────────────────

  /// GET list projects.
  ///
  /// Still unprefixed: only `/project/current` and `/project/:id/directories`
  /// are used (instance HttpApi).
  /// Desktop `project.list` likewise goes through legacy `GET /project`.
  static const String projects = '/project';

  /// GET current project for a location (instance HttpApi).
  static const String projectCurrent = '/project/current';

  // ── VCS (版本控制) ───────────────────────────────────────────

  /// GET workspace diff (`GET /vcs/diff?mode=git|branch&context=...`).
  ///
  /// 注意：OpenCode 后端真实接口路径为 `/vcs/diff`（v1 平路径），
  /// 返回 VcsFileDiff[]（每项含全文 patch / additions / deletions / status）。
  static const String vcsDiff = '/vcs/diff';

  // ── Filesystem (文件系统) ──────────────────────────────────────

  /// GET 获取目录文件列表 (`GET /file?path=...`)。
  ///
  /// 注意：OpenCode 后端真实文件列表接口路径为 `/file`，而非原占位符 `/api/fs/list`。
  static const String fsList = '/file';

  /// GET 读取文件文本内容 (`GET /file/content?path=...`)。
  ///
  /// 注意：OpenCode 后端真实文件内容接口路径为 `/file/content`，而非原占位符 `/api/fs/read`。
  static String fsRead(String path) => '/file/content';

  /// GET text search across project via ripgrep (`GET /find?pattern=...`).
  static const String findText = '/find';

  /// GET find files or directories by name pattern (`GET /find/file?query=...`).
  static const String findFile = '/find/file';

  /// GET find symbols via LSP (`GET /find/symbol?query=...`).
  static const String findSymbol = '/find/symbol';

  /// GET server path info (home, cwd, etc.).
  static const String path = '/path';

  /// GET read file content (legacy v1; absolute path for global AGENTS.md).
  static const String fileContent = '/file/content';

  // ── MCP ───────────────────────────────────────────────────────

  /// GET MCP server status map | POST create MCP server.
  static const String mcp = '/mcp';

  /// POST connect an MCP server.
  static String mcpConnect(String name) => '/mcp/$name/connect';

  /// POST disconnect an MCP server.
  static String mcpDisconnect(String name) => '/mcp/$name/disconnect';

  /// POST start OAuth for an MCP server.
  static String mcpAuthStart(String name) => '/mcp/$name/auth';

  /// POST complete OAuth callback for an MCP server.
  static String mcpAuthCallback(String name) => '/mcp/$name/auth/callback';

  /// POST authenticate (browser flow) for an MCP server.
  static String mcpAuthAuthenticate(String name) =>
      '/mcp/$name/auth/authenticate';

  /// DELETE stored OAuth credentials for an MCP server.
  static String mcpAuthRemove(String name) => '/mcp/$name/auth';

  // ── PTY (v1 flat routes) ──────────────────────────────────────

  /// GET available shell executables (v1 only, no v2 equivalent).
  static const String shells = '/pty/shells';

  // /// GET list PTYs | POST create PTY (v1 flat route).
  // static const String pty = '/pty';

  // /// GET|PUT|DELETE PTY session (v1).
  // static String ptyDetail(String id) => '/pty/$id';

  // /// WebSocket upgrade path for PTY (v1).
  // static String ptyWs(String id) => '/pty/$id';

  // /// GET connect to PTY (WebSocket v1).
  // static String ptyConnect(String id) => '/pty/$id/connect';

  // /// POST obtain PTY connect token (v1).
  // static String ptyConnectToken(String id) => '/pty/$id/connect-token';

  // ── PTY (v2 /api routes) ──────────────────────────────────────

  /// GET list PTYs | POST create PTY (v2 /api route).
  static const String ptyV2 = '/api/pty';

  /// GET|PUT|DELETE PTY session (v2 /api route).
  static String ptyDetailV2(String id) => '/api/pty/$id';

  /// GET connect to PTY (WebSocket v2 /api route).
  static String ptyConnectV2(String id) => '/api/pty/$id/connect';

  /// POST obtain PTY connect token (v2 /api route).
  static String ptyConnectTokenV2(String id) => '/api/pty/$id/connect-token';

  // ── Question ──────────────────────────────────────────────────

  /// GET pending question requests (v1).
  static const String questions = '/question';

  /// POST reply to a question (v1).
  static String questionReply(String requestId) => '/question/$requestId/reply';

  /// POST reject a question (v1).
  static String questionReject(String requestId) =>
      '/question/$requestId/reject';

  // ── Permission ────────────────────────────────────────────────

  /// GET pending permission requests (v1).
  static const String permissions = '/permission';

  /// GET saved permissions (v2-only surface).
  static const String permissionsSaved = '/api/permission/saved';

  /// DELETE a saved permission.
  static String permissionSavedRemove(String id) => '/api/permission/saved/$id';

  /// POST reply to a permission request (v1).
  static String permissionReply(String requestId) =>
      '/permission/$requestId/reply';

  // ── Config / Settings ─────────────────────────────────────────

  /// POST dispose current instance (trigger provider reload).
  static const String instanceDispose = '/instance/dispose';

  /// POST dispose global state.
  static const String globalDispose = '/global/dispose';

  /// GET | PATCH global configuration (legacy v1 route).
  static const String globalConfig = '/global/config';

  /// GET | PATCH project configuration (legacy v1 route).
  static const String projectConfig = '/config';

  /// GET list agent definitions.
  static const String agents = '/api/agent';

  /// GET list skills.
  static const String skills = '/api/skill';

  /// GET list slash commands.
  static const String commands = '/api/command';

  /// GET LSP server configuration.
  static const String lsp = '/lsp';

  /// GET formatter status list.
  static const String formatter = '/formatter';

  /// GET reference list (v2).
  static const String reference = '/api/reference';

  /// POST create MCP server (list remains GET [mcp]).
  static const String mcpCreate = '/mcp';
}
