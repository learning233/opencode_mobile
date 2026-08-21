# OpenCode Mobile

<p align="center">
  <img src="./phone.jpg" width="30%" alt="手机端截图" />
  &nbsp;&nbsp;
  <img src="./tablet.jpg" width="65%" alt="平板端截图" />
</p>

<p align="center">
  <a href="./README.md">English</a> | <b>简体中文</b>
</p>

> [!WARNING]
> **非官方项目 & 非生产级可用** — 本项目为 OpenCode 的**非官方**移动端客户端，目前仍处于积极开发和测试阶段。

---

> [!IMPORTANT]
> 如遇历史消息无法继续聊天，请立即更新 OpenCode 版本。如果是按照 [docs/server.md](./docs/server.md) 中安装的，升级完执行 `sudo systemctl restart opencode`。

---

## 📱 项目简介

**OpenCode Mobile** 是基于 **Flutter** 和 **Rust** 开发的 OpenCode **非官方**移动端客户端，通过 Basic Auth 连接远程 `opencode serve` 后端。

目前针对 Android 手机与平板设备进行了适配：
- **手机端**：简洁高效的单栏对话界面，内置常用语、终端、文件树及浏览器预览。
- **平板端**：基于分屏优化的双栏/多栏布局，大屏空间利用更充分。
- **离线语音**：集成 SenseVoice ASR + Silero VAD + ONNX Runtime Rust 核心，支持中、英、日、韩语音识别。

---

## 🚀 快速连接服务器

详细教程见 [docs/server.md](./docs/server.md) 与 [docs/登录.md](./docs/登录.md)：

1. **服务端启动**：
   ```bash
   opencode serve --hostname 0.0.0.0 --port 4096
   ```
   并设置环境变量 `OPENCODE_SERVER_PASSWORD`。
2. **手机端连接**：
   在 App 登录页面输入 `http://<服务器局域网IP>:4096`，用户名默认 `opencode`，填入密码后点击连接。
3. **新增/扫描项目**：
   详细操作指引见 [docs/新增项目.md](./docs/新增项目.md)。

---

## 🛠️ 本地开发与构建

### 环境要求
- **Flutter SDK**：3.38.x 或更高版本（Dart 3.10+）
- **Rust 工具链**：支持 `flutter_rust_bridge` (2.12.0)
- **ONNX Runtime**：`onnx/libonnxruntime.so`

### 常用命令
```bash
# 获取依赖
flutter pub get

# 运行调试
flutter run

# 运行测试
flutter test

# 静态代码检查
flutter analyze
```

---

## 📋 版本更新记录 (v0.9.10)

### v0.9.10
1. **浏览器预览优化**：优化了打开浏览器预览的逻辑，已绑定端口时，不再打开新标签，而是刷新已有标签。
2. **子会话支持**：子任务的权限、问题事件已正常并入父级展示。

### v0.9.9
1. **消息发送队列**：在 AI 正在生成回复时发送的消息将自动放入待发送区域，生成完成后自动发送。
2. **隐私增强**：日志和 UI 上均隐藏具体 IP 地址。
3. **内置浏览器**：浏览器标签页优先显示网页标题。

### v0.9.8
1. **WebView 扩展**：支持点击预览按钮直接打开设置好的 IP+端口（长按可设置端口，可为每个项目绑定固定端口）。
2. **Terminal 页面**：仿 Termux 风格，支持键盘快捷键与自定义命令。
3. **图片识别模型**：支持设置图片识别模型，可以使用 OpenCode Zen 中的免费模型进行图片识别，识别内容将自动返回到输入框中。
4. **UI 优化**：若干界面细节调整与优化。

### v0.9.7
1. **Thinking Card 流式输出**：修复了此前 Thinking Card 流式输出被误禁用的问题。
2. **国际化补充**：补全并优化了应用内的多语言翻译。
3. **日志查看按钮**：在输入框上方新增临时日志按钮，方便直接查看与复制运行日志。
4. **连接页面修复**：修正了之前连接页面显示的错误 IP 地址。
5. **重连状态刷新**：优化了断线重连后的界面状态自动刷新机制。
6. **Subtask 自动滚动**：子任务列表支持随着状态更新自动滚动。

---

## 💬 问题反馈

如果您在运行过程中遇到任何问题或有改进建议，欢迎提交 [Issue](https://github.com/learning233/opencode_mobile/issues)！
