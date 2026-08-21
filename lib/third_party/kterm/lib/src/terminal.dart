import 'dart:async';
import 'dart:convert' show base64, utf8;
import 'dart:math' show max;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:kitty_protocol/kitty_protocol.dart';
import 'package:kterm/src/base/observable.dart';
import 'package:kterm/src/core/buffer/buffer.dart';
import 'package:kterm/src/core/buffer/cell_offset.dart';
import 'package:kterm/src/core/cell.dart';
import 'package:kterm/src/core/buffer/line.dart';
import 'package:kterm/src/core/cursor.dart';
import 'package:kterm/src/core/escape/emitter.dart';
import 'package:kterm/src/core/graphics_manager.dart';
import 'package:kterm/src/core/escape/handler.dart';
import 'package:kterm/src/core/escape/parser.dart';
import 'package:kterm/src/core/input/handler.dart';
import 'package:kterm/src/core/input/keys.dart';
import 'package:kterm/src/core/mouse/button.dart';
import 'package:kterm/src/core/mouse/button_state.dart';
import 'package:kterm/src/core/mouse/handler.dart';
import 'package:kterm/src/core/mouse/mode.dart';
import 'package:kterm/src/core/platform.dart';
import 'package:kterm/src/core/state.dart';
import 'package:kterm/src/core/tabs.dart';
import 'package:kterm/src/utils/ascii.dart';
import 'package:kterm/src/utils/circular_buffer.dart';

/// [Terminal] is an interface to interact with command line applications. It
/// translates escape sequences from the application into updates to the
/// [buffer] and events such as [onTitleChange] or [onBell], as well as
/// translating user input into escape sequences that the application can
/// understand.
class Terminal with Observable implements TerminalState, EscapeHandler {
  /// The number of lines that the scrollback buffer can hold. If the buffer
  /// exceeds this size, the lines at the top of the buffer will be removed.
  final int maxLines;

  /// Function that is called when the program requests the terminal to ring
  /// the bell. If not set, the terminal will do nothing.
  void Function()? onBell;

  /// Function that is called when the program requests the terminal to change
  /// the title of the window to [title].
  void Function(String title)? onTitleChange;

  /// Function that is called when the program requests the terminal to change
  /// the icon of the window. [icon] is the name of the icon.
  void Function(String icon)? onIconChange;

  /// Function that is called when the terminal emits data to the underlying
  /// program. This is typically caused by user inputs from [textInput],
  /// [keyInput], [mouseInput], or [paste].
  void Function(String data)? onOutput;

  /// Function that is called when the dimensions of the terminal change.
  void Function(int width, int height, int pixelWidth, int pixelHeight)?
      onResize;

  /// The [TerminalInputHandler] used by this terminal. [defaultInputHandler] is
  /// used when not specified. User of this class can provide their own
  /// implementation of [TerminalInputHandler] or extend [defaultInputHandler]
  /// with [CascadeInputHandler].
  TerminalInputHandler? inputHandler;

  TerminalMouseHandler? mouseHandler;

  /// The callback that is called when the terminal receives a unrecognized
  /// escape sequence.
  void Function(String code, List<String> args)? onPrivateOSC;

  /// Callback when terminal requests clipboard read via OSC 52.
  ///
  /// The terminal sends this when it receives `ESC ] 52 ; target ; ? ST`.
  /// The [target] parameter specifies which clipboard:
  /// - "c" for the default clipboard
  /// - "p" for primary selection
  /// - "s" for secondary selection
  ///
  /// Your implementation should read the clipboard content and call
  /// [Terminal.write] with the base64-encoded data wrapped in:
  /// `ESC ] 52 ; target ; base64data ST`
  void Function(String target)? onClipboardRead;

  /// Callback when terminal writes to clipboard via OSC 52.
  ///
  /// The terminal sends this when it receives `ESC ] 52 ; target ; base64data ST`.
  /// The [data] is the decoded clipboard content, and [target] specifies which
  /// clipboard (see [onClipboardRead]).
  void Function(String data, String target)? onClipboardWrite;

  /// Flag to toggle os specific behaviors.
  final TerminalTargetPlatform platform;

  /// Characters that break selection when double clicking. If not set, the
  /// [Buffer.defaultWordSeparators] will be used.
  final Set<int>? wordSeparators;

  Terminal({
    this.maxLines = 1000,
    this.onBell,
    this.onTitleChange,
    this.onIconChange,
    this.onOutput,
    this.onResize,
    this.platform = TerminalTargetPlatform.unknown,
    this.inputHandler = defaultInputHandler,
    this.mouseHandler = defaultMouseHandler,
    this.onPrivateOSC,
    this.reflowEnabled = true,
    this.wordSeparators,
  }) : graphicsManager = GraphicsManager();

  late final _parser = EscapeParser(this);

  final _emitter = const EscapeEmitter();

  late var _buffer = _mainBuffer;

  late final _mainBuffer = Buffer(
    this,
    maxLines: maxLines,
    isAltBuffer: false,
    wordSeparators: wordSeparators,
  );

  late final _altBuffer = Buffer(
    this,
    maxLines: maxLines,
    isAltBuffer: true,
    wordSeparators: wordSeparators,
  );

  final _tabStops = TabStops();

  /// The last character written to the buffer. Used to implement some escape
  /// sequences that repeat the last character.
  var _precedingCodepoint = 0;

  /* TerminalState */

  int _viewWidth = 80;

  int _viewHeight = 24;

  final _cursorStyle = CursorStyle();

  bool _insertMode = false;

  bool _lineFeedMode = false;

  bool _cursorKeysMode = false;

  bool _reverseDisplayMode = false;

  bool _originMode = false;

  bool _autoWrapMode = true;

  MouseMode _mouseMode = MouseMode.none;

  MouseReportMode _mouseReportMode = MouseReportMode.normal;

