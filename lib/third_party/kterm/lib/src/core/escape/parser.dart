import 'dart:convert' show Base64Decoder;

import 'package:kterm/src/core/color.dart';
import 'package:kterm/src/core/mouse/mode.dart';
import 'package:kterm/src/core/escape/handler.dart';
import 'package:kterm/src/utils/ascii.dart';
import 'package:kterm/src/utils/byte_consumer.dart';
import 'package:kterm/src/utils/char_code.dart';
import 'package:kterm/src/utils/lookup_table.dart';

/// [EscapeParser] translates control characters and escape sequences into
/// function calls that the terminal can handle.
///
/// Design goals:
///  * Zero object allocation during processing.
///  * No internal state. Same input will always produce same output.
class EscapeParser {
  final EscapeHandler handler;

  EscapeParser(this.handler);

  final _queue = ByteConsumer();

  /// Start of sequence or character being processed. Useful for debugging.
  var tokenBegin = 0;

  /// End of sequence or character being processed. Useful for debugging.
  int get tokenEnd => _queue.totalConsumed;

  void write(String chunk) {
    _queue.unrefConsumedBlocks();
    _queue.add(chunk);
    _process();
  }

  void _process() {
    while (_queue.isNotEmpty) {
      tokenBegin = _queue.totalConsumed;
      final char = _queue.consume();

      if (char == Ascii.ESC) {
        final processed = _processEscape();
        if (!processed) {
          _queue.rollback(tokenEnd - tokenBegin);
          return;
        }
      } else {
        _processChar(char);
      }
    }
  }

  void _processChar(int char) {
    if (char > _sbcHandlers.maxIndex) {
      handler.writeChar(char);
      return;
    }

    final sbcHandler = _sbcHandlers[char];
    if (sbcHandler == null) {
      handler.unknownEscape(char);
      return;
    }

    sbcHandler();
  }

  /// Processes a sequence of characters that starts with an escape character.
  /// Returns [true] if the sequence was processed, [false] if it was not.
  bool _processEscape() {
    if (_queue.isEmpty) return false;

    final escapeChar = _queue.consume();
    final escapeHandler = _escHandlers[escapeChar];

    if (escapeHandler == null) {
      handler.unknownEscape(escapeChar);
      return true;
    }

    return escapeHandler();
  }

  late final _sbcHandlers = FastLookupTable<_SbcHandler>({
    0x07: handler.bell,
    0x08: handler.backspaceReturn,
    0x09: handler.tab,
    0x0a: handler.lineFeed,
    0x0b: handler.lineFeed,
    0x0c: handler.lineFeed,
    0x0d: handler.carriageReturn,
    0x0e: handler.shiftOut,
    0x0f: handler.shiftIn,
  });

  late final _escHandlers = FastLookupTable<_EscHandler>({
    '['.charCode: _escHandleCSI,
    ']'.charCode: _escHandleOSC,
    '7'.charCode: _escHandleSaveCursor,
    '8'.charCode: _escHandleRestoreCursor,
    'D'.charCode: _escHandleIndex,
    'E'.charCode: _escHandleNextLine,
    'H'.charCode: _escHandleTabSet,
    'M'.charCode: _escHandleReverseIndex,
    // 'P'.charCode: _unsupportedHandler, // Sixel
    // 'c'.charCode: _unsupportedHandler,
    // '#'.charCode: _unsupportedHandler,
    'P'.charCode: _escHandleDCS, // DCS (Device Control String) - Remote Control
    '_'.charCode:
        _escHandleAPC, // APC (Application Program Command) - Kitty Graphics
    '('.charCode: _escHandleDesignateCharset0, //  SCS - G0
    ')'.charCode: _escHandleDesignateCharset1, //  SCS - G1
    // '*'.charCode: _voidHandler(1), // TODO: G2 (vt220)
    // '+'.charCode: _voidHandler(1), // TODO: G3 (vt220)
    '>'.charCode: _escHandleResetAppKeypadMode, // TODO: Normal Keypad
    '='.charCode: _escHandleSetAppKeypadMode, // TODO: Application Keypad
  });

  /// `ESC 7` Save Cursor (DECSC)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_a7/
  bool _escHandleSaveCursor() {
    handler.saveCursor();
    return true;
  }

  /// `ESC 8` Restore Cursor (DECRC)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_a8/
  bool _escHandleRestoreCursor() {
    handler.restoreCursor();
    return true;
  }

  /// `ESC D` Index (IND)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_cd/
  bool _escHandleIndex() {
    handler.index();
    return true;
  }

  /// `ESC E` Next Line (NEL)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_ce/
  bool _escHandleNextLine() {
    handler.nextLine();
    return true;
  }

  /// `ESC H` Horizontal Tab Set (HTS)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_ch/
  bool _escHandleTabSet() {
    handler.setTapStop();
    return true;
  }

  /// `ESC M` Reverse Index (RI)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_cm/
  bool _escHandleReverseIndex() {
    handler.reverseIndex();
    return true;
  }

