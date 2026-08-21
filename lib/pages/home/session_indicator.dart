import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/session_controller.dart';
import '../../models/session_runtime_state.dart';

/// Top AppBar Session Status Lights Row — renders a horizontal row of status dots
/// representing all opened sessions. Active session dot has a surrounding circle ring,
/// and blinking/flashing sessions display a vibrant animated glow halo effect (光晕).
class SessionIndicator extends StatelessWidget {
  final List<String> openedIds;
  final String activeId;
  final ValueChanged<String> onTap;

  static const amber = Color(0xFFF59E0B);
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);

  const SessionIndicator({
    super.key,
    required this.openedIds,
    required this.activeId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: openedIds.map((id) {
          final isActive = id == activeId;

          return _SessionDot(
            key: ValueKey(id),
            isActive: isActive,
            runState: ctrl.stateOf(id),
            onTap: () => onTap(id),
          );
        }).toList(),
      ),
    );
  }
}

enum _BlinkMode { completed, requiresAction }

class _SessionDot extends StatefulWidget {
  final bool isActive;
  final SessionRuntimeState runState;
  final VoidCallback onTap;

  const _SessionDot({
    super.key,
    required this.isActive,
    required this.runState,
    required this.onTap,
  });

  @override
  State<_SessionDot> createState() => _SessionDotState();
}

class _SessionDotState extends State<_SessionDot>
    with SingleTickerProviderStateMixin {
  bool _shouldBlink = false;
  _BlinkMode _blinkMode = _BlinkMode.completed;
  late final AnimationController _blinkController;
  late final Animation<double> _blinkAnimation;
  Worker? _generatingWorker;
  Worker? _permissionWorker;
  Worker? _messagesWorker;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _generatingWorker = ever(widget.runState.isGenerating, (bool generating) {
      if (!generating && !widget.isActive) {
        if (widget.runState.wasAborted.value) {
          _stopBlinking();
        } else if (widget.runState.requiresAction) {
          _startBlinking(_BlinkMode.requiresAction);
        } else {
          _startBlinking(_BlinkMode.completed);
        }
      } else if (generating) {
        _startBlinking(_BlinkMode.completed);
      }
    });

    _permissionWorker = ever<PendingPermission?>(
      widget.runState.pendingPermission,
      (_) => _checkRequiresActionBlink(),
    );
    _messagesWorker = ever(widget.runState.messages, (_) {
      _checkRequiresActionBlink();
    });

    if (widget.runState.isGenerating.value) {
      _startBlinking(_BlinkMode.completed);
    }
  }

  void _checkRequiresActionBlink() {
    // The active session is the one receiving 80ms streaming deltas; skipping
    // the full message/part scan here avoids recomputing requiresAction for the
    // session the user is already watching directly.
    if (widget.isActive) return;
    final requiresAction = widget.runState.requiresAction;
    if (requiresAction) {
      _startBlinking(_BlinkMode.requiresAction);
    } else if (_blinkMode == _BlinkMode.requiresAction) {
      _stopBlinking();
    }
  }

  @override
  void didUpdateWidget(covariant _SessionDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive &&
        _shouldBlink &&
        !widget.runState.isGenerating.value) {
      _stopBlinking();
    }
    // Just became inactive: evaluate once so an already pending action starts
    // blinking without waiting for the next message/permission event.
    if (!widget.isActive && oldWidget.isActive) {
      _checkRequiresActionBlink();
    }
  }

  void _startBlinking(_BlinkMode mode) {
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
    _messagesWorker?.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: GestureDetector(
        onTap: () {
          _stopBlinking();
          widget.onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Obx(() {
          final isGenerating = widget.runState.isGenerating.value;
          widget.runState.pendingPermission.value;
          final hasError = widget.runState.lastError.value?.isNotEmpty == true;
          final requiresAction = widget.isActive
              ? false
              : widget.runState.requiresAction;

          Color dotColor;
          if (hasError) {
            dotColor = SessionIndicator.red;
          } else if (isGenerating) {
            dotColor = SessionIndicator.amber;
          } else {
            dotColor = SessionIndicator.green;
          }

          if (_shouldBlink &&
              _blinkMode == _BlinkMode.requiresAction &&
              requiresAction) {
            dotColor = SessionIndicator.amber;
          }

          final isGlowing = _shouldBlink || isGenerating;

          return SizedBox(
            width: 22,
            height: 22,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Active session outer circle ring ("选中的加个圈")
                if (widget.isActive)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 1.2,
                      ),
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),

                // Dot with animated glow halo when blinking/generating ("闪烁的出现光晕")
                if (isGlowing)
                  AnimatedBuilder(
                    animation: _blinkAnimation,
                    builder: (context, _) {
                      final v = _blinkAnimation.value;
                      return Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                          boxShadow: [
                            // Outer soft halo glow
                            BoxShadow(
                              color: dotColor.withValues(
                                alpha: 0.25 + 0.55 * v,
                              ),
                              blurRadius: 4.0 + 7.0 * v,
                              spreadRadius: 1.0 + 3.0 * v,
                            ),
                            // Inner intense glow core
                            BoxShadow(
                              color: dotColor.withValues(alpha: 0.4 + 0.4 * v),
                              blurRadius: 2.0 + 3.0 * v,
                              spreadRadius: 0.5 + 1.0 * v,
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      boxShadow: widget.isActive
                          ? [
                              BoxShadow(
                                color: dotColor.withValues(alpha: 0.4),
                                blurRadius: 3,
                                spreadRadius: 0.5,
                              ),
                            ]
                          : null,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
