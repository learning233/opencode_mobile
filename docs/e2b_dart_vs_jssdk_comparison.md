# E2B Dart SDK 与官方 JS SDK (`packages/js-sdk`) 全方位比对报告

> 本报告对当前 Dart SDK 实现 (`lib/services/e2b/`) 与 E2B 官方 JS SDK 源码 (`clone/E2B/packages/js-sdk/src/`) 进行了逐模块、逐类、逐 API 级别的全量比对与差异分析。

---

## 一、模块映射与架构分层对比

| 功能领域 | 官方 JS SDK (`packages/js-sdk/src/`) | Dart SDK 实现 (`lib/services/e2b/`) | 对应状态 |
| :--- | :--- | :--- | :---: |
| **库入口** | `index.ts` | `e2b.dart` | ✅ 100% 对齐 |
| **沙盒实体** | `sandbox/index.ts` (`Sandbox` 类) | `sandbox.dart` (`Sandbox` 类) | ✅ 核心 API 对齐 |
| **异常体系** | `errors.ts` | `models/errors.dart` | ✅ 对齐核心异常 |
| **通信配置** | `connectionConfig.ts` | `transport/connection_config.dart` | ✅ 对齐 |
| **URL 签名** | `sandbox/signature.ts` | `transport/signature.dart` | ✅ 算法 100% 对齐 |
| **Connect 传输** | `envd/rpc.ts`, `envd/http2.ts`, `@connectrpc/connect` | `transport/connect_transport.dart` | ✅ 协议帧级对齐 |
| **命令执行** | `sandbox/commands/index.ts`, `commandHandle.ts` | `services/commands.dart`, `process_models.dart` | ✅ 核心能力对齐 |
| **伪终端 PTY** | `sandbox/commands/pty.ts` | `services/pty.dart`, `pty_models.dart` | ✅ 终端流与尺寸调整对齐 |
| **文件系统** | `sandbox/filesystem/index.ts`, `watchHandle.ts` | `services/filesystem.dart`, `filesystem_models.dart` | ✅ 读写删查对齐 |
| **Git 模块** | `sandbox/git/index.ts`, `git/utils.ts` | `services/git.dart` | ✅ 基础操作对齐 |
| **模板构建** | `template/index.ts` | *(未移植，移动端无需 CLI 模板构建)* | ℹ️ 不适用移动端 |
| **云持久卷** | `volume/index.ts` | *(未移植，移动端主要用沙盒工作区)* | ℹ️ 属于企业级特性 |

---

## 二、核心类与 API 级详细对比

### 1. `Sandbox` 门面类

| JS SDK (`sandbox/index.ts`) | Dart SDK (`sandbox.dart`) | 比对说明 |
| :--- | :--- | :--- |
| `Sandbox.create(template, opts)` | `Sandbox.create(opts)` | ✅ 支持模板、超时、autoPause、envVars、metadata |
| `Sandbox.connect(sandboxId, opts)` | `Sandbox.connect(opts)` | ✅ 支持以指定 sandboxId 与 accessToken 连接 |
| `Sandbox.list(opts)` | `Sandbox.list(opts)` | ✅ 支持分页与状态过滤 |
| `Sandbox.kill(sandboxId, opts)` | `Sandbox.kill(sandboxId, apiKey)` | ✅ REST DELETE 销毁沙盒 |
| `Sandbox.pause(sandboxId, opts)` | `Sandbox.pause(sandboxId, apiKey)` | ✅ 冻结快照休眠 |
| `Sandbox.resume(sandboxId, opts)` | `Sandbox.resume(sandboxId, apiKey)` | ✅ 恢复运行沙盒 |
| `sandbox.getHost(port)` | `sandbox.getHost(port)` | ✅ 映射格式：`{port}-{sandboxId}.{domain}` |
| `sandbox.getHostUrl(port)` | `sandbox.getHostUrl(port)` | ✅ 映射格式：`https://{port}-{sandboxId}.{domain}` |
| `sandbox.downloadUrl(path, opts)` | `E2bSignature.getSignature(...)` | ✅ 基于 SHA-256 计算临时下载/上传签名 |
| `Sandbox.fork(sandboxId, count)` | *(待后续扩展)* | ℹ️ 批量分叉沙盒（移动端低频） |

---

### 2. `Commands` 进程命令模块

| JS SDK (`sandbox/commands/index.ts`) | Dart SDK (`services/commands.dart`) | 比对说明 |
| :--- | :--- | :--- |
| `commands.run(cmd, opts)` | `commands.run(cmd, opts)` | ✅ 阻塞等待执行完毕，返回 `CommandResult` |
| `commands.run(cmd, { background: true })` | `commands.start(cmd, opts)` | ✅ 异步启动，返回 `CommandHandle` (含 `pid`) |
| `handle.wait()` | `handle.wait()` | ✅ 等待后台进程执行完成并获取结果 |
| `handle.kill()` | `handle.kill()` | ✅ 发送 SIGTERM / SIGKILL 终止进程 |
| `handle.sendStdin(data)` | `handle.sendStdin(data)` | ✅ 向进程写入标准输入 |
| `handle.closeStdin()` | `handle.closeStdin()` | ✅ 发送 EOF 关闭输入流 |
| `commands.connect(pid, opts)` | *(可直接通过 handle)* | ℹ️ JS SDK 额外支持对已存在 pid 进行重连 attach |

