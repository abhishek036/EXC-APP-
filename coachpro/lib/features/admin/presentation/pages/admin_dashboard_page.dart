import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_shimmer.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../features/shared/presentation/widgets/global_search_overlay.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../data/repositories/admin_repository.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _adminRepo = sl<AdminRepository>();
  bool _loading = true;
  String _error = '';
  final int _unreadNotifications = 0;

  Map<String, dynamic> _stats = const {
    'students': 0, 'teachers': 0, 'batches': 0, 'revenue': 0.0, 'pending': 0.0,
  };
  int _overdueCount = 0;
  double _totalOverdue = 0;

  List<Map<String, dynamic>> _todaysClasses = const [];
  List<Map<String, dynamic>> _recentPayments = const [];
  List<Map<String, dynamic>> _absentToday = const [];

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
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toInt()}';
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final students = await _adminRepo.getStudents();
      final teachers = await _adminRepo.getTeachers();
      final batches = await _adminRepo.getBatches();
      final feeRecords = await _adminRepo.getFeeRecords();

      final activeStudents = students.where((s) {
        final status = (s['status'] ?? s['is_active'])?.toString().toLowerCase();
        return status == null || status == 'active' || status == 'true';
      }).length;

      final activeBatches = batches.where((b) => (b['is_active'] ?? b['isActive']) != false).length;

      double col = 0, pen = 0, overA = 0;
      int overC = 0;
      final paymentRows = <Map<String, dynamic>>[];

      for (final r in feeRecords) {
        final amt = _toDouble(r['final_amount'] ?? r['amount']);
        final pays = (r['payments'] as List?) ?? const [];
        final paid = pays.fold<double>(0, (sum, p) => sum + _toDouble((p as Map)['amount_paid']));
        final rem = (amt - paid).clamp(0, double.infinity);
        
        col += paid;
        if (rem > 0) pen += rem;
        if ((r['status'] ?? '').toString().toLowerCase() == 'overdue') {
          overC++; overA += rem;
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

      paymentRows.sort((a, b) => (b['date'] as DateTime? ?? DateTime(0)).compareTo(a['date'] as DateTime? ?? DateTime(0)));

      final todayCls = _buildTodayClasses(batches);
      final absentToday = await _buildAbsentTodayList(batches);

      if (!mounted) return;
      setState(() {
        _stats = {'students': activeStudents, 'teachers': teachers.length, 'batches': activeBatches, 'revenue': col, 'pending': pen};
        _overdueCount = overC; _totalOverdue = overA;
        _todaysClasses = todayCls; _recentPayments = paymentRows.take(5).toList(); _absentToday = absentToday;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = 'Data out of sync'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> _buildTodayClasses(List<Map<String, dynamic>> batches) {
    final today = DateTime.now().weekday % 7;
    return batches.where((b) {
      if ((b['is_active'] ?? b['isActive']) == false) return false;
      final days = (b['days_of_week'] as List?) ?? const [];
      return days.isEmpty || days.contains(today);
    }).map((b) => {
      'batchName': b['name'] ?? 'Batch',
      'teacherName': b['teacher_name'] ?? 'Faculty',
      'startTime': b['start_time'] ?? '',
      'room': b['room'] ?? '',
      'subject': b['subject'] ?? '',
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _buildAbsentTodayList(List<Map<String, dynamic>> batches) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final rows = <Map<String, dynamic>>[];
    for (final b in batches) {
      final id = (b['id'] ?? '').toString();
      if (id.isEmpty) continue;
      try {
        final sessions = await _adminRepo.getBatchAttendanceMonthly(batchId: id, month: now.month, year: now.year);
        for (final s in sessions) {
          if ((s['date'] ?? '').toString().startsWith(todayStr)) {
            for (final r in (s['student_records'] as List? ?? [])) {
              if (r['status']?.toString().toLowerCase() == 'absent') {
                rows.add({'name': r['student_name'] ?? 'Student', 'batch': b['name'] ?? 'Batch'});
              }
            }
          }
        }
      } catch (_) {}
    }
    return rows;
  }

  double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  DateTime? _parseDateTime(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(top: -100, right: -50, child: _glow(300, AppColors.elitePrimary.withValues(alpha: 0.1))),
            Positioned(bottom: 200, left: -100, child: _glow(400, AppColors.elitePurple.withValues(alpha: 0.05))),
            Positioned(top: 400, right: -150, child: _glow(250, AppColors.coralRed.withValues(alpha: 0.03))),
          ],
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
                    if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Center(child: Text(_error, style: GoogleFonts.inter(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)))),
                    const SizedBox(height: 32),
                    _buildSummaryStats(isDark),
                    const SizedBox(height: 32),
                    _buildQuickActions(isDark),
                    const SizedBox(height: 48),
                    _buildSectionHeader("Management Hub", () {}, isDark),
                    const SizedBox(height: 16),
                    _buildManagementHub(isDark),
                    const SizedBox(height: 40),
                    _buildOverdueBanner(isDark),
                    const SizedBox(height: 16),
                    _buildSectionHeader("Academic Flow", () => context.go('/admin/attendance'), isDark),
                    const SizedBox(height: 16),
                    _buildTodaysClasses(isDark),
                    const SizedBox(height: 40),
                    _buildSectionHeader("Revenue Stream", () => context.go('/admin/fees'), isDark),
                    const SizedBox(height: 16),
                    _buildRecentPayments(isDark),
                    const SizedBox(height: 40),
                    _buildSectionHeader("Activity Timeline", () {}, isDark),
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

  Widget _glow(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: size / 2)]));

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Row(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.premiumEliteGradient),
          child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), image: const DecorationImage(image: NetworkImage('https://i.pravatar.cc/150?img=12'), fit: BoxFit.cover))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_greeting, 👋', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.black38)),
              Text('Elite Admin', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.8)),
            ],
          ),
        ),
        _appBarAction(Icons.search_rounded, () { HapticFeedback.mediumImpact(); GlobalSearchOverlay.show(context); }, isDark),
        const SizedBox(width: 8),
        _appBarAction(Icons.notifications_none_rounded, () { HapticFeedback.mediumImpact(); context.go('/admin/notifications'); }, isDark, badge: _unreadNotifications > 0),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }

  Widget _appBarAction(IconData icon, VoidCallback onTap, bool isDark, {bool badge = false}) {
    return CPPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03))),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 21, color: isDark ? Colors.white : AppColors.deepNavy),
                if (badge) Positioned(top: 10, right: 10, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.elitePrimary, shape: BoxShape.circle, border: Border.all(color: isDark ? AppColors.eliteDarkBg : Colors.white, width: 2)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStats(bool isDark) {
    if (_loading) {
      return SizedBox(height: 120, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: 3, separatorBuilder: (_, _) => const SizedBox(width: 12), itemBuilder: (_, _) => CPShimmer(width: 160, height: 120, borderRadius: 28)));
    }
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _heroStat('COLLECTED REVENUE', _formatCurrency(_toDouble(_stats['revenue'])), AppColors.premiumEliteGradient),
          const SizedBox(width: 14),
          _glassStat('STUDENTS', '${_stats['students']}', AppColors.mintGreen, isDark, Icons.school_rounded),
          const SizedBox(width: 14),
          _glassStat('TOP FACULTY', '${_stats['teachers']}', AppColors.elitePurple, isDark, Icons.psychology_rounded),
          const SizedBox(width: 14),
          _glassStat('PENDING DUES', _formatCurrency(_toDouble(_stats['pending'])), AppColors.coralRed, isDark, Icons.account_balance_wallet_rounded),
          const SizedBox(width: 14),
          _glassStat('BATCHES', '${_stats['batches']}', const Color(0xFF4C6EF5), isDark, Icons.groups_2_rounded),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _heroStat(String label, String value, Gradient gradient) {
    return Container(
      width: 170, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: AppColors.elitePrimary.withValues(alpha: 0.35), blurRadius: 25, offset: const Offset(0, 12))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.2)),
        ],
      ),
    );
  }

  Widget _glassStat(String label, String value, Color color, bool isDark, IconData icon) {
    return SizedBox(
      width: 160,
      child: CPGlassCard(
      isDark: isDark, padding: const EdgeInsets.all(18), borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1)),
              Icon(icon, size: 14, color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
        ],
      ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    final actions = [
      {'icon': Icons.fact_check_rounded, 'label': 'Attendance', 'color': AppColors.elitePrimary, 'route': '/admin/attendance'},
      {'icon': Icons.person_add_alt_1_rounded, 'label': 'Add Pupil', 'color': AppColors.mintGreen, 'route': '/admin/add-student'},
      {'icon': Icons.wallet_rounded, 'label': 'Payments', 'color': AppColors.moltenAmber, 'route': '/admin/fees'},
      {'icon': Icons.campaign_rounded, 'label': 'Announce', 'color': AppColors.elitePurple, 'route': '/admin/announcements'},
    ];
    return Row(
      children: actions.map((a) => Expanded(child: _quickActionItem(a['icon'] as IconData, a['label'] as String, a['color'] as Color, a['route'] as String, isDark))).toList(),
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms);
  }

  Widget _quickActionItem(IconData icon, String label, Color color, String route, bool isDark) {
    return CPPressable(
      onTap: () { HapticFeedback.lightImpact(); context.go(route); },
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(22), border: Border.all(color: color.withValues(alpha: 0.2), width: 1)),
            child: Icon(icon, size: 26, color: color),
          ),
          const SizedBox(height: 10),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.white60 : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildManagementHub(bool isDark) {
    final modules = [
      {'label': 'Academic Oversight', 'icon': Icons.auto_stories_rounded, 'color': AppColors.primary, 'route': '/admin/academics', 'desc': 'Doubts & Course Materials'},
      {'label': 'Human Capital', 'icon': Icons.badge_rounded, 'color': AppColors.mintGreen, 'route': '/admin/staff', 'desc': 'Staff & Payroll Management'},
      {'label': 'Certificate Studio', 'icon': Icons.workspace_premium_rounded, 'color': AppColors.moltenAmber, 'route': '/admin/certificates', 'desc': 'Mint Prestige Documents'},
      {'label': 'Security IAM', 'icon': Icons.shield_rounded, 'color': AppColors.coralRed, 'route': '/admin/users', 'desc': 'Access & Role Control'},
      {'label': 'Opportunity Pipeline', 'icon': Icons.radar_rounded, 'color': AppColors.elitePurple, 'route': '/admin/leads', 'desc': 'Lead & Conversion Tracking'},
      {'label': 'Global Broadcast', 'icon': Icons.sensors_rounded, 'color': AppColors.electricBlue, 'route': '/admin/announcements', 'desc': 'System-wide Notifications'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.1),
      itemCount: modules.length,
      itemBuilder: (ctx, i) {
        final m = modules[i];
        return CPPressable(
          onTap: () => context.go(m['route'] as String),
          child: CPGlassCard(
            isDark: isDark, padding: const EdgeInsets.all(16), borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (m['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 20)),
                const Spacer(),
                Text(m['label'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Text(m['desc'] as String, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: isDark ? Colors.white24 : Colors.black26), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ).animate(delay: (i * 30).ms).fadeIn().slideY(begin: 0.05);
      },
    );
  }

  Widget _buildActivityTimeline(bool isDark) {
    final activities = [
      {'title': 'New Admission Form', 'time': '2 mins ago', 'user': 'Priya Singh', 'type': 'admission'},
      {'title': 'Fee Payment Received', 'time': '15 mins ago', 'user': 'Rahul Verma', 'type': 'fee'},
      {'title': 'Attendance Synced', 'time': '1 hour ago', 'user': 'System', 'type': 'academic'},
    ];

    return Column(
      children: activities.map((a) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Column(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 3))),
                  Expanded(child: Container(width: 2, color: AppColors.primary.withValues(alpha: 0.1))),
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
                          Text(a['title'] as String, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.deepNavy)),
                          Text(a['time'] as String, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white24 : Colors.black26)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('By ${a['user']}', style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildOverdueBanner(bool isDark) {
    if (_overdueCount == 0) return const SizedBox.shrink();
    return CPGlassCard(
      isDark: isDark, padding: const EdgeInsets.all(20), borderRadius: 24,
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.priority_high_rounded, color: AppColors.error, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$_overdueCount Overdue Alerts', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.error, letterSpacing: -0.2)),
            Text('${_formatCurrency(_totalOverdue)} total overdue amount', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.w600)),
          ])),
          CPPressable(onTap: () => context.go('/admin/fees'), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.error, AppColors.error.withValues(alpha: 0.8)]), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppColors.error.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]), child: Text('RESOLVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)))),
        ],
      ),
    ).animate().shake(delay: 1.seconds);
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.6)),
        CPPressable(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppColors.elitePrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Row(children: [Text('Explore all', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.elitePrimary)), const SizedBox(width: 4), const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.elitePrimary)]))),
      ],
    );
  }

  Widget _buildTodaysClasses(bool isDark) {
    if (_todaysClasses.isEmpty) return _emptyCard("Academic schedule is clear today", isDark);
    return Column(children: _todaysClasses.take(3).map((c) => _classItem(c, isDark)).toList());
  }

  Widget _classItem(Map<String, dynamic> c, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CPGlassCard(
        isDark: isDark, padding: const EdgeInsets.all(16), borderRadius: 24,
        child: Row(
          children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16)), child: Center(child: Icon(Icons.timer_outlined, size: 20, color: isDark ? Colors.white38 : Colors.black38))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['batchName'], style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy)),
              const SizedBox(height: 2),
              Text('${c['teacherName']} • ${c['subject']}', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.w600)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text((c['startTime']?.toString() ?? '').split(' ')[0], style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.elitePrimary)),
              if (c['room']?.toString().isNotEmpty == true) Text('Room ${c['room']}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPayments(bool isDark) {
    if (_recentPayments.isEmpty) return _emptyCard("Revenue logs are waiting...", isDark);
    return SizedBox(height: 80, child: ListView.separated(scrollDirection: Axis.horizontal, clipBehavior: Clip.none, itemCount: _recentPayments.length, separatorBuilder: (_, _) => const SizedBox(width: 14), itemBuilder: (_, i) {
      final p = _recentPayments[i];
      return SizedBox(width: 240, child: CPGlassCard(isDark: isDark, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), borderRadius: 24, child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.credit_card_rounded, size: 18, color: AppColors.success)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(p['name'], style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(p['batch'], style: GoogleFonts.inter(fontSize: 10, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Text(_formatCurrency(_toDouble(p['amount'])), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.success)),
      ])),
    );
    }));
  }

  Widget _buildAbsentToday(bool isDark) {
    if (_absentToday.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionHeader("Critical Absences", () {}, isDark),
      const SizedBox(height: 16),
      ..._absentToday.take(3).map((a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: CPGlassCard(isDark: isDark, padding: const EdgeInsets.all(14), borderRadius: 20, child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle), child: Center(child: Text(a['name']?[0] ?? 'S', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.error)))),
        const SizedBox(width: 14),
        Expanded(child: Text(a['name'], style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.deepNavy))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)), child: Text(a['batch'], style: GoogleFonts.inter(fontSize: 10, color: isDark ? Colors.white38 : Colors.black54, fontWeight: FontWeight.w800))),
      ])))),
    ]);
  }

  Widget _emptyCard(String text, bool isDark) => CPGlassCard(isDark: isDark, padding: const EdgeInsets.all(32), borderRadius: 28, child: Center(child: Column(children: [Icon(Icons.inventory_2_outlined, size: 24, color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)), const SizedBox(height: 12), Text(text, style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white.withValues(alpha: 0.24) : Colors.black.withValues(alpha: 0.26), fontWeight: FontWeight.w600))])));
}
