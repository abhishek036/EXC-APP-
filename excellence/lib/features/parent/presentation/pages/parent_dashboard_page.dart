import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_animated_ring.dart';
import '../../../../core/widgets/cp_user_avatar.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../data/repositories/parent_repository.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});
  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  final ParentRepository _parentRepo = sl<ParentRepository>();
  final _realtime = sl<RealtimeSyncService>();
  StreamSubscription<Map<String, dynamic>>? _syncSub;
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  bool _isBackgroundRefreshing = false;
  int _selectedChild = 0;
  List<dynamic> _children = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
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
          reason.contains('student') ||
          reason.contains('notification');
      if (shouldRefresh) {
        _loadDashboard();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    try {
      if (_dashboardData != null) {
        setState(() => _isBackgroundRefreshing = true);
      } else {
        setState(() => _isLoading = true);
      }
      final data = await _parentRepo.getDashboard();
      if (!mounted) return;
      setState(() {
        _dashboardData = data;
        _children = data['children'] ?? [];
        if (_selectedChild >= _children.length && _children.isNotEmpty) {
          _selectedChild = 0;
        }
        _isLoading = false;
        _isBackgroundRefreshing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isBackgroundRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.elitePrimary),
        ),
      );
    }

    if (_dashboardData == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Failed to load dashboard',
                style: GoogleFonts.plusJakartaSans(
                  color: isDark ? AppColors.paleSlate2 : Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _loadDashboard,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.elitePrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.elitePrimary, width: 2),
                    boxShadow: const [
                      BoxShadow(color: AppColors.elitePrimary, offset: Offset(3, 3)),
                    ],
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      drawer: _buildDrawer(isDark),
      body: RefreshIndicator(
        color: AppColors.elitePrimary,
        displacement: 20,
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

  Widget _buildAppBar(bool isDark) {
    final authState = context.read<AuthBloc>().state;
    final parentName = authState is AuthAuthenticated ? authState.user.name : 'Parent';
    final avatarUrl = authState is AuthAuthenticated ? authState.user.avatarUrl : null;
    final greeting = DateTime.now().hour < 12
        ? 'GOOD MORNING'
        : DateTime.now().hour < 17
            ? 'GOOD AFTERNOON'
            : 'GOOD EVENING';
    return Row(
      children: [
        Builder(
          builder: (scaffoldContext) => CPPressable(
            onTap: () {
              Scaffold.maybeOf(scaffoldContext)?.openDrawer();
            },
            child: const Padding(
              padding: EdgeInsets.only(right: 12, top: 4, bottom: 4),
              child: Icon(
                Icons.menu_rounded,
                color: AppColors.elitePrimary,
                size: 28,
              ),
            ),
          ),
        ),
        CPPressable(
          onTap: () => context.go('/parent/profile'),
          child: CpUserAvatar(
            name: parentName,
            avatarUrl: avatarUrl,
            size: 44,
            borderColor: AppColors.elitePrimary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$greeting, 👋',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.paleSlate2 : Colors.black54,
                    ),
                  ),
                  if (_isBackgroundRefreshing)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
              Text(
                parentName.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _appBarAction(Icons.notifications_none_rounded, () {
          context.go('/parent/notifications');
        }, isDark),
        const SizedBox(width: 8),
        _appBarAction(Icons.settings_outlined, () {
          context.go('/parent/settings');
        }, isDark),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }

  Widget _buildDrawer(bool isDark) {
    final authState = context.read<AuthBloc>().state;
    final parentName = authState is AuthAuthenticated ? authState.user.name : 'Parent';
    final avatarUrl = authState is AuthAuthenticated ? authState.user.avatarUrl : null;

    return Drawer(
      backgroundColor: isDark ? AppColors.eliteDarkBg : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CpUserAvatar(
                    name: parentName,
                    avatarUrl: avatarUrl,
                    size: 54,
                    backgroundColor: AppColors.moltenAmber,
                    textColor: AppColors.elitePrimary,
                    borderColor: AppColors.elitePrimary,
                    borderWidth: 3,
                    showShadow: false,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'PARENT\nPANEL',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.elitePrimary,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.elitePrimary, thickness: 2, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerTile(
                    Icons.dashboard_rounded,
                    'DASHBOARD',
                    AppColors.elitePrimary,
                    () => Navigator.pop(context),
                  ),
                  _drawerTile(
                    Icons.insights_rounded,
                    'CHILD ACTIVITY',
                    AppColors.elitePrimary,
                    () {
                      Navigator.pop(context);
                      if (_children.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No child available yet')),
                        );
                        return;
                      }
                      context.go('/parent/weekly-report/${_children[_selectedChild]['id']}');
                    },
                  ),
                  _drawerTile(
                    Icons.history_edu_rounded,
                    'PAYMENT HISTORY',
                    AppColors.elitePrimary,
                    () {
                      Navigator.pop(context);
                      context.go('/parent/payment-history');
                    },
                  ),
                  _drawerTile(
                    Icons.notifications_rounded,
                    'NOTIFICATIONS',
                    AppColors.elitePrimary,
                    () {
                      Navigator.pop(context);
                      context.go('/parent/notifications');
                    },
                  ),
                  _drawerTile(
                    Icons.person_rounded,
                    'PROFILE',
                    AppColors.elitePrimary,
                    () {
                      Navigator.pop(context);
                      context.go('/parent/profile');
                    },
                  ),
                  _drawerTile(
                    Icons.settings_rounded,
                    'SETTINGS',
                    AppColors.elitePrimary,
                    () {
                      Navigator.pop(context);
                      context.go('/parent/settings');
                    },
                  ),
                ],
              ),
            ),
            const Divider(thickness: 2, color: AppColors.elitePrimary, height: 1),
            _drawerTile(
              Icons.logout_rounded,
              'SIGN OUT',
              AppColors.coralRed,
              () {
                Navigator.pop(context);
                context.read<AuthBloc>().add(AuthLogoutRequested());
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _appBarAction(IconData icon, VoidCallback onTap, bool isDark) {
    return CPPressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppColors.eliteDarkBg : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.elitePrimary,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black38 : AppColors.elitePrimary,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 21,
          color: isDark ? AppColors.paleSlate1 : AppColors.elitePrimary,
        ),
      ),
    );
  }

  Widget _buildChildSelector() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: List.generate(_children.length, (i) {
        final sel = _selectedChild == i;
        final child = _children[i];
        return Padding(
          padding: EdgeInsets.only(right: i < _children.length - 1 ? 12 : 0),
          child: CPPressable(
            onTap: () => setState(() => _selectedChild = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? CT.accent(context) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.black,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black,
                    offset: sel ? const Offset(2, 2) : const Offset(3, 3),
                  ),
                ],
              ),
              child: Text(
                (child['name'] ?? 'Child').toString().toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: sel ? Colors.white : Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      }),
    ),
  ).animate(delay: 100.ms).fadeIn(duration: 400.ms);

  Widget _buildChildOverview(bool isDark) {
    final child = _children[_selectedChild];
    return CPPressable(
      onTap: () {
        final id = child['id'] ?? child['uid'] ?? '';
        if (id.isNotEmpty) {
          context.push('/parent/weekly-report/$id');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(4, 4)),
          ],
        ),
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
                  style: GoogleFonts.plusJakartaSans(
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CT.textH(context),
                    ),
                  ),
                  Text(
                    'Child Profile | Tap for details',
                    style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
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
                'No data yet',
                style: GoogleFonts.plusJakartaSans(
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CT.textH(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _fmtDate(item[dateKey]),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: CT.textS(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: GoogleFonts.plusJakartaSans(
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
              style: GoogleFonts.plusJakartaSans(
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
                style: GoogleFonts.plusJakartaSans(
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
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: CT.textH(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Due: $due',
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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(4, 4)),
              ],
            ),
            child: Column(
              children: [
                CPAnimatedRing(
                  progress: attendance,
                  size: 65,
                  strokeWidth: 5,
                  color: AppColors.success,
                  child: Text(
                    '${(attendance * 100).toInt()}%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  'ATTENDANCE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
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
              final recordId = child['pendingFeeRecordId'];
              if (pendingFee > 0 && recordId != null) {
                context.go('/parent/fee-payment/$recordId');
              } else if (pendingFee > 0) {
                context.go('/parent/fee-payment');
              } else {
                context.go('/parent/payment-history');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.account_balance_wallet_rounded, color: AppColors.error, size: 30),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  FittedBox(
                    child: Text(
                      'Rs $pendingFee',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  Text(
                    'PENDING FEE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLatestResult(bool isDark) {
    final results = _dashboardData?['upcomingExams'] as List? ?? [];
    if (results.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UPCOMING EXAM',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildEmptyState(context, "No upcoming exams", Icons.analytics_outlined),
        ],
      );
    }
    final latest = results.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UPCOMING EXAM',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        CPPressable(
          onTap: () {
            if (_children.isNotEmpty) {
              context.go('/parent/weekly-report/${_children[_selectedChild]['id']}');
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(4, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.event_note_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (latest['title'] ?? 'Assessment').toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        latest['subject'] ?? 'General',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.grey[600],
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      latest['exam_date'] ?? '',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTools(bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Quick tools',
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
              onTap: () {
                final child = _children[_selectedChild];
                final recordId = child['pendingFeeRecordId'];
                if (recordId != null) {
                  context.go('/parent/fee-payment/$recordId');
                } else {
                  context.go('/parent/fee-payment');
                }
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: AppDimensions.step),
      Row(
        children: [
          Expanded(
            child: _quickTool(
              icon: Icons.play_circle_fill_rounded,
              title: 'Video Library',
              subtitle: 'Recorded lectures',
              color: AppColors.electricBlue,
              onTap: () => context.go('/parent/video-lectures'),
            ),
          ),
          const SizedBox(width: AppDimensions.step),
          Expanded(
            child: _quickTool(
              icon: Icons.campaign_rounded,
              title: 'Notice Board',
              subtitle: 'School announcements',
              color: AppColors.mintGreen,
              onTap: () => context.go('/parent/notifications'),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CT.textH(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textS(context)),
          ),
        ],
      ),
    ),
  );

  Widget _buildTodaySchedule(bool isDark) {
    final schedules = (_dashboardData?['todaySchedule'] as List? ?? []).cast<dynamic>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UPCOMING SCHEDULE',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        if (schedules.isEmpty)
          _buildEmptyState(context, 'No classes scheduled', Icons.calendar_today_rounded)
        else
          ...schedules.take(4).map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _schedItem(
              _fmtTime(item['start_time']),
              (item['name'] ?? item['subject'] ?? 'Class').toString(),
              '${item['batch_name'] ?? 'Batch'} | ${item['teacher_name'] ?? 'Teacher'}',
              isDark,
            ),
          )),
      ],
    );
  }

  Widget _schedItem(String time, String sub, String info, bool isDark) => CPPressable(
    onTap: () => context.push('/parent/reports'),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3)),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                time.split(' ')[0],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              Text(
                time.split(' ').length > 1 ? time.split(' ')[1] : 'AM',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  info,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black26),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CT.textH(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      latest['body'] ?? '',
                      style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: CT.textS(context)),
          ),
        ],
      ),
    );
  }
}