  bool _escHandleDesignateCharset0() {
    if (_queue.isEmpty) return false;
    int name = _queue.consume();
    handler.designateCharset(0, name);
    return true;
  }

  bool _escHandleDesignateCharset1() {
    if (_queue.isEmpty) return false;
    int name = _queue.consume();
    handler.designateCharset(1, name);
    return true;
  }

  /// `ESC >` Reset Application Keypad Mode (DECKPNM)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_x3c_greater_than/
  bool _escHandleSetAppKeypadMode() {
    handler.setAppKeypadMode(true);
    return true;
  }

  /// `ESC =` Set Application Keypad Mode (DECKPAM)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_x3d_equals/
  bool _escHandleResetAppKeypadMode() {
    handler.setAppKeypadMode(false);
    return true;
  }

  bool _escHandleCSI() {
    final consumed = _consumeCsi();
    if (!consumed) return false;

    // Check for Kitty keyboard protocol: CSI > n u
    if (_csi.prefix == Ascii.greaterThan && _csi.finalByte == Ascii.u) {
      return _handleKittyMode();
    }

    final csiHandler = _csiHandlers[_csi.finalByte];

    if (csiHandler == null) {
      handler.unknownCSI(_csi.finalByte);
    } else {
      csiHandler();
    }

    return true;
  }

  /// Handle Kitty keyboard protocol sequences:
  /// - CSI > n u - Set mode (0 = disable, 1 = enable)
  /// - CSI > + n u - Push flags
  /// - CSI > - n u - Pop flags
  bool _handleKittyMode() {
    if (_csi.params.isEmpty) return true;

    final firstParam = _csi.params[0];

    // CSI > n u - Set mode (0 = disable, 1 = enable)
    if (firstParam == 0) {
      handler.setKittyMode(false);
    } else if (firstParam == 1) {
      handler.setKittyMode(true);
    }
    // CSI > + n u - Push flags
    else if (firstParam == '+'.codeUnitAt(0)) {
      if (_csi.params.length > 1) {
        handler.pushKittyFlags(_csi.params[1]);
      }
    }
    // CSI > - n u - Pop flags
    else if (firstParam == '-'.codeUnitAt(0)) {
      handler.popKittyFlags();
    }

    return true;
  }

  /// The last parsed [_Csi]. This is a mutable singletion by design to reduce
  /// object allocations.
  final _csi = _Csi(finalByte: 0, params: []);

  /// Parse a CSI from the head of the queue. Return false if the CSI isn't
  /// complete. After a CSI is successfully parsed, [_csi] is updated.
  bool _consumeCsi() {
    if (_queue.isEmpty) {
      return false;
    }

    _csi.params.clear();

    // test whether the csi is a `CSI ? Ps ...` or `CSI Ps ...`
    final prefix = _queue.peek();
    if (prefix >= Ascii.colon && prefix <= Ascii.questionMark) {
      _csi.prefix = prefix;
      _queue.consume();
    } else {
      _csi.prefix = null;
    }

    const maxCsiParams = 256;

    var param = 0;
    var hasParam = false;
    while (true) {
      // The sequence isn't completed, just ignore it.
      if (_queue.isEmpty) {
        return false;
      }

      final char = _queue.consume();

      if (char == Ascii.semicolon || char == Ascii.colon) {
        if (hasParam && _csi.params.length < maxCsiParams) {
          _csi.params.add(param);
        }
        param = 0;
        continue;
      }

      if (char >= Ascii.num0 && char <= Ascii.num9) {
        hasParam = true;
        param *= 10;
        param += char - Ascii.num0;
        continue;
      }

      if (char > Ascii.NULL && char < Ascii.num0) {
        // intermediates.add(char);
        continue;
      }

      if (char >= Ascii.atSign && char <= Ascii.tilde) {
        if (hasParam && _csi.params.length < maxCsiParams) {
          _csi.params.add(param);
        }

        _csi.finalByte = char;
        return true;
      }
    }
  }

