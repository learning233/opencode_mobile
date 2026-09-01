# E2B 官方 SDK 源码架构与技术通信原理全景文档

> 基于克隆的官方最新 SDK 源码（`packages/js-sdk`、`packages/python-sdk`、`packages/cli`）深度研读与梳理。

---

## 一、E2B 总体架构全景

E2B 是一套基于 **Firecracker MicroVM** 的云端安全沙盒系统，整个生态分为三层：

```mermaid
flowchart TD
    subgraph Client [客户端 / SDK 层]
        JS_SDK[JavaScript / TypeScript SDK]
        PY_SDK[Python SDK]
        CLI[E2B CLI 工具]
        Mobile[OpenCode Mobile App]
    end

    subgraph ControlPlane [E2B 控制面 Control Plane]
        API[REST API: https://api.e2b.app/v2]
        Router[Edge Ingress 路由代理网关]
    end

    subgraph DataPlane [沙盒数据面 MicroVM (Firecracker)]
        Envd[envd 守护进程 :49983<br/>Connect-RPC 服务]
        ProcSubsystem[进程子系统<br/>process.Process]
        FsSubsystem[文件子系统<br/>filesystem.Filesystem]
        AppServer[用户服务<br/>如 OpenCode :4096]
    end

    Client -->|沙盒创建/销毁/休眠/唤醒/列表| API
    Client -->|进程控制/文件操作/终端交互| Envd
    Client -->|访问应用端点 :4096| Router
    Router -->|透明反向代理| AppServer
    Envd --> ProcSubsystem
    Envd --> FsSubsystem
```

---

## 二、控制面 REST API 规范 (`https://api.e2b.app/v2`)

控制面负责沙盒的生命周期管理，使用标准 HTTPS JSON 协议：

### 1. 核心端点

| 方法 | 端点 | 请求体关键字段 | 返回数据与说明 |
| :--- | :--- | :--- | :--- |
| `POST` | `/sandboxes` | `templateID`, `timeout`, `autoPause`, `envVars`, `metadata` | 创建沙盒，返回 `sandboxID`, `envdAccessToken`, `domain` 等 |
| `GET` | `/sandboxes` | Query: `state` (`running`, `paused`), `limit`, `nextToken` | 分页拉取沙盒列表 |
| `GET` | `/sandboxes/{id}` | - | 获取单个沙盒详情（状态、创建时间等） |
| `POST` | `/sandboxes/{id}/pause` | - | 将沙盒挂起休眠（冻结内存快照，停止计费） |
| `POST` | `/sandboxes/{id}/resume` | - | 秒级从快照唤醒沙盒恢复运行 |
| `DELETE` | `/sandboxes/{id}` | - | 彻底销毁释放沙盒资源 |

### 2. 鉴权头部
所有请求必须携带：
```http
X-API-Key: e2b_***
Content-Type: application/json
```

---

## 三、沙盒内部守护进程 `envd` 与 Connect-RPC（端口 49983）

每个 MicroVM 内部均常驻运行一个名为 `envd` 的 Go 守护进程，监听内部 **49983** 端口。

### 1. 通信协议与网关寻址
SDK 与 `envd` 的通信基于 **Connect-RPC 协议**（兼容 gRPC-Web 与 Connect JSON 格式）：
* **直接域名格式**：`https://49983-{sandboxId}.e2b.app`
* **网关统一域名**：`https://sandbox.e2b.app`

### 2. 鉴权与路由头部
向 `envd` 发起 Connect-RPC 调用时，SDK 会注入以下关键 Header：
```http
Connect-Protocol-Version: 1
Content-Type: application/connect+json
E2b-Sandbox-Id: {sandboxId}
E2b-Sandbox-Port: 49983
X-Access-Token: {envdAccessToken}   # 或 X-API-Key: {apiKey}
Keepalive-Ping-Interval: 50
```

### 3. `process.Process` 服务接口定义

官方 Proto 定义于 `process/process.proto`：

