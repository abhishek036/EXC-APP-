import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../admin/data/repositories/admin_repository.dart';

class GlobalSearchOverlay extends StatefulWidget {
  const GlobalSearchOverlay({super.key});

  static void show(BuildContext context) {
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Search',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => const GlobalSearchOverlay(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10 * animation.value, sigmaY: 10 * animation.value),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<GlobalSearchOverlay> createState() => _GlobalSearchOverlayState();
}

class _GlobalSearchOverlayState extends State<GlobalSearchOverlay> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final _adminRepo = sl<AdminRepository>();

  final List<Map<String, dynamic>> _quickLinks = [
    {'title': 'Access Directory', 'icon': Icons.folder_shared_outlined, 'color': AppColors.primary, 'route': '/admin/students'},
    {'title': 'Broadcast Logic', 'icon': Icons.sensors_rounded, 'color': AppColors.warning, 'route': '/admin/announcements'},
    {'title': 'Security Hub', 'icon': Icons.admin_panel_settings_outlined, 'color': AppColors.error, 'route': '/admin/users'},
    {'title': 'System Metrics', 'icon': Icons.auto_graph_rounded, 'color': AppColors.success, 'route': '/admin/reports'},
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // UNIVERSAL SEARCH BOX
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: CPGlassCard(
                isDark: isDark,
                borderRadius: 28,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: isDark ? Colors.white24 : Colors.black26, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        onChanged: (v) => setState(() {}),
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.deepNavy),
                        decoration: InputDecoration(
                          hintText: 'Search universal nodes...',
                          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w500, color: isDark ? Colors.white24 : Colors.black26),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 24),
                        ),
                      ),
                    ),
                    _buildShortcutHint(isDark),
                    const SizedBox(width: 8),
                    CPPressable(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), shape: BoxShape.circle),
                        child: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white : AppColors.deepNavy),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),

            const SizedBox(height: 24),

            // DYNAMIC CONTENT
            Expanded(
              child: _searchController.text.isEmpty 
                ? _buildInitializationState(isDark)
                : _buildInternalSearchResults(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutHint(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black12),
      ),
      child: Text('ESC', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38)),
    );
  }

  Widget _buildInitializationState(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text('QUICK COMMANDS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 2.0)),
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _quickLinks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final item = _quickLinks[i];
              return CPPressable(
                onTap: () {
                  Navigator.pop(context);
                  context.go(item['route'] as String);
                },
                child: CPGlassCard(
                  isDark: isDark,
                  borderRadius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: (item['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                        child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Text(item['title'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.deepNavy)),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white24 : Colors.black26),
                    ],
                  ),
                ),
              ).animate(delay: (150 + (i * 40)).ms).fadeIn().slideX(begin: 0.05);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInternalSearchResults(bool isDark) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _adminRepo.getStudents(),
        _adminRepo.getTeachers(),
        _adminRepo.getBatches(),
        _adminRepo.getLeads(),
      ]).then((res) => [
        ...res[0].map((e) => {...e, '_type': 'student'}),
        ...res[1].map((e) => {...e, '_type': 'teacher'}),
        ...res[2].map((e) => {...e, '_type': 'batch'}),
        ...res[3].map((e) => {...e, '_type': 'lead'}),
      ]),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        
        final q = _searchController.text.toLowerCase();
        final results = snap.data!.where((d) {
          final name = (d['name'] ?? '').toString().toLowerCase();
          final email = (d['email'] ?? '').toString().toLowerCase();
          final phone = (d['phone'] ?? '').toString().toLowerCase();
          return name.contains(q) || email.contains(q) || phone.contains(q);
        }).toList();

        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.manage_search_rounded, size: 64, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                const SizedBox(height: 16),
                Text('ZERO NODES MATCHED', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 2.0)),
              ],
            ).animate().fadeIn(),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final item = results[i] as Map<String, dynamic>;
            final type = item['_type'] as String;
            
            return CPPressable(
              onTap: () {
                Navigator.pop(context);
                if (type == 'student') {
                  context.go('/admin/students/${item['id']}');
                } else if (type == 'teacher') {
                  context.go('/admin/teachers'); // Navigate to list since no profile yet
                } else if (type == 'batch') {
                  context.go('/admin/batches');
                } else if (type == 'lead') {
                  context.go('/admin/leads');
                }
              },
              child: CPGlassCard(
                isDark: isDark,
                borderRadius: 20,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _getTypeColor(type).withValues(alpha: 0.1),
                      child: Icon(_getTypeIcon(type), color: _getTypeColor(type), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'] ?? 'IDENTITY-PENDING', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy)),
                          Text('${type.toUpperCase()} • ${item['email'] ?? item['phone'] ?? 'NO CONTACT'}', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.black38)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_right_alt_rounded, color: isDark ? Colors.white24 : Colors.black26),
                  ],
                ),
              ),
            ).animate(delay: (i * 30).ms).fadeIn().slideY(begin: 0.05);
          },
        );
      },
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'student': return Icons.face_retouching_natural_rounded;
      case 'teacher': return Icons.psychology_rounded;
      case 'batch': return Icons.groups_2_rounded;
      case 'lead': return Icons.radar_rounded;
      default: return Icons.fingerprint_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'student': return AppColors.primary;
      case 'teacher': return AppColors.elitePurple;
      case 'batch': return AppColors.success;
      case 'lead': return AppColors.moltenAmber;
      default: return Colors.grey;
    }
  }
}