  late final _csiHandlers = FastLookupTable<_CsiHandler>({
    // 'a'.codeUnitAt(0): _csiHandleCursorHorizontalRelative,
    'b'.codeUnitAt(0): _csiHandleRepeatPreviousCharacter,
    'c'.codeUnitAt(0): _csiHandleSendDeviceAttributes,
    'd'.codeUnitAt(0): _csiHandleLinePositionAbsolute,
    'f'.codeUnitAt(0): _csiHandleCursorPosition,
    'g'.codeUnitAt(0): _csiHandelClearTabStop,
    'h'.codeUnitAt(0): _csiHandleMode,
    'l'.codeUnitAt(0): _csiHandleMode,
    'm'.codeUnitAt(0): _csiHandleSgr,
    'n'.codeUnitAt(0): _csiHandleDeviceStatusReport,
    'r'.codeUnitAt(0): _csiHandleSetMargins,
    't'.codeUnitAt(0): _csiWindowManipulation,
    'A'.codeUnitAt(0): _csiHandleCursorUp,
    'B'.codeUnitAt(0): _csiHandleCursorDown,
    'C'.codeUnitAt(0): _csiHandleCursorForward,
    'D'.codeUnitAt(0): _csiHandleCursorBackward,
    'E'.codeUnitAt(0): _csiHandleCursorNextLine,
    'F'.codeUnitAt(0): _csiHandleCursorPrecedingLine,
    'G'.codeUnitAt(0): _csiHandleCursorHorizontalAbsolute,
    'H'.codeUnitAt(0): _csiHandleCursorPosition,
    'J'.codeUnitAt(0): _csiHandleEraseDisplay,
    'K'.codeUnitAt(0): _csiHandleEraseLine,
    'L'.codeUnitAt(0): _csiHandleInsertLines,
    'M'.codeUnitAt(0): _csiHandleDeleteLines,
    'P'.codeUnitAt(0): _csiHandleDelete,
    'S'.codeUnitAt(0): _csiHandleScrollUp,
    'T'.codeUnitAt(0): _csiHandleScrollDown,
    'X'.codeUnitAt(0): _csiHandleEraseCharacters,
    '@'.codeUnitAt(0): _csiHandleInsertBlankCharacters,
  });

  /// `ESC [ Ps a` Cursor Horizontal Position Relative (HPR)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sa/
  // void _csiHandleCursorHorizontalRelative() {
  //   if (_csi.params.isEmpty) {
  //     handler.cursorHorizontal(1);
  //   } else {
  //     handler.cursorHorizontal(_csi.params[0]);
  //   }
  // }

