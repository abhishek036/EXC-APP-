import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';

class TeacherListPage extends StatefulWidget {
  const TeacherListPage({super.key});

  @override
  State<TeacherListPage> createState() => _TeacherListPageState();
}

class _TeacherListPageState extends State<TeacherListPage> {
  final AdminRepository _adminRepo = sl<AdminRepository>();
  bool _isLoading = true;
  List<Map<String, dynamic>> _teachers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    if (!mounted) return;
    try {
      final users = await _adminRepo.getTeachers();
      if (mounted) {
        setState(() {
          _teachers = users;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    final filtered = _teachers.where((t) {
      final name = (t['name'] ?? '').toLowerCase();
      final phone = (t['phone'] ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, isDark),
                _buildSearchSection(isDark),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Faculty Scholars', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      _badge('${filtered.length} ACTIVE MEMBERS', AppColors.mintGreen, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.elitePrimary))
                      : filtered.isEmpty
                          ? _buildEmptyState(isDark)
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              itemCount: filtered.length,
                              physics: const BouncingScrollPhysics(),
                              separatorBuilder: (context, index) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                return _buildTeacherCard(filtered[index], index, isDark);
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          CPPressable(onTap: () => context.pop(), child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : AppColors.deepNavy)),
          const SizedBox(width: 16),
          Expanded(child: Text('Team Management', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.8))),
          _appBarAction(Icons.add_rounded, () => context.go('/admin/teachers/add'), isDark, primary: true),
        ],
      ),
    );
  }

  Widget _appBarAction(IconData icon, VoidCallback onTap, bool isDark, {bool primary = false}) {
    return CPPressable(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: primary ? const Color(0xFF0D1282) : const Color(0xFFEEEDED), border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2))]),
        child: Icon(icon, size: 22, color: primary ? Colors.white : const Color(0xFF0D1282)),
      ),
    );
  }

  Widget _buildSearchSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: CPGlassCard(
        isDark: isDark, padding: EdgeInsets.zero, borderRadius: 20,
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: GoogleFonts.inter(color: isDark ? Colors.white : AppColors.deepNavy, fontSize: 14, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'Search faculty by name or detail...',
            hintStyle: GoogleFonts.inter(color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26), fontWeight: FontWeight.w600),
            prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person_search_rounded, size: 64, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1)),
        const SizedBox(height: 24),
        Text('No faculty members found', style: GoogleFonts.inter(fontSize: 15, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26), fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher, int index, bool isDark) {
    final user = teacher['user'] is Map<String, dynamic> ? teacher['user'] as Map<String, dynamic> : <String, dynamic>{};
    final teacherId = teacher['id']?.toString() ?? '';
    final displayName = (teacher['name'] ?? user['name'] ?? 'Faculty Member').toString();
    final displayPhone = (teacher['phone'] ?? user['phone'] ?? '--').toString();
    final subjects = ((teacher['subjects'] as List?) ?? const [])
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList();
    final subject = subjects.isNotEmpty
      ? subjects.take(2).join(', ')
      : (teacher['subject']?.toString().isNotEmpty == true ? teacher['subject'].toString() : 'Unspecified Subject');
    final isActive = (teacher['is_active'] ?? true) == true;

    return CPPressable(
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _showDeleteConfirm(teacherId, displayName);
      },
      onTap: () {
        HapticFeedback.lightImpact();
        context.go('/admin/teachers/$teacherId');
      },
      child: CPGlassCard(
        isDark: isDark, padding: const EdgeInsets.all(16), borderRadius: 24,
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: const Color(0xFFEEEDED), border: Border.all(color: const Color(0xFF0D1282), width: 2)),
              alignment: Alignment.center,
              child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'F', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282), letterSpacing: -0.4)),
                  const SizedBox(height: 4),
                  Text(subject, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0D1282), fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.phone_iphone_rounded, size: 12, color: const Color(0xFF0D1282).withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Text(displayPhone, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0D1282), fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFF0DE36) : const Color(0xFFD71313),
                          border: Border.all(color: const Color(0xFF0D1282), width: 1.5),
                        ),
                        child: Text(
                          isActive ? 'ACTIVE' : 'INACTIVE',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFEEEDED), border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2))]), child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF0D1282))),
          ],
        ),
      ),
    ).animate(delay: (20 * index).ms).fadeIn(duration: 500.ms).slideX(begin: 0.05);
  }

  void _showDeleteConfirm(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Faculty?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.deepNavy)),
        content: Text('Are you sure you want to remove $name? This action cannot be undone.', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCEL', style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontWeight: FontWeight.w800))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _adminRepo.deleteTeacher(id);
                _loadTeachers();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faculty removed successfully')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD71313), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('DELETE', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2))]),
      child: Text(text, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282), letterSpacing: 0.5)),
    );
  }
}
