# E2B 云端工作区（Cloud Workspace）技术与功能架构文档

## 一、概述

E2B 云端工作区是客户端接入云端 MicroVM 沙盒的核心功能，允许用户在移动端直接创建、唤醒、管理并连接托管在 E2B 上的 OpenCode 开发环境，无需本地电脑开机即可进行全功能 AI 编程与终端交互。

---

## 二、系统架构与通信拓扑

```mermaid
flowchart TD
    subgraph Mobile [手机客户端 opencode_mobile]
        UI[连接页 / 云工作区面板]
        Svc[E2bWorkspaceService]
        Sidecar[SidecarManager]
    end

    subgraph E2B_Cloud [E2B 云端平台]
        API[E2B REST API: api.e2b.app]
        subgraph MicroVM [Firecracker MicroVM 沙盒]
            Envd[envd 守护进程 :49983]
            OpenCode[OpenCode Serve 服务 :4096]
            Workspace[/home/user/workspace Git 工作区]
        end
    end

    UI -->|配置与管理| Svc
    Svc -->|创建/唤醒/休眠/销毁/列表| API
    Svc -->|进程控制 Connect-RPC| Envd
    Sidecar -->|HTTP/SSE/PTY Basic Auth| OpenCode
```

### 关键端口与协议

| 端口 | 协议 / 格式 | 作用 | 访问域名格式 |
| :--- | :--- | :--- | :--- |
| **443** | HTTPS (REST JSON) | E2B 控制面 API（管理沙盒生命周期） | `https://api.e2b.app/v2/sandboxes` |
| **49983** | Connect-RPC (HTTP/2 / HTTP/1.1) | 沙盒内部 `envd` 守护进程，用于执行命令与进程管理 | `https://49983-{sandboxId}.e2b.app` |
| **4096** | HTTP 1.1 + SSE + WebSocket | `opencode serve` 服务端，提供 OpenAPI 接口与 PTY 终端 | `https://4096-{sandboxId}.e2b.app` |

---

## 三、功能模块清单

### 1. 云工作区配置 (`CloudWorkspaceConfig`)
* **E2B API 鉴权**：配置 `e2bApiKey`。
* **模板设置**：默认 `opencode`，支持用户自定义模板 ID。
* **Git 代码仓库集成**：
  * 支持 GitHub、GitLab、Gitee 及自建 Git 服务；
  * Token 鉴权（Personal Access Token），支持自动拉取私有仓库；
  * 支持分支选择（默认 `main` 或自定义）；
  * Git 提交身份设置（Author Name / Email）。
* **资源与生命周期控制**：
  * 沙盒超时时间（默认 30 分钟，最长 24 小时）；
  * 自动休眠（Auto-Pause）开关与时间设定。
* **预装开发工具链**：Node.js、Python、Rust、Go、Flutter 开关标识。

### 2. 仓库选择器 (`GitRepoPickerSheet`)
* 支持根据 Token 实时读取用户的 GitHub 仓库列表（公开/私有、星标、语言、最后更新时间）；
* 实时搜索过滤；
* 选中仓库后自动拉取默认分支信息。

### 3. 一键启动云工作区 (`CloudWorkspaceLaunchDialog`)
* **参数前置校验**：API Key 必填检查；
* **沙盒创建**：调用 `POST /v2/sandboxes` 注入环境变量；
* **服务就绪保障**：
  * 通过内部通道在沙盒内拉起 `opencode serve --hostname 0.0.0.0 --port 4096`；
  * 自动在沙盒内检出/克隆指定的 Git 代码仓库至 `/home/user/workspace`；
  * 轮询 `/api/health` 端口健康状态；
* **全自动接入**：健康检查通过后直接调用 `SidecarManager.updateConnection` 并进入 App 首页。

### 4. 现有沙盒全生命周期管理 (`OpencodeConnectionPage`)
* **沙盒列表读取**：实时拉取用户 E2B 账户下的所有沙盒及其实时状态（运行中、已休眠、已终止）；
* **一键唤醒与进入**：
  * 休眠沙盒先调用 `POST /v2/sandboxes/{id}/resume` 唤醒；
  * 确认服务在 4096 端口在线后自动握手进入；
