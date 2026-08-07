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
> **NOT FOR PRODUCTION USE** — This project is currently in active development.

---

## 📱 About The Project

**OpenCode Mobile** is a mobile client built with **Flutter** and **Rust** for OpenCode. 

It is designed to run seamlessly on Android smartphones and tablets:
- **Phone UI**: Clean, single-column conversational interface.
- **Tablet UI**: Optimized layout using a multi-pane split view.

Voice input currently supports Chinese, English, Japanese, and Korean. Whether additional language support will be added depends on user distribution.

---

## 🚀 Release Notes (v0.9.8)

Here are the latest updates and bug fixes:

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

If you encounter any bugs or have feature requests, please feel free to open an issue!
