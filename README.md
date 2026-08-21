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
> **UNOFFICIAL PROJECT** — This is an **unofficial** mobile client for OpenCode.

---

> [!IMPORTANT]
> If you cannot continue chatting in historical sessions, please update your OpenCode version immediately. If installed following [docs/server_en.md](./docs/server_en.md), run `sudo systemctl restart opencode` after upgrading.

---

Tokens are way too expensive right now, couldn't even afford DeepSeek Flash anymore, so decided to open-source this.

My Windows offline speech-to-text project is available on the Microsoft Store:
- Microsoft Store: https://apps.microsoft.com/detail/9pdf92ts07pf
- Documentation: https://owlmeeting.com/docs/en/
- Small support: Download the trial version and leave a good review
- Big support: You know what to do 😉

---

## 📱 About The Project

**OpenCode Mobile** is an **unofficial** mobile client built with **Flutter** and **Rust** for OpenCode, connecting to a remote `opencode serve` backend via Basic Auth.

Currently adapted for Android phones and tablet devices:
- **Phone UI**: Clean and efficient single-column chat interface, with built-in quick phrases, terminal, file tree, and browser preview.
- **Tablet UI**: Dual-pane / multi-pane layout optimized for split-screen, maximizing wide screen utilization.

---

## 🛠️ Local Development & Build

### Prerequisites
- **Flutter SDK**: 3.38.5(Dart 3.10)
- **Rust**: 1.88 supported

### Common Commands
```bash
# Get dependencies
flutter pub get

cd rust
cargo build --release
```

### Notes
Most APIs are based on OpenCode v1. When this project was being written, there were issues with state control in the session APIs of the v2 version that couldn't be tuned properly. Not sure if those issues still exist now.