  /// `ESC [ Ps b` Repeat Previous Character (REP)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sb/
  void _csiHandleRepeatPreviousCharacter() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.repeatPreviousCharacter(amount);
  }

  /// `ESC [ Ps c` Device Attributes (DA)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sc/
  void _csiHandleSendDeviceAttributes() {
    switch (_csi.prefix) {
      case Ascii.greaterThan:
        return handler.sendSecondaryDeviceAttributes();
      case Ascii.equal:
        return handler.sendTertiaryDeviceAttributes();
      default:
        handler.sendPrimaryDeviceAttributes();
    }
  }

  /// `ESC [ Ps d` Cursor Vertical Position Absolute (VPA)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sd/
  void _csiHandleLinePositionAbsolute() {
    var y = 1;

    if (_csi.params.isNotEmpty) {
      y = _csi.params[0];
    }

    handler.setCursorY(y - 1);
  }

  /// `ESC [ Ps ; Ps f` Alias: Set Cursor Position
  ///
  /// https://terminalguide.namepad.de/seq/csi_sf/
  void _csiHandleCursorPosition() {
    var row = 1;
    var col = 1;

    if (_csi.params.length == 2) {
      row = _csi.params[0];
      col = _csi.params[1];
    }

    handler.setCursor(col - 1, row - 1);
  }

  /// `ESC [ Ps g` Tab Clear (TBC)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sg/
  void _csiHandelClearTabStop() {
    var cmd = 0;

    if (_csi.params.length == 1) {
      cmd = _csi.params[0];
    }

    switch (cmd) {
      case 0:
        return handler.clearTabStopUnderCursor();
      default:
        return handler.clearAllTabStops();
    }
  }

  /// - `ESC [ [ Pm ] h Set Mode (SM)` https://terminalguide.namepad.de/seq/csi_sm/
  /// - `ESC [ ? [ Pm ] h` Set Mode (?) (SM) https://terminalguide.namepad.de/seq/csi_sh__p/
  /// - `ESC [ [ Pm ] l` Reset Mode (RM) https://terminalguide.namepad.de/seq/csi_rm/
  /// - `ESC [ ? [ Pm ] l` Reset Mode (?) (RM) https://terminalguide.namepad.de/seq/csi_sl__p/
  void _csiHandleMode() {
    final isEnabled = _csi.finalByte == Ascii.h;

    final isDecModes = _csi.prefix == Ascii.questionMark;

    if (isDecModes) {
      for (var mode in _csi.params) {
        _setDecMode(mode, isEnabled);
      }
    } else {
      for (var mode in _csi.params) {
        _setMode(mode, isEnabled);
      }
    }
  }

  /// `ESC [ [ Ps ] m` Select Graphic Rendition (SGR)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sm/
  void _csiHandleSgr() {
    final params = _csi.params;

    if (params.isEmpty) {
      return handler.resetCursorStyle();
    }

    // This is a workaround for a bug in the analyzer.
    // ignore: dead_code
    for (var i = 0; i < _csi.params.length; i++) {
      final param = params[i];
      switch (param) {
        case 0:
          handler.resetCursorStyle();
          continue;
        case 1:
          handler.setCursorBold();
          continue;
        case 2:
          handler.setCursorFaint();
          continue;
        case 3:
          handler.setCursorItalic();
          continue;
        case 4:
          // Extended underline: CSI 4:n where n is the style (1-5)
          // Supports both semicolon (4;n) and colon (4:n) separators
          if (i + 1 < params.length) {
            final nextParam = params[i + 1];
            if (nextParam >= 0 && nextParam <= 5) {
              handler.setCursorUnderlineStyle(nextParam);
              i++; // Skip the subparameter
              continue;
            }
          }
          // Plain SGR 4 - single underline
          handler.setCursorUnderline();
          continue;
        case 5:
          handler.setCursorBlink();
          continue;
        case 7:
          handler.setCursorInverse();
          continue;
        case 8:
          // Invisible flag
          handler.setCursorInvisible();
          continue;
        case 9:
          handler.setCursorStrikethrough();
          continue;

        case 21:
          handler.unsetCursorBold();
          continue;
        case 22:
          handler.unsetCursorFaint();
          continue;
        case 23:
          handler.unsetCursorItalic();
          continue;
        case 24:
          handler.unsetCursorUnderline();
          continue;
        case 25:
          handler.unsetCursorBlink();
          continue;
        case 27:
          handler.unsetCursorInverse();
          continue;
        case 28:
          handler.unsetCursorInvisible();
          continue;
        case 29:
          handler.unsetCursorStrikethrough();
          continue;

        case 30:
          handler.setForegroundColor16(NamedColor.black);
          continue;
        case 31:
          handler.setForegroundColor16(NamedColor.red);
          continue;
        case 32:
          handler.setForegroundColor16(NamedColor.green);
          continue;
        case 33:
          handler.setForegroundColor16(NamedColor.yellow);
          continue;
        case 34:
          handler.setForegroundColor16(NamedColor.blue);
          continue;
        case 35:
          handler.setForegroundColor16(NamedColor.magenta);
          continue;
        case 36:
          handler.setForegroundColor16(NamedColor.cyan);
          continue;
        case 37:
          handler.setForegroundColor16(NamedColor.white);
          continue;
        case 38:
          if (i + 1 >= params.length) break;
          final mode = params[i + 1];
          switch (mode) {
            case 2:
              if (i + 4 >= params.length) {
                i++;
                continue;
              }
              handler.setForegroundColorRgb(
                  params[i + 2], params[i + 3], params[i + 4]);
              i += 4;
              continue;
            case 5:
              if (i + 2 >= params.length) {
                i++;
                continue;
              }
              handler.setForegroundColor256(params[i + 2]);
              i += 2;
              continue;
          }
          i++;
          continue;
        case 39:
          handler.resetForeground();
          continue;

        case 40:
          handler.setBackgroundColor16(NamedColor.black);
          continue;
        case 41:
          handler.setBackgroundColor16(NamedColor.red);
          continue;
        case 42:
          handler.setBackgroundColor16(NamedColor.green);
          continue;
        case 43:
          handler.setBackgroundColor16(NamedColor.yellow);
          continue;
        case 44:
          handler.setBackgroundColor16(NamedColor.blue);
          continue;
        case 45:
          handler.setBackgroundColor16(NamedColor.magenta);
          continue;
        case 46:
          handler.setBackgroundColor16(NamedColor.cyan);
          continue;
        case 47:
          handler.setBackgroundColor16(NamedColor.white);
          continue;
        case 48:
          if (i + 1 >= params.length) break;
          final mode = params[i + 1];
          switch (mode) {
            case 2:
              if (i + 4 >= params.length) {
                i++;
                continue;
              }
              handler.setBackgroundColorRgb(
                  params[i + 2], params[i + 3], params[i + 4]);
              i += 4;
              continue;
            case 5:
              if (i + 2 >= params.length) {
                i++;
                continue;
              }
              handler.setBackgroundColor256(params[i + 2]);
              i += 2;
              continue;
          }
          i++;
          continue;
        case 49:
          handler.resetBackground();
          continue;

        // CSI 58 - Underline color
        case 58:
          if (i + 1 >= params.length) break;
          final mode = params[i + 1];
          switch (mode) {
            case 2:
              if (i + 4 >= params.length) {
                i++;
                continue;
              }
              handler.setUnderlineColorRgb(
                  params[i + 2], params[i + 3], params[i + 4]);
              i += 4;
              continue;
            case 5:
              if (i + 2 >= params.length) {
                i++;
                continue;
              }
              handler.setUnderlineColor256(params[i + 2]);
              i += 2;
              continue;
          }
          i++;
          continue;
        case 59:
          handler.resetUnderlineColor();
          continue;

        case 90:
          handler.setForegroundColor16(NamedColor.brightBlack);
          continue;
        case 91:
          handler.setForegroundColor16(NamedColor.brightRed);
          continue;
        case 92:
          handler.setForegroundColor16(NamedColor.brightGreen);
          continue;
        case 93:
          handler.setForegroundColor16(NamedColor.brightYellow);
          continue;
        case 94:
          handler.setForegroundColor16(NamedColor.brightBlue);
          continue;
        case 95:
          handler.setForegroundColor16(NamedColor.brightMagenta);
          continue;
        case 96:
          handler.setForegroundColor16(NamedColor.brightCyan);
          continue;
        case 97:
          handler.setForegroundColor16(NamedColor.brightWhite);
          continue;

        case 100:
          handler.setBackgroundColor16(NamedColor.brightBlack);
          continue;
        case 101:
          handler.setBackgroundColor16(NamedColor.brightRed);
          continue;
        case 102:
          handler.setBackgroundColor16(NamedColor.brightGreen);
          continue;
        case 103:
          handler.setBackgroundColor16(NamedColor.brightYellow);
          continue;
        case 104:
          handler.setBackgroundColor16(NamedColor.brightBlue);
          continue;
        case 105:
          handler.setBackgroundColor16(NamedColor.brightMagenta);
          continue;
        case 106:
          handler.setBackgroundColor16(NamedColor.brightCyan);
          continue;
        case 107:
          handler.setBackgroundColor16(NamedColor.brightWhite);
          continue;

        default:
          handler.unsupportedStyle(param);
          continue;
      }
    }
  }

  /// `ESC [ Ps n` Device Status Report [Dispatch] (DSR)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sn/
  void _csiHandleDeviceStatusReport() {
    if (_csi.params.isEmpty) return;

    switch (_csi.params[0]) {
      case 5:
        return handler.sendOperatingStatus();
      case 6:
        return handler.sendCursorPosition();
    }
  }

  /// `ESC [ Ps ; Ps r` Set Top and Bottom Margins (DECSTBM)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sr/
  void _csiHandleSetMargins() {
    var top = 1;
    int? bottom;

    if (_csi.params.length > 2) return;

    if (_csi.params.isNotEmpty) {
      top = _csi.params[0];

      if (_csi.params.length == 2) {
        bottom = _csi.params[1] - 1;
      }
    }

    handler.setMargins(top - 1, bottom);
  }

  /// `ESC [ Ps t` Window operations [DISPATCH]
  ///
  /// https://terminalguide.namepad.de/seq/csi_st/
  void _csiWindowManipulation() {
    // The sequence needs at least one parameter.
    if (_csi.params.isEmpty) {
      return;
    }
    // Most the commands in this group are either of the scope of this package,
    // or should be disabled for security risks.
    switch (_csi.params.first) {
      // Window handling is currently not in the scope of the package.
      case 1: // Restore Terminal Window (show window if minimized)
      case 2: // Minimize Terminal Window
      case 3: // Set Terminal Window Position
      case 4: // Set Terminal Window Size in Pixels
      case 5: // Raise Terminal Window
      case 6: // Lower Terminal Window
      case 7: // Refresh/Redraw Terminal Window
        return;
      case 8: // Set Terminal Window Size (in characters)
        // This CSI contains 2 more parameters: width and height.
        if (_csi.params.length != 3) {
          return;
        }
        final rows = _csi.params[1];
        final cols = _csi.params[2];
        handler.resize(cols, rows);
        return;
      // Window handling is currently no in the scope of the package.
      case 9: // Maximize Terminal Window
      case 10: // Alias: Maximize Terminal Window
      case 11: // Report Terminal Window State
      case 13: // Report Terminal Window Position
      case 14: // Report Terminal Window Size in Pixels
      case 15: // Report Screen Size in Pixels
      case 16: // Report Cell Size in Pixels
        return;
      case 18: // Report Terminal Size (in characters)
        handler.sendSize();
        return;
      // Screen handling is currently no in the scope of the package.
      case 19: // Report Screen Size (in characters)
      // Disabled as these can a security risk.
      case 20: // Get Icon Title
      case 21: // Get Terminal Title
      // Not implemented.
      case 22: // Push Terminal Title
      case 23: // Pop Terminal Title
        return;
      // Unknown CSI.
      default:
        return;
    }
  }

  /// `ESC [ Ps A` Cursor Up (CUU)
  ///
  /// https://terminalguide.namepad.de/seq/csi_ca/
  void _csiHandleCursorUp() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.moveCursorY(-amount);
  }

  /// `ESC [ Ps B` Cursor Down (CUD)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cb/
  void _csiHandleCursorDown() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.moveCursorY(amount);
  }

  /// `ESC [ Ps C` Cursor Right (CUF)
  ///
  /// Cursor Right (CUF)
  void _csiHandleCursorForward() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.moveCursorX(amount);
  }

  /// `ESC [ Ps D` Cursor Left (CUB)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cd/
  void _csiHandleCursorBackward() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.moveCursorX(-amount);
  }

  /// `ESC [ Ps E` Cursor Next Line (CNL)
  ///
  /// https://terminalguide.namepad.de/seq/csi_ce/
  void _csiHandleCursorNextLine() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.cursorNextLine(amount);
  }

  /// `ESC [ Ps F` Cursor Previous Line (CPL)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cf/
  void _csiHandleCursorPrecedingLine() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.cursorPrecedingLine(amount);
  }

  void _csiHandleCursorHorizontalAbsolute() {
    var x = 1;

    if (_csi.params.isNotEmpty) {
      x = _csi.params[0];
      if (x == 0) x = 1;
    }

    handler.setCursorX(x - 1);
  }

  /// ESC [ Ps J Erase Display [Dispatch] (ED)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cj/
  void _csiHandleEraseDisplay() {
    var cmd = 0;

    if (_csi.params.length == 1) {
      cmd = _csi.params[0];
    }

    switch (cmd) {
      case 0:
        return handler.eraseDisplayBelow();
      case 1:
        return handler.eraseDisplayAbove();
      case 2:
        return handler.eraseDisplay();
      case 3:
        return handler.eraseScrollbackOnly();
    }
  }

  /// `ESC [ Ps K` Erase Line [Dispatch] (EL)
  ///
  /// https://terminalguide.namepad.de/seq/csi_ck/
  void _csiHandleEraseLine() {
    var cmd = 0;

    if (_csi.params.length == 1) {
      cmd = _csi.params[0];
    }

    switch (cmd) {
      case 0:
        return handler.eraseLineRight();
      case 1:
        return handler.eraseLineLeft();
      case 2:
        return handler.eraseLine();
    }
  }

  /// `ESC [ Ps L` Insert Line (IL)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cl/
  void _csiHandleInsertLines() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.insertLines(amount);
  }

  /// ESC [ Ps M Delete Line (DL)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cm/
  void _csiHandleDeleteLines() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.deleteLines(amount);
  }

  /// ESC [ Ps P Delete Character (DCH)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cp/
  void _csiHandleDelete() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.deleteChars(amount);
  }

  /// `ESC [ Ps S` Scroll Up (SU)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cs/
  void _csiHandleScrollUp() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.scrollUp(amount);
  }

  /// `ESC [ Ps T `Scroll Down (SD)
  ///
  /// https://terminalguide.namepad.de/seq/csi_ct_1param/
  void _csiHandleScrollDown() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.scrollDown(amount);
  }

  /// `ESC [ Ps X` Erase Character (ECH)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cx/
  void _csiHandleEraseCharacters() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.eraseChars(amount);
  }

  /// `ESC [ Ps @` Insert Blanks (ICH)
  ///
  /// https://terminalguide.namepad.de/seq/csi_x40_at/
  ///
  /// Inserts amount spaces at current cursor position moving existing cell
  /// contents to the right. The contents of the amount right-most columns in
  /// the scroll region are lost. The cursor position is not changed.
  void _csiHandleInsertBlankCharacters() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.insertBlankChars(amount);
  }

  void _setMode(int mode, bool enabled) {
    switch (mode) {
      case 4:
        return handler.setInsertMode(enabled);
      case 20:
        return handler.setLineFeedMode(enabled);
      default:
        return handler.setUnknownMode(mode, enabled);
    }
  }

  void _setDecMode(int mode, bool enabled) {
    switch (mode) {
      case 1:
        return handler.setCursorKeysMode(enabled);
      case 3:
        return handler.setColumnMode(enabled);
      case 5:
        return handler.setReverseDisplayMode(enabled);
      case 6:
        return handler.setOriginMode(enabled);
      case 7:
        return handler.setAutoWrapMode(enabled);
      case 9:
        return enabled
            ? handler.setMouseMode(MouseMode.clickOnly)
            : handler.setMouseMode(MouseMode.none);
      case 12:
      case 13:
        return handler.setCursorBlinkMode(enabled);
      case 25:
        return handler.setCursorVisibleMode(enabled);
      case 47:
        if (enabled) {
          return handler.useAltBuffer();
        } else {
          return handler.useMainBuffer();
        }
      case 66:
        return handler.setAppKeypadMode(enabled);
      case 1000:
        return enabled
            ? handler.setMouseMode(MouseMode.upDownScroll)
            : handler.setMouseMode(MouseMode.none);
      case 1001:
        return enabled
            ? handler.setMouseMode(MouseMode.upDownScroll)
            : handler.setMouseMode(MouseMode.none);
      case 1002:
        return enabled
            ? handler.setMouseMode(MouseMode.upDownScrollDrag)
            : handler.setMouseMode(MouseMode.none);
      case 1003:
        return enabled
            ? handler.setMouseMode(MouseMode.upDownScrollMove)
            : handler.setMouseMode(MouseMode.none);
      case 1004:
        return handler.setReportFocusMode(enabled);
      case 1005:
        return enabled
            ? handler.setMouseReportMode(MouseReportMode.utf)
            : handler.setMouseReportMode(MouseReportMode.normal);
      case 1006:
        return enabled
            ? handler.setMouseReportMode(MouseReportMode.sgr)
            : handler.setMouseReportMode(MouseReportMode.normal);
      case 1007:
        return handler.setAltBufferMouseScrollMode(enabled);
      case 1015:
        return enabled
            ? handler.setMouseReportMode(MouseReportMode.urxvt)
            : handler.setMouseReportMode(MouseReportMode.normal);
      case 1047:
        if (enabled) {
          handler.useAltBuffer();
        } else {
          handler.clearAltBuffer();
          handler.useMainBuffer();
        }
        return;
      case 1048:
        if (enabled) {
          return handler.saveCursor();
        } else {
          return handler.restoreCursor();
        }
      case 1049:
        if (enabled) {
          handler.saveCursor();
          handler.clearAltBuffer();
          handler.useAltBuffer();
        } else {
          handler.useMainBuffer();
        }
        return;
      case 2004:
        return handler.setBracketedPasteMode(enabled);
      default:
        return handler.setUnknownDecMode(mode, enabled);
    }
  }

  /// Parse a OSC sequence from the queue. Returns true if a sequence was
  /// found and handled.
  bool _escHandleOSC() {
    final consumed = _consumeOsc();
    if (!consumed) {
      return false;
    }

    if (_osc.isEmpty) {
      return true;
    }

    // Common OSCs
    if (_osc.length >= 2) {
      final ps = _osc[0];
      final pt = _osc[1];

      switch (ps) {
        case '0':
          handler.setTitle(pt);
          handler.setIconName(pt);
          return true;
        case '1':
          handler.setIconName(pt);
          return true;
        case '2':
          handler.setTitle(pt);
          return true;
        case '8':
          // Hyperlink: OSC 8 ; params ; URI ST
          // Format: 8;id=xxx;uri or 8;;uri
          // _osc[0] = '8', _osc[1..] = params and uri
          final args = _osc.sublist(1);
          String? id;
          String uri = '';
          for (final arg in args) {
            if (arg.startsWith('id=')) {
              id = arg.substring(3);
            } else if (arg.isNotEmpty) {
              uri = arg;
            }
          }
          handler.setHyperlink(id, uri);
          return true;
        case '52':
          // Clipboard: OSC 52 ; target ; base64data
          // target: c=clipboard, p=primary, s=selection
          if (_osc.length >= 3) {
            final target = _osc[1];
            final data = _osc[2];
            handler.handleClipboard(target, data);
          } else if (_osc.length >= 2) {
            final target = _osc[1];
            handler.handleClipboard(target, '?');
          }
          return true;
        case '10':
          // Font size query: OSC 10 ; ?
          if (_osc.length >= 2 && _osc[1] == '?') {
            handler.handleTextSizeQuery(10);
          }
          return true;
        case '133':
          // Shell integration: OSC 133 ; A|D|P|...
          if (_osc.length >= 2) {
            final cmd = _osc[1];
            handler.handleShellIntegration(cmd, _osc.sublist(2));
          }
          return true;
        case '30001':
          // Color stack push
          handler.handleColorStack(push: true);
          return true;
        case '30101':
          // Color stack pop
          handler.handleColorStack(push: false);
          return true;
        case '99':
          // Desktop notifications: OSC 99 ; title ; body
          if (_osc.length >= 2) {
            final title = _osc[1];
            final body = _osc.length > 2 ? _osc[2] : '';
            handler.handleNotification(['notify', title, body]);
          }
          return true;
        case '777':
          // Desktop notifications: OSC 777 ; cmd ; args...
          if (_osc.length >= 2) {
            handler.handleNotification(_osc.sublist(1));
          }
          return true;
      }
    }

    // Private extensions
    handler.unknownOSC(_osc[0], _osc.sublist(1));

    return true;
  }

  /// Handle DCS (Device Control String) sequences
  /// Used by Kitty Remote Control Protocol: ESC P +q <query> ST
  bool _escHandleDCS() {
    if (_queue.isEmpty) return false;

    final command = _queue.consume();
    // Kitty Remote Control uses '+q'
    if (command != '+'.codeUnitAt(0)) {
      // Not a remote control query, skip
      _skipToStringTerminator();
      return true;
    }

    // Get the query code (one or more chars)
    // Consume bytes until we hit ST (string terminator) or escape
    final queryChars = <int>[];
    while (_queue.isNotEmpty) {
      final c = _queue.consume();
      if (c == 0 || c == 27 || c == 0x1b) {
        // Rollback the escape sequence start
        _queue.rollback(1);
        break;
      }
      queryChars.add(c);
    }
    final query = String.fromCharCodes(queryChars);

    // Handle the query
    handler.handleDcs('+q$query', [], null);
    return true;
  }

  /// Handle APC (Application Program Command) sequences
  /// Used by Kitty Graphics Protocol: ESC _ G <args> ; <payload> ST
  bool _escHandleAPC() {
    if (_queue.isEmpty) return false;

    final command = _queue.consume();
    // Kitty Graphics Protocol uses 'G'
    if (command != 'G'.codeUnitAt(0)) {
      // Unknown APC command, skip until ST
      _skipToStringTerminator();
      return true;
    }

    return _handleKittyGraphics();
  }

  /// Handle Kitty Graphics Protocol sequence
  bool _handleKittyGraphics() {
    // Parse key-value pairs until we hit ';' (payload start) or ST
    final args = _parseGraphicsArgs();

    // Check if this is a chunked transmission (m=1 means more chunks coming)
    final moreFlag = args['m'];

    // Notify handler that graphics command is starting
    handler.graphicsCommandStart(args);

    // If m=1, this is not the final chunk - just acknowledge and return
    // The handler will wait for more chunks
    if (moreFlag == '1') {
      return true;
    }

    // Parse payload (Base64 encoded data)
    final payloadBytes = _parseGraphicsPayload();
    if (payloadBytes.isNotEmpty) {
      handler.graphicsDataChunk(payloadBytes);
    }

    handler.graphicsCommandEnd();
    return true;
  }

  /// Parse graphics key-value arguments
  Map<String, String> _parseGraphicsArgs() {
    final args = <String, String>{};
    final keyBuffer = StringBuffer();
    final valueBuffer = StringBuffer();
    var inKey = true;

    while (_queue.isNotEmpty) {
      final char = _queue.consume();

      // End of arguments, start of payload
      if (char == Ascii.semicolon) {
        break;
      }

      // String terminator - end of sequence (ESC \)
      if (char == Ascii.ESC) {
        if (_queue.isNotEmpty && _queue.peek() == Ascii.backslash) {
          _queue.consume(); // Consume backslash
          break;
        }
      }

      if (char == 61) {
        // =
        inKey = false;
        continue;
      }

      if (char == Ascii.comma) {
        // Save current key-value pair
        if (keyBuffer.isNotEmpty) {
          args[keyBuffer.toString()] = valueBuffer.toString();
        }
        keyBuffer.clear();
        valueBuffer.clear();
        inKey = true;
        continue;
      }

      if (inKey) {
        keyBuffer.writeCharCode(char);
      } else {
        valueBuffer.writeCharCode(char);
      }
    }

    // Save last key-value pair
    if (keyBuffer.isNotEmpty) {
      args[keyBuffer.toString()] = valueBuffer.toString();
    }

    return args;
  }

  /// Parse graphics payload (Base64 encoded)
  List<int> _parseGraphicsPayload() {
    final payloadBuffer = StringBuffer();

    while (_queue.isNotEmpty) {
      final char = _queue.consume();

      // ST (String Terminator) - ESC \
      if (char == Ascii.ESC) {
        if (_queue.isNotEmpty && _queue.peek() == Ascii.backslash) {
          _queue.consume(); // Consume backslash
          break;
        }
        // ESC alone terminates
        break;
      }

      // BEL also terminates
      if (char == Ascii.BEL) {
        break;
      }

      payloadBuffer.writeCharCode(char);
    }

    if (payloadBuffer.isEmpty) {
      return [];
    }

    // Decode Base64
    return _base64Decode(payloadBuffer.toString());
  }

  /// Skip to string terminator (ST = ESC \)
  void _skipToStringTerminator() {
    while (_queue.isNotEmpty) {
      final char = _queue.consume();
      if (char == Ascii.ESC &&
          _queue.isNotEmpty &&
          _queue.peek() == Ascii.backslash) {
        _queue.consume();
        break;
      }
      if (char == Ascii.BEL) {
        break;
      }
    }
  }

  /// Decode Base64 string to bytes
  List<int> _base64Decode(String input) {
    // Remove any whitespace
    final cleaned = input.replaceAll(RegExp(r'\s'), '');
    if (cleaned.isEmpty) {
      return [];
    }
    final decoder = Base64Decoder();
    return decoder.convert(cleaned);
  }

  final _osc = <String>[];

  bool _consumeOsc() {
    _osc.clear();
    final param = StringBuffer();

    while (true) {
      if (_queue.isEmpty) {
        return false;
      }

      final char = _queue.consume();

      // OSC terminates with BEL
      if (char == Ascii.BEL) {
        _osc.add(param.toString());
        return true;
      }

      /// OSC terminates with ST
      if (char == Ascii.ESC) {
        if (_queue.isEmpty) {
          return false;
        }

        if (_queue.consume() == Ascii.backslash) {
          _osc.add(param.toString());
        }

        return true;
      }

      /// Parse next parameter
      if (char == Ascii.semicolon) {
        _osc.add(param.toString());
        param.clear();
        continue;
      }

      param.writeCharCode(char);
    }
  }
}

class _Csi {
  _Csi({
    required this.params,
    required this.finalByte,
    // required this.intermediates,
  });

  int? prefix;

  List<int> params;

  int finalByte;
  // final List<int> intermediates;

  @override
  String toString() {
    return params.join(';') + String.fromCharCode(finalByte);
  }
}

/// Function that handles a sequence of characters that starts with an escape.
/// Returns [true] if the sequence was processed, [false] if it was not.
typedef _EscHandler = bool Function();

typedef _SbcHandler = void Function();

typedef _CsiHandler = void Function();
