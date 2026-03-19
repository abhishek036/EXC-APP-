import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Every list item in the app uses this wrapper for
/// staggered fade+slide entrance animation (80ms delay between items).
class CPAnimatedListItem extends StatelessWidget {
  final int index;
  final Widget child;
  final int delayMs;

  const CPAnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.delayMs = 80,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: Duration(milliseconds: index * delayMs))
        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
        .slideY(begin: 0.3, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}