* **一键休眠（Pause）**：挂起沙盒以节省计算时长与费用；
* **一键销毁（Destroy）**：彻底删除释放沙盒资源；
* **当前活跃沙盒卡片**：展示当前已连接的沙盒 ID、状态、外网访问地址与最后连接时间。

---

## 四、核心交互时序图

### 1. 「一键启动云工作区」全流程

```mermaid
sequenceDiagram
    autonumber
    actor User as 用户
    participant App as 手机 App (UI)
    participant Svc as E2bWorkspaceService
    participant E2B as E2B 云端 API
    participant VM as MicroVM (envd:49983)
    participant OpenCode as OpenCode (:4096)
    participant Sidecar as SidecarManager

    User->>App: 点击「🚀 一键启动云工作区」
    App->>Svc: launchWorkspace(config)
    Svc->>E2B: POST /v2/sandboxes (templateID, envVars, timeout)
    E2B-->>Svc: 201 Created (sandboxID)
    
    rect rgb(240, 248, 255)
    Note over Svc,VM: 沙盒内部初始化与拉起服务
    Svc->>VM: POST /process.Process/Start (opencode serve + git clone)
    VM->>OpenCode: 启动后台守护进程 (0.0.0.0:4096)
    end

    loop 轮询健康检查 (最长 30 秒)
        Svc->>OpenCode: GET /api/health (Basic Auth)
        OpenCode-->>Svc: 200 OK
    end

    Svc-->>App: E2bLaunchResult(success: true)
    App->>Sidecar: updateConnection(endpointUrl, user, password)
    Sidecar-->>App: 握手成功
    App->>User: 跳转至主会话页面，开始编码
```

### 2. 「进入现有沙盒」流程

```mermaid
sequenceDiagram
    autonumber
    actor User as 用户
    participant App as 手机 App (UI)
    participant Svc as E2bWorkspaceService
    participant E2B as E2B 云端 API
    participant OpenCode as OpenCode (:4096)
    participant Sidecar as SidecarManager

    User->>App: 点击沙盒卡片「进入沙盒」
    alt 沙盒处于休眠状态 (paused)
        App->>Svc: resumeSandbox(sandboxId)
        Svc->>E2B: POST /v2/sandboxes/{id}/resume
        E2B-->>Svc: 200 OK (沙盒唤醒)
    end

    App->>Svc: ensureOpenCodeRunning(sandboxId)
    Note over Svc,OpenCode: 确保 opencode serve 进程常驻

    App->>Svc: waitForHealthy(endpointUrl)
    Svc->>OpenCode: GET /api/health
    OpenCode-->>Svc: 200 OK

    App->>Sidecar: updateConnection(endpointUrl, password)
    Sidecar-->>App: 成功连接
    App->>User: 进入主会话
```

---

## 五、代码结构与文件索引

| 模块/层级 | 文件路径 | 职责说明 |
| :--- | :--- | :--- |
| **数据模型** | `lib/models/cloud_workspace_config.dart` | 云工作区用户偏好、Token、Git 仓库、活动沙盒持久化模型 |
| **数据模型** | `lib/models/e2b_sandbox_info.dart` | E2B 沙盒元数据解析（ID、模板、状态、创建时间、外网 URL） |
| **核心服务** | `lib/services/e2b_workspace_service.dart` | E2B REST/RPC 交互单例（创建、销毁、唤醒、休眠、列表、进程守护、健康轮询） |
| **Git 服务** | `lib/services/git_repo_service.dart` | GitHub 仓库读取、搜索、带鉴权 Clone URL 构建 |
| **连接界面** | `lib/pages/settings/opencode/connection_page.dart` | 直连 / 云端工作区双模式切换、沙盒列表展示与操作 |
| **配置底板** | `lib/pages/settings/opencode/cloud_workspace_sheet.dart` | 云工作区配置抽屉（API Key、Git Token、模板、超时） |
| **启动弹窗** | `lib/pages/settings/opencode/cloud_workspace_launch_dialog.dart` | 一键启动进度弹窗动画与状态流转 |
| **仓库选择** | `lib/pages/settings/opencode/git_repo_picker_sheet.dart` | Git 仓库浏览与分支选择抽屉 |
| **多语言** | `lib/utils/translations.dart` | 云工作区中英文国际化文本字典 |
| **单元测试** | `test/services/e2b_workspace_service_test.dart` | 配置持久化、序列化、鉴权 URL、沙盒状态解析等 12 项测试 |

