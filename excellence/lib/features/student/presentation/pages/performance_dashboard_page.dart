import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../student/data/repositories/student_repository.dart';

class PerformanceDashboardPage extends StatefulWidget {
  const PerformanceDashboardPage({super.key});

  @override
  State<PerformanceDashboardPage> createState() =>
      _PerformanceDashboardPageState();
}

class _PerformanceDashboardPageState extends State<PerformanceDashboardPage> {
  final _repo = sl<StudentRepository>();
  final _realtime = sl<RealtimeSyncService>();
  StreamSubscription<Map<String, dynamic>>? _syncSub;
  bool _isLoading = true;
  String? _error;

  // Performance data from backend
  int _overallPercentage = 0;
  int _examsTaken = 0;
  int _attendancePercentage = 0;
  int _totalPresent = 0;
  int _totalClasses = 0;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _loadData();
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
          reason.contains('student');
      if (shouldRefresh) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Parallel fetch: performance + attendance + results
      final futures = await Future.wait([
        _repo.getPerformance(),
        _repo.getMyAttendance(),
        _repo.getMyResults(),
      ]);

      final perf = futures[0] as Map<String, dynamic>;
      final attendance = futures[1] as Map<String, dynamic>;
      final results = futures[2] as List<Map<String, dynamic>>;

      final summary = attendance['summary'] ?? {};

      if (!mounted) return;
      setState(() {
        _overallPercentage = ((perf['percentage'] ?? 0) as num).toInt();
        _examsTaken = ((perf['exams_taken'] ?? 0) as num).toInt();
        _attendancePercentage = ((summary['percentage'] ?? 0) as num).toInt();
        _totalPresent = ((summary['present'] ?? 0) as num).toInt();
        _totalClasses = ((summary['total'] ?? 0) as num).toInt();
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _subjectColor(String? subject) {
    switch (subject?.toLowerCase()) {
      case 'physics':
        return AppColors.physics;
      case 'chemistry':
        return AppColors.chemistry;
      case 'mathematics':
      case 'maths':
        return AppColors.mathematics;
      case 'english':
        return AppColors.english;
      case 'biology':
        return AppColors.biology;
      default:
        return AppColors.electricBlue;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      return DateFormat('d MMM yyyy').format(d);
    } catch (_) {
      return date.toString();
    }
  }

  // Group results by subject and compute averages
  Map<String, double> _computeSubjectAverages() {
    final Map<String, List<double>> subjectScores = {};
    for (final r in _results) {
      final exam = r['exam'] as Map<String, dynamic>? ?? {};
      final subject = (exam['subject'] ?? 'Other').toString();
      final marks = (r['marks_obtained'] ?? 0).toDouble();
      final total = (exam['total_marks'] ?? 100).toDouble();
      final pct = total > 0 ? (marks / total * 100) : 0.0;
      subjectScores.putIfAbsent(subject, () => []).add(pct);
    }
    return subjectScores.map((k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader()),
                        SliverToBoxAdapter(child: _buildStatsRow()),
                        if (_results.isNotEmpty)
                          SliverToBoxAdapter(child: _buildSubjectComparison()),
                        SliverToBoxAdapter(child: _buildRecentExams()),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: CT.textM(context)),
            const SizedBox(height: 12),
            Text('Failed to load performance',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.pagePaddingH,
          AppDimensions.md,
          AppDimensions.pagePaddingH,
          AppDimensions.sm,
        ),
        child: Row(
          children: [
            CPPressable(
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/student');
                }
              },
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.step),
                decoration: CT.cardDecor(context, radius: AppDimensions.radiusSM),
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: CT.textH(context)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'My Performance',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 22, fontWeight: FontWeight.w700, color: CT.textH(context)),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms);

  Widget _buildStatsRow() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            _buildStatDonut('Attendance', _attendancePercentage, AppColors.mintGreen),
            const SizedBox(width: 10),
            _buildStatDonut('Avg Score', _overallPercentage, AppColors.electricBlue),
            const SizedBox(width: 10),
            _buildStatValue('Exams', '$_examsTaken', AppColors.moltenAmber),
            const SizedBox(width: 10),
            _buildStatValue(
                'Classes', '$_totalPresent/$_totalClasses', AppColors.teacherTeal),
          ],
        ),
      ).animate(delay: 200.ms).fadeIn();

  Widget _buildStatDonut(String label, int value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: CT.cardDecor(context),
          child: Column(
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: value / 100,
                      strokeWidth: 5,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                    ),
                    Text(
                      '$value%',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 11, fontWeight: FontWeight.w700, color: CT.textH(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.w600, color: CT.textS(context)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _buildStatValue(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: CT.cardDecor(context),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    value,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 13, fontWeight: FontWeight.w800, color: color),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.w600, color: CT.textS(context)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _buildSubjectComparison() {
    final avgs = _computeSubjectAverages();
    if (avgs.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: CT.cardDecor(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subject-wise Performance',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context)),
            ),
            const SizedBox(height: 16),
            ...avgs.entries.map((e) {
              final percent = e.value.round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _subjectBar(e.key, percent, _subjectColor(e.key)),
              );
            }),
          ],
        ),
      ),
    ).animate(delay: 400.ms).fadeIn();
  }

  Widget _subjectBar(String name, int percent, Color color) => Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w600, color: CT.textH(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (percent / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$percent%',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 12, fontWeight: FontWeight.w700, color: CT.textH(context)),
          ),
        ],
      );

  Widget _buildRecentExams() {
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: CT.cardDecor(context),
          child: Center(
            child: Text(
              'No exam results yet',
              style: GoogleFonts.plusJakartaSans(color: CT.textS(context)),
            ),
          ),
        ),
      );
    }

    final recent = _results.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Exams',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context)),
          ),
          const SizedBox(height: 12),
          ...recent.asMap().entries.map((e) => _buildExamCard(e.value, e.key)),
        ],
      ),
    ).animate(delay: 500.ms).fadeIn();
  }

  Widget _buildExamCard(Map<String, dynamic> result, int index) {
    final exam = result['exam'] as Map<String, dynamic>? ?? {};
    final subject = (exam['subject'] ?? '').toString();
    final color = _subjectColor(subject);
    final marks = result['marks_obtained'] ?? 0;
    final total = exam['total_marks'] ?? 100;
    final percentage = total > 0 ? (marks / total * 100).round() : 0;
    final grade = result['grade'] ?? (percentage >= 90 ? 'A+' : percentage >= 80 ? 'A' : percentage >= 70 ? 'B+' : percentage >= 60 ? 'B' : 'C');

    return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: CT.cardDecor(context),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.description_outlined, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (exam['title'] ?? 'Exam').toString(),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w600, color: CT.textH(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(exam['exam_date']),
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textS(context)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$marks/$total',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 14, fontWeight: FontWeight.w700, color: CT.textH(context)),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.mintGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      grade.toString(),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.mintGreen),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: 550 + index * 80))
        .fadeIn()
        .slideY(begin: 0.2, end: 0);
  }
}
