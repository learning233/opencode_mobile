import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kterm/src/terminal.dart';
import 'package:kterm/src/ui/controller.dart';
import 'package:kterm/src/ui/selection_mode.dart';
import 'shortcuts.dart';

class TerminalActions extends StatelessWidget {
  const TerminalActions({
    super.key,
    required this.terminal,
    required this.controller,
    required this.child,
  });

  final Terminal terminal;

  final TerminalController controller;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        PasteTextIntent: CallbackAction<PasteTextIntent>(
          onInvoke: (intent) async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final text = data?.text;
            if (text != null) {
              terminal.paste(text);
              controller.clearSelection();
            }
            return null;
          },
        ),
        CopySelectionTextIntent: CopySelectionAction(
          terminal: terminal,
          controller: controller,
        ),
        SendSelectionToPromptIntent: SendSelectionToPromptAction(
          terminal: terminal,
          controller: controller,
        ),
        SelectAllTextIntent: CallbackAction<SelectAllTextIntent>(
          onInvoke: (intent) {
            controller.setSelection(
              terminal.buffer.createAnchor(
                0,
                terminal.buffer.height - terminal.viewHeight,
              ),
              terminal.buffer.createAnchor(
                terminal.viewWidth,
                terminal.buffer.height - 1,
              ),
              mode: SelectionMode.line,
            );
            return null;
          },
        ),
      },
      child: child,
    );
  }
}

class CopySelectionAction extends Action<CopySelectionTextIntent> {
  CopySelectionAction({
    required this.terminal,
    required this.controller,
  });

  final Terminal terminal;
  final TerminalController controller;

  @override
  bool isEnabled(CopySelectionTextIntent intent) {
    return controller.selection != null;
  }

  @override
  Object? invoke(CopySelectionTextIntent intent) async {
    final selection = controller.selection;
    if (selection != null) {
      final text = terminal.buffer.getText(selection);
      await Clipboard.setData(ClipboardData(text: text));
    }
    return null;
  }
}

class SendSelectionToPromptAction extends Action<SendSelectionToPromptIntent> {
  SendSelectionToPromptAction({
    required this.terminal,
    required this.controller,
  });

  final Terminal terminal;
  final TerminalController controller;

  @override
  bool isEnabled(SendSelectionToPromptIntent intent) {
    return controller.selection != null &&
        controller.onSendSelectionToPrompt != null;
  }

  @override
  Object? invoke(SendSelectionToPromptIntent intent) {
    final selection = controller.selection;
    if (selection != null && controller.onSendSelectionToPrompt != null) {
      final text = terminal.buffer.getText(selection);
      controller.onSendSelectionToPrompt!(text);
      controller.clearSelection();
    }
    return null;
  }
}
