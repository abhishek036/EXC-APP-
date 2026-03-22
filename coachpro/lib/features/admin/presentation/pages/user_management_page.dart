import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../data/repositories/admin_repository.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final AdminRepository _repo = sl<AdminRepository>();
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';
  String? _filterRole;
  String? _filterStatus;

  static const _roles = ['', 'admin', 'teacher', 'student', 'parent'];
  static const _statuses = ['', 'ACTIVE', 'BLOCKED', 'INACTIVE', 'PENDING'];

  @override
  void initState() {
    super.initState();
    _syncDirectory();
  }

  Future<void> _syncDirectory() async {
    setState(() => _isLoading = true);
    try {
      final users = await _repo.getUsers(
        role: _filterRole?.isEmpty ?? true ? null : _filterRole,
        status: _filterStatus?.isEmpty ?? true ? null : _filterStatus,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      if (mounted) setState(() { _users = users; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CPToast.error(context, 'Directory sync failed: $e');
      }
    }
  }

  Future<void> _updateSecurityState(Map<String, dynamic> user, String newStatus) async {
    try {
      await _repo.updateUserStatus(userId: user['id'], status: newStatus);
      if (mounted) CPToast.success(context, 'Security state: $newStatus');
      _syncDirectory();
    } catch (e) {
      if (mounted) CPToast.error(context, e.toString());
    }
  }

  Future<void> _updateClearanceLevel(Map<String, dynamic> user, String newRole) async {
    try {
      await _repo.changeUserRole(userId: user['id'], role: newRole);
      if (mounted) CPToast.success(context, 'Clearance upgraded: $newRole');
      _syncDirectory();
    } catch (e) {
      if (mounted) CPToast.error(context, e.toString());
    }
  }

  Widget _glow(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: size / 2)]));

  void _showActions(Map<String, dynamic> user) {
    HapticFeedback.heavyImpact();
    final status = (user['status'] ?? 'ACTIVE').toString();
    final role = (user['role'] ?? 'student').toString();
    final isDark = CT.isDark(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 40),
        decoration: BoxDecoration(
          color: isDark ? AppColors.eliteDarkBg : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18)),
                  child: Icon(_roleIcon(role), color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['phone'] ?? 'ID-PENDING', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.8)),
                      Text('CURRENT CLEARANCE: ${role.toUpperCase()}', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.2)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('OVERRIDE SECURITY STATE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (status != 'ACTIVE') _actionButton('AUTHORIZE', Icons.verified_user_rounded, Colors.green, () { Navigator.pop(ctx); _updateSecurityState(user, 'ACTIVE'); }, isDark),
                  if (status != 'BLOCKED') ...[const SizedBox(width: 10), _actionButton('BLACKLIST', Icons.gpp_bad_rounded, AppColors.error, () { Navigator.pop(ctx); _updateSecurityState(user, 'BLOCKED'); }, isDark)],
                  if (status != 'INACTIVE') ...[const SizedBox(width: 10), _actionButton('SUSPEND', Icons.security_rounded, Colors.orange, () { Navigator.pop(ctx); _updateSecurityState(user, 'INACTIVE'); }, isDark)],
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('REASSIGN CLEARANCE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: ['admin', 'teacher', 'student', 'parent']
                  .where((r) => r != role)
                  .map((r) => _actionButton(r.toUpperCase(), _roleIcon(r), isDark ? Colors.white : AppColors.deepNavy, () { Navigator.pop(ctx); _updateClearanceLevel(user, r); }, isDark))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return CPPressable(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin': return Icons.admin_panel_settings_rounded;
      case 'teacher': return Icons.psychology_rounded;
      case 'parent': return Icons.supervised_user_circle_rounded;
      default: return Icons.fingerprint_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE': return AppColors.success;
      case 'BLOCKED': return AppColors.error;
      case 'INACTIVE': return Colors.orange;
      case 'PENDING': return AppColors.primary;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          // Background Glows
          if (isDark) ...[
            Positioned(top: -150, right: -50, child: _glow(400, AppColors.primary.withValues(alpha: 0.12))),
            Positioned(bottom: 100, left: -100, child: _glow(350, AppColors.secondary.withValues(alpha: 0.08))),
            Positioned(top: 400, left: 200, child: _glow(250, AppColors.success.withValues(alpha: 0.05))),
          ],
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 12),
                
                // Security Metrics
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildMetrics(isDark),
                ),
                const SizedBox(height: 24),

                // Control Panel (Search & Filters)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildControlPanel(isDark),
                ),
                const SizedBox(height: 20),

                // Directory List
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3).animate().scale(duration: 400.ms))
                      : _users.isEmpty
                          ? _buildEmptyState(isDark)
                          : RefreshIndicator(
                              onRefresh: _syncDirectory,
                              color: AppColors.primary,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                                itemCount: _users.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 14),
                                itemBuilder: (_, i) => _buildEliteUserCard(_users[i], isDark)
                                    .animate(delay: (30 * i).ms)
                                    .fadeIn(duration: 500.ms)
                                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          CPPressable(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
              ),
              child: Icon(Icons.shield_outlined, size: 22, color: isDark ? Colors.white : AppColors.deepNavy),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IAM PROTOCOL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 2.0)),
                Text('User Directory', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.8)),
              ],
            ),
          ),
          CPPressable(
            onTap: _syncDirectory,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.sync_rounded, size: 20, color: isDark ? Colors.white38 : Colors.black38),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _buildMetrics(bool isDark) {
    final active = _users.where((u) => u['status'] == 'ACTIVE').length;
    final blocked = _users.where((u) => u['status'] == 'BLOCKED').length;

    return Row(
      children: [
        _metricItem('TOTAL NODES', _users.length.toString(), AppColors.primary, isDark),
        const SizedBox(width: 12),
        _metricItem('VERIFIED', active.toString(), AppColors.success, isDark),
        const SizedBox(width: 12),
        _metricItem('BLACKLISTED', blocked.toString(), AppColors.error, isDark),
      ],
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _metricItem(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: CPGlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: Column(
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: color, letterSpacing: -1.0)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel(bool isDark) {
    return CPGlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(6),
      borderRadius: 24,
      child: Column(
        children: [
          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) { _searchQuery = v; _syncDirectory(); },
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search security handles...',
                hintStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white24 : Colors.black26),
                icon: Icon(Icons.search_rounded, color: isDark ? Colors.white24 : Colors.black26, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          
          // Row of Filters
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: _eliteFilter(
                    value: _filterRole ?? '',
                    items: _roles,
                    hint: 'CLEARANCE',
                    onChanged: (v) { _filterRole = v; _syncDirectory(); },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _eliteFilter(
                    value: _filterStatus ?? '',
                    items: _statuses,
                    hint: 'ACCESS STATE',
                    onChanged: (v) { _filterStatus = v; _syncDirectory(); },
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _eliteFilter({required String value, required List<String> items, required String hint, required ValueChanged<String?> onChanged, required bool isDark}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.eliteDarkBg : Colors.white,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.white70 : AppColors.deepNavy),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white24 : Colors.black26, size: 18),
          items: items.map((item) => DropdownMenuItem(
            value: item, 
            child: Text(item.isEmpty ? hint : item.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800))
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEliteUserCard(Map<String, dynamic> user, bool isDark) {
    final phone = user['phone'] ?? 'UNREGISTERED';
    final role = (user['role'] ?? 'student').toString();
    final status = (user['status'] ?? 'ACTIVE').toString();
    final isBlocked = status == 'BLOCKED';

    return CPPressable(
      onTap: () => _showActions(user),
      child: CPGlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(18),
        borderRadius: 24,
        border: Border.all(color: isBlocked ? AppColors.error.withValues(alpha: 0.25) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_roleIcon(role), color: _statusColor(status), size: 24),
                ),
                if (isBlocked) 
                  Positioned(bottom: -2, right: -2, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 10, color: Colors.white))),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(phone, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _eliteBadge(role.toUpperCase(), AppColors.primary, isDark),
                      const SizedBox(width: 8),
                      _eliteBadge(status.toUpperCase(), _statusColor(status), isDark),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.more_vert_rounded, color: isDark ? Colors.white12 : Colors.black12, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _eliteBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.8)),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02), shape: BoxShape.circle),
            child: Icon(Icons.fingerprint_rounded, size: 64, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          ),
          const SizedBox(height: 24),
          Text('ACCESS DENIED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.error, letterSpacing: 3.0)),
          Text('Identity not found in logs', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.black38)),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }
}


