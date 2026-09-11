import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/session_controller.dart';
import '../../models/session_runtime_state.dart';
import '../../utils/translations.dart';

/// 电脑端（桌面端）多会话页签栏（Chrome / VS Code 现代桌面设计）：
/// - 严格遵循移动端 SessionIndicator 的状态控制机与三色指示器体系；
/// - 会话状态指示器位于 Tab 顶部胶囊条，完全不占用任何横向排版空间；
/// - 当页签过多时自动按可用宽度等比自适应缩小每个 Tab 宽度，超长文本自动省略；
/// - 支持悬停淡入关闭按钮、中键点击关闭、右键上下文菜单，以及快速新建会话 [+] 按钮；
/// - 支持鼠标滚轮横向平滑滚动，并支持激活页签自动滚动居中。
class DesktopSessionTabBar extends StatefulWidget {
  final List<String> openedIds;
  final String activeId;
  final SessionController sessionCtrl;
  final ValueChanged<String>? onSelectSession;

  static const amber = Color(0xFFF59E0B);
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);

  const DesktopSessionTabBar({
    super.key,
    required this.openedIds,
    required this.activeId,
    required this.sessionCtrl,
    this.onSelectSession,
  });

  @override
  State<DesktopSessionTabBar> createState() => _DesktopSessionTabBarState();
}

class _DesktopSessionTabBarState extends State<DesktopSessionTabBar> {
  final ScrollController _scrollController = ScrollController();
  List<double> _cachedWidths = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
  }

  @override
  void didUpdateWidget(covariant DesktopSessionTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeId != widget.activeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActive() {
    if (!mounted || !_scrollController.hasClients) return;
    final index = widget.openedIds.indexOf(widget.activeId);
    if (index < 0 || index >= _cachedWidths.length) return;

    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;

    const tabMargin = 2.0;
    double offsetBefore = 0.0;
    for (var i = 0; i < index; i++) {
      offsetBefore += _cachedWidths[i] + tabMargin;
    }

    final tabWidth = _cachedWidths[index];
    final viewportDimension = _scrollController.position.viewportDimension;
    final targetOffset =
        offsetBefore + (tabWidth / 2) - (viewportDimension / 2);

    _scrollController.animateTo(
      targetOffset.clamp(0.0, maxExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.openedIds.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const newBtnWidth = 30.0;
        final maxBarWidth = constraints.maxWidth;
        final availableWidth =
            (maxBarWidth - newBtnWidth - 8).clamp(0.0, double.infinity);
        final count = widget.openedIds.length;

        // 1. 测量每个 Tab 的自然内容宽度（自适应标题长度，短标题紧凑，长标题适度舒展）
        final titles = widget.openedIds
            .map((id) => widget.sessionCtrl.getSessionName(id))
            .toList();
        final naturalWidths = <double>[];
        for (final title in titles) {
          final painter = TextPainter(
            text: TextSpan(
              text: title,
              style: const TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          // 内容宽度 = 文本宽度 + 左右内边距 + 悬停关闭按钮预留空间
          final natural = (painter.width + 36.0).clamp(64.0, 200.0);
          naturalWidths.add(natural);
        }

        const tabMargin = 2.0;
        final totalNaturalWidth = naturalWidths.fold<double>(
              0.0,
              (sum, w) => sum + w,
            ) +
            (count > 0 ? (count - 1) * tabMargin : 0.0);

        // 2. 根据可用宽度进行计算：未撑满时按自然长度展示，撑满后按溢出量等比压缩
        final List<double> finalWidths = List<double>.filled(count, 0.0);
        const minTabWidth = 44.0; // 极限压缩下限

        if (totalNaturalWidth <= availableWidth) {
          // 未撑满：100% 保持自适应标题自然长度
          for (var i = 0; i < count; i++) {
            finalWidths[i] = naturalWidths[i];
          }
        } else {
          // 撑满了可用宽度：长标题按比例优先平滑收缩
          final overflow = totalNaturalWidth - availableWidth;
          final compressible = naturalWidths
              .map((w) => (w - minTabWidth).clamp(0.0, double.infinity))
              .toList();
          final totalCompressible = compressible.fold<double>(
            0.0,
            (sum, c) => sum + c,
          );

          if (totalCompressible > 0 && totalCompressible >= overflow) {
            for (var i = 0; i < count; i++) {
              final reduction =
                  overflow * (compressible[i] / totalCompressible);
              finalWidths[i] = (naturalWidths[i] - reduction).clamp(
                minTabWidth,
                naturalWidths[i],
              );
            }
          } else {
            // 连所有 Tab 全部压缩至 minTabWidth 都放不下时，保持 minTabWidth 并允许平滑横向滚动
            for (var i = 0; i < count; i++) {
              finalWidths[i] = minTabWidth;
            }
          }
        }

        _cachedWidths = finalWidths;

        final totalFinalWidth = finalWidths.fold<double>(
              0.0,
              (sum, w) => sum + w,
            ) +
            (count > 0 ? (count - 1) * tabMargin : 0.0);
        final isScrollable = totalFinalWidth > availableWidth;

        final tabs = <Widget>[];
        for (var i = 0; i < count; i++) {
          final id = widget.openedIds[i];
          final tabWidth = finalWidths[i];
          final isActive = id == widget.activeId;
          final isNextActive =
              (i + 1 < count) && (widget.openedIds[i + 1] == widget.activeId);

          tabs.add(
            SizedBox(
              width: tabWidth,
              child: _DesktopTabItem(
                key: ValueKey(id),
                id: id,
                openedIds: widget.openedIds,
                isActive: isActive,
                runState: widget.sessionCtrl.stateOf(id),
                sessionCtrl: widget.sessionCtrl,
                showTrailingDivider:
                    !isActive && !isNextActive && (i < count - 1),
                onTap: () {
                  if (widget.onSelectSession != null) {
                    widget.onSelectSession!(id);
                  } else {
                    widget.sessionCtrl.selectSession(id);
                  }
                },
                isCompact: tabWidth < 48.0,
              ),
            ),
          );
        }

        final tabRow = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ...tabs,
            const SizedBox(width: 4),
            _NewSessionTabButton(
              onTap: () => widget.sessionCtrl.createNewSession(),
            ),
          ],
        );

        if (isScrollable) {
          return Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent &&
                  _scrollController.hasClients &&
                  pointerSignal.scrollDelta.dy != 0) {
                final target = (_scrollController.offset +
                        pointerSignal.scrollDelta.dy)
                    .clamp(
                  0.0,
                  _scrollController.position.maxScrollExtent,
                );
                _scrollController.jumpTo(target);
              }
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: tabRow,
            ),
          );
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: tabRow,
        );
      },
    );
  }
}

