import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kterm/kterm.dart';
import '../../controllers/pty_controller.dart';
import '../../controllers/session_controller.dart';
import '../../models/pty_session.dart';
import '../../init.dart';
import '../../utils/layout_utils.dart';
import '../../utils/translations.dart';
import 'pty_indicator.dart';

/// Embeddable terminal body widget without Scaffold/AppBar.
/// Used both by the full-screen [TerminalPage] and the tablet tool panel.
class TerminalPanelBody extends StatefulWidget {
  /// If true, show a compact toolbar at the top (for embedded use).
  final bool showToolbar;

  const TerminalPanelBody({super.key, this.showToolbar = false});

  @override
  State<TerminalPanelBody> createState() => _TerminalPanelBodyState();
}

class _TerminalPanelBodyState extends State<TerminalPanelBody> {
  late PageController _pageController;
  Worker? _activePtyWorker;

  /// Shared sticky modifier state for the Termux extra keys bar.
  /// These are read by kterm's TerminalView in _onInsert to intercept
  /// the next software-keyboard character.
  final ValueNotifier<bool> _ctrlNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _altNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    final ptyCtrl = Get.find<PtyController>();

    // Fetch existing sessions from server on load, or create new if none exist
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ptyCtrl.fetchSessions();
    });

    final activeId = ptyCtrl.activePtyId.value;
    final opened = ptyCtrl.filteredSessions;
    final initialIdx = opened.indexWhere((s) => s.id == activeId);

    _pageController = PageController(
      initialPage: initialIdx != -1 ? initialIdx : 0,
    );

    _activePtyWorker = ever(ptyCtrl.activePtyId, (String activeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        final list = ptyCtrl.filteredSessions;
        final idx = list.indexWhere((s) => s.id == activeId);
        if (idx != -1 && _pageController.page?.round() != idx) {
          _pageController.animateToPage(
            idx,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _activePtyWorker?.dispose();
    _pageController.dispose();
    _ctrlNotifier.dispose();
    _altNotifier.dispose();
    super.dispose();
  }

  void _showSettingsSheet(BuildContext context, PtyController ptyCtrl) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.terminalSettings.tr,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Obx(() {
                  return Column(
                    children: [
                      SwitchListTile(
                        title: Text(LocaleKeys.terminalCurrentProjectOnly.tr),
                        subtitle: Text(
                          LocaleKeys.terminalCurrentProjectOnlyDesc.tr,
                        ),
                        value: ptyCtrl.filterCurrentProjectOnly.value,
                        onChanged: (val) {
                          ptyCtrl.setFilterCurrentProjectOnly(val);
                        },
                      ),
                      SwitchListTile(
                        title: Text(LocaleKeys.terminalShowExtraKeys.tr),
                        subtitle: Text(LocaleKeys.terminalShowExtraKeysDesc.tr),
                        value: Global.showTerminalExtraKeysRx.value,
                        onChanged: (val) {
                          Global.setShowTerminalExtraKeys(val);
                        },
                      ),
                      SwitchListTile(
                        title: Text(LocaleKeys.terminalShowQuickCommands.tr),
                        subtitle: Text(
                          LocaleKeys.terminalShowQuickCommandsDesc.tr,
                        ),
                        value: Global.showTerminalQuickCommandsRx.value,
                        onChanged: (val) {
                          Global.setShowTerminalQuickCommands(val);
                        },
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmCloseCurrent(BuildContext context, PtyController ptyCtrl) {
    final session = ptyCtrl.activeSession;
    if (session == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.terminalCloseCurrent.tr),
        content: Text(
          LocaleKeys.terminalConfirmClose.trParams({'title': session.title}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocaleKeys.cancel.tr),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ptyCtrl.closeTerminal(session.id);
            },
            child: Text(
              LocaleKeys.delete.tr,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchBottomSheet(BuildContext context, PtySession session) {
    session.controller.openSearch();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _TerminalSearchSheet(session: session),
    ).whenComplete(() {
      session.controller.closeSearch();
    });
  }

  void _handleSendToAi(BuildContext context, String selectedText) async {
    if (!Get.isRegistered<SessionController>()) return;
    final sessionCtrl = Get.find<SessionController>();

    final openIds = sessionCtrl.openedSessionIds.isNotEmpty
        ? sessionCtrl.openedSessionIds.toList()
        : sessionCtrl.sessions.map((s) => s.id).toList();

    if (openIds.isEmpty) {
      await sessionCtrl.createNewSession();
      final newId = sessionCtrl.activeSessionId.value;
      if (newId.isNotEmpty) {
        sessionCtrl.sendPrompt(selectedText, targetSessionId: newId);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocaleKeys.terminalSentToNewSession.tr),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    if (openIds.length == 1) {
      final targetId = openIds.first;
      sessionCtrl.sendPrompt(selectedText, targetSessionId: targetId);
      sessionCtrl.selectSession(targetId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocaleKeys.terminalSentToSession.trParams({
                'name': sessionCtrl.getSessionName(targetId),
              }),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    // Multiple AI sessions open -> Open BottomSheet with open sessions list
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  LocaleKeys.terminalSelectSession.tr,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: openIds.length,
                  itemBuilder: (context, index) {
                    final id = openIds[index];
                    final name = sessionCtrl.getSessionName(id);
                    final isActive = id == sessionCtrl.activeSessionId.value;

                    return ListTile(
                      leading: Icon(
                        Icons.chat_bubble_outline,
                        color: isActive
                            ? Theme.of(ctx).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isActive
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(ctx).colorScheme.primary,
                              size: 18,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        sessionCtrl.sendPrompt(
                          selectedText,
                          targetSessionId: id,
                        );
                        sessionCtrl.selectSession(id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              LocaleKeys.terminalSentToSession.trParams({
                                'name': name,
                              }),
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ptyCtrl = Get.find<PtyController>();
    final theme = Theme.of(context);

    return Obx(() {
      final sessions = ptyCtrl.filteredSessions;
      final activeId = ptyCtrl.activePtyId.value;
      final activeSession = ptyCtrl.activeSession;

      // Sync PageController if page index mismatch
      if (sessions.isNotEmpty &&
          _pageController.hasClients &&
          _pageController.positions.isNotEmpty) {
        final activeIdx = sessions.indexWhere((s) => s.id == activeId);
        if (activeIdx != -1) {
          int? currentPage;
          try {
            currentPage = _pageController.page?.round();
          } catch (_) {}
          if (currentPage != activeIdx) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients) {
                _pageController.jumpToPage(activeIdx);
              }
            });
          }
        }
      }

      return Column(
        children: [
          // Compact toolbar when embedded
          if (widget.showToolbar)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: PtyIndicator(
                      sessions: sessions,
                      activeId: activeId,
                      onTap: (id) => ptyCtrl.selectPty(id),
                    ),
                  ),
                  if (activeSession != null) ...[
                    IconButton(
                      icon: const Icon(Icons.search, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          _showSearchBottomSheet(context, activeSession),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark, size: 18),
                      tooltip: LocaleKeys.terminalCloseCurrent.tr,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmCloseCurrent(context, ptyCtrl),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(CupertinoIcons.add, size: 18),
                    tooltip: LocaleKeys.terminalNew.tr,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ptyCtrl.createTerminal(),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.settings, size: 18),
                    tooltip: LocaleKeys.terminalSettings.tr,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showSettingsSheet(context, ptyCtrl),
                  ),
                ],
              ),
            ),
          // Terminal content
          Expanded(
            child: _buildTerminalContent(
              ptyCtrl,
              sessions,
              activeId,
              activeSession,
              theme,
            ),
          ),
          if (sessions.isNotEmpty) ...[
            if (Global.showTerminalQuickCommandsRx.value)
              _QuickCommandBar(
                onTap: (cmd) => _runQuickCommand(context, cmd),
                onEdit: (cmd) => _showCommandDialog(context, initial: cmd),
                onAdd: () => _showCommandDialog(context),
              ),
            if (Global.showTerminalExtraKeysRx.value)
              _TermuxExtraKeysBar(
                onSendInput: (seq) => _sendTerminalInput(context, seq),
                ctrlNotifier: _ctrlNotifier,
                altNotifier: _altNotifier,
              ),
          ],
        ],
      );
    });
  }

  Widget _buildTerminalContent(
    PtyController ptyCtrl,
    List<PtySession> sessions,
    String activeId,
    PtySession? activeSession,
    ThemeData theme,
  ) {
    if (ptyCtrl.isLoading.value) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              LocaleKeys.terminalFetchingList.tr,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.terminal, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              LocaleKeys.terminalNoRunning.tr,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.terminalClickPlusToCreate.tr,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => ptyCtrl.createTerminal(),
              icon: const Icon(CupertinoIcons.add),
              label: Text(LocaleKeys.terminalNew.tr),
            ),
          ],
        ),
      );
    }

    if (activeSession == null) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: activeSession.controller,
      builder: (context, _) {
        final isSelecting = activeSession.controller.selection != null;
        return PageView.builder(
          controller: _pageController,
          physics: isSelecting
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          itemCount: sessions.length,
          onPageChanged: (idx) {
            if (idx >= 0 && idx < sessions.length) {
              ptyCtrl.selectPty(sessions[idx].id);
            }
          },
          itemBuilder: (context, index) {
            final session = sessions[index];

            return Obx(() {
              if (session.error.value) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_circle,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        LocaleKeys.mobileConnectionFailed.tr,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.errorMsg.value,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: () => ptyCtrl.reconnectPty(session),
                        child: Text(LocaleKeys.retry.tr),
                      ),
                    ],
                  ),
                );
              }

              if (!session.connected.value) {
                return const Center(child: CircularProgressIndicator());
              }

              return TerminalView(
                session.terminal,
                controller: session.controller,
                focusNode: session.focusNode,
                alwaysShowCursor: true,
                autofocus: false,
                autoResize: true,
                keyboardType: TextInputType.text,
                padding: const EdgeInsets.all(4),
                onSendToAi: (text) => _handleSendToAi(context, text),
                externalCtrl: _ctrlNotifier,
                externalAlt: _altNotifier,
              );
            });
          },
        );
      },
    );
  }
}

