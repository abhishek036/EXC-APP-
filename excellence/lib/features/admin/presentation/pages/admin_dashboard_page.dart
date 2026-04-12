import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_shimmer.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_section_header.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../data/repositories/admin_repository.dart';

import '../../../../core/services/realtime_sync_service.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/cp_user_avatar.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _adminRepo = sl<AdminRepository>();
  final _realtime = sl<RealtimeSyncService>();
  final _scaffoldKey = GlobalKey<ScaffoldState>(); // ← Fix for hamburger
  StreamSubscription<Map<String, dynamic>>? _syncSub;
  bool _loading = true;
  String _error = '';
  final int _unreadNotifications = 0;

  Map<String, dynamic> _stats = const {
    'students': 0,
    'teachers': 0,
    'batches': 0,
    'revenue': 0.0,
    'pending': 0.0,
  };
  int _overdueCount = 0;
  double _totalOverdue = 0;
  int _pendingProofsCount = 0;

  List<Map<String, dynamic>> _todaysClasses = const [];
  List<Map<String, dynamic>> _recentPayments = const [];
  List<Map<String, dynamic>> _absentToday = const [];
  List<Map<String, dynamic>> _auditLogs = [];
  List<double> _revenueTrend = [];

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _initRealtime();
  }

  Future<void> _initRealtime() async {
    await _realtime.connect();
    if (!mounted) return;
    _syncSub?.cancel();
    _syncSub = _realtime.updates.listen((event) {
      if (!mounted) return;
      final type = (event['type'] ?? '').toString();
      if (type == 'dashboard_sync' || type == 'batch_sync') {
        _loadDashboard();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toInt()}';
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final students = await _adminRepo.getStudents();
      final teachers = await _adminRepo.getTeachers();
      final batches = await _adminRepo.getBatches();
      final feeRecords = await _adminRepo.getFeeRecords();
      final auditLogs = await _adminRepo
          .getAuditLogs(limit: 5)
          .catchError((_) => <Map<String, dynamic>>[]);

      final activeStudents = students.where((s) {
        final status = (s['status'] ?? s['is_active'])
            ?.toString()
            .toLowerCase();
        return status == null || status == 'active' || status == 'true';
      }).length;

      final activeBatches = batches
          .where((b) => (b['is_active'] ?? b['isActive']) != false)
          .length;

      double col = 0, pen = 0, overA = 0;
      int overC = 0;
      final paymentRows = <Map<String, dynamic>>[];

      for (final r in feeRecords) {
        final amt = _toDouble(r['final_amount'] ?? r['amount']);
        final pays = (r['payments'] as List?) ?? const [];
        final paid = pays.fold<double>(
          0,
          (sum, p) => sum + _toDouble((p as Map)['amount_paid']),
        );
        final rem = (amt - paid).clamp(0, double.infinity);

        col += paid;
        if (rem > 0) pen += rem;
        if ((r['status'] ?? '').toString().toLowerCase() == 'overdue') {
          overC++;
          overA += rem;
        }

        final stu = r['student'] is Map ? r['student'] as Map : {};
        final bat = r['batch'] is Map ? r['batch'] as Map : {};

        for (final p in pays) {
          if (p is Map) {
            paymentRows.add({
              'name': stu['name'] ?? 'Student',
              'batch': bat['name'] ?? 'Batch',
              'amount': _toDouble(p['amount_paid']),
              'mode': (p['payment_mode'] ?? '').toString(),
              'date': _parseDateTime(p['created_at'] ?? p['paid_at']),
            });
          }
        }
      }

      paymentRows.sort(
        (a, b) => (b['date'] as DateTime? ?? DateTime(0)).compareTo(
          a['date'] as DateTime? ?? DateTime(0),
        ),
      );

      final todayCls = _buildTodayClasses(batches);
      final absentToday = await _buildAbsentTodayList(batches);

      // Calculate revenue trend (monthly)
      final monthly = <int, double>{};
      final now = DateTime.now();
      for (final r in feeRecords) {
        final pays = (r['payments'] as List?) ?? const [];
        for (final p in pays) {
          if (p is Map) {
            final date = _parseDateTime(p['created_at'] ?? p['paid_at']);
            if (date != null && date.year == now.year) {
              monthly[date.month] =
                  (monthly[date.month] ?? 0) + _toDouble(p['amount_paid']);
            }
          }
        }
      }
      final trend = List.generate(6, (i) {
        final targetMonth = now.month - (5 - i);
        final m = targetMonth < 1 ? targetMonth + 12 : targetMonth;
        return monthly[m] ?? 0.0;
      });

      final pendingQueue = await _adminRepo.getFeeVerificationQueue(status: 'pending');

      if (!mounted) return;
      setState(() {
        _stats = {
          'students': activeStudents,
          'teachers': teachers.length,
          'batches': activeBatches,
          'revenue': col,
          'pending': pen,
        };
        _overdueCount = overC;
        _totalOverdue = overA;
        _pendingProofsCount = pendingQueue.length;
        _todaysClasses = todayCls;
        _recentPayments = paymentRows.take(5).toList();
        _absentToday = absentToday;
        _auditLogs = auditLogs;
        _revenueTrend = trend;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not refresh dashboard data';
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _buildTodayClasses(
    List<Map<String, dynamic>> batches,
  ) {
    final today = DateTime.now().weekday % 7;
    return batches
        .where((b) {
          if ((b['is_active'] ?? b['isActive']) == false) return false;
          final days = _normalizeDaysOfWeek(b['days_of_week']);
          return days.isEmpty || days.contains(today);
        })
        .map(
          (b) => {
            'batchName': b['name'] ?? 'Batch',
            'teacherName': b['teacher_name'] ?? 'Faculty',
            'startTime': b['start_time'] ?? '',
            'room': b['room'] ?? '',
            'subject': b['subject'] ?? '',
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _buildAbsentTodayList(
    List<Map<String, dynamic>> batches,
  ) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final rows = <Map<String, dynamic>>[];
    for (final b in batches) {
      final id = (b['id'] ?? '').toString();
      if (id.isEmpty) continue;
      try {
        final sessions = await _adminRepo.getBatchAttendanceMonthly(
          batchId: id,
          month: now.month,
          year: now.year,
        );
        for (final s in sessions) {
          if ((s['date'] ?? '').toString().startsWith(todayStr)) {
            for (final r in (s['student_records'] as List? ?? [])) {
              if (r['status']?.toString().toLowerCase() == 'absent') {
                rows.add({
                  'name': r['student_name'] ?? 'Student',
                  'batch': b['name'] ?? 'Batch',
                });
              }
            }
          }
        }
      } catch (_) {}
    }
    return rows;
  }

  double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  DateTime? _parseDateTime(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  List<int> _normalizeDaysOfWeek(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((value) {
          if (value is int) return value;
          if (value is num) return value.toInt();
          return int.tryParse(value.toString());
        })
        .whereType<int>()
        .toList();
  }

  String _formatTimeLabel(dynamic raw) {
    final source = (raw ?? '').toString().trim();
    if (source.isEmpty) return '--:--';

    final parsed = DateTime.tryParse(source);
    if (parsed != null) {
      return DateFormat('hh:mm a').format(parsed);
    }

    final parts = source.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        final fallback = DateTime(2000, 1, 1, hour, minute);
        return DateFormat('hh:mm a').format(fallback);
      }
    }

    return source;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Scaffold(
      key: _scaffoldKey, // ← Required for openDrawer to work
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      drawer: _buildHamburgerMenu(context, isDark),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.elitePrimary,
              displacement: 20,
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildAppBar(context, isDark),
                    if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                _error,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _loadDashboard,
                              child: Text(
                                'Retry',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.elitePrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),
                    _buildSummaryStats(isDark),
                    const SizedBox(height: 32),
                    _buildRevenueChart(isDark),
                    const SizedBox(height: 32),
                    _buildQuickActions(isDark),
                    const SizedBox(height: 48),
                    _buildSectionHeader("Management Hub", () {}, isDark),
                    const SizedBox(height: 16),
                    _buildManagementHub(isDark),
                    const SizedBox(height: 40),
                    _buildOverdueBanner(isDark),
                    const SizedBox(height: 16),
                    _buildSectionHeader(
                      "Academic Flow",
                      () => context.push('/admin/attendance'),
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildTodaysClasses(isDark),
                    const SizedBox(height: 40),
                    _buildSectionHeader(
                      "Revenue Stream",
                      () => context.push('/admin/fees'),
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildRecentPayments(isDark),
                    const SizedBox(height: 40),
                    _buildSectionHeader(
                      "Activity Timeline",
                      () => context.push('/admin/audit-logs'),
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildActivityTimeline(isDark),
                    const SizedBox(height: 48),
                    _buildAbsentToday(isDark),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHamburgerMenu(BuildContext context, bool isDark) {
    final authState = context.read<AuthBloc>().state;
    final userName = authState is AuthAuthenticated
        ? authState.user.name
        : 'Admin';
    final avatarUrl = authState is AuthAuthenticated
        ? authState.user.avatarUrl
        : null;
    return Drawer(
      backgroundColor: isDark ? AppColors.eliteDarkBg : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            CPPressable(
              onTap: () {
                Navigator.pop(context);
                context.push('/admin/profile');
              },
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    CpUserAvatar(
                      name: userName,
                      avatarUrl: avatarUrl,
                      size: 54,
                      showShadow: false,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.elitePrimary,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'Tap to edit profile',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.elitePrimary.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit_rounded,
                                size: 12,
                                color: AppColors.elitePrimary.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: AppColors.elitePrimary, height: 1),
            _drawerItem(Icons.sync_rounded, 'Global Syncing', () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Syncing all data...',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: const Color(0xFF354388),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            }),
            _drawerItem(Icons.settings_rounded, 'App Settings', () {
              Navigator.pop(context);
              context.push('/admin/settings');
            }),
            _drawerItem(Icons.headset_mic_rounded, 'Support & Help', () {
              Navigator.pop(context);
              context.push('/admin/notifications');
            }),
            _drawerItem(Icons.bolt_rounded, 'Quick Shortcuts', () {
              Navigator.pop(context);
              context.push('/admin/auto-notifications');
            }),
            const Spacer(),
            const Divider(color: AppColors.elitePrimary, height: 1),
            _drawerItem(Icons.logout_rounded, 'Sign Out', () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(AuthLogoutRequested());
            }, isDestructive: true),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.coralRed : AppColors.elitePrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Removed _glow method as it is not used in Neo-Brutalism

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        String userName = 'Admin';
        String? avatarUrl;

        if (state is AuthAuthenticated) {
          userName = state.user.name;
          avatarUrl = state.user.avatarUrl;
        }

        return Row(
          children: [
            CPPressable(
              onTap: () {
                HapticFeedback.lightImpact();
                _scaffoldKey.currentState?.openDrawer();
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 12, top: 4, bottom: 4),
                child: Icon(
                  Icons.menu_rounded,
                  color: AppColors.elitePrimary,
                  size: 28,
                ),
              ),
            ),
            CPPressable(
              onTap: () => context.push('/admin/profile'),
              child: CpUserAvatar(
                name: userName,
                avatarUrl: avatarUrl,
                size: 44,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_greeting, 👋',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  Text(
                    userName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.deepNavy,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            _appBarAction(
              Icons.notifications_none_rounded,
              () {
                HapticFeedback.mediumImpact();
                context.push('/admin/notifications');
              },
              isDark,
              badge: _unreadNotifications > 0,
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
      },
    );
  }

  Widget _appBarAction(
    IconData icon,
    VoidCallback onTap,
    bool isDark, {
    bool badge = false,
  }) {
    return CPPressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppColors.elitePrimary : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(2, 2)),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 21, color: AppColors.elitePrimary),
            if (badge)
              const Positioned(
                top: 8,
                right: 8,
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.coralRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStats(bool isDark) {
    if (_loading) {
      return SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) =>
              CPShimmer(width: 160, height: 120, borderRadius: 28),
        ),
      );
    }
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.9, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SizedBox(
        height: 120,
        child: ListView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(right: 32),
          children: [
            _heroStat(
              'COLLECTED REVENUE',
              _formatCurrency(_toDouble(_stats['revenue'])),
              AppColors.premiumEliteGradient,
            ),
            const SizedBox(width: 14),
            _glassStat(
              'STUDENTS',
              '${_stats['students']}',
              AppColors.mintGreen,
              isDark,
              Icons.school_rounded,
            ),
            const SizedBox(width: 14),
            _glassStat(
              'TOP FACULTY',
              '${_stats['teachers']}',
              AppColors.elitePurple,
              isDark,
              Icons.psychology_rounded,
            ),
            const SizedBox(width: 14),
            _glassStat(
              'PENDING DUES',
              _formatCurrency(_toDouble(_stats['pending'])),
              AppColors.coralRed,
              isDark,
              Icons.account_balance_wallet_rounded,
            ),
            const SizedBox(width: 14),
            _glassStat(
              'VERIFY PROOFS',
              '$_pendingProofsCount',
              AppColors.moltenAmber,
              isDark,
              Icons.fact_check_outlined,
              onTap: () => context.push('/admin/fee-payment'),
            ),
            const SizedBox(width: 14),
            _glassStat(
              'BATCHES',
              '${_stats['batches']}',
              AppColors.elitePrimary,
              isDark,
              Icons.groups_2_rounded,
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _heroStat(String label, String value, Gradient gradient) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.elitePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.moltenAmber,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.trending_up_rounded,
                size: 16,
                color: AppColors.moltenAmber,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassStat(
    String label,
    String value,
    Color color,
    bool isDark,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return CPPressable(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.eliteDarkBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: [
            if (onTap != null)
              BoxShadow(color: color, offset: const Offset(4, 4))
            else
              const BoxShadow(color: Colors.black, offset: Offset(4, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.elitePrimary.withValues(alpha: 0.65),
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.elitePrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.elitePrimary.withValues(alpha: 0.65),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 62,
              child: CPPressable(
                onTap: () => context.push('/admin/add-student'),
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF354388),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Add Student',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Enroll new student',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 38,
              child: CPPressable(
                onTap: () => context.push('/admin/fees'),
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.eliteDarkBg : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.currency_rupee_rounded,
                        size: 22,
                        color: Color(0xFF354388),
                      ),
                      const Spacer(),
                      Text(
                        'Collect Fee',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.elitePrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 38,
              child: CPPressable(
                onTap: () => context.push('/admin/attendance'),
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.eliteDarkBg : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.fact_check_rounded,
                        size: 22,
                        color: Color(0xFFB6231B),
                      ),
                      const Spacer(),
                      Text(
                        'Attendance',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.elitePrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 62,
              child: CPPressable(
                onTap: () => context.push('/admin/announcements'),
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.eliteDarkBg : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.eliteLightBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: AppColors.moltenAmber,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Announce',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.elitePrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Broadcast message',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppColors.elitePrimary.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms);
  }

  Widget _buildManagementHub(bool isDark) {
    final modules = [
      {
        'label': 'Teachers',
        'icon': Icons.psychology_rounded,
        'color': AppColors.elitePrimary,
        'route': '/admin/teachers',
        'desc': 'Faculty Management',
        'stat': '${_stats['teachers']} Active',
      },
      {
        'label': 'Courses & Doubts',
        'icon': Icons.auto_stories_rounded,
        'color': AppColors.elitePrimary,
        'route': '/admin/academics',
        'desc': 'Manage materials',
        'stat': '8 active',
      },
      {
        'label': 'Human Capital',
        'icon': Icons.badge_rounded,
        'color': AppColors.moltenAmber,
        'route': '/admin/staff',
        'desc': 'Staff & Payroll',
        'stat': '3 departments',
      },
      {
        'label': 'Certificate Studio',
        'icon': Icons.workspace_premium_rounded,
        'color': AppColors.elitePrimary,
        'route': '/admin/certificates',
        'desc': 'Mint Documents',
        'stat': '110 minted',
      },
      {
        'label': 'Security IAM',
        'icon': Icons.shield_rounded,
        'color': AppColors.coralRed,
        'route': '/admin/users',
        'desc': 'Role Control',
        'stat': '2 layers',
      },
      {
        'label': 'Opportunity Pipeline',
        'icon': Icons.radar_rounded,
        'color': AppColors.elitePrimary,
        'route': '/admin/leads',
        'desc': 'Lead Tracking',
        'stat': '23 open',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15, // Adjusted to be shorter
      ),
      itemCount: modules.length,
      itemBuilder: (ctx, i) {
        final m = modules[i];
        final col = m['color'] as Color;
        return CPPressable(
          onTap: () => context.push(m['route'] as String),
          child: Container(
            padding: const EdgeInsets.all(14), // Reduced from 16
            decoration: BoxDecoration(
              color: isDark ? AppColors.eliteDarkBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(4, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center, // Vertically centered
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 36,
                      height: 36, // Sightly smaller
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(m['icon'] as IconData, color: col, size: 18),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.elitePrimary.withValues(alpha: 0.65),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  m['label'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.elitePrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  m['desc'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.elitePrimary.withValues(alpha: 0.65),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  m['stat'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: col,
                  ),
                ),
              ],
            ),
          ),
        ).animate(delay: (i * 30).ms).fadeIn().slideY(begin: 0.05);
      },
    );
  }

  Widget _buildActivityTimeline(bool isDark) {
    if (_loading) {
      return Column(
        children: List.generate(
          2,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: CPShimmer(
              width: double.infinity,
              height: 100,
              borderRadius: 24,
            ),
          ),
        ),
      );
    }
    if (_auditLogs.isEmpty) {
      return _emptyCard("No recent activities recorded", isDark);
    }

    return Column(
      children: _auditLogs.map((log) {
        final title = log['action'] ?? 'Sys Action';
        final user = log['user']?['name'] ?? 'System';
        final routeObj = log['target_type'];
        final details = log['details'] is Map
            ? (log['details']['comment'] ?? '')
            : '';

        final dt = DateTime.tryParse(log['created_at']?.toString() ?? '');
        final timeStr = dt != null
            ? DateFormat('MMM d, h:mm a').format(dt)
            : 'Mins ago';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.moltenAmber.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.moltenAmber,
                          width: 3,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: AppColors.moltenAmber.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              title
                                  .toString()
                                  .replaceAll('_', ' ')
                                  .toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.deepNavy,
                              ),
                            ),
                            Text(
                              timeStr,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'By $user',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.black45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (routeObj != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  routeObj.toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (details.toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            details.toString(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOverdueBanner(bool isDark) {
    if (_overdueCount == 0) return const SizedBox.shrink();
    return CPGlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.priority_high_rounded,
              color: AppColors.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_overdueCount Overdue Alerts',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.error,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  '${_formatCurrency(_totalOverdue)} total overdue amount',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          CPPressable(
            onTap: () => context.push('/admin/fees'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF354388),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.3),
                    blurRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'RESOLVE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().shake(delay: 1.seconds);
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap, bool isDark) {
    return CPSectionHeader(
      title: title,
      actionLabel: 'Explore all',
      onAction: onTap,
    );
  }

  Widget _buildTodaysClasses(bool isDark) {
    if (_loading) {
      return Column(
        children: List.generate(
          2,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: CPShimmer(
              width: double.infinity,
              height: 90,
              borderRadius: 24,
            ),
          ),
        ),
      );
    }
    if (_todaysClasses.isEmpty) {
      return _emptyCard("Academic schedule is clear today", isDark);
    }
    return Column(
      children: _todaysClasses
          .take(3)
          .map((c) => _classItem(c, isDark))
          .toList(),
    );
  }

  Widget _classItem(Map<String, dynamic> c, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CPGlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        borderRadius: 24,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c['batchName'],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${c['teacherName']} • ${c['subject']}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTimeLabel(c['startTime']),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.elitePrimary,
                  ),
                ),
                if (c['room']?.toString().isNotEmpty == true)
                  Text(
                    'Room ${c['room']}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white24
                          : Colors.black.withValues(alpha: 0.26),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPayments(bool isDark) {
    if (_loading) {
      return SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: 3,
          separatorBuilder: (context, index) => const SizedBox(width: 14),
          itemBuilder: (context, index) =>
              const CPShimmer(width: 240, height: 80, borderRadius: 24),
        ),
      );
    }
    if (_recentPayments.isEmpty) {
      return _emptyCard("Revenue logs are waiting...", isDark);
    }
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _recentPayments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final p = _recentPayments[i];
          return SizedBox(
            width: 240,
            child: CPGlassCard(
              isDark: isDark,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              borderRadius: 24,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.credit_card_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          p['name'],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.deepNavy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          p['batch'],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black45,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatCurrency(_toDouble(p['amount'])),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAbsentToday(bool isDark) {
    if (_absentToday.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Critical Absences", () {}, isDark),
        const SizedBox(height: 16),
        ..._absentToday
            .take(3)
            .map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CPGlassCard(
                  isDark: isDark,
                  padding: const EdgeInsets.all(14),
                  borderRadius: 20,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (a['name'] != null &&
                                    a['name'].toString().isNotEmpty)
                                ? a['name'].toString()[0].toUpperCase()
                                : 'S',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          a['name']?.toString().isEmpty == true
                              ? 'Unknown Student'
                              : a['name'],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.deepNavy,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          a['batch'],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black54,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildRevenueChart(bool isDark) {
    if (_loading || _revenueTrend.isEmpty || _revenueTrend.every((e) => e == 0)) {
      return const SizedBox.shrink();
    }

    final maxVal = _revenueTrend.reduce((a, b) => a > b ? a : b);
    final interval = maxVal > 0 ? (maxVal / 4).ceilToDouble() : 1000.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          "Financial Pulse",
          () => context.push('/admin/fees'),
          isDark,
        ),
        const SizedBox(height: 16),
        CPGlassCard(
          isDark: isDark,
          padding: const EdgeInsets.fromLTRB(10, 24, 24, 10),
          borderRadius: 32,
          child: SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= 6) {
                          return const SizedBox.shrink();
                        }
                        final months = [
                          'Jan',
                          'Feb',
                          'Mar',
                          'Apr',
                          'May',
                          'Jun',
                          'Jul',
                          'Aug',
                          'Sep',
                          'Oct',
                          'Nov',
                          'Dec',
                        ];
                        final now = DateTime.now();
                        final targetMonth = now.month - (5 - index);
                        final m = targetMonth < 1
                            ? targetMonth + 12
                            : targetMonth;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            months[m - 1],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatCurrency(value),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                maxY: maxVal * 1.2,
                barGroups: List.generate(6, (i) {
                  final isCurrent = i == 5;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _revenueTrend[i],
                        width: 14,
                        color: isCurrent
                            ? AppColors.moltenAmber
                            : AppColors.elitePrimary.withValues(alpha: 0.7),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _emptyCard(String text, bool isDark) => CPGlassCard(
    isDark: isDark,
    padding: const EdgeInsets.all(32),
    borderRadius: 28,
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 24,
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.24)
                  : Colors.black.withValues(alpha: 0.26),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

