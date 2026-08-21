# AGENTS.md — kterm

A Flutter terminal emulator package (mobile + desktop). Published as `kterm` on pub.dev.

## Commands

```bash
flutter pub get
dart format --set-exit-if-changed .
dart analyze lib/   # CI scope: no --fatal-infos needed — lib/ analyzes clean
# Tests — Flutter tests must run individually under flutter test:
flutter test test/kitty_emitter_test.dart    # fast: ~5s
flutter test test/kitty_parser_test.dart     # fast: ~5s
# Pure-Dart core tests can use dart test (no Flutter dependency):
dart test test/src/core/escape/emitter_test.dart   # 19 tests
dart test test/src/zmodem_test.dart                 # 38 tests
# Full suite is available but not run in a single pass (too many test files):
#   dart test test/src/zmodem_test.dart &
#   flutter test test/...
```

## Architecture

- **Core** (`lib/src/core/`) — frontend-independent terminal state machine (buffer, escape parser, input, mouse, cell data)
- **UI** (`lib/src/ui/`) — Flutter widgets: TerminalView, TerminalController, painter, render, search bar, themes
- **Exports**: `core.dart` (core-only), `ui.dart` (Flutter widgets), `kterm.dart` (both + zmodem), `utils.dart` (debug helpers)
- **Entrypoints**: `lib/src/terminal.dart` (Terminal, implements EscapeHandler + TerminalState), `lib/src/terminal_view.dart` (TerminalView widget), `lib/src/ui/controller.dart` (TerminalController)
- **Patterns**: Observable mixin for reactivity; IndexAwareCircularBuffer for scrollback; custom Painter + RenderBox for text grid

## Package dependencies

- `zmodem_lbp` — forked git dep (`pub.dev/packages/zmodem` v0.0.6 with 2 bugfixes: ZFIN frame handling + wrong LF byte). Import as `package:zmodem_lbp/`.
- `kitty_protocol` — upstream Kitty keyboard/graphics protocol bugs should be reported there

## Release

1. Bump version in `pubspec.yaml`, add entry to `CHANGELOG.md` (top, format `## [x.x.x] - YYYY-MM-DD`)
2. Commit, tag (`git tag v{x.x.x}`), push tag — CI publishes to pub.dev automatically
3. Failure modes: missing CHANGELOG entry, analyze errors in `example/` or `script/` (CI only checks `lib/`)