/// Full-screen terminal page with Scaffold wrapper.
/// Uses [TerminalPanelBody] internally.
class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  @override
  Widget build(BuildContext context) {
    final ptyCtrl = Get.find<PtyController>();

    return Obx(() {
      final sessions = ptyCtrl.filteredSessions;
      final activeId = ptyCtrl.activePtyId.value;
      final activeSession = ptyCtrl.activeSession;

      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(CupertinoIcons.settings),
            tooltip: LocaleKeys.terminalSettings.tr,
            onPressed: () => _showSettingsSheet(context, ptyCtrl),
          ),
          title: PtyIndicator(
            sessions: sessions,
            activeId: activeId,
            onTap: (id) => ptyCtrl.selectPty(id),
          ),
          centerTitle: true,
          actions: [
            if (activeSession != null) ...[
              IconButton(
                icon: const Icon(CupertinoIcons.search),
                onPressed: () => _showSearchBottomSheet(context, activeSession),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark),
                tooltip: LocaleKeys.terminalCloseCurrent.tr,
                onPressed: () => _confirmCloseCurrent(context, ptyCtrl),
              ),
            ],
            IconButton(
              icon: const Icon(CupertinoIcons.add),
              tooltip: LocaleKeys.terminalNew.tr,
              onPressed: () => ptyCtrl.createTerminal(),
            ),
          ],
        ),
        body: const TerminalPanelBody(),
      );
    });
  }

  void _showSettingsSheet(BuildContext context, PtyController ptyCtrl) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.terminalSettings.tr,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Obx(() {
                  return SwitchListTile(
                    title: Text(LocaleKeys.terminalCurrentProjectOnly.tr),
                    subtitle: Text(
                      LocaleKeys.terminalCurrentProjectOnlyDesc.tr,
                    ),
                    value: ptyCtrl.filterCurrentProjectOnly.value,
                    onChanged: (val) {
                      ptyCtrl.setFilterCurrentProjectOnly(val);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmCloseCurrent(BuildContext context, PtyController ptyCtrl) {
    final session = ptyCtrl.activeSession;
    if (session == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.terminalCloseCurrent.tr),
        content: Text(
          LocaleKeys.terminalConfirmClose.trParams({'title': session.title}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocaleKeys.cancel.tr),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ptyCtrl.closeTerminal(session.id);
            },
            child: Text(
              LocaleKeys.delete.tr,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchBottomSheet(BuildContext context, PtySession session) {
    session.controller.openSearch();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _TerminalSearchSheet(session: session),
    ).whenComplete(() {
      session.controller.closeSearch();
    });
  }
}

class _TerminalSearchSheet extends StatefulWidget {
  final PtySession session;

  const _TerminalSearchSheet({required this.session});

  @override
  State<_TerminalSearchSheet> createState() => _TerminalSearchSheetState();
}

class _TerminalSearchSheetState extends State<_TerminalSearchSheet> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.session.controller.searchPattern ?? '',
    );
    _focusNode = FocusNode();

    _textController.addListener(_onTextChanged);
    widget.session.controller.addListener(_onControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    widget.session.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onTextChanged() {
    widget.session.controller.search(_textController.text);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildOptionChip(SearchOption option, String label) {
    final isSelected = widget.session.controller.searchOptions.contains(option);

    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        widget.session.controller.toggleSearchOption(option);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.session.controller;
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _textController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _textController.clear();
                              controller.clearSearch();
                            },
                          )
                        : null,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    controller.searchNext();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed: controller.hasSearchResults
                    ? () => controller.searchPrevious()
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: controller.hasSearchResults
                    ? () => controller.searchNext()
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildOptionChip(SearchOption.caseSensitive, 'Aa'),
              const SizedBox(width: 6),
              _buildOptionChip(SearchOption.wholeWord, '\\b'),
              const SizedBox(width: 6),
              _buildOptionChip(SearchOption.regex, '.*'),
              const Spacer(),
              if (_textController.text.isNotEmpty)
                Text(
                  controller.hasSearchResults
                      ? '${controller.currentSearchIndex + 1} / ${controller.searchResultCount}'
                      : LocaleKeys.terminalNoResults.tr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: controller.hasSearchResults
                        ? theme.colorScheme.primary
                        : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 打开新增/编辑常用命令的 Dialog。返回的文本经去重后写入。
Future<void> _showCommandDialog(BuildContext context, {String? initial}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => _CommandEditDialog(initial: initial),
  );
  if (result == null) return;

  final commands = [...Global.terminalCommandsRx];
  if (initial != null) {
    final idx = commands.indexOf(initial);
    if (idx >= 0) {
      commands[idx] = result;
    } else {
      commands.add(result);
    }
  } else {
    commands.add(result);
  }
  await Global.saveTerminalCommands(commands);
}

void _sendTerminalInput(BuildContext context, String input) {
  final session = Get.find<PtyController>().activeSession;
  if (session == null || !session.connected.value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LocaleKeys.terminalNeedSession.tr),
        duration: const Duration(seconds: 1),
      ),
    );
    return;
  }
  session.sendInput(input);
}

void _runQuickCommand(BuildContext context, String command) {
  final session = Get.find<PtyController>().activeSession;
  if (session == null || !session.connected.value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LocaleKeys.terminalNeedSession.tr),
        duration: const Duration(seconds: 1),
      ),
    );
    return;
  }
  session.terminal.textInput(command);
  session.terminal.textInput('\r');
}