enum _TabBlinkMode { completed, requiresAction }

class _DesktopTabItem extends StatefulWidget {
  final String id;
  final List<String> openedIds;
  final bool isActive;
  final SessionRuntimeState runState;
  final SessionController sessionCtrl;
  final VoidCallback onTap;
  final bool isCompact;
  final bool showTrailingDivider;

  const _DesktopTabItem({
    super.key,
    required this.id,
    required this.openedIds,
    required this.isActive,
    required this.runState,
    required this.sessionCtrl,
    required this.onTap,
    required this.isCompact,
    required this.showTrailingDivider,
  });

  @override
  State<_DesktopTabItem> createState() => _DesktopTabItemState();
}

class _DesktopTabItemState extends State<_DesktopTabItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _shouldBlink = false;
  _TabBlinkMode _blinkMode = _TabBlinkMode.completed;
  late final AnimationController _blinkController;
  late final Animation<double> _blinkAnimation;
  Worker? _generatingWorker;
  Worker? _permissionWorker;
  Worker? _pendingQuestionWorker;

  @override
  void initState() {
    super.initState();
    // 严格复刻移动端 SessionIndicator 700ms easeInOut 呼吸动画
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    // 严格遵循移动端响应式监听：生成状态改变/完成时闪烁
    _generatingWorker = ever(widget.runState.isGenerating, (bool generating) {
      if (!generating && !widget.isActive) {
        if (widget.runState.wasAborted.value) {
          _stopBlinking();
        } else if (widget.runState.requiresAction) {
          _startBlinking(_TabBlinkMode.requiresAction);
        } else {
          _startBlinking(_TabBlinkMode.completed);
        }
      } else if (generating) {
        _startBlinking(_TabBlinkMode.completed);
      }
    });

    _permissionWorker = ever<PendingPermission?>(
      widget.runState.pendingPermission,
      (_) => _checkRequiresActionBlink(),
    );
    _pendingQuestionWorker = ever(widget.runState.hasPendingQuestion, (_) {
      _checkRequiresActionBlink();
    });

    if (widget.runState.isGenerating.value) {
      _startBlinking(_TabBlinkMode.completed);
    }
    _checkRequiresActionBlink();
  }

  void _checkRequiresActionBlink() {
    if (widget.isActive) return;
    final requiresAction = widget.runState.requiresAction;
    if (requiresAction) {
      _startBlinking(_TabBlinkMode.requiresAction);
    } else if (_blinkMode == _TabBlinkMode.requiresAction) {
      _stopBlinking();
    }
  }

  @override
  void didUpdateWidget(covariant _DesktopTabItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive &&
        _shouldBlink &&
        !widget.runState.isGenerating.value) {
      _stopBlinking();
    }
    if (!widget.isActive && oldWidget.isActive) {
      _checkRequiresActionBlink();
    }
  }

  void _startBlinking(_TabBlinkMode mode) {
    if (_shouldBlink && _blinkMode == mode && _blinkController.isAnimating) {
      return;
    }
    if (mounted) {
      setState(() {
        _shouldBlink = true;
        _blinkMode = mode;
      });
      _blinkController.repeat(reverse: true);
    }
  }

  void _stopBlinking() {
    if (!_shouldBlink) return;
    if (mounted) {
      setState(() => _shouldBlink = false);
      _blinkController.stop();
      _blinkController.reset();
    }
  }

  @override
  void dispose() {
    _generatingWorker?.dispose();
    _permissionWorker?.dispose();
    _pendingQuestionWorker?.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  void _showContextMenu(BuildContext context, TapUpDetails details) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final theme = Theme.of(context);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'close',
          height: 34,
          child: Row(
            children: [
              const Icon(CupertinoIcons.xmark, size: 13),
              const SizedBox(width: 8),
              Text(
                LocaleKeys.close.tr,
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
        if (widget.openedIds.length > 1)
          PopupMenuItem<String>(
            value: 'close_others',
            height: 34,
            child: Row(
              children: [
                const Icon(CupertinoIcons.clear_thick, size: 13),
                const SizedBox(width: 8),
                Text(
                  LocaleKeys.tabCloseOthers.tr,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'close_all',
          height: 34,
          child: Row(
            children: [
              const Icon(CupertinoIcons.trash, size: 13),
              const SizedBox(width: 8),
              Text(
                LocaleKeys.tabCloseAll.tr,
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    if (selected == 'close') {
      widget.sessionCtrl.closeSession(widget.id);
    } else if (selected == 'close_others') {
      final others =
          widget.openedIds.where((id) => id != widget.id).toList();
      for (final id in others) {
        widget.sessionCtrl.closeSession(id);
      }
    } else if (selected == 'close_all') {
      widget.sessionCtrl.clearAllOpenedSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final isGenerating = widget.runState.isGenerating.value;
      widget.runState.pendingPermission.value;
      final hasError = widget.runState.lastError.value?.isNotEmpty == true;
      final requiresAction =
          widget.isActive ? false : widget.runState.requiresAction;
      final sessionTitle = widget.sessionCtrl.getSessionName(widget.id);

      // 遵循移动端指示器三色：
      // 报错红色、生成中/等待输入琥珀色、闲置绿色
      Color dotColor;
      if (hasError) {
        dotColor = DesktopSessionTabBar.red;
      } else if (isGenerating) {
        dotColor = DesktopSessionTabBar.amber;
      } else {
        dotColor = DesktopSessionTabBar.green;
      }

      if (_shouldBlink &&
          _blinkMode == _TabBlinkMode.requiresAction &&
          requiresAction) {
        dotColor = DesktopSessionTabBar.amber;
      }

      final isGlowing = _shouldBlink || isGenerating;
      final showClose = _isHovered && !widget.isCompact;

      // 悬停完整提示
      String tooltipText = sessionTitle;
      if (hasError) {
        tooltipText = '$sessionTitle (Error)';
      } else if (isGenerating) {
        tooltipText = '$sessionTitle (Generating...)';
      } else if (requiresAction) {
        tooltipText = '$sessionTitle (Action Required)';
      }

      return Tooltip(
        message: tooltipText,
        waitDuration: const Duration(milliseconds: 600),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // 点击切换时停止闪烁，严格遵循移动端 onTap 行为
              _stopBlinking();
              widget.onTap();
            },
            onSecondaryTapUp: (details) => _showContextMenu(context, details),
            onTertiaryTapDown: (_) =>
                widget.sessionCtrl.closeSession(widget.id),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 现代桌面 Tab 卡片主体（极简通透，杜绝粗暴大蓝块）
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  height: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 1.0),
                  decoration: BoxDecoration(
                    color: widget.isActive
                        ? theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.45,
                          )
                        : (_isHovered
                            ? theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.22)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: widget.isActive
                          ? theme.colorScheme.outline.withValues(alpha: 0.18)
                          : (_isHovered
                              ? theme.colorScheme.outline.withValues(alpha: 0.1)
                              : Colors.transparent),
                      width: 0.8,
                    ),
                    boxShadow: widget.isActive
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      // 标题文字与悬停淡入关闭按钮（Positioned.fill 撑满 30px 容器高度实现垂直绝对居中）
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: widget.isCompact ? 6 : 9,
                            right: widget.isCompact ? 6 : (showClose ? 4 : 9),
                            top: 1.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  sessionTitle,
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: widget.isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: widget.isActive
                                        ? theme.colorScheme.onSurface
                                        : (_isHovered
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.85)),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if (showClose)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      widget.sessionCtrl.closeSession(widget.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(2.0),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: theme
                                          .colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.6),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.xmark,
                                      size: 10,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // ─── 顶部指示器（严格遵循移动端三色与双层呼吸光晕，零横向空间占用） ───
                      Positioned(
                        left: widget.isActive ? 6 : 10,
                        right: widget.isActive ? 6 : 10,
                        top: 0,
                        height: widget.isActive ? 2.4 : 1.8,
                        child: isGlowing
                            ? AnimatedBuilder(
                                animation: _blinkAnimation,
                                builder: (context, _) {
                                  final v = _blinkAnimation.value;
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: dotColor.withValues(
                                        alpha: 0.4 + 0.6 * v,
                                      ),
                                      borderRadius: BorderRadius.circular(1.5),
                                      boxShadow: [
                                        // 移动端同款双层呼吸扩散光晕
                                        BoxShadow(
                                          color: dotColor.withValues(
                                            alpha: 0.25 + 0.55 * v,
                                          ),
                                          blurRadius: 4.0 + 6.0 * v,
                                          spreadRadius: 0.5 + 1.5 * v,
                                        ),
                                        BoxShadow(
                                          color: dotColor.withValues(
                                            alpha: 0.35 + 0.4 * v,
                                          ),
                                          blurRadius: 2.0 + 2.5 * v,
                                          spreadRadius: 0.2 + 0.8 * v,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                            : (widget.isActive || hasError
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      borderRadius: BorderRadius.circular(1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: dotColor.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 2.5,
                                          spreadRadius: 0.3,
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink()),
                      ),
                    ],
                  ),
                ),

                // 未选中的相邻 Tab 之间的雅致细分隔线
                if (widget.showTrailingDivider && !_isHovered)
                  Positioned(
                    right: -0.5,
                    top: 8,
                    bottom: 8,
                    width: 1,
                    child: Container(
                      color: theme.colorScheme.outline.withValues(alpha: 0.12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _NewSessionTabButton extends StatefulWidget {
  final VoidCallback onTap;

  const _NewSessionTabButton({required this.onTap});

  @override
  State<_NewSessionTabButton> createState() => _NewSessionTabButtonState();
}

class _NewSessionTabButtonState extends State<_NewSessionTabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: LocaleKeys.cmdNewSession.tr,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _isHovered
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: _isHovered
                    ? theme.colorScheme.outline.withValues(alpha: 0.18)
                    : Colors.transparent,
                width: 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              CupertinoIcons.plus,
              size: 13,
              color: _isHovered
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
