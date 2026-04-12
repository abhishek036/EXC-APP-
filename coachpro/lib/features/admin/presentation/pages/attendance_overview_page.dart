import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/widgets/cp_glass_card.dart';

class AttendanceOverviewPage extends StatefulWidget {
  const AttendanceOverviewPage({super.key});

  @override
  State<AttendanceOverviewPage> createState() => _AttendanceOverviewPageState();
}

class _AttendanceOverviewPageState extends State<AttendanceOverviewPage> {
  final _adminRepo = sl<AdminRepository>();
  final _realtime = sl<RealtimeSyncService>();
  StreamSubscription<Map<String, dynamic>>? _syncSub;
  int _selectedBatch = 0;
  List<_BatchOption> _batchOptions = const [
    _BatchOption(id: null, name: 'All Cohorts'),
  ];
  bool _loading = true;
  bool _isNotifyingAll = false;
  String _error = '';
  List<Map<String, dynamic>> _todayRecords = [];
  List<double> _weeklyPercentages = List<double>.filled(6, 0);

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final reason = (event['reason'] ?? '').toString().toLowerCase();
      if (type == 'dashboard_sync' ||
          type == 'batch_sync' ||
          reason.contains('attendance')) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final batches = await _adminRepo.getBatches();
      final activeBatches = batches.where((batch) {
        final isActive = batch['is_active'] ?? batch['isActive'];
        return isActive == true || isActive == null;
      }).toList();

      final options = <_BatchOption>[
        const _BatchOption(id: null, name: 'All Cohorts'),
        ...activeBatches.map(
          (batch) => _BatchOption(
            id: (batch['id'] ?? '').toString(),
            name: (batch['name'] ?? 'Cohort').toString(),
          ),
        ),
      ];

      if (_selectedBatch >= options.length) _selectedBatch = 0;

      final stats = await _adminRepo.getAttendanceStats(
        batchId: options[_selectedBatch].id,
      );
      final todayData = stats['today'] as List<dynamic>? ?? [];
      final monthlyData = stats['monthly'] as List<dynamic>? ?? [];
      final weeklyRaw = stats['weekly'];

      final todayRecords = <Map<String, dynamic>>[];
      for (final session in todayData) {
        final records = session['records'] as List<dynamic>? ?? [];
        for (final r in records) {
          final rec = Map<String, dynamic>.from(r);
          rec['batchName'] = (session['batch']?['name'] ?? 'Cohort').toString();
          rec['studentName'] = (rec['student']?['name'] ?? 'Student')
              .toString();
          rec['studentId'] = (rec['student']?['id'] ?? '').toString();
          todayRecords.add(rec);
        }
      }

      final weekly = _resolveWeeklyPercentages(weeklyRaw, monthlyData);