/// 底部常用命令条：常驻，chips 横向滑动，右侧固定新增按钮。
/// 点击 chip 发送命令+回车，长按 chip 编辑。
class _QuickCommandBar extends StatelessWidget {
  final ValueChanged<String> onTap;
  final ValueChanged<String> onEdit;
  final VoidCallback onAdd;

  const _QuickCommandBar({
    required this.onTap,
    required this.onEdit,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final commands = Global.terminalCommandsRx;
      final theme = Theme.of(context);
      return Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: commands.map((cmd) {
                    final label = cmd.length > 12
                        ? '${cmd.substring(0, 12)}…'
                        : cmd;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: GestureDetector(
                        onLongPress: () => onEdit(cmd),
                        child: ActionChip(
                          label: Text(
                            label,
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onTap(cmd),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.add_circled, size: 20),
              tooltip: LocaleKeys.developerNewCommand.tr,
              visualDensity: VisualDensity.compact,
              onPressed: onAdd,
            ),
          ],
        ),
      );
    });
  }
}

// ── Termux-style Extra Keys Bar ──

/// A key definition for the Termux extra keys bar.
class _ExtraKey {
  final String label;
  final String? sequence; // null for modifier keys (CTRL, ALT)
  final bool isModifier;

  const _ExtraKey(this.label, {this.sequence, this.isModifier = false});
}

