# 未使用的 opencode API 清单

> 整理日期：2026-08-30
> 配套文档：[api_endpoints.md](./api_endpoints.md)（后端全量端点文档）
> 数据来源：客户端代码盘点（`lib/api/endpoints.dart` + 各 controller 实际调用）+ 本地 `clone/opencode` 后端源码（Effect HttpApi 版，HEAD dc4449d）

## 口径说明

- 客户端实际使用约 **55 个端点**：以 v1 平路径为主（session/permission/question/provider/auth/project/file/find/vcs/config/global/mcp/lsp/formatter/instance/event），v2 `/api/*` 仅 9 个（`/api/health`、`/api/agent`、`/api/skill`、`/api/command`、`/api/reference`、`/api/pty` 系列、`/api/permission/saved` 系列）。
- 后端全量暴露约 **120+ 个端点**。差集中 TUI 全套、sync/workspace、integration/credential v2、v2 session 协议对移动端意义不大（见文末"不建议接入"），**值得补的集中在：会话管理增强、文件/VCS 辅助、PTY 细节、一批已在 SSE 流里但被忽略的事件**。

---

## 1. 低垂果实：`endpoints.dart` 已定义常量但从未调用

| 端点 | 用途 | 价值 |
|---|---|---|
| `GET /session/status` | 所有会话的运行状态 | 会话列表加"运行中"徽标；重连恢复时判断哪些会话还在跑 |
| `POST /session/{id}/unrevert` | 恢复所有已回退的消息 | 现在只有 revert（`session_controller` 的会话回滚）没有反悔，补上才闭环 |
| `GET /find/symbol` | LSP 工作区符号搜索 | 代码符号跳转（需 LSP 在跑） |
| `GET /session/{id}` | 单会话详情 | 一般 |
| `GET /session/{sid}/message/{mid}` | 单条消息详情（含 parts） | 一般 |
| `GET /project/current` | 当前项目 | 一般 |
| `POST /mcp` | 动态添加 MCP server | 价值低，现有 `PATCH /global/config {mcp: ...}` 流程已覆盖 |
| `POST /mcp/{name}/auth/authenticate` | 阻塞式 MCP OAuth（自动开浏览器） | 价值低，现有 auth + callback 流程已覆盖 |

## 2. 会话域（最值得补的一组）

| 端点 | 用途 | 建议接入点 |
|---|---|---|
| `PATCH /session/{id}` | 改 title / 归档 / metadata / 会话级权限规则 | 会话页签重命名、归档会话列表 |
| `POST /session/{id}/share`（`DELETE` 同路径取消） | 生成 / 撤销分享链接 | 消息页分享按钮 + 系统分享面板 |
| `POST /session/{id}/init` | 分析项目并生成 AGENTS.md | 新项目接入引导 |
| `GET /session/{id}/children` | 列出 fork 出的子会话 | 子代理会话树形展示（现在只处理了子会话的权限/提问，见 `子会话权限与提问处理` 相关逻辑） |
| `POST /session/{id}/command` | 在会话内执行自定义命令 | Developer 页已列 `/api/command` 却没有执行入口，可做聊天框 `/` 补全触发 |
| `POST /session/{id}/shell` | 在会话内执行 shell 命令 | 与 PTY 互补，一般 |
| `DELETE /session/{sid}/message/{mid}` | 删除单条消息（不动文件） | 消息长按"删除" |
| （v2）`POST /api/session/{id}/wait` | 阻塞等 agent 空闲 | 可替代部分轮询 |

## 3. 文件 / VCS 域

