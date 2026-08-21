import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:kitty_protocol/kitty_protocol.dart';
import 'package:kterm/src/core/buffer/cell_offset.dart';
import 'package:kterm/src/core/input/keys.dart';
import 'package:kterm/src/terminal.dart';
import 'package:kterm/src/ui/controller.dart';
import 'package:kterm/src/ui/cursor_type.dart';
import 'package:kterm/src/ui/custom_text_edit.dart';
import 'package:kterm/src/ui/gesture/gesture_handler.dart';
import 'package:kterm/src/ui/input_map.dart';
import 'package:kterm/src/ui/keyboard_listener.dart';
import 'package:kterm/src/ui/keyboard_visibility.dart';
import 'package:kterm/src/ui/render.dart';
import 'package:kterm/src/ui/scroll_handler.dart';
import 'package:kterm/src/ui/search_bar.dart';
import 'package:kterm/src/ui/shortcut/actions.dart';
import 'package:kterm/src/ui/shortcut/shortcuts.dart';
import 'package:kterm/src/ui/terminal_text_style.dart';
import 'package:kterm/src/ui/terminal_theme.dart';
import 'package:kterm/src/ui/themes.dart';

class TerminalView extends StatefulWidget {
  const TerminalView(
    this.terminal, {
    super.key,
    this.controller,
    this.theme = TerminalThemes.dark,
    this.textStyle = const TerminalStyle(),
    this.textScaler,
    this.padding,
    this.scrollController,
    this.autoResize = true,
    this.backgroundOpacity = 1,
    this.focusNode,
    this.autofocus = false,
    this.onTapUp,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.mouseCursor = SystemMouseCursors.text,
    this.keyboardType = TextInputType.emailAddress,
    this.keyboardAppearance = Brightness.dark,
    this.cursorType = TerminalCursorType.block,
    this.alwaysShowCursor = false,
    this.deleteDetection = false,
    this.shortcuts,
    this.onKeyEvent,
    this.readOnly = false,
    this.hardwareKeyboardOnly = false,
    this.simulateScroll = true,
    this.showSearchBar = false,
    this.onSendToAi,
    this.externalCtrl,
    this.externalAlt,
  });

  /// Optional callback when user clicks "Send to AI" in text selection popup.
  final void Function(String text)? onSendToAi;

  /// The underlying terminal that this widget renders.
  final Terminal terminal;

  final TerminalController? controller;

  /// The theme to use for this terminal.
  final TerminalTheme theme;

  /// The style to use for painting characters.
  final TerminalStyle textStyle;

  final TextScaler? textScaler;

  /// Padding around the inner [Scrollable] widget.
  final EdgeInsets? padding;

  /// Scroll controller for the inner [Scrollable] widget.
  final ScrollController? scrollController;

  /// Should this widget automatically notify the underlying terminal when its
  /// size changes. [true] by default.
  final bool autoResize;

  /// Opacity of the terminal background. Set to 0 to make the terminal
  /// background transparent.
  final double backgroundOpacity;

  /// An optional focus node to use as the focus node for this widget.
  final FocusNode? focusNode;

  /// True if this widget will be selected as the initial focus when no other
  /// node in its scope is currently focused.
  final bool autofocus;

  /// Callback for when the user taps on the terminal.
  final void Function(TapUpDetails, CellOffset)? onTapUp;

  /// Function called when the user taps on the terminal with a secondary
  /// button.
  final void Function(TapDownDetails, CellOffset)? onSecondaryTapDown;

  /// Function called when the user stops holding down a secondary button.
  final void Function(TapUpDetails, CellOffset)? onSecondaryTapUp;

  /// The mouse cursor for mouse pointers that are hovering over the terminal.
  /// [SystemMouseCursors.text] by default.
  final MouseCursor mouseCursor;

  /// The type of information for which to optimize the text input control.
  /// [TextInputType.emailAddress] by default.
  final TextInputType keyboardType;