/// 手机双行按键定义
const _phoneRow1 = [
  _ExtraKey('ESC', sequence: '\x1b'),
  _ExtraKey('/', sequence: '/'),
  _ExtraKey('-', sequence: '-'),
  _ExtraKey('HOME', sequence: '\x1b[H'),
  _ExtraKey('END', sequence: '\x1b[F'),
  _ExtraKey('PGUP', sequence: '\x1b[5~'),
  _ExtraKey('PGDN', sequence: '\x1b[6~'),
];

const _phoneRow2 = [
  _ExtraKey('TAB', sequence: '\t'),
  _ExtraKey('CTRL', isModifier: true),
  _ExtraKey('ALT', isModifier: true),
  _ExtraKey('←', sequence: '\x1b[D'),
  _ExtraKey('↑', sequence: '\x1b[A'),
  _ExtraKey('↓', sequence: '\x1b[B'),
  _ExtraKey('→', sequence: '\x1b[C'),
];

/// 平板单行按键定义（方向键挨在一起放在右侧）
const _tabletSingleRow = [
  _ExtraKey('ESC', sequence: '\x1b'),
  _ExtraKey('TAB', sequence: '\t'),
  _ExtraKey('CTRL', isModifier: true),
  _ExtraKey('ALT', isModifier: true),
  _ExtraKey('/', sequence: '/'),
  _ExtraKey('-', sequence: '-'),
  _ExtraKey('HOME', sequence: '\x1b[H'),
  _ExtraKey('END', sequence: '\x1b[F'),
  _ExtraKey('PGUP', sequence: '\x1b[5~'),
  _ExtraKey('PGDN', sequence: '\x1b[6~'),
  _ExtraKey('←', sequence: '\x1b[D'),
  _ExtraKey('↑', sequence: '\x1b[A'),
  _ExtraKey('↓', sequence: '\x1b[B'),
  _ExtraKey('→', sequence: '\x1b[C'),
];

