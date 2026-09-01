import 'package:flutter/material.dart';

/// A vertical draggable divider for resizing adjacent panels.
///
/// Place between two widgets in a Row. Fires [onDrag] with horizontal
/// pixel deltas, and [onDragEnd] when the user lifts their finger.
///
/// Rendered as a slim track with a centered capsule grip that highlights in
/// the primary color while hovering/dragging, giving a visible seam between
/// the two panels.
class ResizableDivider extends StatefulWidget {
  final ValueChanged<double> onDrag;
  final VoidCallback? onDragEnd;
  final double width;

  const ResizableDivider({
    super.key,
    required this.onDrag,
    this.onDragEnd,
    this.width = 8.0,
  });

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _isDragging = false;
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Grip sizing animates between idle / hover / drag states.
    final gripWidth = _isDragging ? 7.0 : (_isHovering ? 5.0 : 4.0);
    final gripHeight = _isDragging ? 64.0 : (_isHovering ? 56.0 : 48.0);
    final gripColor = _isDragging
        ? theme.colorScheme.primary
        : _isHovering
        ? theme.colorScheme.primary.withValues(alpha: 0.7)
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        setState(() => _isDragging = true);
      },
      onHorizontalDragUpdate: (details) {
        widget.onDrag(details.delta.dx);
      },
      onHorizontalDragEnd: (_) {
        setState(() => _isDragging = false);
        widget.onDragEnd?.call();
      },
      onHorizontalDragCancel: () {
        setState(() => _isDragging = false);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: Container(
          width: widget.width,
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // Vertical padding keeps the grip floating in the middle.
              const Spacer(flex: 1),
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  width: gripWidth,
                  height: gripHeight,
                  decoration: BoxDecoration(
                    color: gripColor,
                    borderRadius: BorderRadius.circular(gripWidth / 2),
                    boxShadow: _isDragging
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