| 端点 | 用途 | 建议接入点 |
|---|---|---|
| `GET /file/status` | 项目文件的 git 状态（added/deleted/modified） | 文件树标色、Review 页交叉引用 |
| `POST /project/git/init` | 为无 git 的项目初始化仓库 | 添加项目后 VCS 页空白的兜底 |
| `GET /vcs/diff/raw` | 原始 patch 文本（`text/x-diff`） | 一般；Review 页目前用 `/vcs/diff` 的 JSON 形态 |
| `POST /vcs/apply` | 向工作区应用 raw patch | "直接应用 AI 建议的改动"类功能，apply 要谨慎 |
| `PATCH /project/{projectId}` | 改项目名 / 图标 / commands | 一般 |
| `GET /project/{projectId}/directories` | 项目已知本地目录 | 一般 |

## 4. PTY 域

- `GET /pty/shells` — 可用 shell 列表，新建终端时可选。
- `GET /api/pty/{ptyID}` — 单会话详情（含退出码），可减少整表轮询（现在 `pty_controller` 靠 `GET /api/pty` 轮询 + stale 清理）。
- WS `GET /api/pty/{id}/connect` 支持 `cursor` 参数 — 现在 `pty_controller.dart` 连接时没带，**断线重连后终端历史会丢**，补上可回放 scrollback。
- `pty.created/updated/exited/deleted` SSE 事件 — `EventTypes` 里已定义常量但 switch 忽略，消费后可替代现在的 HTTP 轮询。

## 5. 已在 `/event` 流里但被忽略的事件

客户端订阅了全量 `/event` SSE（`session_controller._onEvent` 的 switch 决定消费哪些），以下事件已在流里、只需改 switch：

- `server.heartbeat`（服务端 10s 一跳）— 连接存活探测，比纯靠重连退避更早发现半开连接。
- `vcs.branch.updated` — 切分支自动刷新 VCS 页。
- `installation.update-available` — 后端有新版本提醒。
- `lsp.client.diagnostics` / `lsp.updated` — 做诊断面板。
- `mcp.tools.changed`、`project.updated`、`reference.updated`、`catalog.updated` — 设置页缓存失效信号。

## 6. 其他

- `POST /log` — 把客户端日志镜像写到服务端日志（body: service/level/message/extra），真机排查问题方便（在 `AppLogger` 挂个可选上报）。
- `/experimental/worktree` CRUD + `POST /experimental/worktree/reset` — git worktree 管理，配合并行会话（experimental，谨慎）。
- `GET /experimental/session?archived=` — 跨项目会话搜索 / 归档视图。
- `GET /global/event` — 跨实例全局 SSE（事件外层多包一层 `{directory, project, payload}`），多项目同时活跃时能把多条实例级 SSE 收敛成一条连接。
- `GET /experimental/capabilities` — 实验能力开关探测（如 backgroundSubagents）。

---

## 7. 明确不建议接入的部分

| 功能区 | 原因 |
|---|---|
| TUI 全套（`/tui/*` 13 个端点） | 给终端 UI 用的控制通道，移动端无对应载体 |
| `/sync/*`、`/experimental/workspace` | 多设备 / workspace 同步，experimental 且协议复杂，客户端目前单设备直连场景用不到 |
| `/api/integration*`、`/api/credential*` | 与现有 v1 `/provider/{id}/oauth/*` + `/auth/{providerId}` 流程重复 |
| v2 session 协议（`/api/session` prompt/event/revert 三段式、`session.next.*` 事件族） | 聊天管线明确只用 v1 平路径（`endpoints.dart` 头注释声明不做双协议探测），迁移是大工程且收益不明确 |

## 8. 版本注意点

- 本地 `clone/opencode` 是较新的 dev 版（Effect HttpApi 重构后），**v2 端点与实际部署的后端版本可能有出入**；v1 平路径两个版本基本一致。
- 接 v2 端点前建议先对真实服务器 `GET /doc`（返回 OpenAPI 规范）核对一次路径与参数。
- 后端路由定义位置（供查证）：v1 在 `clone/opencode/packages/opencode/src/server/routes/instance/httpapi/groups/*.ts`，v2 在 `clone/opencode/packages/protocol/src/groups/*.ts`。