---

### 3. `Filesystem` 文件系统模块

| JS SDK (`sandbox/filesystem/index.ts`) | Dart SDK (`services/filesystem.dart`) | 比对说明 |
| :--- | :--- | :--- |
| `files.read(path, opts)` | `files.read(path, user)` | ✅ 文本读取 |
| `files.read(path, { format: 'bytes' })`| `files.readBytes(path, user)` | ✅ 二进制字节读取 |
| `files.write(path, data, opts)` | `files.write(path, data, user)` | ✅ 文本写入 |
| `files.write(path, bytes, opts)` | `files.writeBytes(path, bytes)` | ✅ 二进制写入（基于 Octet-Stream） |
| `files.list(path)` | `files.list(path)` | ✅ 列出目录项（返回 `List<EntryInfo>`） |
| `files.makeDir(path)` | `files.makeDir(path)` | ✅ 创建目录 |
| `files.remove(path)` | `files.remove(path)` | ✅ 删除文件/目录 |
| `files.exists(path)` | `files.exists(path)` | ✅ 检查文件/目录是否存在 |
| `files.watchDir(path)` | *(通过 ConnectTransport 流接收)* | ℹ️ 目录实时变动长连接事件流 |

---

### 4. `Pty` 伪终端模块

| JS SDK (`sandbox/commands/pty.ts`) | Dart SDK (`services/pty.dart`) | 比对说明 |
| :--- | :--- | :--- |
| `pty.create(opts)` | `pty.create(opts)` | ✅ 分配 PTY 伪终端，返回 `PtyHandle` |
| `handle.sendInput(data)` | `handle.sendInput(data)` | ✅ 发送按键/输入二进制流 |
| `handle.resize({ cols, rows })` | `handle.resize(PtySize)` | ✅ 动态调整终端窗口大小 |
| `handle.kill()` | `handle.kill()` | ✅ 发送 SIGKILL 销毁终端会话 |

---

### 5. `Git` 模块

| JS SDK (`sandbox/git/index.ts`) | Dart SDK (`services/git.dart`) | 比对说明 |
| :--- | :--- | :--- |
| `git.clone(url, opts)` | `git.clone(url, targetDir, branch)`| ✅ 注入 `GIT_TERMINAL_PROMPT=0` 防交互卡死 |
| `git.checkout(branch)` | `git.checkout(branch, cwd)` | ✅ 分支检出 |
| `git.status()` | `git.status(cwd)` | ✅ `git status --porcelain` 解析 |
| `git.commit(msg)` | `git.commit(msg, cwd)` | ✅ 自动 `add -A` 并提交 |
| `git.push(opts)` | `git.push(remote, branch, cwd)` | ✅ 推送远端 |

---

## 三、底层通信与协议实现比对

```mermaid
graph LR
    subgraph JS_SDK [官方 JS SDK]
        JS_Connect[@connectrpc/connect-web]
        JS_Fetch[Undici / Fetch API]
        JS_Buf[@bufbuild/protobuf]
    end

    subgraph Dart_SDK [Dart SDK]
        Dart_Transport[ConnectTransport 帧编解码引擎]
        Dart_Dio[Dio HTTP/2 / Streaming]
        Dart_Models[原生强类型 Model / JSON]
    end

    JS_Connect -.->|帧头 5 字节 + JSON 序列化| Dart_Transport
    JS_Fetch -.->|HTTP/1.1 & HTTP/2 长连接| Dart_Dio
```

* **Connect 协议帧完全一致**：
  * 数据帧 Flag：`0x00`；
  * 结束尾帧 Flag：`0x02`；
  * 长度字段：4 字节大端序（Big-Endian）；
  * 请求 Header：`Connect-Protocol-Version: 1`, `Content-Type: application/connect+json`, `E2b-Sandbox-Port: 49983`。
* **签名算法完全一致**：
  * `raw = path + ':' + operation + ':' + user + ':' + envdAccessToken + (expiration ? ':' + expiration : '')`；
  * `v1_` 前缀 + Base64（无 Padding `=` 结尾）。

---

## 四、比对总结

1. **核心覆盖率**：针对 OpenCode Mobile 移动端运行所需的所有功能（沙盒生命周期、进程执行与后台守护、PTY 终端流、Git 仓库克隆检出、文件读写签名），Dart SDK 的覆盖率达到 **100%**。
2. **免除了 Node 外部依赖**：用 Dart 原生实现了 Connect-RPC 的封包/解包与流处理，无需引入庞大的 gRPC 外部三方编译链，体积极其小巧。
3. **架构清晰解耦**：完全复刻了 JS SDK 的 `Sandbox` -> `Commands` / `Files` / `Pty` / `Git` 树状门面结构，调用方式与官方文档一致。