  bool _cursorBlinkMode = false;

  bool _cursorVisibleMode = true;

  bool _appKeypadMode = false;

  bool _reportFocusMode = false;

  bool _altBufferMouseScrollMode = false;

  bool _bracketedPasteMode = false;

  // Kitty Keyboard Protocol state
  KittyKeyboardEncoder? _kittyEncoder;

  bool _kittyMode = false;

  final List<int> _kittyFlagsStack = [];

  // Kitty Graphics Protocol state
  late final GraphicsManager graphicsManager;

  Map<String, String> _currentGraphicsArgs = {};
  final List<List<int>> _graphicsChunks = [];
  bool _graphicsTransmissionActive = false;

  /// Maximum number of chunks to prevent memory exhaustion attacks
  static const int _maxGraphicsChunks = 1000;

  /// Maximum total chunk size (50MB) to prevent memory exhaustion
  static const int _maxTotalChunkSize = 50 * 1024 * 1024;

  /// Wrapper around KittyKeyboardEncoder that fixes keycode mappings.
  ///
  /// The kitty_protocol package incorrectly uses USB HID keycodes instead of
  /// the correct Kitty protocol keycodes:
  /// - Enter: 8 (USB HID) → should be 13 (Kitty)
  /// - Backspace: 127 (Kitty) is correct
  _KittyKeyboardEncoderWrapper? _kittyEncoderWrapper;

  KittyKeyboardEncoder get kittyEncoder {
    _kittyEncoder ??= KittyKeyboardEncoder();
    _kittyEncoderWrapper ??= _KittyKeyboardEncoderWrapper(_kittyEncoder!);
    return _kittyEncoderWrapper!;
  }

  bool get kittyMode => _kittyMode;

  /* State getters */

  /// Number of cells in a terminal row.
  @override
  int get viewWidth => _viewWidth;

  /// Number of rows in this terminal.
  @override
  int get viewHeight => _viewHeight;

  @override
  CursorStyle get cursor => _cursorStyle;

  @override
  bool get insertMode => _insertMode;

  @override
  bool get lineFeedMode => _lineFeedMode;

  @override
  bool get cursorKeysMode => _cursorKeysMode;

  @override
  bool get reverseDisplayMode => _reverseDisplayMode;

  @override
  bool get originMode => _originMode;

  @override
  bool get autoWrapMode => _autoWrapMode;

  @override
  MouseMode get mouseMode => _mouseMode;

  @override
  MouseReportMode get mouseReportMode => _mouseReportMode;

  @override
  bool get cursorBlinkMode => _cursorBlinkMode;

  @override
  bool get cursorVisibleMode => _cursorVisibleMode;

  @override
  bool get appKeypadMode => _appKeypadMode;

  @override
  bool get reportFocusMode => _reportFocusMode;

  @override
  bool get altBufferMouseScrollMode => _altBufferMouseScrollMode;

  @override
  bool get bracketedPasteMode => _bracketedPasteMode;

  /// Current active buffer of the terminal. This is initially [mainBuffer] and
  /// can be switched back and forth from [altBuffer] to [mainBuffer] when
  /// the underlying program requests it.
  Buffer get buffer => _buffer;

  Buffer get mainBuffer => _mainBuffer;

  Buffer get altBuffer => _altBuffer;

  bool get isUsingAltBuffer => _buffer == _altBuffer;

  /// Lines of the active buffer.
  IndexAwareCircularBuffer<BufferLine> get lines => _buffer.lines;

  /// Whether the terminal performs reflow when the viewport size changes or
  /// simply truncates lines. true by default.
  @override
  bool reflowEnabled;

  /// Writes the data from the underlying program to the terminal. Calling this
  /// updates the states of the terminal and emits events such as [onBell] or
  /// [onTitleChange] when the escape sequences in [data] request it.
  void write(String data) {
    _parser.write(data);
    notifyListeners();
  }

