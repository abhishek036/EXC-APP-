import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_shimmer.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../data/repositories/admin_repository.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final _adminRepo = sl<AdminRepository>();
  final _realtime = sl<RealtimeSyncService>();
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  String _error = '';
  StreamSubscription<Map<String, dynamic>>? _syncSub;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _initRealtime();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _initRealtime() async {
    await _realtime.connect();
    _syncSub?.cancel();
    _syncSub = _realtime.updates.listen((event) {
      if (!mounted) return;
      final type = (event['type'] ?? '').toString();
      if (type == 'dashboard_sync' || type == 'batch_sync') {
        _loadLogs();
      }
    });
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final logs = await _adminRepo.getAuditLogs(limit: 50);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load system logs';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(top: -100, left: -50, child: const SizedBox.shrink()),
            Positioned(
              bottom: 200,
              right: -150,
              child: const SizedBox.shrink(),
            ),
          ],
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppBar(context, isDark),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'System Monitoring',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: isDark ? AppColors.paleSlate2 : Colors.black45,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _isLoading
                      ? _buildShimmer(isDark)
                      : _error.isNotEmpty
                      ? Center(
                          child: Text(
                            _error,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : _buildTimeline(isDark),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          CPPressable(
            onTap: () {
              if (GoRouter.of(context).canPop()) {
                GoRouter.of(context).pop();
              } else {
                GoRouter.of(context).go('/admin');
              }
            },
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Audit Logs',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                letterSpacing: -0.8,
              ),
            ),
          ),
          CPPressable(
            onTap: _loadLogs,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: 8,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => const CPShimmer(
        width: double.infinity,
        height: 100,
        borderRadius: 20,
      ),
    );
  }

  Widget _buildTimeline(bool isDark) {
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.monitor_heart_outlined,
              size: 48,
              color: isDark ? AppColors.darkBorder : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'No system logs recorded yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: isDark ? AppColors.paleSlate2 : Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _logs.length,
      itemBuilder: (ctx, i) {
        final log = _logs[i];
        final isLast = i == _logs.length - 1;
        return _buildLogEntry(log, isLast, isDark)
            .animate(delay: (30 * i).ms)
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.1);
      },
      padding: const EdgeInsets.only(bottom: 60, left: 20, right: 20, top: 12),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log, bool isLast, bool isDark) {
    final action = log['action']?.toString() ?? 'SYSTEM_EVENT';
    final user = log['user']?['name']?.toString() ?? 'System / Automation';
    final userRole = log['user']?['role']?.toString().toUpperCase() ?? 'SYS';
    final targetType = log['target_type']?.toString() ?? 'Unknown Entity';
    final details = log['details'] is Map ? log['details'] : {};
    final comment = details['comment']?.toString() ?? '';

    final dt = DateTime.tryParse(log['created_at']?.toString() ?? '');
    final timeStr = dt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(dt)
        : 'Unknown Time';

    Color actColor = AppColors.elitePrimary;
    IconData actIcon = Icons.info_outline_rounded;

    if (action.contains('CREATE') ||
        action.contains('ADD') ||
        action.contains('REGISTER')) {
      actColor = AppColors.mintGreen;
      actIcon = Icons.add_circle_outline_rounded;
    } else if (action.contains('UPDATE') ||
        action.contains('EDIT') ||
        action.contains('VERIFIED')) {
      actColor = AppColors.moltenAmber;
      actIcon = Icons.edit_note_rounded;
    } else if (action.contains('DELETE') ||
        action.contains('REMOVE') ||
        action.contains('BLOCK')) {
      actColor = AppColors.coralRed;
      actIcon = Icons.remove_circle_outline_rounded;
    } else if (action.contains('LOGIN') || action.contains('AUTH')) {
      actColor = AppColors.electricBlue;
      actIcon = Icons.login_rounded;
    } else if (action.contains('PAYMENT') || action.contains('FEE')) {
      actColor = AppColors.success;
      actIcon = Icons.payments_outlined;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: actColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: actColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(actIcon, size: 14, color: actColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDark ? AppColors.darkBorder.withValues(alpha: 0.5) : Colors.black12,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: CPGlassCard(
                isDark: isDark,
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            action.replaceAll('_', ' ').toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: actColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white12
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            targetType.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: isDark ? AppColors.paleSlate2 : Colors.black54,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_pin_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            userRole,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '"$comment"',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: isDark ? AppColors.paleSlate2 : Colors.black87,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: isDark ? AppColors.darkBorder : Colors.black38,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.paleSlate2 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

