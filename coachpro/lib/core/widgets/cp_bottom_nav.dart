import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/theme_aware.dart';

class CPBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<CPBottomNavItem> items;

  const CPBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Container(
      height: 64, // Base height, safe area added below
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1282) : const Color(0xFFEEEDED),
        border: const Border(top: BorderSide(color: Color(0xFF0D1282), width: 1.2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: _NavItem(
                  item: item,
                  isActive: isActive,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap(i);
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class CPBottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const CPBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavItem extends StatelessWidget {
  final CPBottomNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    final activeColor = isDark ? const Color(0xFFE3D465) : const Color(0xFF0D1282);
    final inactiveColor = isDark ? const Color(0xFFEEEDED) : const Color(0xFF0D1282);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark ? const Color(0xFFEEEDED).withValues(alpha: 0.18) : activeColor.withValues(alpha: 0.1))
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: 24,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
          if (isActive)
            Positioned(
              bottom: 0,
              child: Container(
                width: 24,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3D465), // Yellow Indicator
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
