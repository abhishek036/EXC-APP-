import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../data/repositories/parent_repository.dart';

class WeeklyReportPage extends StatefulWidget {
  final String studentId;
  const WeeklyReportPage({super.key, required this.studentId});

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  final ParentRepository _parentRepo = sl<ParentRepository>();
  final _realtime = sl<RealtimeSyncService>();
  StreamSubscription<Map<String, dynamic>>? _syncSub;
  Map<String, dynamic>? _reportData;
  bool _loading = true;
  bool _isBackgroundRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
    _initRealtime();
  }

  Future<void> _initRealtime() async {
    await _realtime.connect();
    _syncSub?.cancel();
    _syncSub = _realtime.updates.listen((event) {
      if (!mounted) return;
      final type = (event['type'] ?? '').toString();
      final reason = (event['reason'] ?? '').toString().toLowerCase();
      final shouldRefresh =
          type == 'dashboard_sync' ||
          type == 'batch_sync' ||
          reason.contains('attendance') ||
          reason.contains('exam') ||
          reason.contains('quiz') ||
          reason.contains('result') ||
          reason.contains('fee') ||
          reason.contains('assignment') ||
          reason.contains('lecture') ||
          reason.contains('schedule') ||
          reason.contains('student');
      if (shouldRefresh) {
        _loadReport();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadReport() async {
    try {
      if (_reportData != null) {
        setState(() => _isBackgroundRefreshing = true);
      }
      final data = await _parentRepo.getWeeklyReport(widget.studentId);
      if (!mounted) return;
      setState(() {
        _reportData = data;
        _loading = false;
        _isBackgroundRefreshing = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_reportData == null) {
          _error = e.toString();
        }
        _loading = false;
        _isBackgroundRefreshing = false;
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) => _toDouble(value).round();

  String _fmtDate(dynamic value) {
    if (value == null) return 'N/A';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _fmtDateShort(dynamic value) {
    if (value == null) return 'N/A';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  String _fmtTime(dynamic value) {
    if (value == null) return 'TBA';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'TBA';
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${date.minute.toString().padLeft(2, '0')} $suffix';
  }

  Color _activityColor(String type) {
    switch (type.toLowerCase()) {
      case 'attendance':
        return AppColors.success;
      case 'quiz':
        return AppColors.primary;
      case 'exam':
      case 'test':
        return AppColors.warning;
      case 'assignment':
        return AppColors.moltenAmber;
      default:
        return AppColors.primary;
    }
  }

  IconData _activityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'attendance':
        return Icons.fact_check_outlined;
      case 'quiz':
        return Icons.quiz_outlined;
      case 'exam':
      case 'test':
        return Icons.school_outlined;
      case 'assignment':
        return Icons.assignment_outlined;
      default:
        return Icons.timeline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    final child = (_reportData?['child'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final summary = (_reportData?['summary'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final attendanceDaily = (_reportData?['attendance_daily'] as List? ?? []).cast<dynamic>();
    final schedule = (_reportData?['schedule'] as List? ?? []).cast<dynamic>();
    final results = (_reportData?['results'] as List? ?? []).cast<dynamic>();
    final quizzes = (_reportData?['quizzes'] as List? ?? []).cast<dynamic>();
    final assignments = ((_reportData?['assignments'] as Map?) ?? <String, dynamic>{})
        .cast<String, dynamic>();
    final assignmentPending = (assignments['pending'] as List? ?? []).cast<dynamic>();
    final assignmentUpcoming = (assignments['upcoming'] as List? ?? []).cast<dynamic>();
    final assignmentRecent = (assignments['recent_submissions'] as List? ?? []).cast<dynamic>();
    final fees = ((_reportData?['fees'] as Map?) ?? <String, dynamic>{}).cast<String, dynamic>();
    final feeSummary = ((fees['summary'] as Map?) ?? <String, dynamic>{}).cast<String, dynamic>();
    final feeRecords = (fees['records'] as List? ?? []).cast<dynamic>();
    
    final activityFeed = [
      ...attendanceDaily.map((e) => {
        'type': 'attendance',
        'title': 'Attendance ${e['status']}',
        'subtitle': '${_toInt(e['attendance_percent'])}% present',
        'timestamp': e['date'],
      }),
      ...schedule.map((e) => {
        'type': 'lecture',
        'title': 'Lecture Scheduled',
        'subtitle': (e['title'] ?? e['subject'] ?? 'Class').toString(),
        'timestamp': e['scheduled_at'],
      }),
      ...results.map((e) => {
        'type': 'exam',
        'title': 'Test Result: ${_toInt(e['percentage'])}%',
        'subtitle': (e['exam']?['title'] ?? 'Exam').toString(),
        'timestamp': e['exam']?['exam_date'],
      }),
      ...quizzes.map((e) => {
        'type': 'quiz',
        'title': 'Quiz Result: ${_toInt(e['percentage'])}%',
        'subtitle': (e['quiz']?['title'] ?? 'Quiz').toString(),
        'timestamp': e['submitted_at'],
      }),
      ...assignmentRecent.map((e) => {
        'type': 'assignment',
        'title': 'Assignment Submitted',
        'subtitle': (e['assignment_title'] ?? 'Assignment').toString(),
        'timestamp': e['submitted_at'],
      }),
      ...feeRecords.map((e) => {
        'type': 'fee',
        'title': 'Fee Update: ${e['status'].toString().toUpperCase()}',
        'subtitle': '₹${e['paid_amount']} paid out of ₹${e['final_amount']}',
        'timestamp': e['updated_at'] ?? e['due_date'], 
      }),
    ];
    
    activityFeed.sort((a, b) {
      DateTime toD(dynamic v) {
        if (v is DateTime) return v;
        if (v == null) return DateTime(0);
        return DateTime.tryParse(v.toString()) ?? DateTime(0);
      }
      return toD(b['timestamp']).compareTo(toD(a['timestamp']));
    });

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/parent');
            }
          },
          icon: Icon(Icons.arrow_back_rounded, color: CT.textH(context)),
        ),
        title: Text(
          'WEEKLY REPORT',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: CT.textH(context),
            letterSpacing: 1,
          ),
        ),
        actions: [
          if (_isBackgroundRefreshing)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                'Error: $_error',
                style: GoogleFonts.plusJakartaSans(color: CT.textS(context)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.pagePaddingH,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppDimensions.md),
                    _headerCard(context, isDark, child),
                    const SizedBox(height: AppDimensions.lg),
                    _summaryRow(
                      context,
                      summary,
                      attendanceDaily,
                      quizzes,
                      results,
                      assignmentPending,
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    _attendanceTimeline(context, attendanceDaily),
                    const SizedBox(height: AppDimensions.lg),
                    _scheduleSection(context, schedule),
                    const SizedBox(height: AppDimensions.lg),
                    _scoresSection(context, quizzes, results),
                    const SizedBox(height: AppDimensions.lg),
                    _assignmentSection(
                      context,
                      assignmentPending,
                      assignmentUpcoming,
                      assignmentRecent,
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    _feesSection(context, feeSummary, feeRecords),
                    const SizedBox(height: AppDimensions.lg),
                    _activitySection(context, activityFeed),
                    const SizedBox(height: AppDimensions.lg),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _headerCard(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> child,
  ) {
    final name = (child['name'] ?? 'Student').toString();
    final batches = (child['batches'] as List? ?? [])
        .map((item) {
          if (item is Map) return (item['name'] ?? '').toString();
          return '';
        })
        .where((name) => name.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: const Color(0xFFE5A100),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            batches.isEmpty
                ? 'Latest updates for your child'
                : batches.join(' | '),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _summaryRow(
    BuildContext context,
    Map<String, dynamic> summary,
    List<dynamic> daily,
    List<dynamic> quizzes,
    List<dynamic> results,
    List<dynamic> assignmentPending,
  ) {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            context,
            'Attendance',
            '${_toInt(summary['attendance_percentage_30d'])}%',
            Icons.fact_check_outlined,
            AppColors.success,
            onTap: () => _showAttendanceDetail(context, daily),
          ),
        ),
        const SizedBox(width: AppDimensions.step),
        Expanded(
          child: _metricCard(
            context,
            'Quiz Avg',
            '${_toInt(summary['avg_quiz_score'])}%',
            Icons.quiz_outlined,
            AppColors.primary,
            onTap: () => _showScoreDetail(context, 'Quizzes', quizzes, AppColors.primary),
          ),
        ),
        const SizedBox(width: AppDimensions.step),
        Expanded(
          child: _metricCard(
            context,
            'Test Avg',
            '${_toInt(summary['avg_test_score'])}%',
            Icons.school_outlined,
            AppColors.warning,
            onTap: () => _showScoreDetail(context, 'Tests', results, AppColors.success),
          ),
        ),
        const SizedBox(width: AppDimensions.step),
        Expanded(
          child: _metricCard(
            context,
            'Tasks',
            '${_toInt(summary['pending_assignments'])}',
            Icons.assignment_late_outlined,
            AppColors.moltenAmber,
            onTap: () => _showAssignmentDetail(context, assignmentPending),
          ),
        ),
      ],
    ).animate(delay: 100.ms).fadeIn();
  }

  Widget _metricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(3, 3)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: CT.textH(context),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: CT.textS(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendanceTimeline(BuildContext context, List<dynamic> daily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Attendance',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: CT.textH(context),
          ),
        ),
        const SizedBox(height: AppDimensions.step),
        if (daily.isEmpty)
          _emptyCard(context, 'No attendance records yet')
        else
          ...daily.take(7).map((item) {
            final percent = _toDouble(item['attendance_percent']) / 100;
            final status = (item['status'] ?? 'unknown').toString().toLowerCase();
            final color = status == 'present'
                ? AppColors.success
                : status == 'absent'
                    ? AppColors.error
                    : AppColors.warning;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(
                        _fmtDateShort(item['date']),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: CT.textH(context),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: percent.clamp(0.0, 1.0),
                          backgroundColor: Colors.black.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_toInt(item['attendance_percent'])}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    ).animate(delay: 140.ms).fadeIn();
  }

  Widget _scheduleSection(BuildContext context, List<dynamic> schedule) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Schedule',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: CT.textH(context),
          ),
        ),
        const SizedBox(height: AppDimensions.step),
        if (schedule.isEmpty)
          _emptyCard(context, 'No upcoming classes')
        else
          ...schedule.take(5).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _fmtTime(item['scheduled_at']),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.step),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (item['title'] ?? 'Class').toString(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: CT.textH(context),
                              ),
                            ),
                            Text(
                              '${item['subject'] ?? ''} | ${item['batch_name'] ?? ''} | ${item['teacher_name'] ?? ''}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: CT.textS(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    ).animate(delay: 160.ms).fadeIn();
  }

  Widget _scoresSection(
    BuildContext context,
    List<dynamic> quizzes,
    List<dynamic> results,
  ) {
    Widget scoreList({
      required String title,
      required Color color,
      required IconData icon,
      required List<dynamic> items,
      required String dateKey,
      required String titleKey,
    }) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: CT.cardDecor(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CT.textH(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            if (items.isEmpty)
              Text(
                'No records',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: CT.textS(context)),
              )
            else
              ...items.take(3).map((item) {
                final percent = _toInt(item['percentage']);
                final exam = item['exam'] is Map ? (item['exam'] as Map) : null;
                final quiz = item['quiz'] is Map ? (item['quiz'] as Map) : null;
                final scoreTitle = (item[titleKey] ?? exam?['title'] ?? quiz?['title'] ?? 'Assessment').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scoreTitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CT.textH(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _fmtDate(item[dateKey] ?? exam?['exam_date'] ?? quiz?['scheduled_at']),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: CT.textS(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quiz & Test Scores',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: CT.textH(context),
          ),
        ),
        const SizedBox(height: AppDimensions.step),
        Row(
          children: [
            Expanded(
              child: scoreList(
                title: 'Quizzes',
                color: AppColors.primary,
                icon: Icons.quiz_outlined,
                items: quizzes,
                dateKey: 'submitted_at',
                titleKey: 'title',
              ),
            ),
            const SizedBox(width: AppDimensions.step),
            Expanded(
              child: scoreList(
                title: 'Tests',
                color: AppColors.success,
                icon: Icons.school_outlined,
                items: results,
                dateKey: 'exam_date',
                titleKey: 'title',
              ),
            ),
          ],
        ),
      ],
    ).animate(delay: 180.ms).fadeIn();
  }

  Widget _assignmentSection(
    BuildContext context,
    List<dynamic> pending,
    List<dynamic> upcoming,
    List<dynamic> recent,
  ) {
    Widget assignmentListTile(Map item, {required Color color, required IconData icon}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.sm),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: CT.cardDecor(context),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: AppDimensions.step),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['title'] ?? item['assignment_title'] ?? 'Assignment').toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CT.textH(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item['due_date'] != null
                          ? 'Due: ${_fmtDate(item['due_date'])}'
                          : 'Submitted: ${_fmtDate(item['submitted_at'])}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: CT.textS(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assignments',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: CT.textH(context),
          ),
        ),
        const SizedBox(height: AppDimensions.step),
        if (pending.isEmpty && upcoming.isEmpty && recent.isEmpty)
          _emptyCard(context, 'No assignment activity yet')
        else ...[
          if (pending.isNotEmpty)
            ...pending.take(2).map((item) => assignmentListTile(
                  item as Map,
                  color: AppColors.warning,
                  icon: Icons.assignment_late_outlined,
                )),
          if (upcoming.isNotEmpty)
            ...upcoming.take(1).map((item) => assignmentListTile(
                  item as Map,
                  color: AppColors.primary,
                  icon: Icons.upcoming_outlined,
                )),
          if (recent.isNotEmpty)
            ...recent.take(2).map((item) => assignmentListTile(
                  item as Map,
                  color: AppColors.success,
                  icon: Icons.assignment_turned_in_outlined,
                )),
        ],
      ],
    ).animate(delay: 200.ms).fadeIn();
  }

  Widget _feesSection(
    BuildContext context,
    Map<String, dynamic> summary,
    List<dynamic> records,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fees Overview',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: CT.textH(context),
          ),
        ),
        const SizedBox(height: AppDimensions.step),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                context,
                'Pending',
                'Rs ${_toInt(summary['pending_amount'])}',
                Icons.warning_amber_rounded,
                AppColors.warning,
                onTap: () => _showFeeDetail(context, records),
              ),
            ),
            const SizedBox(width: AppDimensions.step),
            Expanded(
              child: _metricCard(
                context,
                'Paid',
                'Rs ${_toInt(summary['paid_amount'])}',
                Icons.check_circle_outline,
                AppColors.success,
                onTap: () => _showFeeDetail(context, records),
              ),
            ),
            const SizedBox(width: AppDimensions.step),
            Expanded(
              child: _metricCard(
                context,
                'Records',
                '${_toInt(summary['total_records'])}',
                Icons.receipt_long_outlined,
                AppColors.primary,
                onTap: () => _showFeeDetail(context, records),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.step),
        if (records.isEmpty)
          _emptyCard(context, 'No fee records found')
        else
          ...records.take(3).map((item) {
            final status = (item['status'] ?? '').toString().toLowerCase();
            final remaining = _toInt(item['remaining_amount']);
            final color = status == 'paid' || remaining <= 0 ? AppColors.success : AppColors.warning;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: GestureDetector(
                onTap: () => _showFeeDetail(context, records),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['month']}/${item['year']} | ${(item['batch']?['name'] ?? 'Batch').toString()}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: CT.textH(context),
                              ),
                            ),
                            Text(
                              'Due: ${_fmtDate(item['due_date'])}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: CT.textS(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rs $remaining',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    ).animate(delay: 220.ms).fadeIn();
  }

  void _showDetailSheet(BuildContext context, String title, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: CT.bg(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: const Border(top: BorderSide(color: Colors.black, width: 2.5)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: CT.textH(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.black, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 1.5, color: Colors.black12),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  void _showAttendanceDetail(BuildContext context, List<dynamic> daily) {
    _showDetailSheet(
      context,
      'Attendance Detail',
      ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: daily.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item = daily[i];
          final percent = _toDouble(item['attendance_percent']);
          final status = (item['status'] ?? 'unknown').toString().toLowerCase();
          final color = status == 'present'
              ? AppColors.success
              : status == 'absent'
                  ? AppColors.error
                  : AppColors.warning;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black, width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(3, 3)),
              ],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtDate(item['date']),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: CT.textH(context),
                      ),
                    ),
                    Text(
                      status.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${_toInt(percent)}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showScoreDetail(BuildContext context, String type, List<dynamic> items, Color color) {
    _showDetailSheet(
      context,
      '$type History',
      ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item = items[i];
          final percent = _toInt(item['percentage']);
          final exam = item['exam'] is Map ? (item['exam'] as Map) : null;
          final quiz = item['quiz'] is Map ? (item['quiz'] as Map) : null;
          final title = (item['title'] ?? exam?['title'] ?? quiz?['title'] ?? 'Assessment').toString();
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black, width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(3, 3)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: CT.textH(context),
                        ),
                      ),
                      Text(
                        _fmtDate(item['submitted_at'] ?? item['exam_date'] ?? exam?['exam_date'] ?? quiz?['scheduled_at']),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: CT.textS(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$percent%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAssignmentDetail(BuildContext context, List<dynamic> items) {
    _showDetailSheet(
      context,
      'Assignments Detail',
      items.isEmpty
          ? Center(child: Text('No records found', style: GoogleFonts.plusJakartaSans()))
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final item = items[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.assignment_late_outlined, color: AppColors.warning, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (item['title'] ?? item['assignment_title'] ?? 'Assignment').toString(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: CT.textH(context),
                              ),
                            ),
                            Text(
                              'Due: ${_fmtDate(item['due_date'])}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: CT.textS(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showFeeDetail(BuildContext context, List<dynamic> records) {
    _showDetailSheet(
      context,
      'Fee Breakdown',
      ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item = records[i];
          final status = (item['status'] ?? '').toString().toUpperCase();
          final amount = _toInt(item['total_amount']);
          final paid = _toInt(item['paid_amount']);
          final due = amount - paid;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black, width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(3, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (item['invoice_label'] ?? 'Monthly Fee').toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: CT.textH(context),
                      ),
                    ),
                    Text(
                      status,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: status == 'PAID' ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _smallStat('Bill', '₹$amount'),
                    _smallStat('Paid', '₹$paid'),
                    _smallStat('Due', '₹$due', color: AppColors.error),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _smallStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color ?? Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _emptyCard(BuildContext context, String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppDimensions.md),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 1.5),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(color: CT.textS(context), fontSize: 13),
    ),
  );

  Widget _activitySection(BuildContext context, List<dynamic> feed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: CT.textH(context),
          ),
        ),
        const SizedBox(height: AppDimensions.step),
        if (feed.isEmpty)
          _emptyCard(context, 'No activity recorded')
        else
          ...feed.take(8).map((item) {
            final type = (item['type'] ?? 'system').toString();
            final color = _activityColor(type);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_activityIcon(type), size: 16, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['title'] ?? '').toString(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: CT.textH(context),
                          ),
                        ),
                        Text(
                          (item['subtitle'] ?? '').toString(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: CT.textS(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _fmtDateShort(item['timestamp']),
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            );
          }),
      ],
    ).animate(delay: 240.ms).fadeIn();
  }
}
