# AGENTS.md

Flutter（Android/iOS/Web）客户端，通过 Basic Auth 连接远程 `opencode serve` 后端。GetX + Dio + SSE + PTY WebSocket。含 Rust 核心（flutter_rust_bridge 2.12.0），负责语音输入（SenseVoice ASR + Silero VAD + onnxruntime）。

## 开发命令

- `flutter pub get` / `flutter run`
- `flutter analyze` — lint（analyzer 已排除 `clone/opencode_flutter/lib/**`）
- 修改 `rust/src/api/*.rs` 后必须重新生成桥接代码：`flutter_rust_bridge_codegen generate`（配置见 `flutter_rust_bridge.yaml`，本机已装 2.12.0）
- 生成产物 `rust/src/frb_generated.rs`、`lib/src/rust/frb_generated*.dart` —— 不要手改

## 目录边界

- `lib/main.dart` → `AppLogger.init` → `Global.init` → SplashPage → `SidecarManager` 连接（`/api/health` 健康检查）→ HomePage。完整流程见 `docs/startup_architecture.md`
- `lib/api/` — HTTP/SSE 客户端。客户端**混用 v1（无 `/api` 前缀：`/project`、`/file`、`/session/{id}`）与 v2（`/api/...`）**两套端点，别随意迁移；端点清单见 `docs/api_endpoints.md`
- `lib/controllers/` — GetX 控制器，在 `lib/bindings.dart` 注册为 `permanent`，SSE 长连接与流式接管依赖其存活，勿置为临时
- `rust/` — FRB Rust 核心（ASR/VAD/重采样），`Cargo.toml` 锁定 `flutter_rust_bridge = "=2.12.0"`（与 pubspec 一致）
- `rust_builder/` — cargokit 构建胶水（其 README 声明直接忽略该目录）
- `lib/third_party/kterm`、`lib/third_party/zmodem_lbp` — vendor 包，各自带 AGENTS.md，除非改终端相关功能否则不要动
- `clone/` — **gitignored，不在仓库内**：`clone/opencode` 后端源码与 `clone/opencode_flutter` 桌面参考客户端需另行获取

## 运行时依赖

- `assets/vad_stream.onnx` — **gitignored**，缺失会导致语音不可用（需自备 Silero VAD 模型）
- `assets/sensevoice/tokens.txt`、`assets/sensevoice/am.mvn`、`onnx/libonnxruntime.so` — 已跟踪

## 调试后端连接

- 服务端：`opencode serve --hostname 0.0.0.0 --port 4096` + 设置 `OPENCODE_SERVER_PASSWORD`（Basic Auth，用户名默认 `opencode`）
- 真机/模拟器：`flutter run` 后需重新执行 `adb reverse tcp:<端口> tcp:<端口>`，App 内填 `http://localhost:<端口>`；局域网直连填宿主机 IP（WSL2 内跑 opencode 会自动端口映射，无需 netsh）。详见 `docs/登录.md`

## 行为约定（容易踩坑）

- 已打开会话页签持久化（`openedSessionIds`）：**只在用户主动操作时写库**；启动/切项目（`onProjectChanged`）仅清内存，禁止调用 `_persistOpenedIds()`，否则重启丢页签
- 语音设置集中走 `Global.*Rx` + `AppSettingsStore`（`lib/init.dart` 加载）；`AppFeedbackService` 前台提示音统一走 SoundPool 低延迟通道（不抢音频焦点），连续语音/录音中也会播且不打断 AudioRecord（勿改回 MediaPlayer，否则会静音失效）
- 服务器配置 `Global.server*` **仅在健康检查通过后**写入（`SidecarManager.updateConnection` 内部处理），失败保留 last-known-good；不要在外部手动写库
- `updateConnection` 已内置 generation + `CancelToken` 串行化（新连接/`stop()` 取消在途健康检查），Splash/连接页**无需再加并发锁**
- 健康检查固定 `connectTimeout: 5s`、至多 3 次、401 快速失败；勿去掉超时，否则启动页会长时间阻塞
- HTTP 请求收到 401/403 会置全局 `OpenCodeClient.unauthorized`（`resetUnauthorized()` 恢复）；SSE 侧仍是独立的 `SseClient.isCredentialFailed`，两者作用域不同
- 切后端/连接刷新（`ProjectController.refreshAfterConnect`）：切换后端必须清空旧 `projects` 内存；`fetchProjects` 严格以当前后端返回的列表为准，禁止跨端合并 `localOnly` 幽灵项目；`_restoreLastProject` 无法匹配时默认选中当前后端首个项目，禁止把宿主机路径（如 Windows 盘符）强行注入 Linux 沙盒容器
- E2B 超时与生命周期：Hobby 计划单次限制 1h（3600s），Pro 支持最长 24h（86400s），SDK（create/connect/setTimeout）底层统一内置 400 timeout 自动降级 3600s 重试；沙盒保活（keep-alive）连接后每 5 分钟刷新一次
- 左抽屉多后端展示：自建服务器与 E2B 云端沙盒双分组并存（绿点指示当前连接），沙盒项目直接平铺展示（点击自动连接/唤醒目标沙盒）；隐藏项目统一沉底展示

## 文档（中文）

改动子系统前先读对应文档：`e2b_cloud_workspace.md`（E2B架构/演进）、`e2b_dart_sdk_specification.md`（E2B SDK规范）、`登录.md`（双后端连接/冷启动）、`voice_input_logic.md`（语音）、`startup_architecture.md`（启动/会话恢复）、`reconnect.md`（自动重连）、`api_endpoints.md`、`会话缓存.md`（会话历史 SWR 缓存）、`终态复审与修复记录.md`（13eef43e 后缓存/流式/性能改动的复审与修复，含 messageWithSyncedParts 语义）、`项目.md`（项目扫描/添加）、`子会话权限与提问处理.md`、`多项目.md`、`mcp/`、`lsp/`、`agent/`、`developer/`。
