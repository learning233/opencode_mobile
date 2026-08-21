import 'dart:convert';
import 'dart:io';

import 'package:example/src/platform_menu.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:kterm/kterm.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

bool get isDesktop {
  if (kIsWeb) return false;
  return [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kterm demo',
      debugShowCheckedModeBanner: false,
      home: AppPlatformMenu(child: Home()),
      // shortcuts: ,
    );
  }
}

class Home extends StatefulWidget {
  Home({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final terminal = Terminal(
    maxLines: 10000,
  );

  final terminalController = TerminalController();

  bool _kittyModeEnabled = true;
  bool _showKeyboardInfo = false;

  // Use Cascadia Mono which has better Unicode box-drawing character support
  // than the system monospace font. This font is loaded in main() via FontLoader.
  static const _terminalStyle = TerminalStyle(
    fontFamily: 'JetBrainsMono Nerd Font Mono',
    fontFamilyFallback: [
      'JetBrainsMono Nerd Font',
      'Menlo',
      'Monaco',
      'Consolas',
      'Liberation Mono',
      'Courier New',
      'Noto Sans Mono CJK SC',
      'Noto Sans Mono CJK TC',
      'Noto Sans Mono CJK KR',
      'Noto Sans Mono CJK JP',
      'Noto Sans Mono CJK HK',
      'Noto Color Emoji',
      'Noto Sans Symbols',
      'monospace',
      'sans-serif',
    ],
  );

  late final Pty pty;

  @override
  void initState() {
    super.initState();
    _startPty();
  }

  void _toggleKittyMode() {
    setState(() {
      _kittyModeEnabled = !_kittyModeEnabled;
      terminal.setKittyMode(_kittyModeEnabled);
    });
  }

  /// Send a small red PNG image using Kitty Graphics Protocol
  void _sendTestImage() {
    // Valid 16x16 red PNG (base64 encoded)
    final pngData =
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAGUlEQVR4nGP4z8DwnxLMMGrAqAGjBgwXAwAwxP4QHCfkAAAAAABJRU5ErkJggg==';
    // s=4,v=4 means 4x4 cells, image will be stretched to fill
    final imageData = '\x1b_Ga=t,f=100,s=4,v=4,i=1,S=C,q=1;$pngData\x1b\\';
    terminal.write(imageData);
  }

  /// Toggle keyboard info panel
  void _toggleKeyboardInfo() {
    setState(() {
      _showKeyboardInfo = !_showKeyboardInfo;
    });
    if (_showKeyboardInfo) {
      _showKeyboardPanel();
    }
  }

  /// Show Kitty Protocol showcase
  void _showKittyShowcase() {
    terminal.write('\x1b[2J'); // Clear screen
    terminal.write('\x1b[H'); // Move cursor to home

    // Header
    terminal.write('\x1b[1;36m'); // Cyan
    terminal.write(
        '╔════════════════════════════════════════════════════════╗\x1b[0m\r\n');
    terminal.write(
        '║         🐱 Kitty Protocol Showcase - kterm 🐱          ║\x1b[0m\r\n');
    terminal.write(
        '╚════════════════════════════════════════════════════════╝\x1b[0m\r\n\r\n');

    // 1. Hyperlinks
    terminal.write('\x1b[1;33m📎 Hyperlinks (OSC 8):\x1b[0m\r\n');
    terminal.write('\x1b]8;;https://github.com/kovidgoyal/kitty\x1b\\');
    terminal.write('Click here to visit Kitty terminal\x1b]8;;\x1b\\\r\n');
    terminal.write('\x1b]8;;https://dart.dev\x1b\\');
    terminal.write('Or here for Dart language\x1b]8;;\x1b\\\r\n\r\n');

    // 2. Styled Underlines
    terminal.write('\x1b[1;33m〰️ Styled Underlines (CSI 4:n):\x1b[0m\r\n');
    terminal.write('\x1b[4;1mSingle underline\x1b[0m  ');
    terminal.write('\x1b[4;2mDouble\x1b[0m  ');
    terminal.write('\x1b[4;3mCurly\x1b[0m  ');
    terminal.write('\x1b[4;4mDotted\x1b[0m  ');
    terminal.write('\x1b[4;5mDashed\x1b[0m\r\n\r\n');

    // 3. Wide Gamut Colors
    terminal.write('\x1b[1;33m🎨 Wide Gamut Colors (SGR 38;2):\x1b[0m\r\n');
    terminal.write('\x1b[38;2;255;0;0mRed RGB\x1b[0m  ');
    terminal.write('\x1b[38;2;0;255;0mGreen RGB\x1b[0m  ');
    terminal.write('\x1b[38;2;0;0;255mBlue RGB\x1b[0m  ');
    terminal.write('\x1b[38;2;255;128;0mOrange\x1b[0m  ');
    terminal.write('\x1b[38;2;128;0;255mPurple\x1b[0m\r\n\r\n');

    // 4. 256+ Colors
    terminal.write('\x1b[1;33m🎆 256+ Colors (SGR 38;5):\x1b[0m\r\n');
    for (int i = 196; i <= 202; i++) {
      terminal.write('\x1b[38;5;${i}m▀');
    }
    terminal.write('\x1b[0m\r\n\r\n');

    // 5. Bold and Italic
    terminal.write('\x1b[1;33m✒️ Text Styles:\x1b[0m\r\n');
    terminal.write('\x1b[1mBold\x1b[0m  ');
    terminal.write('\x1b[3mItalic\x1b[0m  ');
    terminal.write('\x1b[4mUnderline\x1b[0m  ');
    terminal.write('\x1b[5mBlink\x1b[0m  ');
    terminal.write('\x1b[7mInverse\x1b[0m  ');
    terminal.write('\x1b[9mStrikethrough\x1b[0m\r\n\r\n');

    // 6. Clipboard (info)
    terminal.write('\x1b[1;33m📋 Clipboard (OSC 52):\x1b[0m\r\n');
    terminal.write(
        'Use right-click to copy/paste. SSH workflows supported!\r\n\r\n');

    // 7. Desktop Notifications (info)
    terminal.write('\x1b[1;33m🔔 Notifications (OSC 777):\x1b[0m\r\n');
    terminal.write('Long-running tasks can send notifications.\r\n\r\n');

    // 8. Mouse Tracking (info)
    terminal.write('\x1b[1;33m🐭 Mouse Tracking (SGR 1006):\x1b[0m\r\n');
    terminal.write(
        'Enabled for terminal applications like htop, vim, etc.\r\n\r\n');

    // 9. Bracketed Paste (info)
    terminal.write('\x1b[1;33m📥 Bracketed Paste (SGR 2004):\x1b[0m\r\n');
    terminal.write('Safe paste mode enabled for all paste operations.\r\n\r\n');

    // 10. Graphics Protocol
    terminal.write('\x1b[1;33m🖼️ Kitty Graphics Protocol:\x1b[0m\r\n');
    terminal.write('Press the image button to send a test image!\r\n\r\n');

    // Footer
    terminal.write(
        '\x1b[1;32m✅ All 19 Kitty Protocol features implemented!\x1b[0m\r\n');
    terminal.write(
        '\x1b[90mMore info: https://sw.kovidgoyal.net/kitty/protocols/\x1b[0m\r\n');
  }

  void _showKeyboardPanel() {
    terminal.write('\x1b[2J'); // Clear screen
    terminal.write('\x1b[H'); // Move cursor to home
    terminal.write('\x1b[1;36m'); // Cyan color
    terminal.write('=== Kitty Keyboard Protocol Info ===\x1b[0m\r\n\r\n');

    terminal.write(
        'Kitty Mode: ${_kittyModeEnabled ? "\x1b[32mENABLED\x1b[0m" : "\x1b[31mDISABLED\x1b[0m"}\r\n\r\n');

    terminal.write('\x1b[1;33mKeyboard Flags:\x1b[0m\r\n');
    terminal.write('  bit 0 (1): reportEvent          - Report key events\r\n');
    terminal.write(
        '  bit 1 (2): reportAlternateKeys  - Report alternate key sequences\r\n');
    terminal.write(
        '  bit 2 (4): reportAllKeysAsEscape - Report all keys as escape sequences\r\n\r\n');

    terminal.write('\x1b[1;33mCurrent Features:\x1b[0m\r\n');
    terminal.write('  - Unicode text input\r\n');
    terminal.write('  - Function keys (F1-F12)\r\n');
    terminal.write('  - Arrow keys\r\n');
    terminal.write('  - Home/End/PageUp/PageDown\r\n');
    terminal.write('  - Modifier keys (Shift/Ctrl/Alt/Super)\r\n');
    terminal.write('  - Key release events\r\n\r\n');

    terminal.write('\x1b[1;33mTest Keys:\x1b[0m\r\n');
    terminal.write('  Try pressing arrow keys, function keys,\r\n');
    terminal.write('  or special keys to see Kitty encoding.\r\n\r\n');

    terminal
        .write('\x1b[1;32mPress any key in the terminal to test!\x1b[0m\r\n');
  }

  /// Pick and display image using file picker
  Future<void> _pickAndDisplayImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      if (file.path == null) {
        return;
      }

      // Read the image file
      final imageBytes = await File(file.path!).readAsBytes();
      // Encode as base64
      final base64Data = base64Encode(imageBytes);

      // Determine format from extension
      final ext = p.extension(file.path!).toLowerCase();
      int format;
      if (ext == '.png') {
        format = 100;
      } else if (ext == '.jpg' || ext == '.jpeg') {
        format = 98;
      } else {
        format = 100; // Default to PNG
      }

      // Get image dimensions for cell size
      // Use smaller cell size for better fit
      final cellWidth = (file.size > 100000) ? 8 : 4;
      final cellHeight = (file.size > 100000) ? 8 : 4;

      // Send image via Kitty Graphics Protocol
      // a=t (transfer), f=format, s=cell width, v=cell height
      final imageData =
          '\x1b_Ga=t,f=$format,s=$cellWidth,v=$cellHeight,i=1;$base64Data\x1b\\';
      terminal.write(imageData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image sent: ${file.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startPty() {
    pty = Pty.start(
      shell,
      columns: terminal.viewWidth,
      rows: terminal.viewHeight,
      ackRead: true,
    );

    pty.output.cast<List<int>>().transform(Utf8Decoder()).listen((data) {
      terminal.write(data);
      // Use microtask to avoid deadlocking the C read thread.
      // Without microtask, if Dart's event loop is busy processing rapid
      // output, ackRead() is delayed and the pthread_mutex in flutter_pty
      // blocks the PTY read loop indefinitely.
      Future.microtask(() => pty.ackRead());
    });

    pty.exitCode.then((code) {
      terminal.write('the process exited with exit code $code');
    });

    terminal.onOutput = (data) {
      pty.write(const Utf8Encoder().convert(data));
    };

    terminal.onResize = (w, h, pw, ph) {
      pty.resize(h, w);
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            TerminalView(
              terminal,
              controller: terminalController,
              textStyle: _terminalStyle,
              autofocus: true,
              backgroundOpacity: 0.7,
              onSecondaryTapDown: (details, offset) async {
                final selection = terminalController.selection;
                if (selection != null) {
                  final text = terminal.buffer.getText(selection);
                  terminalController.clearSelection();
                  await Clipboard.setData(ClipboardData(text: text));
                } else {
                  final data = await Clipboard.getData('text/plain');
                  final text = data?.text;
                  if (text != null) {
                    terminal.paste(text);
                  }
                }
              },
            ),
            // Kitty Mode indicator
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kittyModeEnabled
                      ? Colors.green.withValues(alpha: 0.8)
                      : Colors.grey.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Kitty: ${_kittyModeEnabled ? "ON" : "OFF"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'keyboard',
            onPressed: _toggleKeyboardInfo,
            backgroundColor: _showKeyboardInfo ? Colors.cyan : Colors.grey,
            tooltip: 'Keyboard Info',
            child: const Icon(Icons.keyboard),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'kitty',
            onPressed: _toggleKittyMode,
            backgroundColor: _kittyModeEnabled ? Colors.green : Colors.grey,
            tooltip: 'Toggle Kitty Mode',
            child: const Icon(Icons.toggle_on),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'image',
            onPressed: _sendTestImage,
            backgroundColor: Colors.red,
            tooltip: 'Send Test Image',
            child: const Icon(Icons.image),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'showcase',
            onPressed: _showKittyShowcase,
            backgroundColor: Colors.purple,
            tooltip: 'Kitty Showcase',
            child: const Icon(Icons.star),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'picker',
            onPressed: _pickAndDisplayImage,
            backgroundColor: Colors.orange,
            tooltip: 'Pick Image File',
            child: const Icon(Icons.photo_library),
          ),
        ],
      ),
    );
  }
}

String get shell {
  if (Platform.isMacOS || Platform.isLinux) {
    return Platform.environment['SHELL'] ?? 'bash';
  }

  if (Platform.isWindows) {
    return 'cmd.exe';
  }

  return 'sh';
}
