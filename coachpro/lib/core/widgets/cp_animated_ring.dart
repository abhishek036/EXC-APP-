import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated circular progress ring with smooth fill animation.
/// Used for attendance %, scores, etc. on dashboards.
class CPAnimatedRing extends StatefulWidget {
  final double progress; // 0.0 → 1.0
  final Color color;
  final Color? trackColor;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final Duration duration;

  const CPAnimatedRing({
    super.key,
    required this.progress,
    required this.color,
    this.trackColor,
    this.size = 48,
    this.strokeWidth = 4.0,
    this.child,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<CPAnimatedRing> createState() => _CPAnimatedRingState();
}

class _CPAnimatedRingState extends State<CPAnimatedRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CPAnimatedRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track =
        widget.trackColor ??
        widget.color.withValues(alpha: isDark ? 0.12 : 0.15);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => CustomPaint(
          painter: _RingPainter(
            progress: widget.progress * _animation.value,
            color: widget.color,
            trackColor: track,
            strokeWidth: widget.strokeWidth,
          ),
          child: child,
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