  /// Sends a key event to the underlying program.
  ///
  /// See also:
  /// - [charInput]
  /// - [textInput]
  /// - [paste]
  bool keyInput(
    TerminalKey key, {
    bool shift = false,
    bool alt = false,
    bool ctrl = false,
  }) {
    final output = inputHandler?.call(
      TerminalKeyboardEvent(
        key: key,
        shift: shift,
        alt: alt,
        ctrl: ctrl,
        state: this,
        altBuffer: isUsingAltBuffer,
        platform: platform,
      ),
    );

    if (output != null) {
      onOutput?.call(output);
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Similary to [keyInput], but takes a character as input instead of a
  /// [TerminalKey].
  ///
  /// See also:
  /// - [keyInput]
  /// - [textInput]
  /// - [paste]
  bool charInput(
    int charCode, {
    bool alt = false,
    bool ctrl = false,
  }) {
    if (ctrl) {
      // a(97) ~ z(122)
      if (charCode >= Ascii.a && charCode <= Ascii.z) {
        final output = charCode - Ascii.a + 1;
        onOutput?.call(String.fromCharCode(output));
        notifyListeners();
        return true;
      }

      // [(91) ~ _(95)
      if (charCode >= Ascii.openBracket && charCode <= Ascii.underscore) {
        final output = charCode - Ascii.openBracket + 27;
        onOutput?.call(String.fromCharCode(output));
        notifyListeners();
        return true;
      }
    }

    if (alt && platform != TerminalTargetPlatform.macos) {
      if (charCode >= Ascii.a && charCode <= Ascii.z) {
        final code = charCode - Ascii.a + 65;
        final input = [0x1b, code];
        onOutput?.call(String.fromCharCodes(input));
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  /// Sends regular text input to the underlying program.
  ///
  /// See also:
  /// - [keyInput]
  /// - [charInput]
  /// - [paste]
  void textInput(String text) {
    onOutput?.call(text);
    notifyListeners();
  }

  /// Similar to [textInput], except that when the program tells the terminal
  /// that it supports [bracketedPasteMode], the text is wrapped in escape
  /// sequences to indicate that it is a paste operation. Prefer this method
  /// over [textInput] when pasting text.
  ///
  /// See also:
  /// - [textInput]
  void paste(String text) {
    // Filter ANSI escape sequences to prevent formatting (like inverse colors)
    // from being pasted into the terminal.
    text = text.replaceAll(RegExp(r'\x1b\[[0-9;]*[a-zA-Z]'), '');

    // Filter control characters (0x00-0x1F) except TAB (\x09), LF (\x0a), CR (\x0d), ESC (\x1b)
    // These include: BEL (\x07), FF (\x0c - clears screen), SO (\x0e), SI (\x0f), etc.
    // Note: We keep ESC (\x1b) to preserve OSC and other escape sequences
    text =
        text.replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1a\x1c-\x1f]'), '');

    // Normalize all line endings to match what the Enter key sends
    // This ensures consistent behavior regardless of the source of the pasted text
    // 1. Convert all CRLF to LF
    text = text.replaceAll('\r\n', '\n');
    // 2. Convert all remaining CR to LF
    text = text.replaceAll('\r', '\n');
    // 3. Convert LF to the appropriate newline sequence based on current mode
    // Match what the Enter key sends: "\r" when lineFeedMode is false, "\r\n" when true
    final newline = _lineFeedMode ? '\r\n' : '\r';
    text = text.replaceAll('\n', newline);

    if (_bracketedPasteMode) {
      onOutput?.call(_emitter.bracketedPaste(text));
      notifyListeners();
    } else {
      textInput(text);
    }
  }

  // Handle a mouse event and return true if it was handled.
  bool mouseInput(
    TerminalMouseButton button,
    TerminalMouseButtonState buttonState,
    CellOffset position,
  ) {
    final output = mouseHandler?.call(TerminalMouseEvent(
      button: button,
      buttonState: buttonState,
      position: position,
      state: this,
      platform: platform,
    ));
    if (output != null) {
      onOutput?.call(output);
      return true;
    }
    return false;
  }

  /// Resize the terminal screen. [newWidth] and [newHeight] should be greater
  /// than 0. Text reflow is currently not implemented and will be avaliable in
  /// the future.
  @override
  void resize(
    int newWidth,
    int newHeight, [
    int? pixelWidth,
    int? pixelHeight,
  ]) {
    newWidth = max(newWidth, 1);
    newHeight = max(newHeight, 1);

    onResize?.call(newWidth, newHeight, pixelWidth ?? 0, pixelHeight ?? 0);

    //we need to resize both buffers so that they are ready when we switch between them
    _altBuffer.resize(_viewWidth, _viewHeight, newWidth, newHeight);
    _mainBuffer.resize(_viewWidth, _viewHeight, newWidth, newHeight);

    _viewWidth = newWidth;
    _viewHeight = newHeight;

    if (buffer == _altBuffer) {
      buffer.clearScrollback();
    }

    _altBuffer.resetVerticalMargins();
    _mainBuffer.resetVerticalMargins();
  }

  @override
  String toString() {
    return 'Terminal(#$hashCode, $_viewWidth x $_viewHeight, ${_buffer.height} lines)';
  }

  /* Handlers */

  @override
  void writeChar(int char) {
    _precedingCodepoint = char;
    _buffer.writeChar(char);
  }

  /* SBC */

  @override
  void bell() {
    onBell?.call();
  }

  @override
  void backspaceReturn() {
    _buffer.moveCursorX(-1);
  }

  @override
  void tab() {
    final nextStop = _tabStops.find(_buffer.cursorX + 1, _viewWidth);

    if (nextStop != null) {
      _buffer.setCursorX(nextStop);
    } else {
      _buffer.setCursorX(_viewWidth);
      _buffer.cursorGoForward(); // Enter pending-wrap state
    }
  }

  @override
  void lineFeed() {
    _buffer.lineFeed();
  }

  @override
  void carriageReturn() {
    _buffer.setCursorX(0);
  }

  @override
  void shiftOut() {
    _buffer.charset.use(1);
  }

  @override
  void shiftIn() {
    _buffer.charset.use(0);
  }

  @override
  void unknownSBC(int char) {
    // no-op
  }

  /* ANSI sequence */

  @override
  void saveCursor() {
    _buffer.saveCursor();
  }

  @override
  void restoreCursor() {
    _buffer.restoreCursor();
  }

  @override
  void index() {
    _buffer.index();
  }

  @override
  void nextLine() {
    _buffer.index();
    _buffer.setCursorX(0);
  }

  @override
  void setTapStop() {
    _tabStops.isSetAt(_buffer.cursorX);
  }

  @override
  void reverseIndex() {
    _buffer.reverseIndex();
  }

  @override
  void designateCharset(int charset, int name) {
    _buffer.charset.designate(charset, name);
  }

  @override
  void unknownEscape(int char) {
    // no-op
  }

  /* CSI */

  @override
  void repeatPreviousCharacter(int count) {
    if (_precedingCodepoint == 0) {
      return;
    }

    for (var i = 0; i < count; i++) {
      _buffer.writeChar(_precedingCodepoint);
    }
  }

  @override
  void setCursor(int x, int y) {
    _buffer.setCursor(x, y);
  }

  @override
  void setCursorX(int x) {
    _buffer.setCursorX(x);
  }

  @override
  void setCursorY(int y) {
    _buffer.setCursorY(y);
  }

  @override
  void moveCursorX(int offset) {
    _buffer.moveCursorX(offset);
  }

  @override
  void moveCursorY(int n) {
    _buffer.moveCursorY(n);
  }

  @override
  void clearTabStopUnderCursor() {
    _tabStops.clearAt(_buffer.cursorX);
  }

  @override
  void clearAllTabStops() {
    _tabStops.clearAll();
  }

  @override
  void sendPrimaryDeviceAttributes() {
    onOutput?.call(_emitter.primaryDeviceAttributes());
  }

  @override
  void sendSecondaryDeviceAttributes() {
    onOutput?.call(_emitter.secondaryDeviceAttributes());
  }

  @override
  void sendTertiaryDeviceAttributes() {
    onOutput?.call(_emitter.tertiaryDeviceAttributes());
  }

  @override
  void sendOperatingStatus() {
    onOutput?.call(_emitter.operatingStatus());
  }

  @override
  void sendCursorPosition() {
    onOutput?.call(_emitter.cursorPosition(_buffer.cursorX, _buffer.cursorY));
  }

  @override
  void setMargins(int top, [int? bottom]) {
    _buffer.setVerticalMargins(top, bottom ?? viewHeight - 1);
  }

  @override
  void cursorNextLine(int amount) {
    _buffer.moveCursorY(amount);
    _buffer.setCursorX(0);
  }

  @override
  void cursorPrecedingLine(int amount) {
    _buffer.moveCursorY(-amount);
    _buffer.setCursorX(0);
  }

  @override
  void eraseDisplayBelow() {
    _buffer.eraseDisplayFromCursor();
  }

  @override
  void eraseDisplayAbove() {
    _buffer.eraseDisplayToCursor();
  }

  @override
  void eraseDisplay() {
    _buffer.eraseDisplay();
  }

  @override
  void eraseScrollbackOnly() {
    _buffer.clearScrollback();
  }

  @override
  void eraseLineRight() {
    _buffer.eraseLineFromCursor();
  }

  @override
  void eraseLineLeft() {
    _buffer.eraseLineToCursor();
  }

  @override
  void eraseLine() {
    _buffer.eraseLine();
  }

  @override
  void insertLines(int amount) {
    _buffer.insertLines(amount);
  }

  @override
  void deleteLines(int amount) {
    _buffer.deleteLines(amount);
  }

  @override
  void deleteChars(int amount) {
    _buffer.deleteChars(amount);
  }

  @override
  void scrollUp(int amount) {
    _buffer.scrollUp(amount);
  }

  @override
  void scrollDown(int amount) {
    _buffer.scrollDown(amount);
  }

  @override
  void eraseChars(int amount) {
    _buffer.eraseChars(amount);
  }

  @override
  void insertBlankChars(int amount) {
    _buffer.insertBlankChars(amount);
  }

  @override
  void sendSize() {
    onOutput?.call(_emitter.size(viewHeight, viewWidth));
  }

  @override
  void unknownCSI(int finalByte) {
    // no-op
  }

  /* Modes */

  @override
  void setInsertMode(bool enabled) {
    _insertMode = enabled;
  }

  @override
  void setLineFeedMode(bool enabled) {
    _lineFeedMode = enabled;
  }

  @override
  void setUnknownMode(int mode, bool enabled) {
    // no-op
  }

  /* DEC Private modes */

  @override
  void setCursorKeysMode(bool enabled) {
    _cursorKeysMode = enabled;
  }

  @override
  void setReverseDisplayMode(bool enabled) {
    _reverseDisplayMode = enabled;
  }

  @override
  void setOriginMode(bool enabled) {
    _originMode = enabled;
  }

  @override
  void setColumnMode(bool enabled) {
    // no-op
  }

  @override
  void setAutoWrapMode(bool enabled) {
    _autoWrapMode = enabled;
  }

  @override
  void setMouseMode(MouseMode mode) {
    _mouseMode = mode;
  }

  @override
  void setCursorBlinkMode(bool enabled) {
    _cursorBlinkMode = enabled;
  }

  @override
  void setCursorVisibleMode(bool enabled) {
    _cursorVisibleMode = enabled;
  }

  @override
  void useAltBuffer() {
    _buffer = _altBuffer;
  }

  @override
  void useMainBuffer() {
    _buffer = _mainBuffer;
  }

  @override
  void clearAltBuffer() {
    _altBuffer.clear();
  }

  @override
  void setAppKeypadMode(bool enabled) {
    _appKeypadMode = enabled;
  }

  @override
  void setReportFocusMode(bool enabled) {
    _reportFocusMode = enabled;
  }

  @override
  void setMouseReportMode(MouseReportMode mode) {
    _mouseReportMode = mode;
  }

  @override
  void setAltBufferMouseScrollMode(bool enabled) {
    _altBufferMouseScrollMode = enabled;
  }

  @override
  void setBracketedPasteMode(bool enabled) {
    _bracketedPasteMode = enabled;
  }

  /// Handle CSI > n u - Set Kitty keyboard mode
  @override
  void setKittyMode(bool enabled) {
    _kittyMode = enabled;
  }

  /// Handle CSI > + n u - Push (enable) Kitty flags
  @override
  void pushKittyFlags(int flags) {
    _kittyFlagsStack.add(flags);
    _updateKittyKeyboardEncoder();
  }

  /// Handle CSI > - n u - Pop (disable) Kitty flags
  @override
  void popKittyFlags() {
    if (_kittyFlagsStack.isNotEmpty) {
      _kittyFlagsStack.removeLast();
      _updateKittyKeyboardEncoder();
    }
  }

  void _updateKittyKeyboardEncoder() {
    if (_kittyEncoder == null) return;
    // Apply flags from stack - use the last flags pushed
    final flags = _kittyFlagsStack.isNotEmpty ? _kittyFlagsStack.last : 0;
    // Update encoder flags based on Kitty protocol flags
    // bit 0 (1): reportEvent
    // bit 1 (2): reportAlternateKeys
    // bit 2 (4): reportAllKeysAsEscape
    final updatedInner = _kittyEncoder!.withFlags(KittyKeyboardEncoderFlags(
      reportEvent: (flags & 1) != 0,
      reportAlternateKeys: (flags & 2) != 0,
      reportAllKeysAsEscape: (flags & 4) != 0,
    ));
    // Recreate wrapper with updated inner encoder
    _kittyEncoderWrapper = _KittyKeyboardEncoderWrapper(updatedInner);
  }

  /* Kitty Graphics Protocol */

  @override
  void graphicsCommandStart(Map<String, String> args) {
    _currentGraphicsArgs = args;
    _graphicsChunks.clear();
    _graphicsTransmissionActive = true;
  }

  @override
  void graphicsDataChunk(List<int> data) {
    if (!_graphicsTransmissionActive) return;

    // Prevent memory exhaustion: limit chunk count
    if (_graphicsChunks.length >= _maxGraphicsChunks) {
      _graphicsTransmissionActive = false;
      _graphicsChunks.clear();
      _currentGraphicsArgs.clear();
      return;
    }

    // Prevent memory exhaustion: limit total size
    final totalSize =
        _graphicsChunks.fold<int>(0, (sum, c) => sum + c.length) + data.length;
    if (totalSize > _maxTotalChunkSize) {
      _graphicsTransmissionActive = false;
      _graphicsChunks.clear();
      _currentGraphicsArgs.clear();
      return;
    }

    _graphicsChunks.add(data);
  }

  @override
  Future<void> graphicsCommandEnd() async {
    if (!_graphicsTransmissionActive) return;

    _graphicsTransmissionActive = false;

    // Check the action type
    final action = _currentGraphicsArgs['a'] ?? 't';

    // Handle query action (a=q)
    if (action == 'q') {
      await _handleGraphicsQuery();
      _currentGraphicsArgs.clear();
      return;
    }

    // Handle delete action (a=d)
    if (action == 'd') {
      await _handleGraphicsDelete();
      _currentGraphicsArgs.clear();
      return;
    }

    // Handle transfer action (a=t) - original image handling code
    // Concatenate all chunks
    final totalLength =
        _graphicsChunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final combinedData = List<int>.filled(totalLength, 0);
    var offset = 0;
    for (final chunk in _graphicsChunks) {
      combinedData.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _graphicsChunks.clear();

    // Process based on format
    final format = int.tryParse(_currentGraphicsArgs['f'] ?? '') ?? 0;

    ui.Image? image;

    switch (format) {
      case 32: // RGBA raw
        image = await _createRgbaImage(combinedData);
        break;
      case 100: // PNG
      case 98: // JPEG
        image = await _createPngImage(combinedData);
        break;
      case 50: // GIF
        // GIF handling - store as animated image
        final imageId =
            await graphicsManager.storeGif(Uint8List.fromList(combinedData));
        // Continue with placement using first frame
        await _createPlacementForImage(imageId);
        _currentGraphicsArgs.clear();
        return;
      default:
        // Unsupported format
        _currentGraphicsArgs.clear();
        return;
    }

    if (image == null) {
      _currentGraphicsArgs.clear();
      return;
    }

    // Store image and get ID
    final imageId = graphicsManager.storeImage(image);

    // Create placement for the image
    await _createPlacementForImage(imageId);
  }

  /// Create a placement for an existing image ID
  Future<void> _createPlacementForImage(int imageId) async {
    // Get placement coordinates
    // Kitty protocol: x,y = position in cells, s,v = cell dimensions, w,h = pixel dimensions
    final x = int.tryParse(_currentGraphicsArgs['x'] ?? '') ?? 0;
    final y = int.tryParse(_currentGraphicsArgs['y'] ?? '') ?? 0;
    // Use s (columns) and v (rows) for cell dimensions, fallback to w/h for pixels
    final width = int.tryParse(
            _currentGraphicsArgs['s'] ?? _currentGraphicsArgs['w'] ?? '') ??
        1;
    final height = int.tryParse(
            _currentGraphicsArgs['v'] ?? _currentGraphicsArgs['h'] ?? '') ??
        1;

    // Create placement and get placement ID
    final overlay = _currentGraphicsArgs['S'] ==
        'C'; // C = cursor (above), S = screen (default = below)
    final placementId = graphicsManager.createPlacement(
      imageId: imageId,
      x: x,
      y: y,
      width: width,
      height: height,
      overlay: overlay,
    );

    // Mark cells with image reference (using packed image data)
    _placeImage(imageId, placementId, x, y, width, height);

    _currentGraphicsArgs.clear();
  }

  /// Create image from RGBA pixel data
  Future<ui.Image?> _createRgbaImage(List<int> data) async {
    // Try to get pixel dimensions from w/h, otherwise use s/v (cell dims) or infer
    var width = int.tryParse(_currentGraphicsArgs['w'] ?? '');
    var height = int.tryParse(_currentGraphicsArgs['h'] ?? '');

    // If w/h not provided, use s/v as the pixel dimensions (each cell = 1 pixel for f=32)
    if (width == null || height == null) {
      width = int.tryParse(_currentGraphicsArgs['s'] ?? '');
      height = int.tryParse(_currentGraphicsArgs['v'] ?? '');
    }

    // Last resort: infer from data length (assume square-ish)
    if (width == null || height == null) {
      final pixels = data.length ~/ 4;
      width = pixels > 0 ? pixels : 1;
      height = 1;
    }

    // Don't fail - just use what we have
    if (data.isEmpty) {
      return null;
    }

    // Use decodeImageFromPixels with callback
    final completer = Completer<ui.Image?>();
    try {
      ui.decodeImageFromPixels(
        Uint8List.fromList(data),
        width,
        height,
        ui.PixelFormat.rgba8888,
        // Use dynamic to safely handle cases where decoder passes null on failure
        (dynamic image) {
          if (!completer.isCompleted) {
            if (image is ui.Image) {
              completer.complete(image);
            } else {
              completer.complete(null);
            }
          }
        },
        rowBytes: width * 4,
      );
    } catch (e) {
      // Synchronous decode failure (e.g., invalid buffer size)
      return null;
    }

    ui.Image? image;
    try {
      image = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
    } catch (e) {
      return null;
    }
    if (image == null) return null;
    // Validate that the image has valid dimensions (catch corrupted images)
    try {
      if (image.width <= 0 || image.height <= 0) return null;
    } catch (e) {
      // Accessing properties threw - invalid image
      return null;
    }
    return image;
  }

  /// Create image from PNG/JPEG data
  Future<ui.Image?> _createPngImage(List<int> data) async {
    try {
      final bytes = Uint8List.fromList(data);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      return null;
    }
  }

  /// Handle graphics query action (a=q)
  /// Returns image information via escape sequence response
  Future<void> _handleGraphicsQuery() async {
    // Check for specific image ID query
    final imageIdStr = _currentGraphicsArgs['i'];
    // Check for position query
    final xStr = _currentGraphicsArgs['x'];
    final yStr = _currentGraphicsArgs['y'];

    if (imageIdStr != null && imageIdStr.isNotEmpty) {
      // Query specific image(s) by ID
      final ids = imageIdStr
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
      for (final id in ids) {
        final image = graphicsManager.getImage(id);
        if (image != null) {
          final placements = graphicsManager.placements.entries
              .where((e) => e.value.imageId == id)
              .toList();
          for (final entry in placements) {
            final p = entry.value;
            _sendGraphicsResponse(
              imageId: id,
              type: 'png',
              width: image.width,
              height: image.height,
              x: p.x,
              y: p.y,
              placementId: p.placementId,
            );
          }
        }
      }
    } else if (xStr != null && yStr != null) {
      // Query by position
      final x = int.tryParse(xStr) ?? 0;
      final y = int.tryParse(yStr) ?? 0;
      final placementId = graphicsManager.getPlacementIdAt(x, y);
      if (placementId != 0) {
        final placement = graphicsManager.getPlacement(placementId);
        if (placement != null) {
          final image = graphicsManager.getImage(placement.imageId);
          if (image != null) {
            _sendGraphicsResponse(
              imageId: placement.imageId,
              type: 'png',
              width: image.width,
              height: image.height,
              x: placement.x,
              y: placement.y,
              placementId: placementId,
            );
          }
        }
      }
    } else {
      // Query all images - send response for each
      for (final entry in graphicsManager.placements.entries) {
        final p = entry.value;
        final image = graphicsManager.getImage(p.imageId);
        if (image != null) {
          _sendGraphicsResponse(
            imageId: p.imageId,
            type: 'png',
            width: image.width,
            height: image.height,
            x: p.x,
            y: p.y,
            placementId: p.placementId,
          );
        }
      }
    }
  }

  /// Handle graphics delete action (a=d)
  Future<void> _handleGraphicsDelete() async {
    // Check for specific image ID to delete
    final imageIdStr = _currentGraphicsArgs['i'];
    // Check for position-based deletion
    final xStr = _currentGraphicsArgs['x'];
    final yStr = _currentGraphicsArgs['y'];

    if (imageIdStr != null && imageIdStr.isNotEmpty) {
      // Delete specific image(s) by ID
      final ids = imageIdStr
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
      for (final id in ids) {
        graphicsManager.removeImage(id);
        // Also clear cells that referenced this image
        _clearImageFromCells(id);
      }
    } else if (xStr != null && yStr != null) {
      // Delete by position
      final x = int.tryParse(xStr) ?? 0;
      final y = int.tryParse(yStr) ?? 0;
      final placementId = graphicsManager.getPlacementIdAt(x, y);
      if (placementId != 0) {
        final placement = graphicsManager.getPlacement(placementId);
        if (placement != null) {
          graphicsManager.removeImage(placement.imageId);
          _clearImageFromCells(placement.imageId);
        }
      }
    } else {
      // Delete all images
      graphicsManager.clear();
      _clearAllImagesFromCells();
    }
  }

  /// Send graphics protocol response
  void _sendGraphicsResponse({
    required int imageId,
    required String type,
    required int width,
    required int height,
    required int x,
    required int y,
    required int placementId,
  }) {
    // Format: \x1b_Gi=<id>,t=<type>,w=<width>,h=<height>,x=<x>,y=<y>,p=<placement_id>\x1b\\
    final response =
        '\x1b_Gi=$imageId,t=$type,w=$width,h=$height,x=$x,y=$y,p=$placementId\x1b\\';
    onOutput?.call(response);
  }

  /// Clear image references from cells
  void _clearImageFromCells(int imageId) {
    for (var y = 0; y < lines.length; y++) {
      final line = lines[y];
      for (var x = 0; x < buffer.viewWidth; x++) {
        final cellImageData = line.getImageData(x);
        if (CellImage.getImageId(cellImageData) == imageId) {
          line.setImageData(x, 0);
        }
      }
    }
    // Clean up stale placements after clearing cells
    _cleanupStalePlacements();
  }

  /// Clear all image references from cells
  void _clearAllImagesFromCells() {
    for (var y = 0; y < lines.length; y++) {
      final line = lines[y];
      for (var x = 0; x < buffer.viewWidth; x++) {
        final cellImageData = line.getImageData(x);
        if (CellImage.hasImage(cellImageData)) {
          line.setImageData(x, 0);
        }
      }
    }
    // Clean up stale placements after clearing cells
    _cleanupStalePlacements();
  }

  /// Collect active placement IDs from cells and clean up stale ones
  void _cleanupStalePlacements() {
    final activePlacements = <int>{};
    for (var y = 0; y < lines.length; y++) {
      final line = lines[y];
      for (var x = 0; x < buffer.viewWidth; x++) {
        final cellImageData = line.getImageData(x);
        if (CellImage.hasImage(cellImageData)) {
          activePlacements.add(CellImage.getPlacementId(cellImageData));
        }
      }
    }
    graphicsManager.cleanupStalePlacements(activePlacements);
  }

  /// Place image at cell position
  void _placeImage(
      int imageId, int placementId, int x, int y, int width, int height) {
    // Pack image data: image ID in upper 16 bits, placement ID in lower 16 bits
    final imageData = CellImage.packImageData(imageId, placementId);

    // Mark cells in the image area
    for (var dy = 0; dy < height && y + dy < buffer.height; dy++) {
      if (y + dy >= lines.length) continue;
      final bufferLine = lines[y + dy];

      for (var dx = 0; dx < width && x + dx < buffer.viewWidth; dx++) {
        bufferLine.setImageData(dx, imageData);
      }
    }
  }

  @override
  void setUnknownDecMode(int mode, bool enabled) {
    // no-op
  }

  /* Select Graphic Rendition (SGR) */

  @override
  void resetCursorStyle() {
    _cursorStyle.reset();
  }

  @override
  void setCursorBold() {
    _cursorStyle.setBold();
  }

  @override
  void setCursorFaint() {
    _cursorStyle.setFaint();
  }

  @override
  void setCursorItalic() {
    _cursorStyle.setItalic();
  }

  @override
  void setCursorUnderline() {
    _cursorStyle.setUnderline();
  }

  @override
  void setCursorUnderlineStyle(int style) {
    _cursorStyle.setUnderlineStyle(style);
  }

  @override
  void setCursorBlink() {
    _cursorStyle.setBlink();
  }

  @override
  void setCursorInverse() {
    _cursorStyle.setInverse();
  }

  @override
  void setCursorInvisible() {
    _cursorStyle.setInvisible();
  }

  @override
  void setCursorStrikethrough() {
    _cursorStyle.setStrikethrough();
  }

  @override
  void unsetCursorBold() {
    _cursorStyle.unsetBold();
  }

  @override
  void unsetCursorFaint() {
    _cursorStyle.unsetFaint();
  }

  @override
  void unsetCursorItalic() {
    _cursorStyle.unsetItalic();
  }

  @override
  void unsetCursorUnderline() {
    _cursorStyle.unsetUnderline();
  }

  @override
  void unsetCursorBlink() {
    _cursorStyle.unsetBlink();
  }

  @override
  void unsetCursorInverse() {
    _cursorStyle.unsetInverse();
  }

  @override
  void unsetCursorInvisible() {
    _cursorStyle.unsetInvisible();
  }

  @override
  void unsetCursorStrikethrough() {
    _cursorStyle.unsetStrikethrough();
  }

  @override
  void setUnderlineColor256(int color) {
    _cursorStyle.setUnderlineColor256(color);
  }

  @override
  void setUnderlineColorRgb(int r, int g, int b) {
    _cursorStyle.setUnderlineColorRgb(r, g, b);
  }

  @override
  void resetUnderlineColor() {
    _cursorStyle.resetUnderlineColor();
  }

  @override
  void setForegroundColor16(int color) {
    _cursorStyle.setForegroundColor16(color);
  }

  @override
  void setForegroundColor256(int index) {
    _cursorStyle.setForegroundColor256(index);
  }

  @override
  void setForegroundColorRgb(int r, int g, int b) {
    _cursorStyle.setForegroundColorRgb(r, g, b);
  }

  @override
  void resetForeground() {
    _cursorStyle.resetForegroundColor();
  }

  @override
  void setBackgroundColor16(int color) {
    _cursorStyle.setBackgroundColor16(color);
  }

  @override
  void setBackgroundColor256(int index) {
    _cursorStyle.setBackgroundColor256(index);
  }

  @override
  void setBackgroundColorRgb(int r, int g, int b) {
    _cursorStyle.setBackgroundColorRgb(r, g, b);
  }

  @override
  void resetBackground() {
    _cursorStyle.resetBackgroundColor();
  }

  @override
  void unsupportedStyle(int param) {
    // no-op
  }

  /* OSC */

  @override
  void setTitle(String name) {
    onTitleChange?.call(name);
  }

  @override
  void setIconName(String name) {
    onIconChange?.call(name);
  }

  int? _currentHyperlinkId;
  final Map<int, _HyperlinkEntry> _hyperlinks = {};
  int _hyperlinkIdCounter = 1;

  /// Get the URI for a hyperlink by its ID.
  ///
  /// Use this to look up the URI associated with a [hyperlinkId] from [CellData].
  /// Returns null if the hyperlink ID is not found.
  String? getHyperlinkUri(int hyperlinkId) {
    return _hyperlinks[hyperlinkId]?.uri;
  }

  /// Get all registered hyperlinks.
  ///
  /// Returns a map of hyperlink IDs to their URIs.
  Map<int, String> get hyperlinks {
    return _hyperlinks.map((key, value) => MapEntry(key, value.uri));
  }

  @override
  void setHyperlink(String? id, String uri) {
    if (uri.isEmpty) {
      // End hyperlink
      _currentHyperlinkId = null;
      _cursorStyle.hyperlinkId = 0;
      // Clean up stale hyperlinks
      _cleanupStaleHyperlinks();
    } else {
      // Register or find existing hyperlink
      _currentHyperlinkId = _registerHyperlink(uri, id);
      _cursorStyle.hyperlinkId = _currentHyperlinkId!;
    }
  }

  /// Clean up hyperlink entries that are no longer referenced by cells.
  void _cleanupStaleHyperlinks() {
    // Collect hyperlink IDs that are currently in use by cells
    final activeHyperlinkIds = <int>{};
    for (var y = 0; y < lines.length; y++) {
      final line = lines[y];
      for (var x = 0; x < buffer.viewWidth; x++) {
        final hyperlinkId = line.getHyperlinkId(x);
        if (hyperlinkId != 0) {
          activeHyperlinkIds.add(hyperlinkId);
        }
      }
    }
    // Remove hyperlinks that are no longer active (but keep the current one)
    _hyperlinks.removeWhere((key, _) =>
        key != _currentHyperlinkId && !activeHyperlinkIds.contains(key));
  }

  int _registerHyperlink(String uri, String? id) {
    final key = id ?? uri;
    for (var entry in _hyperlinks.entries) {
      if (entry.value.uri == uri && entry.value.id == key) {
        return entry.key;
      }
    }
    final newId = _hyperlinkIdCounter++;
    _hyperlinks[newId] = _HyperlinkEntry(uri, key);
    return newId;
  }

  @override
  void handleClipboard(String target, String data) {
    if (data == '?') {
      // Query clipboard - trigger callback for UI to read
      onClipboardRead?.call(target);
    } else {
      // Set clipboard - decode base64 and pass to callback
      try {
        final decoded = utf8.decode(base64.decode(data));
        onClipboardWrite?.call(decoded, target);
      } catch (e) {
        // Invalid base64, ignore
      }
    }
  }

  @override
  void handleNotification(List<String> args) {
    if (args.isEmpty) return;

    final cmd = args[0];
    if (cmd == 'notify') {
      // OSC 777;notify;title;body
      final title = args.length > 1 ? args[1] : '';
      final body = args.length > 2 ? args[2] : '';
      onNotification?.call(title, body);
    }
  }

  /// Callback for desktop notifications via OSC 777.
  ///
  /// The terminal sends this when it receives `ESC ] 777 ; notify ; title ; body ST`.
  /// This is used for long-running commands to notify the user when complete.
  /// Your implementation should display a desktop notification with [title] and [body].
  void Function(String title, String body)? onNotification;

  @override
  void handleTextSizeQuery(int command) {
    // Respond to text size queries
    if (command == 10) {
      // Font size query - respond with default
      _emit('\x1b]10;12\x1b\\');
    } else if (command == 133) {
      // Font family query - respond with default
      _emit('\x1b]133;monospace\x1b\\');
    }
  }

  @override
  void handleShellIntegration(String cmd, List<String> args) {
    // Shell integration via onPrivateOSC for extensibility
    onPrivateOSC?.call('133', [cmd, ...args]);
  }

  // Color stack for OSC 30001/30101
  final List<CursorStyle> _colorStack = [];

  @override
  void handleColorStack({required bool push}) {
    if (push) {
      // Push current attributes to stack
      _colorStack.add(_cursorStyle.copy());
    } else {
      // Pop attributes from stack
      if (_colorStack.isNotEmpty) {
        final saved = _colorStack.removeLast();
        _cursorStyle.foreground = saved.foreground;
        _cursorStyle.background = saved.background;
        _cursorStyle.attrs = saved.attrs;
        // Use setUnderlineStyle to ensure attrs underline bit is synced
        _cursorStyle.setUnderlineStyle(saved.underlineStyle);
        _cursorStyle.underlineColor = saved.underlineColor;
      }
    }
  }

  @override
  void handleDcs(String command, List<String> args, List<int>? data) {
    // Handle Remote Control queries: DCS +q<query> ST
    // Query format: +q<hex-encoded-query> where 'q' is the subparameter indicator
    if (command.startsWith('+q')) {
      final query = command.substring(2); // Remove '+q' prefix
      String response = '';

      // Handle hex-encoded queries (e.g., q544e = q + TN)
      // or plain text queries (e.g., qTN)
      switch (query) {
        case 'qTN':
        case 'q544e': // q + TN (hex)
          response = 'kterm';
          break;
        case 'qcl':
        case 'q636c': // q + cl (hex)
          // Would need to query clipboard
          response = '';
          break;
        case 'qVC':
        case 'q5643': // q + VC (hex)
          response = '1.0';
          break;
        case 'q?':
        case 'q3f': // q + ? (hex)
          response = 'qTN;qcl;qVC';
          break;
        default:
          response = '';
      }

      // Always respond, even if empty (for clipboard queries)
      _emit('\x1bP1+r$response\x1b\\');
    }
  }

  void _emit(String data) {
    onOutput?.call(data);
  }

  @override
  void unknownOSC(String ps, List<String> pt) {
    onPrivateOSC?.call(ps, pt);
  }
}

class _HyperlinkEntry {
  final String uri;
  final String id;
  _HyperlinkEntry(this.uri, this.id);
}

/// Wrapper around KittyKeyboardEncoder that fixes incorrect keycode mappings.
///
/// The kitty_protocol package uses USB HID keycodes instead of the
/// correct Kitty protocol keycodes:
/// - Enter: 8 (USB HID) → should be 13 (Kitty)
class _KittyKeyboardEncoderWrapper extends KittyKeyboardEncoder {
  final KittyKeyboardEncoder _inner;

  _KittyKeyboardEncoderWrapper(this._inner);

  @override
  String encode(SimpleKeyEvent event) {
    final result = _inner.encode(event);

    // Fix Enter key: USB HID codes → correct Kitty protocol codes
    // The sequence format is: \x1B[code;modifiersu
    // - Shift+Enter: 8 (USB HID) → 13 (Kitty)
    // - Enter without modifiers: 28 (USB HID) → 13 (Kitty)
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      // Replace both possible incorrect keycodes with 13
      var fixed = result.replaceFirst('\x1B[8;', '\x1B[13;');
      fixed = fixed.replaceFirst('\x1B[28;', '\x1B[13;');
      return fixed;
    }

    // Note: Backspace is 127 in Kitty protocol, which is handled correctly
    // by the kitty_protocol package, so no fix needed there.

    return result;
  }

  @override
  KittyKeyboardEncoder withFlags(KittyKeyboardEncoderFlags flags) {
    return _inner.withFlags(flags);
  }
}