---

## 六、排查与容错规范

1. **凭证隔离与安全性**：
   * E2B API Key 仅在请求 E2B 官方接口时以 `X-API-Key` 携带，绝不对外暴露；
   * 沙盒服务密码由系统每次启动随机生成 24 位高强度字符串，仅注入 MicroVM 环境变量与客户端本地加密持久化；
   * Git Token 仅在沙盒内部通过 `git clone` 临时使用，不保留在公开 URL 中。
2. **健康检查与防挂死机制**：
   * 启动与连接均配置有超时与最大重试次数限制（15~20 次，每次间隔 2 秒）；
   * 超时未就绪会主动向用户给出明确的错误原因与排查提示，阻止 App 无限等待。

---

## 七、502 故障修复记录(2026-08-31)

### 现象

创建沙盒成功,但健康检查轮询 `https://4096-{sandboxId}.e2b.app/api/health` 持续返回
`HTTP 502 {"message":"The sandbox is running but port is not open","port":4096}`。
含义:沙盒 MicroVM 活着,但 4096 端口上没有任何进程在监听 —— 即
`opencode serve` 从未在沙盒内成功启动。

### 根因(共 4 处叠加)

1. **envd 地址是空壳**:`ConnectionConfig.getSandboxEnvdUrl` 无视 sandboxId 恒返回
   `https://sandbox.e2b.app`,命令未路由到目标沙箱。已改为直连域名路由
   `https://49983-{sandboxId}.{domain}`(与业务端口 `4096-{sandboxId}` 同一机制)。
2. **Connect-RPC 流式请求体未加信封帧**:`process.Process/Start` 是 server-streaming
   RPC,请求体必须是 `1 字节 flags + 4 字节大端长度 + JSON` 帧
   (Content-Type: `application/connect+json`);原实现发送裸 JSON 必被 400 拒绝。
   unary 方法则应为裸 JSON(`application/json`)。
3. **启动失败被静默吞掉**:`ensureOpenCodeRunning` 返回值在两处调用点均被丢弃,
   失败后照常进入健康轮询,表现为无限 502。
4. **缺少 opencode 安装兜底**:bootstrap 脚本只做 `which opencode` 检查,
   模板内没有 opencode 二进制时进程即退,端口永远打不开。

### 修复与新增能力

| 项 | 说明 |
|---|---|
| envd 直连域名 | `getSandboxEnvdUrl(sandboxId)` → `https://49983-{sandboxId}.{domain}`,支持 sandboxUrl 显式覆盖 |
| 信封帧协议 | `serverStreamCall` 请求体用 `encodeFrame` 编码;unary 用裸 JSON;修复 UTF-16 codeUnits 解帧损坏多字节字符 |
| envd 认证 | `X-Access-Token` 使用创建/连接响应签发的 `envdAccessToken`(已持久化到 `CloudWorkspaceConfig.activeSandboxEnvdToken`),API Key 仅兜底 |
| 安装兜底 | bootstrap 脚本内 `command -v opencode` 失败时先跑官方安装脚本 `curl -fsSL https://opencode.ai/install | bash`,再 `npm i -g opencode-ai` 兜底;退出码 42=安装失败、43=serve 启动失败 |
| 失败上抛 | `ensureOpenCodeRunning` 返回结构化 `E2bBootstrapResult`(成功/原因/`/tmp/opencode.log` 尾部),launch 与连接页检查失败即中止并展示 |
| 健康轮询 | 502=未就绪继续重试;401/403=密码不匹配立即失败;总窗口放宽至约 120 秒(60 次 × 2 秒) |
| 真实 connect | `Sandbox.connect` 真正调用 `POST /sandboxes/{id}/connect`(body `{timeout}`),自动唤醒 paused 沙盒(201)并刷新 envdAccessToken;404 明确报错 |
| TTL keep-alive | 新增 `Sandbox.setTimeout`(`POST /sandboxes/{id}/timeout`),连接成功后每 5 分钟续期,销毁/切回自建服务器时停止 |
| 密码恢复 | bootstrap 将密码落盘 `~/.opencode_pw`(chmod 600);重连密码未知时通过 envd 读取恢复,不再使用字面量 `'opencode'` 兜底 |
| background 语义 | `Commands.start(background: true)` 收到 start 事件(pid)即脱离事件流返回,进程由 envd 托管继续运行(对齐官方 JS SDK) |
| 错误映射 | envd 401/403 → `SandboxAuthenticationException`,404 → `SandboxNotFoundException`,5xx → `SandboxException` |

