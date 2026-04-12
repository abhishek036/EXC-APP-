import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/theme/theme_aware.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _adminRepo = sl<AdminRepository>();

  bool _isLoading = true;
  String _loadError = '';
  int _studentCount = 0;
  int _teacherCount = 0;
  int _batchCount = 0;
  int _examCount = 0;
  List<Map<String, dynamic>> _feeRecords = [];
  List<Map<String, dynamic>> _upcomingExams = [];

  double _totalCollected = 0;
  double _totalPending = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = '';
    });

    var hasPartialFailure = false;
    List<Map<String, dynamic>> students = [];
    List<Map<String, dynamic>> teachers = [];
    List<Map<String, dynamic>> batches = [];
    List<Map<String, dynamic>> fees = [];
    List<Map<String, dynamic>> exams = [];

    try {
      students = await _adminRepo.getStudents();
    } catch (_) {
      hasPartialFailure = true;
    }

    try {
      teachers = await _adminRepo.getTeachers();
    } catch (_) {
      hasPartialFailure = true;
    }

    try {
      batches = await _adminRepo.getBatches();
    } catch (_) {
      hasPartialFailure = true;
    }

    try {
      fees = await _adminRepo.getFeeRecords();
    } catch (_) {
      hasPartialFailure = true;
    }

    try {
      exams = await _adminRepo.getExams();
    } catch (_) {
      hasPartialFailure = true;
    }

    try {
      double collected = 0;
      double pending = 0;

      for (var f in fees) {
        final paid = _paidAmount(f);
        final total = _toDouble(
          f['final_amount'] ?? f['totalAmount'] ?? f['amount'],
        );
        collected += paid;
        pending += (total - paid).clamp(0, double.infinity);
      }

      final upcomingExams = exams
          .where((exam) {
            final status = (exam['status'] ?? '').toString().toLowerCase();
            return status != 'completed' && status != 'cancelled';
          })
          .map((exam) {
            final batch = exam['batch'] is Map<String, dynamic>
                ? exam['batch'] as Map<String, dynamic>
                : <String, dynamic>{};
            return {
              'name': (exam['name'] ?? 'Assessment Event').toString(),
              'date':
                  (exam['date'] ?? exam['scheduled_at'] ?? 'TBD').toString(),
              'batchName':
                  (exam['batchName'] ?? batch['name'] ?? 'General').toString(),
            };
          })
          .take(8)
          .toList();

      if (mounted) {
        setState(() {
          _studentCount = students.length;
          _teacherCount = teachers.length;
          _batchCount = batches.length;
          _upcomingExams = upcomingExams;
          _examCount = upcomingExams.length;
          _feeRecords = fees;
          _totalCollected = collected;
          _totalPending = pending;
          _loadError = hasPartialFailure
              ? 'Some report data may be stale. Pull to refresh.'
              : '';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Unable to load reports';
        });
      }
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // Removed _glow method

  String _getInitial(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(' ');
    final lastWord = parts.isNotEmpty ? parts.last : name;
    return lastWord.isNotEmpty ? lastWord[0] : '?';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.eliteDarkBg
            : AppColors.eliteLightBg,
        appBar: AppBar(
          title: Text(
            'Analytics Engine',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.deepNavy,
              letterSpacing: -1,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.electricBlue),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  floating: true,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: Text(
                    'Analytics Engine',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: isDark ? Colors.white : AppColors.deepNavy,
                      letterSpacing: -1,
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/admin/data-export');
                      },
                      icon: Icon(
                        Icons.get_app_rounded,
                        color: isDark ? Colors.white : AppColors.deepNavy,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(60),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          border: Border.all(
                            color: const Color(0xFF354388),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF354388),
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                        child: TabBar(
                          controller: _tabCtrl,
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: const Color(0xFFBDAE18),
                            border: Border.all(
                              color: const Color(0xFF354388),
                              width: 2,
                            ),
                          ),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          labelColor: const Color(0xFF354388),
                          unselectedLabelColor: const Color(
                            0xFF354388,
                          ).withValues(alpha: 0.5),
                          tabs: const [
                            Tab(text: 'OVERVIEW'),
                            Tab(text: 'FINANCIAL'),
                            Tab(text: 'ACADEMIC'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabCtrl,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildOverviewTab(isDark),
                  _buildFinanceTab(isDark),
                  _buildAcademicTab(isDark),
                ],
              ),
            ),
          ),
          if (_loadError.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildLoadWarning(isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadWarning(bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: isDark ? Colors.black.withValues(alpha: 0.86) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _loadError,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : AppColors.deepNavy,
            ),
          ),
        ),
        TextButton(
          onPressed: _loadData,
          child: Text(
            'Retry',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: AppColors.elitePrimary,
            ),
          ),
        ),
      ],
    ),
  );

  // ── OVERVIEW TAB ──
  Widget _buildOverviewTab(bool isDark) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRevenueCard(isDark),
        const SizedBox(height: 16),
        _buildQuickStats(isDark),
        const SizedBox(height: 20),
        _buildEnrollmentTrend(isDark),
        const SizedBox(height: 20),
        _buildAttendanceTrend(isDark),
        const SizedBox(height: 20),
        _buildRecentActions(isDark),
        const SizedBox(height: 24),
      ],
    ),
  );

  // ── FINANCE TAB ──
  Widget _buildFinanceTab(bool isDark) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRevenueCard(isDark),
        const SizedBox(height: 16),
        _buildMonthlyRevenue(isDark),
        const SizedBox(height: 20),
        _buildFeeBreakdown(isDark),
        const SizedBox(height: 20),
        _buildCollectionRate(isDark),
        const SizedBox(height: 20),
        _buildPendingFees(isDark),
        const SizedBox(height: 24),
      ],
    ),
  );

  // ── ACADEMIC TAB ──
  Widget _buildAcademicTab(bool isDark) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBatchPerformance(isDark),
        const SizedBox(height: 20),
        _buildSubjectAnalysis(isDark),
        const SizedBox(height: 20),
        _buildTeacherWorkload(isDark),
        const SizedBox(height: 20),
        _buildExamTimeline(isDark),
        const SizedBox(height: 24),
      ],
    ),
  );

  Widget _buildRevenueCard(bool isDark) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: const Color(0xFF354388),
      border: Border.all(color: const Color(0xFF354388), width: 3),
      boxShadow: const [
        BoxShadow(color: Color(0xFF354388), offset: Offset(4, 4)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'TOTAL REVENUE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white70,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${(_totalCollected + _totalPending).toStringAsFixed(0)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFBDAE18),
                border: Border.all(color: const Color(0xFF354388), width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF354388), offset: Offset(2, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF354388),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF354388),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        const SizedBox(height: 20),
        Row(
          children: [
            _heroStat(
              'Collected',
              '₹${_totalCollected.toStringAsFixed(0)}',
              Icons.check_circle_rounded,
              AppColors.mintGreen,
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withValues(alpha: 0.2),
              margin: const EdgeInsets.symmetric(horizontal: 20),
            ),
            _heroStat(
              'Pending',
              '₹${_totalPending.toStringAsFixed(0)}',
              Icons.pending_rounded,
              AppColors.moltenAmber,
            ),
          ],
        ),
      ],
    ),
  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05);

  Widget _heroStat(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white54,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );

  Widget _buildQuickStats(bool isDark) => Row(
    children: [
      _quickStat(
        'Students',
        '$_studentCount',
        Icons.people_alt_rounded,
        AppColors.electricBlue,
        isDark,
      ),
      const SizedBox(width: 10),
      _quickStat(
        'Teachers',
        '$_teacherCount',
        Icons.school_rounded,
        AppColors.teacherTeal,
        isDark,
      ),
      const SizedBox(width: 10),
      _quickStat(
        'Batches',
        '$_batchCount',
        Icons.layers_rounded,
        AppColors.moltenAmber,
        isDark,
      ),
      const SizedBox(width: 10),
      _quickStat(
        'Exams',
        '$_examCount',
        Icons.quiz_rounded,
        AppColors.parentPurple,
        isDark,
      ),
    ],
  ).animate(delay: 200.ms).fadeIn();

  Widget _quickStat(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) => Expanded(
    child: CPGlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.deepNavy,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildMonthlyRevenue(bool isDark) => CPGlassCard(
    isDark: isDark,
    padding: const EdgeInsets.all(28),
    borderRadius: 32,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cashflow Projections',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.deepNavy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 300,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35,
                    interval: 100,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}k',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      const months = ['Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb'];
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          v.toInt() < months.length ? months[v.toInt()] : '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 100,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.12),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              barGroups: [180, 220, 195, 250, 210, 240]
                  .asMap()
                  .entries
                  .map(
                    (e) => BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.toDouble(),
                          width: 14,
                          borderRadius: BorderRadius.zero,
                          color: const Color(0xFF354388),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    ),
  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.05);

  Widget _buildBatchPerformance(bool isDark) => CPGlassCard(
    isDark: isDark,
    padding: const EdgeInsets.all(28),
    borderRadius: 32,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Batch Metrics',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.deepNavy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        _batchRow('JEE Sprint', 88, AppColors.electricBlue, isDark),
        const SizedBox(height: 16),
        _batchRow('NEET Elite', 79, AppColors.elitePurple, isDark),
        const SizedBox(height: 16),
        _batchRow('Foundation X', 85, AppColors.mintGreen, isDark),
        const SizedBox(height: 16),
        _batchRow('Crash Course', 72, AppColors.moltenAmber, isDark),
      ],
    ),
  ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.05);

  Widget _batchRow(String name, int pct, Color color, bool isDark) => Row(
    children: [
      SizedBox(
        width: 100,
        child: Text(
          name.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white70 : Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
      ),
      Expanded(
        child: Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: pct / 100,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 16),
      SizedBox(
        width: 32,
        child: Text(
          '$pct%',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.right,
        ),
      ),
    ],
  );

  Widget _buildRecentActions(bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Systems Activity Log',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white : AppColors.deepNavy,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 16),
      ..._activities.asMap().entries.map(
        (e) => _activityRow(e.value, e.key, isDark),
      ),
    ],
  ).animate(delay: 500.ms).fadeIn();

  final _activities = [
    {
      'icon': Icons.payment_rounded,
      'text': 'Fee payment verified & mapped',
      'time': 'Live',
      'color': AppColors.mintGreen,
    },
    {
      'icon': Icons.person_add_rounded,
      'text': 'Student profile provisioned',
      'time': 'Live',
      'color': AppColors.electricBlue,
    },
    {
      'icon': Icons.quiz_rounded,
      'text': 'Assessment schedule updated',
      'time': 'Live',
      'color': AppColors.physics,
    },
    {
      'icon': Icons.notifications_rounded,
      'text': 'Announcements delivered successfully',
      'time': 'Live',
      'color': AppColors.moltenAmber,
    },
  ];

  Widget _activityRow(Map<String, dynamic> item, int i, bool isDark) =>
      Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              border: Border.all(color: const Color(0xFF354388), width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0xFF354388), offset: Offset(2, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    size: 20,
                    color: item['color'] as Color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item['text'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  item['time'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white38 : Colors.black38,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          )
          .animate(delay: Duration(milliseconds: 550 + i * 60))
          .fadeIn()
          .slideX(begin: 0.05, end: 0);

  // ── ENROLLMENT TREND ──
  Widget _buildEnrollmentTrend(bool isDark) => CPGlassCard(
    isDark: isDark,
    padding: const EdgeInsets.all(28),
    borderRadius: 32,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Enrollment Trajectory',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.deepNavy,
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.mintGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'LIVE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: AppColors.mintGreen,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.12),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 20,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      const m = ['Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb'];
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          v.toInt() < m.length ? m[v.toInt()] : '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: 100, // scaled roughly
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    FlSpot(0, 10),
                    FlSpot(1, 15),
                    FlSpot(2, 25),
                    FlSpot(3, 40),
                    FlSpot(4, 60),
                    FlSpot(5, _studentCount.toDouble()),
                  ],
                  isCurved: false,
                  color: const Color(0xFF354388),
                  barWidth: 4,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (s, d, bar, i) => FlDotCirclePainter(
                      radius: 4,
                      color: const Color(0xFFFFFFFF),
                      strokeWidth: 2,
                      strokeColor: const Color(0xFF354388),
                    ),
                  ),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.05);

  // ── ATTENDANCE TREND ──
  Widget _buildAttendanceTrend(bool isDark) => CPGlassCard(
    isDark: isDark,
    padding: const EdgeInsets.all(28),
    borderRadius: 32,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Attendance Pulse',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.deepNavy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        ...[
          {'day': 'Monday', 'present': 92, 'total': 100},
          {'day': 'Tuesday', 'present': 88, 'total': 100},
          {'day': 'Wednesday', 'present': 95, 'total': 100},
          {'day': 'Thursday', 'present': 85, 'total': 100},
          {'day': 'Friday', 'present': 94, 'total': 100},
        ].map((d) {
          final pct = ((d['present'] as int) / (d['total'] as int) * 100)
              .round();
          final color = pct >= 90
              ? AppColors.mintGreen
              : pct >= 80
              ? AppColors.moltenAmber
              : AppColors.coralRed;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    (d['day'] as String).toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white70 : Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: pct / 100,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 32,
                  child: Text(
                    '$pct%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.05);

  // ── FEE BREAKDOWN PIE ──
  Widget _buildFeeBreakdown(bool isDark) => CPGlassCard(
    isDark: isDark,
    padding: const EdgeInsets.all(28),
    borderRadius: 32,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue Distribution',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.deepNavy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 36,
                    sections: [
                      PieChartSectionData(
                        value: 45,
                        title: '45%',
                        color: AppColors.electricBlue,
                        radius: 50,
                        titleStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      PieChartSectionData(
                        value: 25,
                        title: '25%',
                        color: AppColors.mintGreen,
                        radius: 45,
                        titleStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      PieChartSectionData(
                        value: 18,
                        title: '18%',
                        color: AppColors.moltenAmber,
                        radius: 42,
                        titleStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      PieChartSectionData(
                        value: 12,
                        title: '12%',
                        color: AppColors.coralRed,
                        radius: 40,
                        titleStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pieLegend(AppColors.electricBlue, 'Tuition Fee', isDark),
                  const SizedBox(height: 12),
                  _pieLegend(AppColors.mintGreen, 'Test Series', isDark),
                  const SizedBox(height: 12),
                  _pieLegend(AppColors.moltenAmber, 'Study Material', isDark),
                  const SizedBox(height: 12),
                  _pieLegend(AppColors.coralRed, 'Other Fees', isDark),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.05);

  Widget _pieLegend(Color color, String label, bool isDark) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 0),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    ],
  );

  // ── COLLECTION RATE ──
  Widget _buildCollectionRate(bool isDark) => CPGlassCard(
    isDark: isDark,
    padding: const EdgeInsets.all(28),
    borderRadius: 32,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collection Velocity',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.deepNavy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        ...[
          {
            'month': 'Current',
            'rate':
                ((_totalCollected /
                            (_totalCollected + _totalPending == 0
                                ? 1
                                : _totalCollected + _totalPending)) *
                        100)
                    .toInt(),
            'collected': '₹${_totalCollected.toStringAsFixed(0)}',
            'target':
                '₹${(_totalCollected + _totalPending).toStringAsFixed(0)}',
          },
        ].map((d) {
          final rate = d['rate'] as int;
          final color = rate >= 90
              ? AppColors.mintGreen
              : rate >= 80
              ? AppColors.moltenAmber
              : AppColors.coralRed;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      (d['month'] as String).toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white70 : Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$rate%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: rate / 100,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'COLLECTED: ${d['collected']}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white38 : Colors.black38,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'TOTAL: ${d['target']}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white38 : Colors.black38,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    ),
  ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.05);

  // ── PENDING FEES ──
  Widget _buildPendingFees(bool isDark) {
    final pending = _feeRecords
        .where((record) {
          final status = ((record['status'] ?? '') as String).toLowerCase();
          return status == 'pending' ||
              status == 'partial' ||
              status == 'overdue';
        })
        .take(5)
        .toList();

    return CPGlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(28),
      borderRadius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Critical Pending Accounts',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.deepNavy,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.coralRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LIVE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppColors.coralRed,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (pending.isEmpty)
            Text(
              'No pending fees found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ...pending.map((record) {
            final student = record['student'] as Map<String, dynamic>?;
            final batch = record['batch'] as Map<String, dynamic>?;
            final studentName = (student?['name'] ?? 'Student').toString();
            final batchName = (batch?['name'] ?? 'Batch').toString();
            final total = _toDouble(
              record['final_amount'] ??
                  record['totalAmount'] ??
                  record['amount'],
            );
            final paid = _paidAmount(record);
            final amount = (total - paid).clamp(0, double.infinity);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.coralRed.withValues(alpha: 0.1),
                    child: Text(
                      studentName
                          .split(' ')
                          .where((e) => e.isNotEmpty)
                          .map((w) => w[0])
                          .take(2)
                          .join(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.coralRed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          batchName.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white38 : Colors.black38,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.coralRed,
                          letterSpacing: -1.0,
                        ),
                      ),
                      Text(
                        'PENDING',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: AppColors.coralRed.withValues(alpha: 0.8),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.05);
  }

  // ── SUBJECT ANALYSIS ──
  Widget _buildSubjectAnalysis(bool isDark) => CPGlassCard(
    isDark: isDark,
    padding: const EdgeInsets.all(28),
    borderRadius: 32,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject Mastery Indices',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.deepNavy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 25,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      const sub = ['PHY', 'CHE', 'MAT', 'BIO', 'ENG'];
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          v.toInt() < sub.length ? sub[v.toInt()] : '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.12),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              barGroups:
                  [
                        {'val': 78.0, 'color': AppColors.physics},
                        {'val': 72.0, 'color': AppColors.chemistry},
                        {'val': 68.0, 'color': AppColors.mathematics},
                        {'val': 82.0, 'color': AppColors.biology},
                        {'val': 85.0, 'color': AppColors.english},
                      ]
                      .asMap()
                      .entries
                      .map(
                        (e) => BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value['val'] as double,
                              width: 24,
                              borderRadius: BorderRadius.circular(6),
                              color: e.value['color'] as Color,
                            ),
                          ],
                        ),
                      )
                      .toList(),
            ),
          ),
        ),
      ],
    ),
  ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05);

  // ── TEACHER WORKLOAD ──
  Widget _buildTeacherWorkload(bool isDark) => CPGlassCard(
    isDark: isDark,
    padding: const EdgeInsets.all(28),
    borderRadius: 32,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Educator Workload Overview',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.deepNavy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        ...[
          {
            'name': 'Active Teacher Data',
            'subj': 'System Info',
            'classes': _batchCount,
            'students': _studentCount,
            'color': AppColors.physics,
          },
        ].map(
          (t) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (t['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _getInitial(t['name'] as String?),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: t['color'] as Color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['name'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        (t['subj'] as String).toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white38 : Colors.black38,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${t['classes']} CLASSES',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.deepNavy,
                      ),
                    ),
                    Text(
                      '${t['students']} STUDENTS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.05);

  // ── EXAM TIMELINE ──
  Widget _buildExamTimeline(bool isDark) {
    final exams = _upcomingExams;
    return CPGlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(28),
      borderRadius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assessment Logistics',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.deepNavy,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          if (exams.isEmpty)
            Text(
              'No upcoming assessments indexed',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ...exams.asMap().entries.map((e) {
            final ex = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.science_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      if (e.key < exams.length - 1)
                        Container(
                          width: 2,
                          height: 30,
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.12),
                          margin: const EdgeInsets.only(top: 8),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex['name'] as String? ?? 'Assessment Event',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ex['date'] ?? "TBD"} • ${(ex['batchName'] ?? "GENERAL").toUpperCase()}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white38 : Colors.black38,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.05);
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  double _paidAmount(Map<String, dynamic> record) {
    final payments = record['payments'] as List<dynamic>?;
    if (payments == null || payments.isEmpty) return 0;

    return payments.fold<double>(
      0,
      (sum, payment) =>
          sum + _toDouble((payment as Map<String, dynamic>)['amount_paid']),
    );
  }
}