      if (!mounted) return;
      setState(() {
        _batchOptions = options;
        _todayRecords = todayRecords;
        _weeklyPercentages = weekly;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Oversight sync failed';
        _loading = false;
      });
    }
  }

  List<double> _resolveWeeklyPercentages(dynamic weeklyRaw, List<dynamic> monthlyData) {
    if (weeklyRaw is List && weeklyRaw.length == 6) {
      final values = weeklyRaw
          .map((value) => value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0)
          .toList();
      return values;
    }
    return _processMonthlyStats(monthlyData);
  }

  List<double> _processMonthlyStats(List<dynamic> monthlyData) {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final presentByDay = List<int>.filled(6, 0);
    final totalByDay = List<int>.filled(6, 0);

    for (final record in monthlyData) {
      final session = record['session'] as Map<String, dynamic>?;
      if (session == null) continue;
      final date = DateTime.tryParse(
        (session['session_date'] ?? '').toString(),
      );
      if (date == null) continue;

      final diff = DateTime(
        date.year,
        date.month,
        date.day,
      ).difference(monday).inDays;
      if (diff < 0 || diff > 5) continue;

      final status = (record['status'] ?? '').toString().toLowerCase();
      totalByDay[diff]++;
      if (status == 'present' || status == 'late') presentByDay[diff]++;
    }

    return List<double>.generate(
      6,
      (i) => totalByDay[i] == 0 ? 0 : (presentByDay[i] / totalByDay[i]) * 100,
    );
  }

  Future<void> _notifyAllAbsentees(List<Map<String, dynamic>> absentees) async {
    if (absentees.isEmpty || _isNotifyingAll) return;
    try {
      setState(() => _isNotifyingAll = true);
      final uniqueStudents = absentees
          .map((item) => (item['studentId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final batches = absentees
          .map((item) => (item['batchName'] ?? '').toString())
          .where((name) => name.isNotEmpty)
          .toSet()
          .join(', ');

      await _adminRepo.sendNotification(
        title: 'Attendance Alert',
        body:
            'Absent students detected today (${uniqueStudents.length}). Please check attendance updates.',
        type: 'attendance',
        roleTarget: 'student',
        meta: {
          'reason': 'absence_alert',
          'student_ids': uniqueStudents,
          'batch_names': batches,
          'date': DateTime.now().toIso8601String(),
        },
      );
      if (!mounted) return;
      CPToast.success(context, 'Attendance alert sent');
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Failed to notify absentees');
    } finally {
      if (mounted) setState(() => _isNotifyingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, isDark),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.elitePrimary,
                    onRefresh: _loadData,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error.isNotEmpty
                        ? Center(
                            child: Text(
                              _error,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.error,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                _buildSummaryStats(isDark),
                                const SizedBox(height: 32),
                                _buildSectionHeader("Academic Filter", isDark),
                                const SizedBox(height: 16),
                                _buildBatchFilter(isDark),
                                const SizedBox(height: 32),
                                _buildSectionHeader("Weekly Flux", isDark),
                                const SizedBox(height: 16),
                                _buildWeeklyChart(isDark),
                                const SizedBox(height: 32),
                                _buildAbsentToday(isDark),
                                const SizedBox(height: 100),
                              ],
                            ),
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

  // Removed _glow method

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          CPPressable(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? Colors.white : AppColors.deepNavy,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Attendance Analytics',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.deepNavy,
                letterSpacing: -0.8,
              ),
            ),
          ),
          _appBarAction(Icons.refresh_rounded, _loadData, isDark),
        ],
      ),
    );
  }

  Widget _appBarAction(IconData icon, VoidCallback onTap, bool isDark) {
    return CPPressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFEEEDED),
          border: Border.all(color: const Color(0xFF0D1282), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF0D1282),
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF0D1282)),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : AppColors.deepNavy,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildSummaryStats(bool isDark) {
    final present = _todayRecords
        .where(
          (r) => [
            'present',
            'late',
          ].contains(r['status']?.toString().toLowerCase()),
        )
        .length;
    final absent = _todayRecords
        .where((r) => r['status']?.toString().toLowerCase() == 'absent')
        .length;
    final total = _todayRecords.length;
    final perc = total > 0 ? (present * 100 ~/ total) : 0;

    return Row(
      children: [
        _statHero('QUOTA', '$perc%', AppColors.premiumEliteGradient, isDark),
        const SizedBox(width: 12),
        _statGlass('PRESENT', '$present', AppColors.mintGreen, isDark),
        const SizedBox(width: 12),
        _statGlass('ABSENT', '$absent', AppColors.coralRed, isDark),
      ],
    ).animate().fadeIn(duration: 500.ms).slideX(begin: 0.1);
  }

  Widget _statHero(String label, String value, Gradient grad, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1282),
          border: Border.all(color: const Color(0xFF0D1282), width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF0D1282),
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFF0DE36),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFEEEDED),
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statGlass(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: CPGlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(20),
        borderRadius: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0D1282),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchFilter(bool isDark) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _batchOptions.length,
        physics: const BouncingScrollPhysics(),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => CPPressable(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedBatch = i);
            _loadData();
          },
          child: AnimatedContainer(
            duration: 250.ms,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _selectedBatch == i
                  ? const Color(0xFFF0DE36)
                  : const Color(0xFFEEEDED),
              border: Border.all(color: const Color(0xFF0D1282), width: 2),
              boxShadow: _selectedBatch == i
                  ? const [
                      BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3)),
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                _batchOptions[i].name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0D1282),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(bool isDark) {
    return CPGlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(24),
      borderRadius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance Yield (%)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.deepNavy,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.elitePrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  size: 14,
                  color: AppColors.elitePrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.elitePrimary,
                    getTooltipItem: (_, _, rod, _) => BarTooltipItem(
                      '${rod.toY.toInt()}%',
                      GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 50,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: isDark
                              ? Colors.white24
                              : Colors.black.withValues(alpha: 0.26),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            v.toInt() < 6 ? days[v.toInt()] : '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              color: isDark ? Colors.white38 : Colors.black45,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
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
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _weeklyPercentages
                    .asMap()
                    .entries
                    .map(
                      (e) => BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value,
                            width: 14,
                            borderRadius: BorderRadius.zero,
                            color: const Color(0xFF0D1282),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: 100,
                              color: const Color(0xFFEEEDED),
                            ),
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
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildAbsentToday(bool isDark) {
    final list = _todayRecords
        .where((r) => r['status']?.toString().toLowerCase() == 'absent')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader("Absentee Board", isDark),
            if (list.isNotEmpty)
              CPPressable(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _notifyAllAbsentees(list);
                },
                child: Text(
                  _isNotifyingAll ? 'SENDING...' : 'NOTIFY ALL',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.elitePurple,
                    letterSpacing: 1,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          CPGlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(40),
            borderRadius: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 48,
                  color: AppColors.mintGreen.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Peak Integrity Maintained',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          )
        else
          ...list.asMap().entries.map(
            (e) => _absentItem(e.value, e.key, isDark),
          ),
      ],
    );
  }

  Widget _absentItem(Map<String, dynamic> r, int i, bool isDark) {
    return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CPGlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(16),
            borderRadius: 24,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEDED),
                    border: Border.all(color: AppColors.coralRed, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.coralRed,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      r['studentName']?[0] ?? 'S',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.coralRed,
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
                        r['studentName'],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0D1282),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${r['batchName']} • ID: ${r['studentId']}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D1282),
                        ),
                      ),
                    ],
                  ),
                ),
                CPPressable(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    CPToast.success(context, 'Alert Dispatched');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEDED),
                      border: Border.all(
                        color: const Color(0xFF0D1282),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF0D1282),
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notification_important_rounded,
                      size: 20,
                      color: AppColors.moltenAmber,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: 300 + i * 50))
        .fadeIn(duration: 500.ms)
        .slideX(begin: 0.05);
  }
}

class _BatchOption {
  final String? id;
  final String name;
  const _BatchOption({required this.id, required this.name});
}
