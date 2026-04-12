import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/parent_repository.dart';

class WeeklyReportPage extends StatefulWidget {
  final String studentId;
  const WeeklyReportPage({super.key, required this.studentId});

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  final ParentRepository _parentRepo = sl<ParentRepository>();
  Map<String, dynamic>? _reportData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final data = await _parentRepo.getWeeklyReport(widget.studentId);
      if (!mounted) return;
      setState(() {
        _reportData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
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
    final activityFeed = (_reportData?['activity_feed'] as List? ?? []).cast<dynamic>();

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
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
          'Weekly Report',
          style: GoogleFonts.sora(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: CT.textH(context),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                'Error: $_error',
                style: GoogleFonts.dmSans(color: CT.textS(context)),
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
                    _summaryRow(context, summary),
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
        gradient: LinearGradient(
          colors: [
            CT.accent(context),
            CT.accent(context).withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        boxShadow: AppDimensions.shadowMd(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.sora(
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
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _summaryRow(BuildContext context, Map<String, dynamic> summary) {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            context,
            'Attendance',
            '${_toInt(summary['attendance_percentage_30d'])}%',
            Icons.fact_check_outlined,
            AppColors.success,
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
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: CT.cardDecor(context),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: CT.textH(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 11, color: CT.textS(context)),
          ),
        ],
      ),
    );
  }

  Widget _attendanceTimeline(BuildContext context, List<dynamic> daily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Attendance',
          style: GoogleFonts.sora(
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
                decoration: CT.cardDecor(context),
                child: Row(
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(
                        _fmtDateShort(item['date']),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CT.textH(context),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: percent.clamp(0.0, 1.0),
                          backgroundColor: CT.textM(context).withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_toInt(item['attendance_percent'])}%',
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
          style: GoogleFonts.sora(
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
                  decoration: CT.cardDecor(context),
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
                          style: GoogleFonts.dmSans(
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
                              style: GoogleFonts.sora(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: CT.textH(context),
                              ),
                            ),
                            Text(
                              '${item['subject'] ?? ''} | ${item['batch_name'] ?? ''} | ${item['teacher_name'] ?? ''}',
                              style: GoogleFonts.dmSans(
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
                  style: GoogleFonts.sora(
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
                style: GoogleFonts.dmSans(fontSize: 12, color: CT.textS(context)),
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
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CT.textH(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _fmtDate(item[dateKey] ?? exam?['exam_date'] ?? quiz?['scheduled_at']),
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: CT.textS(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: GoogleFonts.sora(
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
          style: GoogleFonts.sora(
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
                      style: GoogleFonts.dmSans(
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
                      style: GoogleFonts.dmSans(
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
          style: GoogleFonts.sora(
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
          style: GoogleFonts.sora(
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
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: CT.cardDecor(context),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['month']}/${item['year']} | ${(item['batch']?['name'] ?? 'Batch').toString()}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: CT.textH(context),
                            ),
                          ),
                          Text(
                            'Due: ${_fmtDate(item['due_date'])}',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: CT.textS(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Rs $remaining',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    ).animate(delay: 220.ms).fadeIn();
  }

  Widget _activitySection(BuildContext context, List<dynamic> feed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity Feed',
          style: GoogleFonts.sora(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: CT.textH(context),
          ),
        ),
        const SizedBox(height: AppDimensions.step),
        if (feed.isEmpty)
          _emptyCard(context, 'No activity updates yet')
        else
          ...feed.take(8).map((item) {
            final type = (item['type'] ?? 'system').toString();
            final color = _activityColor(type);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: CT.cardDecor(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_activityIcon(type), size: 16, color: color),
                    ),
                    const SizedBox(width: AppDimensions.step),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['title'] ?? 'Activity update').toString(),
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: CT.textH(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (item['subtitle'] ?? '').toString(),
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: CT.textS(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _fmtDate(item['timestamp']),
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: CT.textM(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    ).animate(delay: 240.ms).fadeIn();
  }

  Widget _emptyCard(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: CT.cardDecor(context),
      child: Text(
        message,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: CT.textS(context),
        ),
      ),
    );
  }
}
