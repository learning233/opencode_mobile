# OpenCode Mobile

<p align="center">
  <img src="./phone.jpg" width="30%" alt="Phone Screenshot" />
  &nbsp;&nbsp;
  <img src="./tablet.jpg" width="65%" alt="Tablet Screenshot" />
</p>

<p align="center">
  <b>English</b> | <a href="./README_CN.md">简体中文</a>
</p>

> [!WARNING]
> **UNOFFICIAL PROJECT & NOT FOR PRODUCTION USE** — This is an **unofficial** mobile client for OpenCode and is currently in active development.

---

> [!IMPORTANT]
> If you cannot continue chatting in historical sessions, please update your OpenCode version immediately. If installed following [docs/server_en.md](./docs/server_en.md), run `sudo systemctl restart opencode` after upgrading.

---

## 📱 About The Project

**OpenCode Mobile** is an **unofficial** mobile client built with **Flutter** and **Rust** for OpenCode, connecting to a remote `opencode serve` instance via Basic Auth.

It is designed to run seamlessly on Android smartphones and tablets:
- **Phone UI**: Clean, single-column conversational interface with quick phrases, built-in terminal, file tree, and browser preview.
- **Tablet UI**: Optimized layout using a multi-pane split view to maximize wide screen usability.
- **Offline Voice Input**: Integrated SenseVoice ASR + Silero VAD + ONNX Runtime Rust core supporting Chinese, English, Japanese, and Korean voice recognition.

---

## 🚀 Quick Server Connection

For detailed setup guides, see [docs/server_en.md](./docs/server_en.md) and [docs/登录.md](./docs/登录.md):

1. **Start Server**:
   ```bash
   opencode serve --hostname 0.0.0.0 --port 4096
   ```
   and set the `OPENCODE_SERVER_PASSWORD` environment variable.
2. **Connect from Mobile**:
   Enter `http://<server-ip>:4096` in the splash screen, default username `opencode`, enter your password and connect.
3. **Project Management**:
   Check [docs/ADD_PROJECT_EN.md](./docs/ADD_PROJECT_EN.md) for adding and managing remote projects.

---

## 🛠️ Local Development & Build

### Prerequisites
- **Flutter SDK**: 3.38.x or higher (Dart 3.10+)
- **Rust Toolchain**: `flutter_rust_bridge` (2.12.0)
- **ONNX Runtime**: `onnx/libonnxruntime.so`

### Useful Commands
```bash
# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Run tests
flutter test

# Code analysis
flutter analyze
```

---

## 📋 Release Notes (v0.9.10)

### v0.9.10
1. **Browser Preview Optimization**: Improved browser preview behavior — if a port is bound, opening a preview now refreshes the existing tab instead of launching a new one.
2. **Subsession Support**: Subtask permissions and question events are merged cleanly into parent views.

### v0.9.9
1. **Message Queue**: Messages submitted while AI is generating responses are added to a pending area and sent automatically once completed.
2. **Privacy Enhancement**: Hidden specific IP addresses from both runtime logs and the user interface.
3. **In-App Browser**: Tab bar now prioritizes displaying web page titles over raw URLs.

### v0.9.8
1. **WebView Extension**: Added preview button support to open pre-configured IP and port directly (long-press to configure port; supports binding a fixed port for each project).
2. **Terminal Page**: Termux-inspired terminal page featuring keyboard shortcuts and custom commands.
3. **Image Recognition Model**: Added support for configuring vision/image recognition models (e.g., using free models from OpenCode Zen), with recognized text automatically returned to the input bar.
4. **UI Adjustments**: Various user interface tweaks and refinements.

### v0.9.7
1. **Thinking Card Streaming Output**: Fixed issue where streaming output for thinking cards was temporarily disabled.
2. **Internationalization (i18n)**: Expanded localization support across the app.
3. **Log Viewer**: Added a temporary log action button above the input bar to quickly view and copy runtime logs.
4. **Connection Page**: Fixed incorrect IP address display on the connection setup screen.
5. **Reconnection Handling**: Improved state refresh mechanism after reconnecting to the server.
6. **Subtasks Auto-scroll**: Subtasks now scroll automatically as progress updates arrive.

---

## 💬 Issues & AI Collaboration

If you encounter any bugs or have feature requests, please feel free to open an [Issue](https://github.com/learning233/opencode_mobile/issues)!
