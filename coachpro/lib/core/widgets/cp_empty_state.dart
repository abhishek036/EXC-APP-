import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/theme_aware.dart';

/// Full-screen empty state for lists with no data.
/// Pairs with CPErrorState for the complete state management UX.
/// Now theme-aware — adapts to light/dark mode automatically.
class CPEmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CPEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: CT.accent(context).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: CT.accent(context).withValues(alpha: 0.5),
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            Text(
              title,
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CT.textH(context),
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 200.ms).fadeIn(),

            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: CT.textS(context),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 300.ms).fadeIn(),
            ],

            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  actionLabel!,
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: CT.accent(context),
                ),
              ).animate(delay: 400.ms).fadeIn(),
            ],
          ],
        ),
      ),
    );
  }
}
