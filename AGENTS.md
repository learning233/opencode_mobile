# AGENTS.md

Flutter（Android / iOS / Windows / Web）客户端，通过 Basic Auth 连接远程 `opencode serve` 后端。GetX + Dio + 自实现 SSE 流式 + PTY WebSocket。含 Rust 核心（flutter_rust_bridge 2.12.0），负责语音输入（SenseVoice ASR + Silero VAD + onnxruntime 推理）。Windows 桌面端提供完整无边框窗口、会话页签栏与键盘交互适配。

## 开发命令

- `flutter pub get` / `flutter run`（支持 `-d windows`、`-d <device_id>`、`-d chrome` 等）
- `flutter analyze` — lint（analyzer 已排除 `clone/opencode_flutter/lib/**`）
- 修改 `rust/src/api/*.rs` 后必须重新生成桥接代码：`flutter_rust_bridge_codegen generate`（配置见 `flutter_rust_bridge.yaml`，本机已装 2.12.0）
- 生成产物 `rust/src/frb_generated.rs`、`lib/src/rust/frb_generated*.dart` —— 不要手改

## 目录与系统边界

- `lib/main.dart` → `AppLogger.init` → `Global.init` → `if (isDesktop) await WindowsAdapter.setSize()`（配置 `window_manager` 无边框、800x500 最小尺寸、记忆窗口位置与尺寸/置顶、设置 `setPreventClose(true)` 拦截关闭）→ `runApp` → `AppRoutes.splash` → `app.dart` builder 挂载全局 `DesktopTitleBar` → SplashPage 触发 `SidecarManager` 连接与健康检查（`/api/health`）→ HomePage。完整启动流程参考 `docs_my/startup_architecture.md`
- `lib/api/` — HTTP/SSE 客户端。客户端**混用 v1（无 `/api` 前缀：`/project`、`/file`、`/session/{id}`）与 v2（`/api/...`）**两套端点，别随意迁移；端点清单见 `docs/api_endpoints.md`
- `lib/controllers/` — GetX 控制器，在 `lib/bindings.dart` 注册为 `permanent`（`ProjectController`、`SessionController`、`SettingsController`、`PtyController`、`TabletToolController`、`FileSearchController`、`VcsController`、`AppFeedbackService`，桌面端按需注入 `TitleBarController`）。SSE 长连接与流式接管依赖其常驻存活，勿置为临时
- `lib/utils/window/` — 桌面窗口管理：`windows_adaptor.dart`、`window_controller.dart`、`desktop_title_bar.dart`、`window_button.dart`
- `lib/pages/home/desktop_session_tab_bar.dart` — 桌面端多会话页签（Chrome/VS Code 风格，支持拖拽重排、滚轮平滑横向滚动、激活态居中、等比自适应收缩、中键/右键菜单/悬浮关闭）
- `rust/` — FRB Rust 核心（ASR/VAD/重采样），`Cargo.toml` 锁定 `flutter_rust_bridge = "=2.12.0"`（与 pubspec 一致）
- `rust_builder/` — cargokit 构建胶水（其 README 声明直接忽略该目录）
- `lib/third_party/kterm`、`lib/third_party/zmodem_lbp` — vendor 包，各自带 AGENTS.md，除非改终端相关功能否则不要动
- `clone/` — **gitignored，不在仓库内**：`clone/opencode` 后端源码与 `clone/opencode_flutter` 桌面参考客户端需另行获取

## 运行时依赖与资产

- `assets/vad_stream.onnx` — **已跟踪**，Silero VAD 流式模型
- `assets/sensevoice/tokens.txt`、`assets/sensevoice/am.mvn` — **已跟踪**，SenseVoice 词表与均值方差文件
- `onnx/libonnxruntime.so`（Android/Linux）与 `onnx/onnxruntime.dll`（Windows）— **已跟踪**；Rust 侧 `configure_onnxruntime_dylib` 自动探测 exe 同级目录或候选路径并配置 `ORT_DYLIB_PATH`
- SenseVoice ASR 大模型文件（`model_q8.onnx`，约 230MB）— 运行时首次使用按需从 ModelScope 下载（`VoiceInputService.ensureModelDownloaded`），内置 >200MB 尺寸完整性校验与进度提示

## 调试后端连接

- 服务端：`opencode serve --hostname 0.0.0.0 --port 4096` + 设置 `OPENCODE_SERVER_PASSWORD`（Basic Auth，用户名默认 `opencode`）
- 真机/模拟器：`flutter run` 后需重新执行 `adb reverse tcp:<端口> tcp:<端口>`，App 内填 `http://localhost:<端口>`；局域网直连填宿主机 IP（WSL2 内跑 opencode 会自动端口映射，无需 netsh）。详见 `docs/登录.md`
- 桌面端直连：Windows 本地运行直接填 `http://localhost:4096`（或局域网/公网后端地址）

## 行为约定（容易踩坑）