  /// The appearance of the keyboard. [Brightness.dark] by default.
  ///
  /// This setting is only honored on iOS devices.
  final Brightness keyboardAppearance;

  /// The type of cursor to use. [TerminalCursorType.block] by default.
  final TerminalCursorType cursorType;

  /// Whether to always show the cursor. This is useful for debugging.
  /// [false] by default.
  final bool alwaysShowCursor;

  /// Workaround to detect delete key for platforms and IMEs that does not
  /// emit hardware delete event. Prefered on mobile platforms. [false] by
  /// default.
  final bool deleteDetection;

  /// Shortcuts for this terminal. This has higher priority than input handler
  /// of the terminal If not provided, [defaultTerminalShortcuts] will be used.
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// Keyboard event handler of the terminal. This has higher priority than
  /// [shortcuts] and input handler of the terminal.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// True if no input should send to the terminal.
  final bool readOnly;

  /// True if only hardware keyboard events should be used as input. This will
  /// also prevent any on-screen keyboard to be shown.
  final bool hardwareKeyboardOnly;

  /// If true, when the terminal is in alternate buffer (for example running
  /// vim, man, etc), if the application does not declare that it can handle
  /// scrolling, the terminal will simulate scrolling by sending up/down arrow
  /// keys to the application. This is standard behavior for most terminal
  /// emulators. True by default.
  final bool simulateScroll;

  /// If true, shows a search bar above the terminal and enables search
  /// keyboard shortcuts (Ctrl+F / Cmd+F to open, F3 to find next,
  /// Shift+F3 to find previous, Escape to close).
  /// Default is false.
  final bool showSearchBar;

  /// External sticky Ctrl modifier state.
  /// When `value` is true, the next character from the software keyboard
  /// will be converted to a Ctrl+char control code and the notifier
  /// will be reset to false automatically.
  final ValueNotifier<bool>? externalCtrl;

  /// External sticky Alt modifier state.
  /// When `value` is true, the next character will be prefixed with ESC
  /// and the notifier will be reset to false automatically.
  final ValueNotifier<bool>? externalAlt;

  @override
  State<TerminalView> createState() => TerminalViewState();
}

class TerminalViewState extends State<TerminalView> {
  late FocusNode _focusNode;

  late final ShortcutManager _shortcutManager;

  final _customTextEditKey = GlobalKey<CustomTextEditState>();

  final _scrollableKey = GlobalKey<ScrollableState>();

  final _viewportKey = GlobalKey();

  String? _composingText;

  late TerminalController _controller;

  late ScrollController _scrollController;

  bool _showSearchBar = false;

  RenderTerminal get renderTerminal =>
      _viewportKey.currentContext!.findRenderObject() as RenderTerminal;

  ScrollController get scrollController => _scrollController;

