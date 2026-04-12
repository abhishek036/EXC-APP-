import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Shimmer skeleton loading widget.
/// Matches exact content shapes for premium loading experience.
class CPShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isCircle;

  const CPShimmer({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12.0,
    this.isCircle = false,
  });

  /// Quick card-shaped shimmer
  const CPShimmer.card({super.key, this.height = 100})
      : width = double.infinity,
        borderRadius = AppDimensions.radiusMD,
        isCircle = false;

  /// Circular shimmer for avatars
  const CPShimmer.circle({super.key, double size = 44})
      : width = size,
        height = size,
        borderRadius = 0,
        isCircle = true;

  /// Line shimmer for text placeholders
  const CPShimmer.line({super.key, this.width = 120, this.height = 14})
      : borderRadius = 7,
        isCircle = false;

  @override
  State<CPShimmer> createState() => _CPShimmerState();
}

class _CPShimmerState extends State<CPShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.charcoalDark : const Color(0xFFE8E8E8);
    final highlightColor = isDark ? AppColors.graphite : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircle
                ? null
                : BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Pre-built shimmer for a typical list card
class CPShimmerCard extends StatelessWidget {
  const CPShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.midnightBlack : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Row(
        children: [
          const CPShimmer.circle(size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CPShimmer.line(width: 140, height: 14),
                const SizedBox(height: 8),
                CPShimmer.line(width: 200, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