### 真机联调步骤

1. 在 [e2b.app](https://e2b.app) 获取 API Key(`e2b_` 前缀),App 设置 → 连接 → E2B 云端 → 配置中填入;
2. 模板 ID 可留空默认 `opencode`,或使用[自定义模板](e2b_template_guide.md)(秒级启动);
3. 点击「新建沙盒」,观察弹窗进度:申请沙盒 → 部署 OpenCode(首启需安装约 30~60 秒)→ 健康握手 → 进入工作区;
4. 若失败,弹窗会展示具体原因与沙盒内 `/tmp/opencode.log` 尾部;沙盒保留在列表中,可销毁或重连。

### 补充修复(2026-08-31 第二轮:状态展示与错误透出)

1. **云端模式专属状态条**:此前顶部状态条在云端模式也显示自建服务器连接状态
   (来自上次持久化的 `Global.serverUrl` 健康检查),导致未配置 Key 也显示"已连接"。
   现在云端模式显示自身状态:未配置 Key / 未连接 / 已连接(实时探测)/ 服务未就绪(502)/ 认证未通过(401)。
2. **控制面错误透出**:`Sandbox.create/list/pause/resume/kill/setTimeout` 均改为
   `validateStatus: true` + 解析 E2B 错误体 `{code,message}`,不再被 Dio 通用异常文案
   吞掉真实原因(如 "Template not found"、"Invalid API key");401/403 → "API Key 无效",
   message 含 template → 附加"检查模板 ID"指引。
3. **"当前连接"徽标收紧**:仅当 `Global.serverUrl` 真实包含该沙盒 ID 时才标记,
   不再仅凭持久化的 `activeSandboxId`。
4. **启动弹窗前置校验**:Key 为空直接报错,不发起任何请求。

### 补充修复(2026-08-31 第三轮:bootstrap 自匹配导致 serve 未启动)

**现象**:沙盒 RUNNING、`opencode --version` 正常输出,但 4096 端口始终 502,
bootstrap 却报成功。

**根因**:bootstrap 脚本经 `bash -l -c '<全文>'` 执行,**进程自身 cmdline 包含脚本全文**,
开头的 `pgrep -f "opencode serve"` 匹配到了脚本自己,误判"已在运行"直接 `exit 0`,
serve 从未被拉起。`recoverPassword` 存在同款自匹配。

**修复**:
* 服务就绪判定全部改为 **curl 探测本机 `127.0.0.1:4096/api/health`**(带密码),
  三态:200=健康跳过 / 000=无监听需启动 / 其他=有服务但密码不匹配,kill 后带正确密码重启;
* `pgrep`/`pkill` 一律使用 `[o]pencode serve` 正则写法规避自匹配;
* 启动后从「固定 sleep 2 检查一次」改为**轮询等待端口就绪(最多约 30 秒)**,
  进程中途退出立即 `exit 43` 并输出 `/tmp/opencode.log`;
* serve 以 `setsid nohup` 脱离会话启动;密码落盘 `~/.opencode_pw` 移至脚本最前。