/// Termux 风格扩展键盘：
/// - 手机端：采用【双行】扩展栏（方向键 ← ↑ ↓ → 挨在一起放在第二排右侧）
/// - 平板端：屏幕宽，采用【单行】扩展栏（按键平铺，方向键挨在一起放在最右侧）
/// - CTRL/ALT 为粘滞修饰键：点击高亮激活，下一个按键（或软键盘字符）自动组合后复位。
class _TermuxExtraKeysBar extends StatefulWidget {
  final ValueChanged<String> onSendInput;
  final ValueNotifier<bool>? ctrlNotifier;
  final ValueNotifier<bool>? altNotifier;

  const _TermuxExtraKeysBar({
    required this.onSendInput,
    this.ctrlNotifier,
    this.altNotifier,
  });

  @override
  State<_TermuxExtraKeysBar> createState() => _TermuxExtraKeysBarState();
}

class _TermuxExtraKeysBarState extends State<_TermuxExtraKeysBar> {
  void _onKeyTap(_ExtraKey key) {
    if (key.isModifier) {
      if (key.label == 'CTRL' && widget.ctrlNotifier != null) {
        widget.ctrlNotifier!.value = !widget.ctrlNotifier!.value;
      } else if (key.label == 'ALT' && widget.altNotifier != null) {
        widget.altNotifier!.value = !widget.altNotifier!.value;
      }
      return;
    }

    final seq = key.sequence ?? '';
    if (seq.isEmpty) return;

    final ctrlActive = widget.ctrlNotifier?.value ?? false;
    final altActive = widget.altNotifier?.value ?? false;

    String? output;
    if (ctrlActive) {
      // Ctrl + 可映射字符：发送控制码；不可映射（如 ESC/TAB/符号）不吞键
      output = ctrlCodeForInsert(seq);
    }
    if (output == null && altActive) {
      // Alt + 序列：ESC 前缀
      output = '\x1b$seq';
    }
    output ??= seq;

    // 发送完毕后复位修饰键
    if (ctrlActive) widget.ctrlNotifier?.value = false;
    if (altActive) widget.altNotifier?.value = false;

    widget.onSendInput(output);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surfaceContainer;

    final ctrlListenable = widget.ctrlNotifier ?? ValueNotifier(false);
    final altListenable = widget.altNotifier ?? ValueNotifier(false);

    final isTablet = isTabletLayout(context);

    return ListenableBuilder(
      listenable: Listenable.merge([ctrlListenable, altListenable]),
      builder: (context, _) {
        final isCtrlActive = widget.ctrlNotifier?.value ?? false;
        final isAltActive = widget.altNotifier?.value ?? false;

        return Container(
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.6),
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: isTablet
              ? _buildRow(
                  _tabletSingleRow,
                  theme,
                  isDark,
                  isCtrlActive,
                  isAltActive,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRow(
                      _phoneRow1,
                      theme,
                      isDark,
                      isCtrlActive,
                      isAltActive,
                    ),
                    _buildRow(
                      _phoneRow2,
                      theme,
                      isDark,
                      isCtrlActive,
                      isAltActive,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildRow(
    List<_ExtraKey> keys,
    ThemeData theme,
    bool isDark,
    bool isCtrlActive,
    bool isAltActive,
  ) {
    return SizedBox(
      height: 36,
      child: Row(
        children: keys.map((key) {
          final isActive =
              (key.label == 'CTRL' && isCtrlActive) ||
              (key.label == 'ALT' && isAltActive);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 3),
              child: Material(
                color: isActive
                    ? theme.colorScheme.primaryContainer
                    : isDark
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _onKeyTap(key),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isActive
                            ? theme.colorScheme.primary.withValues(alpha: 0.5)
                            : theme.colorScheme.outline.withValues(alpha: 0.15),
                        width: isActive ? 1.0 : 0.5,
                      ),
                    ),
                    child: Text(
                      key.label,
                      style: TextStyle(
                        fontSize: key.label.length > 3 ? 9.5 : 11,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontFamily: 'monospace',
                        color: isActive
                            ? theme.colorScheme.primary
                            : key.isModifier
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CommandEditDialog extends StatefulWidget {
  final String? initial;

  const _CommandEditDialog({this.initial});

  @override
  State<_CommandEditDialog> createState() => _CommandEditDialogState();
}

class _CommandEditDialogState extends State<_CommandEditDialog> {
  late final TextEditingController _ctrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial ?? '');
    _ctrl.addListener(() {
      if (_errorText != null && _ctrl.text.trim().isNotEmpty) {
        setState(() => _errorText = null);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final initial = widget.initial;
    if (initial == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.quickPhrasesDeleteTitle.tr),
        content: Text(
          LocaleKeys.quickPhrasesDeleteConfirm.trParams({'name': initial}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocaleKeys.cancel.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(LocaleKeys.delete.tr),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await Global.saveTerminalCommands(
      [...Global.terminalCommandsRx]..remove(initial),
    );
    if (mounted) Navigator.pop(context);
  }

  void _save() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = LocaleKeys.terminalCommandRequired.tr);
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? LocaleKeys.developerNewCommand.tr
            : LocaleKeys.developerEditCommand.tr,
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 3,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: LocaleKeys.terminalCommandLabel.tr,
          errorText: _errorText,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: _confirmDelete,
            child: Text(
              LocaleKeys.delete.tr,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LocaleKeys.cancel.tr),
        ),
        FilledButton(onPressed: _save, child: Text(LocaleKeys.save.tr)),
      ],
    );
  }
}
