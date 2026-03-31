import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_section_header.dart';
import '../../../../core/widgets/cp_animated_list_item.dart';

import '../../../../core/di/injection_container.dart';
import '../../data/repositories/student_repository.dart';

class ExamResultsPage extends StatefulWidget {
  const ExamResultsPage({super.key});

  @override
  State<ExamResultsPage> createState() => _ExamResultsPageState();
}

class _ExamResultsPageState extends State<ExamResultsPage> {
  final _repo = sl<StudentRepository>();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;
  String? _error;

  // Computed stats
  double _overallPercentage = 0;
  int _examsTaken = 0;
  Map<String, double> _subjectAverages = {};

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _results = await _repo.getMyResults();
      _computeStats();
    } catch (e) {
      _error = e.toString();
      _results = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _computeStats() {
    _examsTaken = _results.length;
    double totalScore = 0;
    double totalMax = 0;
    final Map<String, List<double>> subjectScores = {};

    for (final r in _results) {
      final exam = r['exam'] as Map<String, dynamic>? ?? {};
      final marks = (r['marks_obtained'] ?? 0).toDouble();
      final total = (exam['total_marks'] ?? 100).toDouble();
      totalScore += marks;
      totalMax += total;

      final subject = (exam['subject'] ?? 'Other').toString();
      final pct = total > 0 ? (marks / total * 100) : 0.0;
      subjectScores.putIfAbsent(subject, () => []).add(pct);
    }

    _overallPercentage = totalMax > 0 ? (totalScore / totalMax * 100) : 0;
    _subjectAverages = subjectScores.map(
        (k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length));
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

  String _gradeFromPct(double pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    return 'D';
  }

  String _levelFromPct(double pct) {
    if (pct >= 80) return 'Excellent';
    if (pct >= 70) return 'Strong';
    return 'Average';
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

  void _shareResults() {
    final grade = _gradeFromPct(_overallPercentage);
    final text = 'My Results — Excellence Academy\n'
        'Overall: ${_overallPercentage.toStringAsFixed(1)}% (Grade $grade)\n'
        'Exams taken: $_examsTaken\n\n'
        '${_subjectAverages.entries.map((e) => '${e.key}: ${e.value.round()}%').join('\n')}';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: CT.bg(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: CT.bg(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: CT.textM(context)),
              const SizedBox(height: 12),
              Text('Failed to load results',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
              const SizedBox(height: 8),
              TextButton(onPressed: _fetchResults, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CT.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchResults,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildOverallCard(context)),
              if (_subjectAverages.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.lg)),
                SliverToBoxAdapter(child: _buildSubjectBreakdown(context)),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.lg)),
              SliverToBoxAdapter(child: _buildRecentTests(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.pagePaddingH,
          AppDimensions.md,
          AppDimensions.pagePaddingH,
          AppDimensions.sm,
        ),
        child: Row(
          children: [
            CPPressable(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.step),
                decoration: CT.cardDecor(context, radius: AppDimensions.radiusSM),
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: CT.textH(context)),
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Text(
                'My Results',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 22, fontWeight: FontWeight.w700, color: CT.textH(context)),
              ),
            ),
            CPPressable(
              onTap: _shareResults,
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.step),
                decoration: CT.cardDecor(context, radius: AppDimensions.radiusSM),
                child: Icon(Icons.share_outlined, size: 18, color: CT.textS(context)),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms);

  Widget _buildOverallCard(BuildContext context) {
    final grade = _gradeFromPct(_overallPercentage);
    // Build mini bars from recent results (up to 5)
    final recentBars = _results.take(5).map((r) {
      final exam = r['exam'] as Map<String, dynamic>? ?? {};
      final marks = (r['marks_obtained'] ?? 0).toDouble();
      final total = (exam['total_marks'] ?? 100).toDouble();
      return total > 0 ? (marks / total).clamp(0.0, 1.0) : 0.0;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1282),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          boxShadow: const [
            BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Overall Score',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              _results.isEmpty ? '—' : '${_overallPercentage.toStringAsFixed(1)}%',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 48, fontWeight: FontWeight.w700, color: Colors.white, height: 1),
            ),
            const SizedBox(height: AppDimensions.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.step, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Text(
                _results.isEmpty ? 'No exams yet' : 'Grade: $grade · $_examsTaken exams',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
            if (recentBars.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.lg),
              SizedBox(
                height: 50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(recentBars.length, (i) {
                    return Padding(
                      padding: EdgeInsets.only(left: i > 0 ? 14 : 0),
                      child: _miniBar(recentBars[i], 'T${i + 1}'),
                    );
                  }),
                ),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _miniBar(double h, String label) => Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: FractionallySizedBox(
              heightFactor: h.clamp(0.05, 1.0),
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 9, color: Colors.white60, fontWeight: FontWeight.w700),
          ),
        ],
      );

  Widget _buildSubjectBreakdown(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CPSectionHeader(
              title: 'Subject Breakdown',
              icon: Icons.pie_chart_outline_rounded,
            ),
            const SizedBox(height: AppDimensions.step),
            ..._subjectAverages.entries.toList().asMap().entries.map((e) {
              final subject = e.value.key;
              final pct = e.value.value.round();
              final color = _subjectColor(subject);
              final level = _levelFromPct(e.value.value);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.step),
                child: _subjectRow(context, subject, pct, color, level, e.key),
              );
            }),
          ],
        ).animate(delay: 200.ms).fadeIn(duration: 500.ms),
      );

  Widget _subjectRow(
    BuildContext context,
    String name,
    int pct,
    Color color,
    String level,
    int index,
  ) {
    final levelColor = level == 'Excellent' || level == 'Strong'
        ? AppColors.success
        : AppColors.warning;
    return CPAnimatedListItem(
      index: index,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: CT.cardDecor(context, radius: AppDimensions.radiusMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w700, color: CT.textH(context)),
                ),
                Row(
                  children: [
                    Text(
                      '$pct%',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16, fontWeight: FontWeight.w700, color: color),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      child: Text(
                        level,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, fontWeight: FontWeight.w700, color: levelColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (pct / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTests(BuildContext context) {
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CPSectionHeader(
              title: 'Recent Tests',
              icon: Icons.history_rounded,
            ),
            const SizedBox(height: AppDimensions.step),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.lg),
              decoration: CT.cardDecor(context, radius: AppDimensions.radiusMD),
              child: Column(
                children: [
                  Icon(Icons.analytics_outlined, size: 48,
                      color: CT.textS(context).withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text("No results yet",
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
                  const SizedBox(height: 4),
                  Text("Take a quiz to see your scores here.",
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: CT.textS(context))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CPSectionHeader(
            title: 'Recent Tests',
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: AppDimensions.step),
          ..._results.asMap().entries.map((e) {
            final r = e.value;
            final exam = r['exam'] as Map<String, dynamic>? ?? {};
            final marks = (r['marks_obtained'] ?? 0).toDouble();
            final total = (exam['total_marks'] ?? 100).toDouble();
            final pct = total > 0 ? (marks / total * 100) : 0.0;
            final grade = r['grade']?.toString() ?? _gradeFromPct(pct);
            final subject = (exam['subject'] ?? 'General').toString();
            final color = _subjectColor(subject);
            final date = _formatDate(exam['exam_date']);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.step),
              child: _testCard(
                context,
                (exam['title'] ?? 'Exam').toString(),
                subject,
                '${marks.round()}/${total.round()}',
                date,
                grade,
                color,
                e.key,
              ),
            );
          }),
        ],
      ).animate(delay: 400.ms).fadeIn(duration: 500.ms),
    );
  }

  Widget _testCard(
    BuildContext context,
    String name,
    String sub,
    String score,
    String date,
    String grade,
    Color color,
    int index,
  ) {
    final gradeColor = grade.startsWith('A')
        ? AppColors.success
        : grade.startsWith('B')
            ? AppColors.info
            : AppColors.warning;
    return CPAnimatedListItem(
      index: index,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: CT.card(context),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border(left: BorderSide(color: color, width: 3)),
          boxShadow: const [
            BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.xxs),
                  Text(
                    '$sub · $date',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: CT.textM(context)),
                  ),
                ],
              ),
            ),
            Text(
              score,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context)),
            ),
            const SizedBox(width: AppDimensions.step),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: 3),
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
              ),
              child: Text(
                grade,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w800, color: gradeColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
