import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_animated_ring.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme_aware.dart';

import '../../../../core/di/injection_container.dart';
import '../../data/repositories/parent_repository.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});
  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  final ParentRepository _parentRepo = sl<ParentRepository>();
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  int _selectedChild = 0;
  List<dynamic> _children = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      setState(() => _isLoading = true);
      final data = await _parentRepo.getDashboard();
      setState(() {
        _dashboardData = data;
        _children = data['children'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: CT.bg(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_dashboardData == null) {
      return Scaffold(
        backgroundColor: CT.bg(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Failed to load dashboard',
                style: GoogleFonts.dmSans(color: CT.textS(context)),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _loadDashboard,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CT.bg(context),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.pagePaddingH,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimensions.md),
                _buildAppBar(isDark),
                const SizedBox(height: AppDimensions.lg),
                if (_children.isNotEmpty) _buildChildSelector(),
                const SizedBox(height: AppDimensions.lg),
                if (_children.isNotEmpty) ...[
                  _buildChildOverview(isDark),
                  const SizedBox(height: AppDimensions.lg),
                  _buildAttendanceFee(isDark),
                  const SizedBox(height: AppDimensions.lg),
                  _buildActivitySnapshot(isDark),
                  const SizedBox(height: AppDimensions.lg),
                  _buildScoreHighlights(isDark),
                  const SizedBox(height: AppDimensions.lg),
                  _buildAssignmentsPreview(isDark),
                  const SizedBox(height: AppDimensions.lg),
                ],
                _buildQuickTools(isDark),
                const SizedBox(height: AppDimensions.lg),
                _buildLatestResult(isDark),
                const SizedBox(height: AppDimensions.lg),
                _buildTodaySchedule(isDark),
                const SizedBox(height: AppDimensions.lg),
                _buildAnnouncement(isDark),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) => Row(
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.sm),
            decoration: BoxDecoration(
              color: CT.accent(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.school_rounded,
              size: 20,
              color: CT.accent(context),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Excellence Academy',
            style: GoogleFonts.sora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CT.accent(context),
            ),
          ),
        ],
      ),
      const Spacer(),

      CPPressable(
        onTap: () => context.go('/parent/notifications'),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: CT.card(context),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            boxShadow: AppDimensions.shadowSm(isDark),
          ),
          child: Icon(
            Icons.notifications_outlined,
            size: 20,
            color: CT.textH(context),
          ),
        ),
      ),
      const SizedBox(width: AppDimensions.sm),
      CPPressable(
        onTap: () => context.go('/parent/settings'),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: CT.card(context),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            boxShadow: AppDimensions.shadowSm(isDark),
          ),
          child: Icon(
            Icons.settings_outlined,
            size: 20,
            color: CT.textH(context),
          ),
        ),
      ),
    ],
  ).animate().fadeIn(duration: 500.ms);

  Widget _buildChildSelector() => Row(
    children: List.generate(_children.length, (i) {
      final sel = _selectedChild == i;
      final child = _children[i];
      return Padding(
        padding: EdgeInsets.only(right: i < _children.length - 1 ? 10 : 0),
        child: CPPressable(
          onTap: () => setState(() => _selectedChild = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? CT.accent(context) : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: sel ? CT.accent(context) : CT.textM(context),
                width: 1.5,
              ),
            ),
            child: Text(
              child['name'] ?? 'Child',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : CT.textS(context),
              ),
            ),
          ),
        ),
      );
    }),
  ).animate(delay: 100.ms).fadeIn(duration: 400.ms);

  Widget _buildChildOverview(bool isDark) {
    final child = _children[_selectedChild];
    return CPPressable(
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: CT.elevatedCardDecor(context),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              ),
              child: Center(
                child: Text(
                  child['name']?[0] ?? 'C',
                  style: GoogleFonts.sora(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child['name'] ?? 'Student',
                    style: GoogleFonts.sora(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CT.textH(context),
                    ),
                  ),
                  Text(
                    'Child Profile | Tap for details',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: CT.textS(context),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _miniTag(
                        icon: Icons.quiz_outlined,
                        label: 'Quiz ${child['avgQuizScore'] ?? 0}%',
                        color: AppColors.primary,
                      ),
                      _miniTag(
                        icon: Icons.school_outlined,
                        label: 'Test ${child['avgTestScore'] ?? 0}%',
                        color: AppColors.success,
                      ),
                      _miniTag(
                        icon: Icons.assignment_late_outlined,
                        label: '${child['pendingAssignments'] ?? 0} pending',
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: 200.ms).fadeIn(duration: 500.ms);
  }

  Widget _miniTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySnapshot(bool isDark) {
    final child = _children[_selectedChild];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity Snapshot',
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
              child: _snapshotTile(
                icon: Icons.event_available_rounded,
                label: 'Today',
                value: (child['todayAttendance'] ?? 'not_marked')
                    .toString()
                    .replaceAll('_', ' ')
                    .toUpperCase(),
                color: ((child['todayAttendance'] ?? '').toString().toLowerCase() == 'present')
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ),
            const SizedBox(width: AppDimensions.step),
            Expanded(
              child: _snapshotTile(
                icon: Icons.schedule_rounded,
                label: 'Classes',
                value: '${child['upcomingClasses'] ?? 0}',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppDimensions.step),
            Expanded(
              child: _snapshotTile(
                icon: Icons.campaign_rounded,
                label: 'Exams',
                value: '${child['upcomingExams'] ?? 0}',
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    ).animate(delay: 320.ms).fadeIn(duration: 500.ms);
  }

  Widget _snapshotTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: CT.cardDecor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CT.textH(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: CT.textS(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreHighlights(bool isDark) {
    final quiz = (_dashboardData?['quizHighlights'] as List? ?? []).cast<dynamic>();
    final tests = (_dashboardData?['testHighlights'] as List? ?? []).cast<dynamic>();

    if (quiz.isEmpty && tests.isEmpty) {
      return _buildEmptyState(
        context,
        'No quiz/test scores yet',
        Icons.bar_chart_rounded,
      );
    }

    Widget scoreCard({
      required String title,
      required IconData icon,
      required Color color,
      required List<dynamic> items,
      required String dateKey,
      required String labelKey,
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
                'No data yet',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: CT.textS(context),
                ),
              )
            else
              ...items.take(2).map((item) {
                final pct = (item['percentage'] ?? 0).toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (item[labelKey] ?? item['title'] ?? '').toString(),
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CT.textH(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _fmtDate(item[dateKey]),
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: CT.textS(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: GoogleFonts.sora(
                          fontSize: 13,
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
          'Recent Scores',
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
              child: scoreCard(
                title: 'Quiz',
                icon: Icons.quiz_outlined,
                color: AppColors.primary,
                items: quiz,
                dateKey: 'submitted_at',
                labelKey: 'title',
              ),
            ),
            const SizedBox(width: AppDimensions.step),
            Expanded(
              child: scoreCard(
                title: 'Tests',
                icon: Icons.menu_book_rounded,
                color: AppColors.success,
                items: tests,
                dateKey: 'exam_date',
                labelKey: 'title',
              ),
            ),
          ],
        ),
      ],
    ).animate(delay: 340.ms).fadeIn(duration: 500.ms);
  }

  Widget _buildAssignmentsPreview(bool isDark) {
    final childId = _children[_selectedChild]['id'];
    final pendingAssignments = (_dashboardData?['pendingAssignments'] as List? ?? [])
        .where((item) => (item as Map)['student_id'] == childId)
        .take(3)
        .cast<Map>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Assignments',
              style: GoogleFonts.sora(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CT.textH(context),
              ),
            ),
            const Spacer(),
            CPPressable(
              onTap: () => context.go('/parent/weekly-report/$childId'),
              child: Text(
                'View all',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: CT.accent(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.step),
        if (pendingAssignments.isEmpty)
          _buildEmptyState(
            context,
            'No pending assignments',
            Icons.assignment_turned_in_outlined,
          )
        else
          ...pendingAssignments.map((item) {
            final due = _fmtDate(item['due_date']);
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
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.assignment_late_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.step),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['title'] ?? 'Assignment').toString(),
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: CT.textH(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Due: $due',
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
          }),
      ],
    ).animate(delay: 360.ms).fadeIn(duration: 500.ms);
  }

  String _fmtDate(dynamic value) {
    if (value == null) return 'N/A';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  Widget _buildAttendanceFee(bool isDark) {
    final child = _children[_selectedChild];
    final attendance = (child['attendance'] ?? 0).toDouble() / 100.0;
    final pendingFee = child['pendingFee'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: CT.cardDecor(context),
            child: Column(
              children: [
                CPAnimatedRing(
                  progress: attendance,
                  size: 65,
                  strokeWidth: 5,
                  color: AppColors.success,
                  child: Text(
                    '${(attendance * 100).toInt()}%',
                    style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  'Attendance',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CT.textS(context),
                  ),
                ),
                Text(
                  'Current Month',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: CT.textM(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.step),
        Expanded(
          child: CPPressable(
            onTap: () {
              if (pendingFee > 0) {
                context.go('/parent/fee-payment');
              } else {
                context.go('/parent/payment-history');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: (pendingFee > 0 ? AppColors.warning : AppColors.success)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                border: Border.all(
                  color:
                      (pendingFee > 0 ? AppColors.warning : AppColors.success)
                          .withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        pendingFee > 0
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        size: 16,
                        color: pendingFee > 0
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        pendingFee > 0 ? 'Fee pending' : 'Fees Paid',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: pendingFee > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'Rs $pendingFee',
                    style: GoogleFonts.sora(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: CT.textH(context),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  if (pendingFee > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'Pay Now',
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate(delay: 300.ms).fadeIn(duration: 500.ms);
  }

  Widget _buildLatestResult(bool isDark) {
    final results =
        _dashboardData?['upcomingExams'] as List? ??
        []; // upcomingExams already used
    if (results.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming Exam',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: CT.textH(context),
            ),
          ),
          const SizedBox(height: AppDimensions.step),
          _buildEmptyState(
            context,
            "No upcoming exams",
            Icons.analytics_outlined,
          ),
        ],
      ).animate(delay: 400.ms).fadeIn(duration: 500.ms);
    }
    if (results.isNotEmpty) {
      final latest = results.first;

      return CPPressable(
        onTap: () {
          if (_children.isNotEmpty) {
            context.go(
              '/parent/weekly-report/${_children[_selectedChild]['id']}',
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: CT.cardDecor(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upcoming Exam',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latest['title'] ?? 'Test',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: CT.textH(context),
                          ),
                        ),
                        Text(
                          latest['subject'] ?? '',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: CT.textS(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Marks: ${latest['total_marks']}',
                        style: GoogleFonts.sora(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: CT.accent(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ).animate(delay: 400.ms).fadeIn(duration: 500.ms);
    }
    return const SizedBox.shrink();
  }

  Widget _buildQuickTools(bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Quick tools',
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
            child: _quickTool(
              icon: Icons.insights_outlined,
              title: 'Weekly Report',
              subtitle: 'Attendance, marks, rank',
              color: AppColors.primary,
              onTap: () {
                if (_children.isNotEmpty) {
                  context.go(
                    '/parent/weekly-report/${_children[_selectedChild]['id']}',
                  );
                }
              },
            ),
          ),
          const SizedBox(width: AppDimensions.step),
          Expanded(
            child: _quickTool(
              icon: Icons.history_edu_outlined,
              title: 'Payment History',
              subtitle: 'Paid, pending, overdue',
              color: AppColors.warning,
              onTap: () => context.go('/parent/payment-history'),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppDimensions.step),
      Row(
        children: [
          Expanded(
            child: _quickTool(
              icon: Icons.insights_rounded,
              title: 'Child Activity',
              subtitle: 'Quiz, tests, tasks, schedule',
              color: AppColors.success,
              onTap: () {
                if (_children.isNotEmpty) {
                  context.go('/parent/weekly-report/${_children[_selectedChild]['id']}');
                }
              },
            ),
          ),
          const SizedBox(width: AppDimensions.step),
          Expanded(
            child: _quickTool(
              icon: Icons.currency_rupee_rounded,
              title: 'Pay Fees',
              subtitle: 'Upload proof and track status',
              color: AppColors.warning,
              onTap: () => context.go('/parent/fee-payment'),
            ),
          ),
        ],
      ),
    ],
  ).animate(delay: 360.ms).fadeIn(duration: 500.ms);

  Widget _quickTool({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) => CPPressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: CT.cardDecor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CT.textH(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(fontSize: 11, color: CT.textS(context)),
          ),
        ],
      ),
    ),
  );

  Widget _buildTodaySchedule(bool isDark) {
    final schedules =
        (_dashboardData?['todaySchedule'] as List? ?? []).cast<dynamic>();
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
        if (schedules.isEmpty)
          _buildEmptyState(
            context,
            'No classes scheduled',
            Icons.calendar_today_rounded,
          )
        else
          ...schedules
              .take(4)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                  child: _schedItem(
                    _fmtTime(item['start_time']),
                    (item['name'] ?? item['subject'] ?? 'Class').toString(),
                    '${item['batch_name'] ?? 'Batch'} | ${item['teacher_name'] ?? 'Teacher'}',
                    isDark,
                  ),
                ),
              ),
      ],
    ).animate(delay: 500.ms).fadeIn(duration: 500.ms);
  }

  Widget _schedItem(String time, String sub, String info, bool isDark) =>
      CPPressable(
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.step),
          decoration: CT.cardDecor(context),
          child: Row(
            children: [
              Text(
                time,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CT.accent(context),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CT.textH(context),
                      ),
                    ),
                    Text(
                      info,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
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

  Widget _buildAnnouncement(bool isDark) {
    final announcements = _dashboardData?['announcements'] as List? ?? [];
    if (announcements.isEmpty) {
      return _buildEmptyState(
        context,
        "No new announcements",
        Icons.campaign_outlined,
      ).animate(delay: 600.ms).fadeIn(duration: 500.ms);
    }
    if (announcements.isNotEmpty) {
      final latest = announcements.first;

      return CPPressable(
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: CT.accent(context).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            border: Border.all(
              color: CT.accent(context).withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: CT.accent(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.campaign_outlined,
                  size: 18,
                  color: CT.accent(context),
                ),
              ),
              const SizedBox(width: AppDimensions.step),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest['title'] ?? 'Announcement',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CT.textH(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      latest['body'] ?? '',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: CT.textS(context),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate(delay: 600.ms).fadeIn(duration: 500.ms);
    }
    return const SizedBox.shrink();
  }

  String _fmtTime(dynamic value) {
    if (value == null) return 'TBA';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return 'TBA';
    final hour = parsed.hour == 0 ? 12 : (parsed.hour > 12 ? parsed.hour - 12 : parsed.hour);
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${parsed.minute.toString().padLeft(2, '0')} $suffix';
  }

  Widget _buildEmptyState(BuildContext context, String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: CT.cardDecor(context),
      child: Column(
        children: [
          Icon(icon, size: 36, color: CT.textS(context).withValues(alpha: 0.3)),
          const SizedBox(height: AppDimensions.sm),
          Text(
            message,
            style: GoogleFonts.dmSans(fontSize: 13, color: CT.textS(context)),
          ),
        ],
      ),
    );
  }
}