- **已打开会话页签持久化（`openedSessionIds`）**：**只在用户主动操作时写库**；启动/切项目（`onProjectChanged`）仅清内存，禁止调用 `_persistOpenedIds()`，否则重启丢页签
- **桌面窗口关闭与优雅退出**：桌面端通过 `windowManager.setPreventClose(true)` 拦截关闭，必须由 `TitleBarController.onWindowClose` 先执行 `await SidecarManager.instance.stop()` 优雅清理后端子进程与连接，再 `windowManager.destroy()` 退出，避免产生孤儿后台进程
- **桌面输入框（`PromptInput`）行为规范**：
  - **Enter 发送**：默认 Enter 发送，Shift+Enter 换行；必须增加 IME 拼音输入法合成态检测（`composing.isValid && !composing.isCollapsed`），打字拼音上屏时严禁误触发发送
  - **剪贴板图像粘贴**：Ctrl+V（或 Cmd+V）优先通过 `super_clipboard` 探测并提取 PNG/JPEG 图片附加为附件（单次最多 5 张）；无图片或读取失败时无缝降级为原生文本粘贴
  - **Esc 键**：消息生成中按 Esc 中止当前生成（`_handleAbort`）；空闲时使输入框失焦
  - **输入框尺寸**：桌面端默认多行自适应 2~8 行（移动端 1~4 行）
- **路径规范化（`ProjectController.normalizeDirectory`）**：跨平台路径统一转为正斜杠 `/` 并移除尾部多余斜杠；严禁把 Windows 宿主机盘符路径注入 Linux 沙盒容器；切后端（`refreshAfterConnect`）时严格以当前服务端返回列表为准，禁止跨端合并 `localOnly` 幽灵项目
- **切换项目联动清理**：`selectProject` 切换项目时，除刷新会话与失效目录缓存外，必须调用 `toolCtrl.closeAllFiles()` 和 `toolCtrl.clearReview()` 同步清空已打开文件与代码审阅作用域，防止上一个项目的 diff 残留在新项目中
- **代码审阅与 VCS 联动**：VCS sheet 中点击单个文件变更会调用 `toolCtrl.openReviewAll(selectFile: path)` 直接定位并聚焦该文件的 Diff/详情；Review 视图支持直接打开和预览图片与文本文件
- **桌面与移动端 UI 差异化规范**：
  - **Snackbar / Toast（`SnackbarUtils`）**：桌面端（`isDesktop`）采用右下角贴边自适应宽度浮动卡片（不遮挡主操作区），移动端采用顶部悬浮药丸卡片
  - **终端（`TerminalPanelBody`）**：桌面端隐藏移动端专用的虚拟辅助功能键条（`_TermuxExtraKeysBar`），直接内嵌搜索栏（`showSearchBar: true`）；移动端点击搜索弹出 BottomSheet
  - **内置浏览器（`InAppBrowserView`）**：Windows 平台基于 `flutter_inappwebview`（搭配独立 `WebViewEnvironment` 用户数据目录隔离），移动平台基于 `webview_flutter`
- **语音设置与前台反馈**：
  - 语音设置集中走 `Global.*Rx` + `AppSettingsStore`（`lib/init.dart` 加载）
  - `AppFeedbackService` 前台提示音统一走 SoundPool 低延迟通道（不抢音频焦点），连续语音/录音中也会播且不打断 AudioRecord（勿改回 MediaPlayer，否则会静音失效）
  - Windows 端跳过移动端特有的运行时权限申请（`Permission.microphone`），直接基于 `AudioRecorder` 探测硬件并调用 Rust 推理
- **连接与网络状态机**：
  - 服务器配置 `Global.server*` **仅在健康检查通过后**写入（`SidecarManager.updateConnection` 内部处理），失败保留 last-known-good；不要在外部手动写库
  - `updateConnection` 已内置 generation + `CancelToken` 串行化（新连接/`stop()` 取消在途健康检查），Splash/连接页无需再加并发锁
  - 健康检查固定 `connectTimeout: 5s`、至多 3 次、401 快速失败；勿去掉超时，否则启动页会长时间阻塞
  - HTTP 请求收到 401/403 会置全局 `OpenCodeClient.unauthorized`（`resetUnauthorized()` 恢复）；SSE 侧仍是独立的 `SseClient.isCredentialFailed`，两者作用域不同
- **E2B 超时与生命周期**：
  - Hobby 计划单次限制 1h（3600s），Pro 支持最长 24h（86400s），SDK（create/connect/setTimeout）底层统一内置 400 timeout 自动降级 3600s 重试；沙盒保活（keep-alive）连接后每 5 分钟刷新一次
  - 左抽屉多后端展示：自建服务器与 E2B 云端沙盒双分组并存（绿点指示当前连接），沙盒项目直接平铺展示（点击自动连接/唤醒目标沙盒）；隐藏项目统一沉底展示

## 文档索引（中文）

改动子系统前先读对应文档：
- **核心架构与端点**：`docs/项目结构.md`、`docs/api_endpoints.md`（v1/v2 混用说明）、`docs/登录.md`（双后端连接/冷启动）、`docs/新增项目.md`
- **会话与流式**：`docs/会话缓存.md`（会话历史 SWR 缓存）、`docs/终态复审与修复记录.md`（缓存/流式/性能改动复审，含 `messageWithSyncedParts` 语义）
- **E2B 云端沙盒**：`docs/e2b/e2b_cloud_workspace.md`（E2B 架构/演进）、`docs/e2b/e2b_dart_sdk_specification.md`（E2B SDK 规范）
- **性能与审查**：`docs/性能优化.md`、`docs/代码审查.md`、`docs/v1_v2迁移评估.md`
- **专题实现参考（`docs_my/`）**：`docs_my/startup_architecture.md`（启动流程）、`docs_my/reconnect.md`（自动重连）、`docs_my/voice_input_logic.md`（语音）、`docs_my/子会话权限与提问处理.md`、`docs_my/多项目.md`、`docs_my/diff card 和  diff panel.md`、`docs_my/mcp/`、`docs_my/lsp/`、`docs_my/agent/`、`docs_my/developer/`
