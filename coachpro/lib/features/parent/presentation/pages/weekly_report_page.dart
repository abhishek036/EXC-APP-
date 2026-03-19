import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
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
              ? Center(child: Text('Error: $_error', style: GoogleFonts.dmSans(color: CT.textS(context))))
              : RefreshIndicator(
                  onRefresh: _loadReport,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppDimensions.md),
                        _headerCard(context, isDark),
                        const SizedBox(height: AppDimensions.lg),
                        _summaryRow(context),
                        const SizedBox(height: AppDimensions.lg),
                        _buildResults(context),
                        const SizedBox(height: AppDimensions.lg),
                        _teacherNotes(context),
                        const SizedBox(height: AppDimensions.lg),
                        _nextWeekPlan(context),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _headerCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CT.accent(context), CT.accent(context).withValues(alpha: 0.8)],
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
            'Performance Analysis',
            style: GoogleFonts.sora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Latest updates for your child',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _summaryRow(BuildContext context) {
    final attendance = _reportData?['attendance'] as List? ?? [];
    int present = 0;
    int total = 0;
    for (var a in attendance) {
      if (a['status'] == 'present') present = a['_count']?['status'] ?? 0;
      total += (a['_count']?['status'] as num?)?.toInt() ?? 0;
    }
    final attendPercent = total > 0 ? (present / total * 100).toInt() : 100;

    return Row(
      children: [
        Expanded(child: _metricCard(context, 'Attendance', '$attendPercent%', Icons.fact_check_outlined, AppColors.success)),
        const SizedBox(width: AppDimensions.step),
        Expanded(child: _metricCard(context, 'Tests', '${(_reportData?['results'] as List?)?.length ?? 0}', Icons.bar_chart_rounded, AppColors.primary)),
        const SizedBox(width: AppDimensions.step),
        Expanded(child: _metricCard(context, 'Status', 'Active', Icons.auto_graph_rounded, AppColors.warning)),
      ],
    ).animate(delay: 100.ms).fadeIn();
  }

  Widget _metricCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: CT.cardDecor(context),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: CT.textH(context)),
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

  Widget _buildResults(BuildContext context) {
    final results = _reportData?['results'] as List? ?? [];
    if (results.isEmpty) {
      return Center(child: Text('No exam results yet', style: GoogleFonts.dmSans(color: CT.textS(context))));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Scores', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: CT.textH(context))),
        const SizedBox(height: AppDimensions.step),
        ...results.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: _subjectProgress(
                context,
                r['exam']?['title'] ?? 'Test',
                (r['marks_obtained'] as num? ?? 0) / (r['exam']?['total_marks'] as num? ?? 100),
                AppColors.primary,
              ),
            )),
      ],
    ).animate(delay: 200.ms).fadeIn();
  }

  Widget _subjectProgress(BuildContext context, String subject, double progress, Color color) {
    final percent = (progress * 100).toInt();
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: CT.cardDecor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject,
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context)),
                ),
              ),
              Text(
                '$percent%',
                style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: CT.textM(context).withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teacherNotes(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: CT.cardDecor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teacher Notes',
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: CT.textH(context)),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Your child is showing consistent performance. Attendance is good. We recommend focusing more on the upcoming mock tests for better preparation.',
            style: GoogleFonts.dmSans(fontSize: 13, height: 1.55, color: CT.textS(context)),
          ),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn();
  }

  Widget _nextWeekPlan(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next Week Focus',
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: CT.textH(context)),
          ),
          const SizedBox(height: AppDimensions.sm),
          _point(context, 'Mock Test Series starts this Monday'),
          _point(context, 'Special doubt sessions for Science subjects'),
          _point(context, 'Assignment submission deadline: Friday'),
          const SizedBox(height: AppDimensions.md),
          CPPressable(
            onTap: () => context.go('/parent/chat-list'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: CT.accent(context),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Message Class Teacher',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 400.ms).fadeIn();
  }

  Widget _point(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: CT.accent(context), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(fontSize: 13, color: CT.textS(context)),
            ),
          ),
        ],
      ),
    );
  }
}
