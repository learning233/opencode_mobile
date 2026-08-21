import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class TextShimmer extends StatefulWidget {
  final String text;
  final bool active;
  final TextStyle? style;
  final int swapMs;

  const TextShimmer({
    super.key,
    required this.text,
    this.active = true,
    this.style,
    this.swapMs = 220,
  });

  @override
  State<TextShimmer> createState() => _TextShimmerState();
}

class _TextShimmerState extends State<TextShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _stopTimer;
  bool _run = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.swapMs),
    );
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(covariant TextShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _start();
      } else {
        _scheduleStop();
      }
    }
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    _stopTimer?.cancel();
    if (_run) return;
    _run = true;
    _controller.repeat();
  }

  void _scheduleStop() {
    _stopTimer?.cancel();
    _controller.stop();
    _stopTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _run = false);
      _controller.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = (widget.style ?? theme.textTheme.bodySmall)
        ?.copyWith(fontSize: 12);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return RichText(
          text: TextSpan(
            children: List.generate(widget.text.length, (i) {
              final phase = _run ? _charPhase(i, t: t) : 1.0;
              return TextSpan(
                text: widget.text[i],
                style: effectiveStyle?.copyWith(
                  color: effectiveStyle.color?.withValues(alpha: phase),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  double _charPhase(int index, {required double t}) {
    final offset = index * 0.15;
    final raw = (t + offset) % 1.0;
    return 0.3 + 0.6 * sin(raw * 3.14159 * 2).abs();
  }
}