#### (1) `Start` (Server Streaming RPC)
```protobuf
rpc Start(StartRequest) returns (stream StartResponse);
```
* **请求结构 `StartRequest`**：
  ```json
  {
    "process": {
      "cmd": "/bin/bash",
      "args": ["-l", "-c", "echo hello"],
      "envs": { "KEY": "VALUE" },
      "cwd": "/home/user"
    },
    "pty": { "size": { "cols": 80, "rows": 24 } },  // 可选：启用 PTY
    "stdin": false
  }
  ```
* **响应流 `StartResponse`**：
  返回二进制 Connect 帧序列，包含三种事件：
  1. `start` 事件：`{ "pid": 12345 }`
  2. `data` 事件：`{ "stdout": "base64...", "stderr": "...", "pty": "..." }`
  3. `end` 事件：`{ "exit_code": 0, "exited": true, "error": "" }`

#### (2) `SendInput` / `StreamInput`
用于向运行中的进程输入 stdin 或终端按键。

#### (3) `SendSignal`
向进程发送信号（`SIGTERM=15`, `SIGKILL=9`）。

---

## 四、外网端口暴露与路由机制（`getHost`）

### 1. 域名生成规则
在 E2B 中，沙盒内运行的任何网络服务（如 OpenCode 的 4096 端口、Web 服务的 3000/8000 端口）通过 E2B 边缘网关自动暴露：

```typescript
getHost(port: number): string {
  return `${port}-${sandboxId}.${domain}` // 例如：4096-izz06i52v927k3g5dy73o.e2b.app
}
```

### 2. 边缘网关状态码与诊断

| 网关返回 HTTP 状态 | 含义与根本原因 |
| :--- | :--- |
| **`200 OK`** | 服务正常运行且端口监听在 `0.0.0.0:{port}` 上 |
| **`502 Bad Gateway`** | **最常见错误**：<br/>1. 沙盒处于休眠（paused）或已被销毁；<br/>2. 沙盒内部**没有进程监听该端口**；<br/>3. 进程监听在 `127.0.0.1` 而不是 `0.0.0.0`，导致外网流量无法转发。 |
| **`401 Unauthorized`** | 外网已接通，但应用服务自身的认证失败（例如 OpenCode 的密码错误）。 |

---

## 五、官方 SDK 中的三大子系统实现机制

### 1. 进程命令系统 (`Commands` / `Pty`)
* **前台阻塞运行 (`commands.run(cmd)`)**：
  调用 `Process.Start` 建立 Connect-RPC 长连接流，消费流中全部 `stdout`/`stderr` 数据，直到收到 `end` 事件返回 `CommandResult`。
* **后台异步守护运行 (`commands.run(cmd, { background: true })`)**：
  发起 `Process.Start` 收到 `start` 事件获取 `pid` 后立即返回 `CommandHandle`，后台流通过管道独立管理。

### 2. 文件系统 (`Filesystem`)
* 基于 `filesystem.Filesystem` 服务实现 `read`, `write`, `list`, `makeDir`, `remove`, `watchDir`；
* 大文件走分块流式上传/下载；
* 文件监视器（`watchDir`）通过 Server Streaming 实时回传 `CREATE`, `WRITE`, `REMOVE`, `RENAME` 事件。

### 3. Git 模块 (`Git`)
* 官方 SDK 内部直接通过 `commands.run` 调用系统 `git` 命令行完成 clone、checkout、commit、push 等操作；
* 注入 `GIT_TERMINAL_PROMPT=0` 防止交互式卡死；
* 通过带有 Token 的 URL 或环境变量传递凭证。

---

## 六、模板（Template）系统与快照机制

### 1. 模板构建原理（v2 构建系统）
* 开发者通过 `e2b template create` 提交 `e2b.Dockerfile`；
* E2B 云端构建 Docker 镜像并在 Firecracker 中启动；
* 执行 `CMD` 或 `-c` 声明的 `start_cmd`，等待 `ready_cmd`（例如等待 4096 端口或特定健康 URL 就绪）；
* 对 MicroVM 整个内存状态制作 **Snapshot（内存快照）** 并持久化为模板。

### 2. 启动速度差异
* **基于带 `start_cmd` 的专用模板**：启动即是从就绪内存快照恢复，**耗时 < 1 秒**，端口瞬时在线；
* **基于空白 `base` 模板动态安装**：需要实时联网下载解压二进制，受网络与 I/O 影响耗时 3~10 秒。
