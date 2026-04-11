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
                    'Child Profile · Tap for details',
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
    ).animate(delay: 200.ms).fadeIn(duration: 500.ms);
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
                    '₹$pendingFee',
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
        _dashboardData?['todaySchedule'] as List? ??
        []; // Changed 'schedule' to 'todaySchedule' and variable name
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Schedule",
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
            "No classes scheduled today",
            Icons.calendar_today_rounded,
          )
        else
          ...schedules
              .take(3)
              .map(
                (item) => Padding(
                  // Changed 'schedule' to 'schedules'
                  padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                  child: _schedItem(
                    'Active',
                    item['name'] ?? '',
                    '${item['student_name']} · ${item['teacher_name'] ?? "Teacher"}',
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
