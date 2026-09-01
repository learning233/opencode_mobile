# E2B 自定义模板指南:预装 opencode 秒级启动

> 配套文档:`e2b_cloud_workspace.md`(功能设计与 502 修复记录)。
>
> 不构建自定义模板也能用:App 的 bootstrap 脚本会在沙盒内自动安装 opencode
> (官方安装脚本 / npm 兜底),首次启动约需 30~60 秒。构建自定义模板后,
> opencode 与启动命令被**快照固化**,创建沙盒 < 1 秒即可连接。

## 一、为什么自定义模板更快

E2B Build System 2.0 在构建期执行 `start_cmd` 并对**整块内存做 Snapshot** 固化为模板。
之后每次 `Sandbox.create(template)` 都是从快照拉起:进程已经在跑、端口已监听,
App 侧健康检查秒过。

## 二、构建步骤(在装有 Node.js 的电脑上执行一次)

### 1. 准备文件

新建目录,放入以下两个文件:

**`e2b.Dockerfile`**

```dockerfile
FROM e2bdev/base

# e2bdev/base 为 Debian 系,预装 Python3 / Node.js / Yarn / git / curl / build-essential / gh
RUN npm install -g opencode-ai@latest \
    && ln -sf "$(command -v opencode)" /usr/local/bin/opencode

# 预装常用开发工具链(按需增删)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ripgrep jq unzip \
    && rm -rf /var/lib/apt/lists/*
```

**`e2b.toml`**

```toml
[template]
name = "opencode"
# 沙盒每次启动时由 envd 自动拉起 opencode serve(构建期固化进快照)
start_cmd = "opencode serve --hostname 0.0.0.0 --port 4096"
# 就绪判定:构建期轮询该命令,exit 0 才允许固化快照
ready_cmd = "curl -fsS http://127.0.0.1:4096/global/health"
```

要点:
* `--hostname 0.0.0.0` **必须显式指定**(opencode serve 默认 `127.0.0.1`,绑定回环会导致公网 502);
* `start_cmd` 里**不要**写死 `OPENCODE_SERVER_PASSWORD` —— 密码由 App 在创建沙盒时
  通过环境变量注入,由 bootstrap 脚本负责带密码拉起(模板的 start_cmd 作为兜底,无密码时健康检查 401 也会被 App 识别)。

### 2. 构建并发布

```bash
npm i -g @e2b/cli@latest
e2b login                 # 浏览器授权,或 e2b auth login --token <你的API Key>
e2b template create       # 提交云端构建(旧命令 e2b template build 已 deprecated)
e2b template list         # 记下模板 ID,形如 <your-username>/opencode
```

### 3. 在 App 中使用

设置 → 连接 → E2B 云端 → 配置 → 「模板 ID」填入 `e2b template list` 输出的 ID
(如 `myname/opencode`)。此后每次「新建沙盒」都从快照秒级拉起。

## 三、模板与 App bootstrap 的分工

| 阶段 | 模板(start_cmd 固化) | App bootstrap 脚本 |
|---|---|---|
| opencode 安装 | 构建期 `npm i -g opencode-ai` | 运行时缺失才装(curl 脚本 → npm 兜底,退出码 42) |
| serve 拉起 | envd 随沙盒启动自动执行 | 检测 4096 已监听则跳过;否则补拉起(带密码) |
| 密码 | 无(模板不知道密码) | 创建时注入 `OPENCODE_SERVER_PASSWORD` 并落盘 `~/.opencode_pw` |
| Git 仓库 | 无 | 创建时注入 `GIT_CLONE_URL`/`GIT_BRANCH`,clone 到 `~/<GitHub项目名>`(未绑仓库时 `~/workspace`) |

> 注意:模板 start_cmd 拉起的 serve **没有密码**,公网健康检查会返回 401。
> App 的 bootstrap 会检测到 4096 已有监听进程,若密码不一致会以注入密码重启 serve;
> 因此即使用了带 start_cmd 的模板,也请让 App 完成 bootstrap 再连接。
> 若想模板内直接免密启动后由 App 重启,保持 `start_cmd` 原样即可,无需额外处理。

## 四、常见问题

* **构建后创建沙盒仍 502**:检查模板 `ready_cmd` 是否真的 exit 0;登录 E2B Dashboard 看构建日志。
* **Hobby 计划限制**:沙盒单次 TTL 上限 1 小时(Pro 为 24 小时);App 的 keep-alive 每 5 分钟续期,
  超过套餐上限由服务端钳制。
* **模板更新**:改 Dockerfile 后重新 `e2b template create`;同名模板默认覆盖 `:default` tag。
