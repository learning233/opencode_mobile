# OpenCode Sidecar API 端点文档

> **基础 URL**: `http://localhost:4096`
> **认证方式**: Basic Auth（用户名: `opencode`, 密码: 启动时指定）
> **版本说明**: v2 为当前活跃端点（基于 Effect HttpApi），v1 legacy 为旧版端点

---

## 目录

1. [Global — 全局控制](#1-global--全局控制)
2. [Auth — 认证](#2-auth--认证)
3. [Session — 会话管理](#3-session--会话管理)
4. [Project Copy — 项目克隆](#4-project-copy--项目克隆)
5. [Location — 位置信息](#5-location--位置信息)
6. [Config — 项目级配置](#6-config--项目级配置)
7. [Provider — AI Provider 管理](#7-provider--ai-provider-管理)
8. [Integration / Credential](#8-integration--credential)
9. [Projects — 项目管理](#9-projects--项目管理)
10. [Events — SSE 事件流](#10-events--sse-事件流)
11. [File — 文件操作](#11-file--文件操作)
12. [Find — 搜索](#12-find--搜索)
13. [VCS — 版本控制（已废弃）](#13-vcs--版本控制已废弃)
14. [Instance — 实例管理](#14-instance--实例管理)
15. [Command / Agent / Skill / Model — 工具列表](#15-command--agent--skill--model--工具列表)
16. [Reference — 引用](#16-reference--引用)
17. [LSP / Formatter — 语言服务 & 格式化](#17-lsp--formatter--语言服务--格式化)
18. [MCP — Model Context Protocol](#18-mcp--model-context-protocol)
19. [PTY — 伪终端](#19-pty--伪终端)
20. [Question — 问答交互](#20-question--问答交互)
21. [Permission — 权限请求](#21-permission--权限请求)
22. [Log — 日志](#22-log--日志)
23. [Sync — 同步](#23-sync--同步)
24. [TUI — 终端 UI 控制](#24-tui--终端-ui-控制)
25. [Experimental — 实验性功能](#25-experimental--实验性功能)

---

## 1. Global — 全局控制

| 路径 | 方法 | 查询参数 | 请求体 | 响应 | 版本 | 状态 |
|------|------|----------|--------|------|------|------|
| `/api/health` | GET | — | — | `{ healthy: true }` | v2 | active |
| `/api/event` | GET | — | — | **SSE 流**: `V2Event`（union，如 `server.connected` 等） | v2 | active |
| `/global/config` | GET | — | — | `GlobalConfig` | v1 | active |
| `/global/config` | PATCH | — | `{ ...GlobalConfig 字段 }` | `GlobalConfig` | v1 | active |
| `/global/dispose` | POST | — | — | `void` | v1 | active |
| `/global/upgrade` | POST | — | `{ version?: string }` | `void` | v1 | active |

---

## 2. Auth — 认证

| 路径 | 方法 | 路径参数 | 查询参数 | 请求体 | 响应 | 版本 | 状态 |
|------|------|----------|----------|--------|------|------|------|
| `/api/integration/{integrationID}/connect/key` | POST | `integrationID: Integration.ID` | `location?: { directory?: string, workspace?: string }` | `{ key: string, label?: string }` | `NoContent` | v2 | active |
| `/auth/{providerId}` | DELETE | `providerId: string` | — | — | `void` | v1 | active |

---

## 3. Session — 会话管理

| 路径 | 方法 | 路径参数 | 查询参数 | 请求体 | 响应 | 版本 | 状态 |
|------|------|----------|----------|--------|------|------|------|
| `/api/session` | GET | — | `workspace?: Workspace.ID`, `limit?: PositiveInt`, `order?: "asc" \| "desc"`, `search?: string`, `directory?: AbsolutePath`, `project?: Project.ID`, `subpath?: RelativePath`, `cursor?: SessionsCursor`（base64url） | — | `{ data: Session.Info[], cursor: { previous?: string, next?: string } }` | v2 | active |
| `/api/session` | POST | — | — | `{ id?: Session.ID, agent?: Agent.ID, model?: Model.Ref, location?: Location.Ref }` | `{ data: Session.Info }` | v2 | active |
| `/api/session/active` | GET | — | — | — | `{ data: Record<Session.ID, { type: "running" }> }` | v2 | active |
| `/api/session/{sessionID}` | GET | `sessionID: Session.ID` | — | — | `{ data: Session.Info }` | v2 | active |
| `/api/session/{sessionID}` | PATCH | `sessionID: Session.ID` | — | `{ ...Session 可更新字段 }` | `{ data: Session.Info }` | v2 | active |
| `/session/{id}` | DELETE | `id: string` | — | — | `void` | v1 | active |
| `/session/{id}/children` | GET | `id: string` | — | — | `Session.Info[]` | v1 | legacy |
| `/session/{id}/todo` | GET | `id: string` | — | — | `Todo[]` | v1 | legacy |
| `/session/{id}/diff` | GET | `id: string`, `messageID: string`（必填） | — | — | `SnapshotFileDiff[]` | v1 | **active**（消息变更文件卡 sheet 与 Review message scope 的数据源，见 `session_controller.fetchMessageDiff`；服务端 `SessionSummary.diff` 无 messageID 时返回空数组） |
| `/api/session/{sessionID}/message` | GET | `sessionID: Session.ID` | `limit?: number (1-200)`, `order?: "asc" \| "desc"`, `cursor?: string` | — | `{ data: SessionMessage.Message[], cursor: { previous?: string, next?: string } }` | v2 | active |
| `/api/session/{sessionID}/message` | POST | `sessionID: Session.ID` | — | `{ ...message content }` | `{ data: SessionMessage.Message }` | v2 | active |
| `/api/session/{sessionID}/prompt` | POST | `sessionID: Session.ID` | — | `{ id?: SessionMessage.ID, prompt: PromptInput.Prompt, delivery?: SessionInput.Delivery, resume?: boolean }` | `{ data: SessionInput.Admitted }` | v2 | active |
| `/api/session/{sid}/message/{mid}` | GET | `sid: Session.ID, mid: SessionMessage.ID` | — | — | `{ data: SessionMessage.Message }` | v2 | active |
| `/session/{sid}/message/{mid}/part/{pid}` | PATCH | `sid, mid, pid: string` | — | `{ ...part 内容 }` | `void` | v1 | legacy |
| `/session/{sid}/message/{mid}/part/{pid}` | DELETE | `sid, mid, pid: string` | — | — | `void` | v1 | legacy |
| `/session/{id}/fork` | POST | `id: string` | — | `{ messageID: string }` | `Session.Info` | v1 | legacy |
| `/session/{id}/abort` | POST | `id: string` | — | — | `void` | v1 | legacy |
| `/session/{id}/init` | POST | `id: string` | — | — | `void` | v1 | legacy |
| `/session/{id}/share` | POST | `id: string` | — | — | `{ shareUrl: string }` | v1 | legacy |
| `/session/{id}/share` | DELETE | `id: string` | — | — | `void` | v1 | legacy |
| `/api/session/{sessionID}/compact` | POST | `sessionID: Session.ID` | — | — | `NoContent` | v2 | active |
| `/session/{id}/command` | POST | `id: string` | — | `{ command: string, args?: string[] }` | `void` | v1 | legacy |
| `/session/{id}/shell` | POST | `id: string` | — | `{ command: string }` | `void` | v1 | legacy |
| `/session/{id}/revert` | POST | `id: string` | — | `{ messageID: string }` | `void` | v1 | legacy |
| `/session/{id}/unrevert` | POST | `id: string` | — | — | `void` | v1 | legacy |
| `/session/{sid}/permissions/{pid}` | POST | `sid, pid: string` | — | `{ reply: Permission.Reply }` | `void` | v1 | legacy |
| `/experimental/control-plane/move-session` | POST | — | — | `MoveSessionPayload`（含 sessionID, directory） | `NoContent` | v1 | experimental |
| `/api/session/{sessionID}/interrupt` | POST | `sessionID: Session.ID` | — | — | `NoContent` | v2 | active |
| `/api/session/{sessionID}/agent` | POST | `sessionID: Session.ID` | — | `{ agent: Agent.ID }` | `NoContent` | v2 | active |
| `/api/session/{sessionID}/model` | POST | `sessionID: Session.ID` | — | `{ model: Model.Ref }` | `NoContent` | v2 | active |
| `/api/session/{sessionID}/history` | GET | `sessionID: Session.ID` | `limit?: PositiveInt (max 100)`, `after?: NonNegativeInt` | — | `{ data: SessionEvent.Durable[], hasMore: boolean }` | v2 | active |
| `/api/session/{sessionID}/event` | GET | `sessionID: Session.ID` | `after?: NonNegativeInt` | — | **SSE 流**: `SessionEvent.Durable` | v2 | active |
| `/api/session/{sessionID}/revert/stage` | POST | `sessionID: Session.ID` | — | `{ messageID: SessionMessage.ID, files?: boolean }` | `{ data: Revert.State }` | v2 | active |
| `/api/session/{sessionID}/revert/clear` | POST | `sessionID: Session.ID` | — | — | `NoContent` | v2 | active |
| `/api/session/{sessionID}/revert/commit` | POST | `sessionID: Session.ID` | — | — | `NoContent` | v2 | active |
| `/api/session/{sessionID}/context` | GET | `sessionID: Session.ID` | — | — | `{ data: SessionMessage.Message[] }` | v2 | active |
| `/api/session/{sessionID}/wait` | POST | `sessionID: Session.ID` | — | — | `NoContent` | v2 | active |

---

## 4. Project Copy — 项目克隆

| 路径 | 方法 | 路径参数 | 查询参数 | 请求体 | 响应 | 版本 | 状态 |
|------|------|----------|----------|--------|------|------|------|
| `/experimental/project/{projectID}/copy` | POST | `projectID: Project.ID` | `location?: { directory?: string, workspace?: string }` | `ProjectCopy.CreateInput`（不含 projectID, sourceDirectory） | `ProjectCopy.Copy` | v1 | experimental |
| `/experimental/project/{projectID}/copy` | DELETE | `projectID: Project.ID` | `location?: { directory?: string, workspace?: string }` | `ProjectCopy.RemoveInput`（不含 projectID） | `NoContent` | v1 | experimental |
| `/experimental/project/{projectID}/copy/refresh` | POST | `projectID: Project.ID` | `location?: { directory?: string, workspace?: string }` | — | `NoContent` | v1 | experimental |

---

## 5. Location — 位置信息

| 路径 | 方法 | 查询参数 | 响应 | 版本 | 状态 |
|------|------|----------|------|------|------|
| `/api/location` | GET | `location?: { directory?: string, workspace?: string }` | `Location.Info` | v2 | active |

---

## 6. Config — 项目级配置

| 路径 | 方法 | 请求体 | 响应 | 版本 | 状态 |
|------|------|--------|------|------|------|
| `/config` | GET | — | `ProjectConfig` | v1 | active |
| `/config` | PATCH | `{ ...ProjectConfig 可更新字段 }` | `ProjectConfig` | v1 | active |
| `/config/providers` | GET | — | `{ providers: Provider.Info[], defaultModels: ... }` | v1 | active |

---

## 7. Provider — AI Provider 管理

| 路径 | 方法 | 路径参数 | 查询参数 | 响应 | 版本 | 状态 |
|------|------|----------|----------|------|------|------|
| `/api/provider` | GET | — | `location?: { directory?: string, workspace?: string }` | `{ location: Location.Info, data: Provider.Info[] }` | v2 | active |
| `/api/provider/{providerID}` | GET | `providerID: Provider.ID` | `location?: { directory?: string, workspace?: string }` | `{ location: Location.Info, data: Provider.Info }` | v2 | active |
| `/api/integration/{integrationID}` | GET | `integrationID: Integration.ID` | `location?: { directory?: string, workspace?: string }` | `{ location: Location.Info, data: Integration.Info \| undefined }` | v2 | active |
| `/api/integration/{integrationID}/connect/oauth` | POST | `integrationID: Integration.ID` | `location?: { directory?: string, workspace?: string }` | `{ methodID: Integration.MethodID, inputs: Record<string,string>, label?: string }` → `{ location: Location.Info, data: Integration.Attempt }` | v2 | active |
| `/api/integration/attempt/{attemptID}/complete` | POST | `attemptID: Integration.AttemptID` | `location?: { directory?: string, workspace?: string }` | `{ code?: string }` → `NoContent` | v2 | active |

---

## 8. Integration / Credential

| 路径 | 方法 | 路径参数 | 查询参数 | 请求体 | 响应 | 版本 | 状态 |
|------|------|----------|----------|--------|------|------|------|
| `/api/integration` | GET | — | `location?: { directory?: string, workspace?: string }` | — | `{ location: Location.Info, data: Integration.Info[] }` | v2 | active |
| `/api/integration/attempt/{attemptID}` | GET | `attemptID: Integration.AttemptID` | `location?: { directory?: string, workspace?: string }` | — | `{ location: Location.Info, data: Integration.AttemptStatus }` | v2 | active |
| `/api/integration/attempt/{attemptID}` | DELETE | `attemptID: Integration.AttemptID` | `location?: { directory?: string, workspace?: string }` | — | `NoContent` | v2 | active |
| `/api/credential/{credentialID}` | PATCH | `credentialID: Credential.ID` | `location?: { directory?: string, workspace?: string }` | `{ label: string }` | `NoContent` | v2 | active |
| `/api/credential/{credentialID}` | DELETE | `credentialID: Credential.ID` | `location?: { directory?: string, workspace?: string }` | — | `NoContent` | v2 | active |

---

## 9. Projects — 项目管理

| 路径 | 方法 | 路径参数 | 请求体 | 响应 | 版本 | 状态 |
|------|------|----------|--------|------|------|------|
| `/project` | GET | — | — | `Project.Info[]` | v1 | active |
| `/project/current` | GET | — | — | `Project.Info` | v1 | active |
| `/project/git/init` | POST | — | — | `void` | v1 | **unused** |
| `/project/{projectId}` | PATCH | `projectId: string` | `{ name?: string, icon?: string, command?: string, ... }` | `Project.Info` | v1 | active |
| `/project/{projectId}/directories` | GET | `projectId: string` | — | `Directory[]` | v1 | active |

---

## 10. Events — SSE 事件流

| 路径 | 方法 | 描述 | 响应 | 版本 | 状态 |
|------|------|------|------|------|------|
| `/api/event` | GET | 订阅当前实例的 SSE 事件流 | **SSE 流**: `V2Event`（含 `server.connected` 等事件类型） | v2 | active |

### `session.diff` 事件语义（服务端实证，clone/opencode 源码）

载荷为 `{ sessionID, diff }`（经 event-v2-bridge 包装进 `properties`）。**两种发布路径**：

- `SessionSummary.summarize`（summary.ts:114）：在**每回合开始**（prompt.ts step===1）与**回合结束**（processor.ts）发布 **`diff: []` 空载荷**，语义是「重置/重新拉取」信号，实际 per-message diff 仅通过 `GET /session/{id}/diff?messageID=` 提供；
- `SessionRevert.revert`（revert.ts:78）：发布回滚点之后剩余范围的**实际 diff**（也可能为空）。

因此客户端收到空 diff 属正常信号，应视作「清空 SSE 侧快照、回落本地聚合」而非「忽略」（见 `session_controller._onSessionDiff`）。

---

## 11. File — 文件操作

| 路径 | 方法 | 查询参数 | 响应 | 版本 | 状态 |
|------|------|----------|------|------|------|
| `/file` | GET | `path: string` | `FileSystem.Entry[]` | v1 | **active** (客户端文件列表主用) |
| `/file/content` | GET | `path: string` | `{ type, content: string }` | v1 | **active** (客户端文件读取主用) |
| `/api/fs/read/*` | GET | `location?...` | `Uint8Array`（文件内容，含 MIME 类型） | v2 | placeholder / 无效 |
| `/api/fs/list` | GET | `location?...`, `path?...` | `{ location: Location.Info, data: FileSystem.Entry[] }` | v2 | placeholder / 无效 |
| `/api/fs/find` | GET | `location?...`, `query: string`, `type: "text" \| "name" \| "symbol"`, `limit?: PositiveInt` | `{ location: Location.Info, data: FileSystem.Entry[] }` | v2 | active |
| `/file/status` | GET | — | `FileStatus[]` | v1 | **unused** |
| `/find` | GET | `pattern: string` | `TextSearchMatch[]`（ripgrep 代码内容文本检索） | v1 | **active** (客户端代码搜索主用) |
| `/find/file` | GET | `query: string`, `type?: "file" \| "directory"`, `limit?: PositiveInt`, `dirs?: string` | `string[]` | v1 | **active** (客户端文件名搜索主用) |
| `/find/symbol` | GET | `query: string`, `path?: string` | `SymbolEntry[]` | v1 | legacy |

---

## 12. Find — 搜索

v2 搜索端点已整合进 `/api/fs/find`，详见 [File 章节](#11-file--文件操作)。

v1 搜索端点：

| 路径 | 方法 | 查询参数 | 响应 | 版本 | 状态 |
|------|------|----------|------|------|------|
| `/find` | GET | `pattern: string` | `TextSearchMatch[]`（ripgrep 代码内容检索，含行号与 submatches） | v1 | **active** |
| `/find/file` | GET | `query: string`, `type?: "file" \| "directory"`, `limit?: PositiveInt`, `dirs?: string` | `string[]`（匹配的文件路径列表） | v1 | **active** |
| `/find/symbol` | GET | `query: string`, `path?: string` | `SymbolEntry[]` | v1 | legacy |

---

## 13. VCS — 版本控制

| 路径 | 方法 | 查询参数 | 响应 | 版本 | 状态 |
|------|------|----------|------|------|------|
| `/vcs` | GET | — | `VcsInfo`（分支名 `branch`、默认分支 `defaultBranch`、`isClean` 等） | v1 | **active** (分支信息主用) |
| `/vcs/status` | GET | — | `VcsStatusFile[]`（变更文件列表 `file`、`status`、`additions`、`deletions`） | v1 | **active** (工作区状态主用) |
| `/vcs/diff` | GET | `mode: "git" \| "branch"`, `context?: number` | `SnapshotFileDiff[]` 形态 JSON（全量或分支 diff 及 patch；客户端由 `SnapshotFileDiff.fromJson` 消费，原 `VcsFileDiff` 模型已删） | v1 | **active** (Review Tab 差异对比主用) |
| `/vcs/diff/raw` | GET | — | `string`（patch 文本） | v1 | unused |
| `/vcs/apply` | POST | — | `void` | v1 | unused |

---

## 14. Instance — 实例管理

| 路径 | 方法 | 响应 | 版本 | 状态 |
|------|------|------|------|------|
| `/instance/dispose` | POST | `void` | v1 | active |
| `/path` | GET | `{ cwd: string, home: string, ... }` | v1 | active |

---

## 15. Command / Agent / Skill / Model — 工具列表

| 路径 | 方法 | 查询参数 | 响应 | 版本 | 状态 |
|------|------|----------|------|------|------|
| `/api/command` | GET | `location?: { directory?: string, workspace?: string }` | `{ location: Location.Info, data: Command.Info[] }` | v2 | active |
| `/api/agent` | GET | `location?: { directory?: string, workspace?: string }` | `{ location: Location.Info, data: Agent.Info[] }` | v2 | active |
| `/api/skill` | GET | `location?: { directory?: string, workspace?: string }` | `{ location: Location.Info, data: Skill.Info[] }` | v2 | active |
| `/api/model` | GET | `location?: { directory?: string, workspace?: string }` | `{ location: Location.Info, data: Model.Info[] }` | v2 | active |

---

## 16. Reference — 引用

| 路径 | 方法 | 查询参数 | 响应 | 版本 | 状态 |
|------|------|----------|------|------|------|
| `/api/reference` | GET | `location?: { directory?: string, workspace?: string }` | `{ location: Location.Info, data: Reference.Info[] }` | v2 | active |

---

## 17. LSP / Formatter — 语言服务 & 格式化

| 路径 | 方法 | 响应 | 版本 | 状态 |
|------|------|------|------|------|
| `/lsp` | GET | `{ status: "running" \| "stopped", servers: LspServer[] }` | v1 | active |
| `/formatter` | GET | `{ formatters: FormatterInfo[] }` | v1 | active |

---

## 18. MCP — Model Context Protocol

| 路径 | 方法 | 路径参数 | 请求体 | 响应 | 版本 | 状态 |
|------|------|----------|--------|------|------|------|
| `/mcp` | GET | — | — | `McpServer[]` | v1 | active |
| `/mcp` | POST | — | `{ name: string, command: string, args?: string[], env?: Record<string,string> }` | `McpServer` | v1 | active |
| `/mcp/{name}/connect` | POST | `name: string` | — | `void` | v1 | active |
| `/mcp/{name}/disconnect` | POST | `name: string` | — | `void` | v1 | active |
| `/mcp/{name}/auth` | POST | `name: string` | — | `{ authUrl: string }` | v1 | active |
| `/mcp/{name}/auth` | DELETE | `name: string` | — | `void` | v1 | active |
| `/mcp/{name}/auth/callback` | POST | `name: string` | `{ code: string }` | `void` | v1 | active |
| `/mcp/{name}/auth/authenticate` | POST | `name: string` | — | `void` | v1 | active |

---

## 19. PTY — 伪终端

| 路径 | 方法 | 路径参数 | 查询参数 | 请求体 | 响应 | 版本 | 状态 |
|------|------|----------|----------|--------|------|------|------|
| `/api/pty` | GET | — | `location?: { directory?: string, workspace?: string }` | — | `{ location: Location.Info, data: Pty.Info[] }` | v2 | active |
| `/api/pty` | POST | — | `location?: { directory?: string, workspace?: string }` | `Pty.CreateInput` | `{ location: Location.Info, data: Pty.Info }` | v2 | active |
| `/pty/shells` | GET | — | — | — | `string[]`（可用 shell 列表） | v1 | active |
| `/api/pty/{ptyID}` | GET | `ptyID: Pty.ID` | `location?: { directory?: string, workspace?: string }` | — | `{ location: Location.Info, data: Pty.Info }` | v2 | active |
| `/api/pty/{ptyID}` | PUT | `ptyID: Pty.ID` | `location?: { directory?: string, workspace?: string }` | `Pty.UpdateInput` | `{ location: Location.Info, data: Pty.Info }` | v2 | active |
| `/api/pty/{ptyID}` | DELETE | `ptyID: Pty.ID` | `location?: { directory?: string, workspace?: string }` | — | `NoContent` | v2 | active |
| `/api/pty/{ptyID}/connect-token` | POST | `ptyID: Pty.ID` | `location?: { directory?: string, workspace?: string }` | — | `{ location: Location.Info, data: PtyTicket.ConnectToken }` | v2 | active |
| `/api/pty/{ptyID}/connect` | GET | `ptyID: Pty.ID` | `ticket?: string`, `location[directory]?: string`, `location[workspace]?: string`, `cursor?: string` | — | **WebSocket 升级**（PTY I/O 流） | v2 | active |

---

## 20. Question — 问答交互

| 路径 | 方法 | 路径参数 | 查询参数 | 请求体 | 响应 | 版本 | 状态 |
|------|------|----------|----------|--------|------|------|------|
| `/api/question/request` | GET | — | `location?: { directory?: string, workspace?: string }` | — | `{ location: Location.Info, data: Question.Request[] }` | v2 | active |
| `/api/session/{sessionID}/question/{requestID}/reply` | POST | `sessionID: Session.ID, requestID: Question.ID` | — | `Question.Reply` | `NoContent` | v2 | active |
| `/api/session/{sessionID}/question/{requestID}/reject` | POST | `sessionID: Session.ID, requestID: Question.ID` | — | — | `NoContent` | v2 | active |
| `/api/session/{sessionID}/question` | GET | `sessionID: Session.ID` | — | — | `{ data: Question.Request[] }` | v2 | active |

---

## 21. Permission — 权限请求

| 路径 | 方法 | 路径参数 | 查询参数 | 请求体 | 响应 | 版本 | 状态 |
|------|------|----------|----------|--------|------|------|------|
| `/api/permission/request` | GET | — | `location?: { directory?: string, workspace?: string }` | — | `{ location: Location.Info, data: Permission.Request[] }` | v2 | active |
| `/api/permission/saved` | GET | — | `projectID?: Project.ID` | — | `{ data: PermissionSaved.Info[] }` | v2 | active |
| `/api/permission/saved/{id}` | DELETE | `id: PermissionSaved.ID` | — | — | `NoContent` | v2 | active |
| `/api/session/{sessionID}/permission` | POST | `sessionID: Session.ID` | — | `{ id?: Permission.ID, action, resources, save, metadata, source, agent?: Agent.ID }` | `{ data: { id: Permission.ID, effect: Permission.Effect } }` | v2 | active |
| `/api/session/{sessionID}/permission` | GET | `sessionID: Session.ID` | — | — | `{ data: Permission.Request[] }` | v2 | active |
| `/api/session/{sessionID}/permission/{requestID}` | GET | `sessionID: Session.ID, requestID: Permission.ID` | — | — | `{ data: Permission.Request }` | v2 | active |
| `/api/session/{sessionID}/permission/{requestID}/reply` | POST | `sessionID: Session.ID, requestID: Permission.ID` | — | `{ reply: Permission.Reply, message?: string }` | `NoContent` | v2 | active |

---

## 22. Log — 日志

| 路径 | 方法 | 请求体 | 响应 | 版本 | 状态 |
|------|------|--------|------|------|------|
| `/log` | POST | `{ level: string, message: string, ... }` | `void` | v1 | active |

---

## 23. Sync — 同步

| 路径 | 方法 | 响应 | 版本 | 状态 |
|------|------|------|------|------|
| `/sync/start` | POST | `void` | v1 | active |
| `/sync/replay` | POST | `void` | v1 | active |
| `/sync/steal` | POST | `void` | v1 | active |
| `/sync/history` | POST | `{ aggregateID: seq, ... }` → `HistoryEvent[]` | v1 | active |

---

## 24. TUI — 终端 UI 控制

| 路径 | 方法 | 请求体 | 响应 | 版本 | 状态 |
|------|------|--------|------|------|------|
| `/tui/append-prompt` | POST | `{ text: string }` | `void` | v1 | active |
| `/tui/open-help` | POST | — | `void` | v1 | active |
| `/tui/open-sessions` | POST | — | `void` | v1 | active |
| `/tui/open-themes` | POST | — | `void` | v1 | active |
| `/tui/open-models` | POST | — | `void` | v1 | active |
| `/tui/submit-prompt` | POST | — | `void` | v1 | active |
| `/tui/clear-prompt` | POST | — | `void` | v1 | active |
| `/tui/execute-command` | POST | `{ command: string }` | `void` | v1 | active |
| `/tui/show-toast` | POST | `{ message: string, type?: string }` | `void` | v1 | active |
| `/tui/publish` | POST | `{ event: string, data?: any }` | `void` | v1 | active |
| `/tui/select-session` | POST | `{ sessionID: string }` | `void` | v1 | active |
| `/tui/control/next` | GET | — | `{ request?: TuiRequest }` | v1 | active |
| `/tui/control/response` | POST | `{ ...TuiResponse }` | `void` | v1 | active |

---

## 25. Experimental — 实验性功能

| 路径 | 方法 | 路径参数 | 查询参数 | 请求体 | 响应 | 版本 | 状态 |
|------|------|----------|----------|--------|------|------|------|
| `/experimental/console` | GET | — | — | — | `ConsoleMetadata` | v1 | experimental |
| `/experimental/console/orgs` | GET | — | — | — | `ConsoleOrg[]` | v1 | experimental |
| `/experimental/console/switch` | POST | — | — | `{ orgID: string }` | `void` | v1 | experimental |
| `/experimental/tool` | GET | — | `provider?: string`, `model?: string` | — | `ToolInfo[]`（含 JSON Schema） | v1 | experimental |
| `/experimental/tool/ids` | GET | — | — | — | `string[]` | v1 | experimental |
| `/experimental/worktree` | GET | — | — | — | `Worktree[]` | v1 | experimental |
| `/experimental/worktree` | POST | — | — | `{ ... }` | `Worktree` | v1 | experimental |
| `/experimental/worktree` | DELETE | — | — | `{ id: string }` | `void` | v1 | experimental |
| `/experimental/worktree/reset` | POST | — | — | `{ id: string }` | `void` | v1 | experimental |
| `/experimental/session` | GET | — | — | — | `Session.Info[]` | v1 | experimental |
| `/experimental/resource` | GET | — | — | — | `McpResource[]` | v1 | experimental |
| `/experimental/workspace/adapter` | GET | — | `location?: { directory?, workspace? }` | — | `WorkspaceAdapterEntry[]` | v1 | experimental |
| `/experimental/workspace` | GET | — | — | — | `Workspace[]` | v1 | experimental |
| `/experimental/workspace` | POST | — | — | `{ ... }` | `Workspace` | v1 | experimental |
| `/experimental/workspace/sync-list` | POST | — | — | `{ ... }` | `void` | v1 | experimental |
| `/experimental/workspace/status` | GET | — | — | — | `WorkspaceStatus` | v1 | experimental |
| `/experimental/workspace/{id}` | GET | `id: string` | — | — | `Workspace` | v1 | experimental |
| `/experimental/workspace/{id}` | PUT | `id: string` | — | `{ ... }` | `Workspace` | v1 | experimental |
| `/experimental/workspace/{id}` | DELETE | `id: string` | — | — | `void` | v1 | experimental |
| `/experimental/workspace/warp` | POST | — | — | `{ workspaceID: string }` | `void` | v1 | experimental |

---

## 错误码参考

所有 v2 端点共享以下错误类型：

| 错误 | HTTP 状态 | 描述 |
|------|-----------|------|
| `InvalidRequestError` | 400 | 请求参数不合法 |
| `InvalidCursorError` | 400 | 分页游标无效 |
| `ProjectCopyError` | 400 | 项目克隆操作失败 |
| `ForbiddenError` | 403 | 无权限 |
| `SessionNotFoundError` | 404 | 会话不存在 |
| `ProviderNotFoundError` | 404 | Provider 不存在 |
| `PermissionNotFoundError` | 404 | 权限请求不存在 |
| `QuestionNotFoundError` | 404 | 问题请求不存在 |
| `PtyNotFoundError` | 404 | PTY 会话不存在 |
| `MessageNotFoundError` | 404 | 消息不存在 |
| `ConflictError` | 409 | 资源冲突（如消息 ID 冲突） |
| `ServiceUnavailableError` | 503 | 服务不可用 |
| `UnknownError` | 500 | 未知服务器错误 |

---

> **文档生成自**: `lib/api/endpoints.dart`  
> **后端源码映射**: `clone/opencode/packages/protocol/src/groups/` (v2 协议定义) + `clone/opencode/packages/server/src/handlers/` (v2 处理器)  
> **端点总计**: ~121 个（v2 活跃 ~62 个，v1 legacy ~41 个，experimental ~18 个）