  @override
  void initState() {
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TerminalController();
    _scrollController = widget.scrollController ?? ScrollController();
    _shortcutManager = ShortcutManager(
      shortcuts: widget.shortcuts ?? defaultTerminalShortcuts,
    );
    _showSearchBar = widget.showSearchBar;

    // Setup search callbacks
    _controller.onGetText = () => widget.terminal.buffer.getText();
    _controller.onCreateAnchor = (offset) {
      return widget.terminal.buffer.createAnchorFromOffset(offset);
    };

    super.initState();
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
    }
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _controller = widget.controller ?? TerminalController();
    }
    if (oldWidget.scrollController != widget.scrollController) {
      if (oldWidget.scrollController == null) {
        _scrollController.dispose();
      }
      _scrollController = widget.scrollController ?? ScrollController();
    }
    _shortcutManager.shortcuts = widget.shortcuts ?? defaultTerminalShortcuts;
    if (oldWidget.showSearchBar != widget.showSearchBar) {
      _showSearchBar = widget.showSearchBar;
      if (!_showSearchBar) {
        _controller.closeSearch();
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    _shortcutManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Scrollbar(
      controller: _scrollController,
      child: Scrollable(
        key: _scrollableKey,
        controller: _scrollController,
        viewportBuilder: (context, offset) {
          return _TerminalView(
            key: _viewportKey,
            terminal: widget.terminal,
            controller: _controller,
            offset: offset,
            padding: MediaQuery.of(context).padding,
            autoResize: widget.autoResize,
            textStyle: widget.textStyle,
            textScaler: widget.textScaler ?? MediaQuery.textScalerOf(context),
            theme: widget.theme,
            focusNode: _focusNode,
            cursorType: widget.cursorType,
            alwaysShowCursor: widget.alwaysShowCursor,
            onEditableRect: _onEditableRect,
            composingText: _composingText,
          );
        },
      ),
    );

    child = TerminalScrollGestureHandler(
      terminal: widget.terminal,
      simulateScroll: widget.simulateScroll,
      getCellOffset: (offset) => renderTerminal.getCellOffset(offset),
      getLineHeight: () => renderTerminal.lineHeight,
      child: child,
    );

    if (!widget.hardwareKeyboardOnly) {
      child = CustomTextEdit(
        key: _customTextEditKey,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        inputType: widget.keyboardType,
        keyboardAppearance: widget.keyboardAppearance,
        deleteDetection: widget.deleteDetection,
        onInsert: _onInsert,
        onDelete: () {
          _scrollToBottom();
          widget.terminal.keyInput(TerminalKey.backspace);
        },
        onComposing: _onComposing,
        onAction: (action) {
          _scrollToBottom();
          // Android sends TextInputAction.newline when the user presses the virtual keyboard's enter key.
          if (action == TextInputAction.done ||
              action == TextInputAction.newline) {
            widget.terminal.keyInput(TerminalKey.enter);
          }
        },
        onKeyEvent: _handleKeyEvent,
        onRequestRect: _onRequestRect,
        readOnly: widget.readOnly,
        child: child,
      );
    } else if (!widget.readOnly) {
      // Only listen for key input from a hardware keyboard.
      child = CustomKeyboardListener(
        child: child,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onInsert: _onInsert,
        onComposing: _onComposing,
        onKeyEvent: _handleKeyEvent,
      );
    }

    child = TerminalActions(
      terminal: widget.terminal,
      controller: _controller,
      child: child,
    );

    child = KeyboardVisibilty(onKeyboardShow: _onKeyboardShow, child: child);

    child = TerminalGestureHandler(
      terminalView: this,
      terminalController: _controller,
      onTapUp: _onTapUp,
      onSingleTapUp: _onTapUp,
      onTapDown: _onTapDown,
      onSecondaryTapDown:
          widget.onSecondaryTapDown != null ? _onSecondaryTapDown : null,
      onSecondaryTapUp:
          widget.onSecondaryTapUp != null ? _onSecondaryTapUp : null,
      readOnly: widget.readOnly,
      child: child,
    );

    child = MouseRegion(cursor: widget.mouseCursor, child: child);

    child = Container(
      color: widget.theme.background.withValues(
        alpha: widget.backgroundOpacity,
      ),
      padding: widget.padding,
      child: child,
    );

    child = Stack(
      children: [
        child,
        _TerminalSelectionOverlay(
          terminalView: this,
          controller: _controller,
          terminal: widget.terminal,
          onSendToAi: widget.onSendToAi,
        ),
      ],
    );

    // Add search bar if enabled
    if (_showSearchBar) {
      child = Stack(
        children: [
          child,
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (_controller.isSearching) {
                return Positioned(
                  top: 8,
                  right: 24,
                  child: SizedBox(
                    width: 380,
                    child: TerminalSearchBar(
                      controller: _controller,
                      onClose: () {
                        _controller.closeSearch();
                      },
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      );
    }

    // Wrap with keyboard shortcuts handler for search
    if (_showSearchBar) {
      child = CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          // Ctrl+F / Cmd+F - Open search
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
            _controller.openSearch();
          },
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
            _controller.openSearch();
          },
          // F3 - Next match
          const SingleActivator(LogicalKeyboardKey.f3): () {
            _controller.searchNext();
          },
          // Shift+F3 - Previous match
          const SingleActivator(LogicalKeyboardKey.f3, shift: true): () {
            _controller.searchPrevious();
          },
          // Cmd+G - Next match (macOS)
          const SingleActivator(LogicalKeyboardKey.keyG, meta: true): () {
            _controller.searchNext();
          },
          // Cmd+Shift+G - Previous match (macOS)
          const SingleActivator(
            LogicalKeyboardKey.keyG,
            meta: true,
            shift: true,
          ): () {
            _controller.searchPrevious();
          },
        },
        child: Focus(autofocus: false, child: child),
      );
    }

    return child;
  }

  void requestKeyboard() {
    _customTextEditKey.currentState?.requestKeyboard();
  }

  void closeKeyboard() {
    _customTextEditKey.currentState?.closeKeyboard();
  }

  Rect get cursorRect {
    return renderTerminal.cursorOffset & renderTerminal.cellSize;
  }

  Rect get globalCursorRect {
    return renderTerminal.localToGlobal(renderTerminal.cursorOffset) &
        renderTerminal.cellSize;
  }

  void _onTapUp(TapUpDetails details) {
    if (_controller.selection != null) {
      _controller.clearSelection();
    } else {
      if (!widget.hardwareKeyboardOnly) {
        _customTextEditKey.currentState?.requestKeyboard();
      } else {
        _focusNode.requestFocus();
      }
    }
    final offset = renderTerminal.getCellOffset(details.localPosition);
    widget.onTapUp?.call(details, offset);
  }

  void _onTapDown(_) {}

  void _onSecondaryTapDown(TapDownDetails details) {
    final offset = renderTerminal.getCellOffset(details.localPosition);
    widget.onSecondaryTapDown?.call(details, offset);
  }

  void _onSecondaryTapUp(TapUpDetails details) {
    final offset = renderTerminal.getCellOffset(details.localPosition);
    widget.onSecondaryTapUp?.call(details, offset);
  }

  bool get hasInputConnection {
    return _customTextEditKey.currentState?.hasInputConnection == true;
  }

  void _onInsert(String text) {
    // Check external sticky modifiers (from Extra Keys bar).
    final ctrlActive = widget.externalCtrl?.value ?? false;
    final altActive = widget.externalAlt?.value ?? false;

    // Reset sticky modifiers once input is received
    if (ctrlActive) widget.externalCtrl?.value = false;
    if (altActive) widget.externalAlt?.value = false;

    final trimmed = text.trim();

    if (ctrlActive) {
      final ctrlCode = ctrlCodeForInsert(text);
      if (ctrlCode != null) {
        widget.terminal.textInput(ctrlCode);
        _scrollToBottom();
        return;
      }
    }

    if (altActive && trimmed.isNotEmpty) {
      // Alt + char: send ESC prefix
      widget.terminal.textInput('\x1b$trimmed');
      _scrollToBottom();
      return;
    }

    final key = charToTerminalKey(trimmed);

    // On mobile platforms there is no guarantee that virtual keyboard will
    // generate hardware key events. So we need first try to send the key
    // as a hardware key event. If it fails, then we send it as a text input.
    final consumed = key == null ? false : widget.terminal.keyInput(key);

    if (!consumed) {
      widget.terminal.textInput(text);
    }

    _scrollToBottom();
  }

  void _onComposing(String? text) {
    setState(() => _composingText = text);
  }

  KeyEventResult _handleKeyEvent(FocusNode focusNode, KeyEvent event) {
    final resultOverride = widget.onKeyEvent?.call(focusNode, event);
    if (resultOverride != null && resultOverride != KeyEventResult.ignored) {
      return resultOverride;
    }

    // Intercept search shortcuts if search bar is enabled
    if (_showSearchBar) {
      final isControlPressed = HardwareKeyboard.instance.isControlPressed;
      final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        // Ctrl+F / Cmd+F
        if (event.logicalKey == LogicalKeyboardKey.keyF &&
            (isControlPressed || isMetaPressed)) {
          _controller.openSearch();
          return KeyEventResult.handled;
        }
        // F3 / Shift+F3
        if (event.logicalKey == LogicalKeyboardKey.f3) {
          if (isShiftPressed) {
            _controller.searchPrevious();
          } else {
            _controller.searchNext();
          }
          return KeyEventResult.handled;
        }
        // Cmd+G / Cmd+Shift+G (macOS)
        if (event.logicalKey == LogicalKeyboardKey.keyG && isMetaPressed) {
          if (isShiftPressed) {
            _controller.searchPrevious();
          } else {
            _controller.searchNext();
          }
          return KeyEventResult.handled;
        }
      } else if (event is KeyUpEvent) {
        if ((event.logicalKey == LogicalKeyboardKey.keyF &&
                (isControlPressed || isMetaPressed)) ||
            event.logicalKey == LogicalKeyboardKey.f3 ||
            (event.logicalKey == LogicalKeyboardKey.keyG && isMetaPressed)) {
          return KeyEventResult.handled;
        }
      }
    }

    // Intercept with Kitty keyboard protocol if enabled
    if (widget.terminal.kittyMode) {
      // Check if any modifiers are pressed
      final keyboard = HardwareKeyboard.instance;
      final hasModifiers = keyboard.isShiftPressed ||
          keyboard.isControlPressed ||
          keyboard.isAltPressed ||
          keyboard.isMetaPressed;

      // Determine if this is a special key (Enter, Tab, Backspace, Space, Arrows)
      final isSpecialKey = _isSpecialKey(event.logicalKey);

      // Handle KeyUp events in Kitty mode - only encode if reportAllKeysAsEscape or modifiers
      if (event is KeyUpEvent) {
        // Only send KeyUp encoding when:
        // 1. reportAllKeysAsEscape is true, OR
        // 2. Modifiers are pressed
        // Otherwise, ignore KeyUp to avoid duplicate output
        final shouldEncodeKeyUp =
            widget.terminal.kittyEncoder.flags.reportAllKeysAsEscape ||
                hasModifiers;

        if (shouldEncodeKeyUp) {
          final seq = _encodeWithKitty(event);
          if (seq != null) {
            widget.terminal.onOutput?.call(seq);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      }

      // Only use Kitty encoding for:
      // 1. Special keys with modifiers (Shift+Enter, Ctrl+Tab, etc.)
      // 2. When reportAll enabled
      // For alphanumeric keys (like 'A'), always let IME handleKeysAsEscape is them
      final shouldUseKittyEncoding = hasModifiers
          ? isSpecialKey // Modifier + special key → Kitty
          : widget
              .terminal.kittyEncoder.flags.reportAllKeysAsEscape; // No modifier

      if (shouldUseKittyEncoding) {
        final seq = _encodeWithKitty(event);
        if (seq != null && seq.isNotEmpty) {
          widget.terminal.onOutput?.call(seq);
          return KeyEventResult.handled;
        }
      }

      // Default Mode:
      // - Bare Tab/Enter/Backspace: send standard ASCII directly
      // - Alphanumeric keys: let Flutter IME handle them
      // - Only send Kitty encoding if reportAllKeysAsEscape is true OR modifiers pressed
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        // Check if we should use Kitty encoding or standard handling
        // Kitty encoding should only be used when:
        // 1. reportAllKeysAsEscape is true, OR
        // 2. Modifiers are pressed
        // Otherwise, use standard character input
        final useKittyEncoding =
            widget.terminal.kittyEncoder.flags.reportAllKeysAsEscape ||
                hasModifiers;

        if (!useKittyEncoding) {
          // Use standard character input for bare keys
          if (event.logicalKey == LogicalKeyboardKey.tab) {
            widget.terminal.textInput('\t');
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            widget.terminal.textInput('\r');
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            widget.terminal.textInput('\x7f');
            return KeyEventResult.handled;
          }
          // For alphanumeric keys, let Flutter's TextInputClient handle them
          return KeyEventResult.ignored;
        }

        // Get the Kitty encoding
        final seq = _encodeWithKitty(event);
        if (seq != null && seq.isNotEmpty) {
          // Send the Kitty encoding
          widget.terminal.onOutput?.call(seq);
          return KeyEventResult.handled;
        }

        // Fallback if Kitty encoding is empty
        return KeyEventResult.ignored;
      }

      // For alphanumeric keys, let Flutter's TextInputClient handle them
      return KeyEventResult.ignored;
    }

    // ignore: invalid_use_of_protected_member
    final shortcutResult = _shortcutManager.handleKeypress(
      focusNode.context!,
      event,
    );

    if (shortcutResult != KeyEventResult.ignored) {
      return shortcutResult;
    }

    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    final key = keyToTerminalKey(event.logicalKey);

    if (key == null) {
      return KeyEventResult.ignored;
    }

    final handled = widget.terminal.keyInput(
      key,
      ctrl: HardwareKeyboard.instance.isControlPressed,
      alt: HardwareKeyboard.instance.isAltPressed,
      shift: HardwareKeyboard.instance.isShiftPressed,
    );

    if (handled) {
      _scrollToBottom();
    }

    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _onKeyboardShow() {
    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _onEditableRect(Rect rect, Rect caretRect, Matrix4 transform) {
    _customTextEditKey.currentState
        ?.setEditableRect(rect, caretRect, transform);
  }

  void _onRequestRect() {
    if (!_customTextEditKey.currentState!.hasInputConnection) return;
    final render = renderTerminal;
    if (render.size.isEmpty) return;
    final rect = Offset.zero & render.size;
    final caretRect = render.cursorOffset & render.cellSize;
    final transform = render.getTransformTo(null);
    _onEditableRect(rect, caretRect, transform);
  }

  void _scrollToBottom() {
    final position = _scrollableKey.currentState?.position;
    if (position != null) {
      position.jumpTo(position.maxScrollExtent);
    }
  }

  /// Check if the key is a special key (Enter, Tab, Backspace, Space, Arrows, etc.)
  bool _isSpecialKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.f1 ||
        key == LogicalKeyboardKey.f2 ||
        key == LogicalKeyboardKey.f3 ||
        key == LogicalKeyboardKey.f4 ||
        key == LogicalKeyboardKey.f5 ||
        key == LogicalKeyboardKey.f6 ||
        key == LogicalKeyboardKey.f7 ||
        key == LogicalKeyboardKey.f8 ||
        key == LogicalKeyboardKey.f9 ||
        key == LogicalKeyboardKey.f10 ||
        key == LogicalKeyboardKey.f11 ||
        key == LogicalKeyboardKey.f12 ||
        key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.insert ||
        key == LogicalKeyboardKey.home ||
        key == LogicalKeyboardKey.end ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown;
  }

  String? _encodeWithKitty(KeyEvent event) {
    // Handle KeyUp events - encode them to signal key release
    final isKeyUp = event is KeyUpEvent;

    if (isKeyUp || event is KeyDownEvent || event is KeyRepeatEvent) {
      final modifiers = <SimpleModifier>{};
      final keyboard = HardwareKeyboard.instance;

      if (keyboard.isShiftPressed) modifiers.add(SimpleModifier.shift);
      if (keyboard.isControlPressed) modifiers.add(SimpleModifier.control);
      if (keyboard.isAltPressed) modifiers.add(SimpleModifier.alt);
      if (keyboard.isMetaPressed) modifiers.add(SimpleModifier.meta);

      final keyEvent = SimpleKeyEvent(
        logicalKey: event.logicalKey,
        modifiers: modifiers,
        isKeyUp: isKeyUp,
        isKeyRepeat: event is KeyRepeatEvent,
      );

      return widget.terminal.kittyEncoder.encode(keyEvent);
    }
    return null;
  }
}

class _TerminalView extends LeafRenderObjectWidget {
  const _TerminalView({
    super.key,
    required this.terminal,
    required this.controller,
    required this.offset,
    required this.padding,
    required this.autoResize,
    required this.textStyle,
    required this.textScaler,
    required this.theme,
    required this.focusNode,
    required this.cursorType,
    required this.alwaysShowCursor,
    this.onEditableRect,
    this.composingText,
  });

  final Terminal terminal;

  final TerminalController controller;

  final ViewportOffset offset;

  final EdgeInsets padding;

  final bool autoResize;

  final TerminalStyle textStyle;

  final TextScaler textScaler;

  final TerminalTheme theme;

  final FocusNode focusNode;

  final TerminalCursorType cursorType;

  final bool alwaysShowCursor;

  final EditableRectCallback? onEditableRect;

  final String? composingText;

  @override
  RenderTerminal createRenderObject(BuildContext context) {
    return RenderTerminal(
      terminal: terminal,
      controller: controller,
      offset: offset,
      padding: padding,
      autoResize: autoResize,
      textStyle: textStyle,
      textScaler: textScaler,
      theme: theme,
      focusNode: focusNode,
      cursorType: cursorType,
      alwaysShowCursor: alwaysShowCursor,
      onEditableRect: onEditableRect,
      composingText: composingText,
      graphicsManager: terminal.graphicsManager,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderTerminal renderObject) {
    renderObject
      ..terminal = terminal
      ..controller = controller
      ..offset = offset
      ..padding = padding
      ..autoResize = autoResize
      ..textStyle = textStyle
      ..textScaler = textScaler
      ..theme = theme
      ..focusNode = focusNode
      ..cursorType = cursorType
      ..alwaysShowCursor = alwaysShowCursor
      ..onEditableRect = onEditableRect
      ..composingText = composingText;
  }
}

class _TerminalSelectionOverlay extends StatelessWidget {
  final TerminalViewState terminalView;
  final TerminalController controller;
  final Terminal terminal;
  final void Function(String text)? onSendToAi;

  const _TerminalSelectionOverlay({
    required this.terminalView,
    required this.controller,
    required this.terminal,
    this.onSendToAi,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selection = controller.selection;
        if (selection == null || selection.isCollapsed) {
          return const SizedBox.shrink();
        }

        final normalized = selection.normalized;
        RenderTerminal renderTerminal;
        try {
          renderTerminal = terminalView.renderTerminal;
        } catch (_) {
          return const SizedBox.shrink();
        }

        if (renderTerminal.size.isEmpty) {
          return const SizedBox.shrink();
        }

        final lineHeight = renderTerminal.lineHeight;
        final beginOffset = renderTerminal.getOffset(normalized.begin);
        final endOffset = renderTerminal.getOffset(normalized.end);

        final viewportHeight = renderTerminal.size.height;
        final viewportWidth = renderTerminal.size.width;

        final isBeginVisible =
            beginOffset.dy >= -lineHeight && beginOffset.dy <= viewportHeight;
        final isEndVisible =
            endOffset.dy >= -lineHeight && endOffset.dy <= viewportHeight;

        final controls = MaterialTextSelectionControls();

        // Calculate position for floating selection toolbar (Copy / Send)
        final topY =
            beginOffset.dy < endOffset.dy ? beginOffset.dy : endOffset.dy;
        final bottomY =
            (beginOffset.dy > endOffset.dy ? beginOffset.dy : endOffset.dy) +
                lineHeight;
        final centerX = (beginOffset.dx + endOffset.dx) / 2;

        double toolbarTop = topY - 44;
        if (toolbarTop < 8) {
          toolbarTop = bottomY + 24;
        }
        final toolbarLeft = (centerX - 90).clamp(8.0, viewportWidth - 190.0);

        return Stack(
          children: [
            // Floating Selection Toolbar (Copy / Send Terminal / Send AI)
            Positioned(
              left: toolbarLeft,
              top: toolbarTop,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Copy button
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final sel = controller.selection;
                          if (sel != null) {
                            final text = terminal.buffer.getText(sel);
                            await Clipboard.setData(ClipboardData(text: text));
                            controller.clearSelection();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('已复制'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy, size: 14),
                              SizedBox(width: 3),
                              Text(
                                '复制',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        height: 14,
                        width: 1,
                        color: Theme.of(context).dividerColor,
                      ),

                      // 2. Send to Terminal (pastes text and triggers Enter key to execute)
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          final sel = controller.selection;
                          if (sel != null) {
                            final text = terminal.buffer.getText(sel).trim();
                            if (text.isNotEmpty) {
                              terminal.paste(text);
                              terminal.keyInput(TerminalKey.enter);
                            }
                            controller.clearSelection();
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.terminal, size: 14),
                              SizedBox(width: 3),
                              Text(
                                '终端',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        height: 14,
                        width: 1,
                        color: Theme.of(context).dividerColor,
                      ),

                      // 3. Send to AI Chat
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          final sel = controller.selection;
                          if (sel != null) {
                            final text = terminal.buffer.getText(sel);
                            controller.clearSelection();
                            onSendToAi?.call(text);
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.smart_toy_outlined, size: 14),
                              SizedBox(width: 3),
                              Text(
                                '发送AI',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isBeginVisible)
              Positioned(
                left: (beginOffset.dx - 22.0 - 10.0)
                    .clamp(-10.0, viewportWidth - 32.0),
                top: beginOffset.dy + lineHeight - 10.0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) =>
                      _updateSelectionBegin(details.globalPosition),
                  onPanUpdate: (details) =>
                      _updateSelectionBegin(details.globalPosition),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: controls.buildHandle(
                      context,
                      TextSelectionHandleType.left,
                      lineHeight,
                    ),
                  ),
                ),
              ),
            if (isEndVisible)
              Positioned(
                left: (endOffset.dx - 10.0).clamp(-10.0, viewportWidth - 32.0),
                top: endOffset.dy + lineHeight - 10.0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) =>
                      _updateSelectionEnd(details.globalPosition),
                  onPanUpdate: (details) =>
                      _updateSelectionEnd(details.globalPosition),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: controls.buildHandle(
                      context,
                      TextSelectionHandleType.right,
                      lineHeight,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _updateSelectionBegin(Offset globalPosition) {
    try {
      final renderTerminal = terminalView.renderTerminal;
      final localOffset = renderTerminal.globalToLocal(globalPosition);
      final adjustedOffset = Offset(
        localOffset.dx,
        localOffset.dy - renderTerminal.lineHeight / 2,
      );
      final newCell = renderTerminal.getCellOffset(adjustedOffset);
      final selection = controller.selection;
      if (selection != null) {
        controller.setSelection(
          terminal.buffer.createAnchorFromOffset(newCell),
          terminal.buffer.createAnchorFromOffset(selection.normalized.end),
        );
      }
    } catch (_) {}
  }

  void _updateSelectionEnd(Offset globalPosition) {
    try {
      final renderTerminal = terminalView.renderTerminal;
      final localOffset = renderTerminal.globalToLocal(globalPosition);
      final adjustedOffset = Offset(
        localOffset.dx,
        localOffset.dy - renderTerminal.lineHeight / 2,
      );
      final newCell = renderTerminal.getCellOffset(adjustedOffset);
      final selection = controller.selection;
      if (selection != null) {
        controller.setSelection(
          terminal.buffer.createAnchorFromOffset(selection.normalized.begin),
          terminal.buffer.createAnchorFromOffset(newCell),
        );
      }
    } catch (_) {}
  }
}
