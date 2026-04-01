import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_animated_ring.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/student/data/repositories/student_repository.dart';
import '../../../../core/di/injection_container.dart';

import '../../../../core/services/realtime_sync_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/widgets/cp_user_avatar.dart';
import 'dart:async';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _studentRepo = sl<StudentRepository>();
  final _realtime = sl<RealtimeSyncService>();
  StreamSubscription<Map<String, dynamic>>? _syncSub;

  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _error;
  int _unreadCount = 0;

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
      if (type == 'notification' ||
          type == 'broadcast' ||
          reason.contains('notification') ||
          reason.contains('announcement')) {
        _checkNotifications();
      }
      if (type == 'unread_count_update') {
        final count = (event['unread_count'] as num?)?.toInt() ?? 0;
        if (mounted) setState(() => _unreadCount = count);
      }
      // Refresh dashboard on schedule/data changes
      if (type == 'batch_sync' || type == 'dashboard_sync') {
        if (reason.contains('lecture') ||
            reason.contains('schedule') ||
            reason.contains('attendance') ||
            reason.contains('assignment') ||
            reason.contains('doubt') ||
            reason.contains('quiz') ||
            reason.contains('fee') ||
            reason.contains('exam') ||
            reason.contains('student')) {
          _loadDashboard();
        }
      }
    });
  }

  Future<void> _checkNotifications() async {
    try {
      final count = await _studentRepo.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _studentRepo.getDashboardStats();
      int count = 0;
      try {
        count = await _studentRepo.getUnreadCount();
      } catch (e) {
        debugPrint('Failed to fetch unread count dashboard call: $e');
      }

      setState(() {
        _dashboardData = data;
        _unreadCount = count;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _formattedDate {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Widget _neoContainer({
    required Widget child,
    bool isDark = true,
    EdgeInsetsGeometry? padding,
    Color? bgColor,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor ?? (isDark ? AppColors.eliteDarkBg : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elitePrimary, width: 3),
        boxShadow: const [
          BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4)),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      drawer: _buildDrawer(context, isDark),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.elitePrimary,
          displacement: 20,
          onRefresh: _loadDashboard,
          child: _isLoading
              ? _buildLoadingState(context)
              : _error != null
              ? _buildErrorState(context)
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildAppBar(context, isDark),
                      const SizedBox(height: 8),
                      Text(
                        _formattedDate,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildQuickAccess(context, isDark),
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        "Today's Schedule",
                        () => context.push('/student/timetable'),
                        isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildTodaysClasses(context, isDark),
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        "Exam Center",
                        () => context.push('/student/exam-calendar'),
                        isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildExamCountdown(context, isDark),
                      const SizedBox(height: 32),
                      _buildSectionHeader("Academic Flow", () {}, isDark),
                      const SizedBox(height: 16),
                      _buildExploreMore(context, isDark),
                      const SizedBox(height: 48),
                      _buildSectionHeader(
                        "Performance Stats",
                        () => context.push('/student/results'),
                        isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildStatsRow(context, isDark),
                      const SizedBox(height: 40),
                      _buildFeeBanner(context, isDark),
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        "Notice Board",
                        () => context.push('/student/announcements'),
                        isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildAnnouncements(context, isDark),
                      const SizedBox(height: 40),
                      _buildSectionHeader("Connect", () {}, isDark),
                      const SizedBox(height: 16),
                      _buildConnectWithUs(context, isDark),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.elitePrimary),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.coralRed),
          const SizedBox(height: 16),
          Text(
            'Failed to load dashboard',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.elitePrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.elitePrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.elitePrimary, width: 2),
              ),
              elevation: 0,
            ),
            onPressed: _loadDashboard,
            child: Text(
              'Retry',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // DRAWER
  // ═══════════════════════════════════════════════════════
  Widget _buildDrawer(BuildContext context, bool isDark) {
    final name = _dashboardData?['student']?['name'] ?? 'Student';
    final authState = context.read<AuthBloc>().state;
    final avatarUrl = authState is AuthAuthenticated
        ? authState.user.avatarUrl
        : null;
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
                    name: name,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STUDENT\nPANEL',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.elitePrimary,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              color: AppColors.elitePrimary,
              thickness: 2,
              height: 1,
            ),
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
                    Icons.menu_book_rounded,
                    'STUDY MATERIAL',
                    AppColors.elitePrimary,
                    () {
                      Navigator.pop(context);
                      context.go('/student/materials');
                    },
                  ),
                  _drawerTile(
                    Icons.play_circle_rounded,
                    'CONCEPT VIDEOS',
                    AppColors.elitePrimary,
                    () {
                      Navigator.pop(context);
                      context.go('/student/video-lectures');
                    },
                  ),
                  _drawerTile(
                    Icons.calendar_month_rounded,
                    'EXAM CALENDAR',
                    AppColors.elitePrimary,
                    () {
                      Navigator.pop(context);
                      context.go('/student/exam-calendar');
                    },
                  ),
                  _drawerTile(
                    Icons.receipt_long_rounded,
                    'FEE HISTORY',
                    AppColors.elitePrimary,
                    () {
                      Navigator.pop(context);
                      context.go('/student/fee-history');
                    },
                  ),
                  _drawerTile(
                    Icons.person_rounded,
                    'PROFILE',
                    AppColors.elitePrimary,
                    () {
                      Navigator.pop(context);
                      context.go('/student/profile');
                    },
                  ),
                  _drawerTile(
                    Icons.settings_rounded,
                    'SETTINGS',
                    AppColors.elitePrimary,
                    () {
                      Navigator.pop(context);
                      context.go('/student/settings');
                    },
                  ),
                ],
              ),
            ),
            const Divider(
              thickness: 2,
              color: AppColors.elitePrimary,
              height: 1,
            ),
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

  // ═══════════════════════════════════════════════════════
  // APP BAR — time-aware greeting
  // ═══════════════════════════════════════════════════════
  Widget _buildAppBar(BuildContext context, bool isDark) {
    final name =
        (_dashboardData?['student']?['name']?.split(' ').first) ?? 'Student';
    final authState = context.read<AuthBloc>().state;
    final avatarUrl = authState is AuthAuthenticated
        ? authState.user.avatarUrl
        : null;

    return Row(
      children: [
        CPPressable(
          onTap: () {
            HapticFeedback.lightImpact();
            _scaffoldKey.currentState?.openDrawer();
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
        CPPressable(
          onTap: () => context.go('/student/profile'),
          child: CpUserAvatar(
            name: name,
            avatarUrl: avatarUrl,
            size: 44,
            borderColor: AppColors.elitePrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              Text(
                '$name 🙌',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.deepNavy,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        _appBarAction(
          Icons.notifications_none_rounded,
          () {
            HapticFeedback.mediumImpact();
            context.go('/student/notifications');
          },
          isDark,
          badge: _unreadCount > 0,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }

  Widget _appBarAction(
    IconData icon,
    VoidCallback onTap,
    bool isDark, {
    bool badge = false,
  }) {
    return CPPressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppColors.eliteDarkBg : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.elitePrimary, width: 2),
          boxShadow: const [
            BoxShadow(color: AppColors.elitePrimary, offset: Offset(2, 2)),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 21, color: AppColors.elitePrimary),
            if (badge)
              const Positioned(
                top: 8,
                right: 8,
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.coralRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SECTION HEADER
  // ═══════════════════════════════════════════════════════
  Widget _buildSectionHeader(String title, VoidCallback onTap, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.deepNavy,
              letterSpacing: -0.6,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        CPPressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.moltenAmber,
              border: Border.all(color: AppColors.elitePrimary, width: 2),
              boxShadow: const [
                BoxShadow(color: AppColors.elitePrimary, offset: Offset(2, 2)),
              ],
            ),
            child: Row(
              children: [
                Text(
                  'Open',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.elitePrimary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: AppColors.elitePrimary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // QUICK ACCESS — 4 action shortcut row
  // ═══════════════════════════════════════════════════════
  Widget _buildQuickAccess(BuildContext context, bool isDark) => Row(
    children: [
      _qaItem(
        context,
        Icons.trending_up_rounded,
        'Performance',
        AppColors.elitePrimary,
        '/student/performance',
        isDark,
      ),
      const SizedBox(width: 10),
      _qaItem(
        context,
        Icons.calendar_month_rounded,
        'Timetable',
        const Color(0xFF5C7CFA),
        '/student/timetable',
        isDark,
      ),
      const SizedBox(width: 10),
      _qaItem(
        context,
        Icons.help_outline_rounded,
        'Doubts',
        AppColors.moltenAmber,
        '/student/doubts',
        isDark,
      ),
      const SizedBox(width: 10),
      _qaItem(
        context,
        Icons.checklist_rounded,
        'Syllabus',
        AppColors.elitePurple,
        '/student/syllabus',
        isDark,
      ),
    ],
  ).animate(delay: 150.ms).fadeIn(duration: 400.ms);

  Widget _qaItem(
    BuildContext ctx,
    IconData icon,
    String label,
    Color color,
    String route,
    bool isDark,
  ) => Expanded(
    child: CPPressable(
      onTap: () => ctx.push(route),
      child: _neoContainer(
        isDark: isDark,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.elitePrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════
  // TODAY'S SCHEDULE — horizontal class cards
  // ═══════════════════════════════════════════════════════
  Widget _buildTodaysClasses(BuildContext context, bool isDark) {
    final lectures = _dashboardData?['today_schedule'] as List? ?? [];

    if (lectures.isEmpty) {
      return _neoContainer(
        isDark: isDark,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No classes scheduled for today',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
      ).animate(delay: 200.ms).fadeIn(duration: 500.ms);
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: lectures.length,
        itemBuilder: (context, index) {
          final l = lectures[index];
          final subject = (l['title'] ?? l['subject'] ?? 'No Subject')
              .toString();
          final time =
              '${l['start_time'] ?? '00:00'} - ${l['end_time'] ?? '00:00'}';
          final teacher = l['teacher_name'] ?? 'TBA';

          Color c = AppColors.elitePrimary;
          if (subject.toLowerCase().contains('physics')) {
            c = AppColors.physics;
          } else if (subject.toLowerCase().contains('chemistry')) {
            c = AppColors.chemistry;
          } else if (subject.toLowerCase().contains('math')) {
            c = AppColors.mathematics;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _classCard(context, subject, time, teacher, c, isDark),
          );
        },
      ),
    ).animate(delay: 200.ms).fadeIn(duration: 500.ms);
  }

  Widget _classCard(
    BuildContext ctx,
    String subject,
    String time,
    String teacher,
    Color c,
    bool isDark,
  ) {
    return CPPressable(
      onTap: () => ctx.push('/student/timetable'),
      child: _neoContainer(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.elitePrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subject,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.elitePrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  time,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepNavy,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      teacher,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // EXAM COUNTDOWN
  // ═══════════════════════════════════════════════════════
  Widget _buildExamCountdown(BuildContext context, bool isDark) {
    final exams = _dashboardData?['upcoming_exams'] as List? ?? [];
    if (exams.isEmpty) return const SizedBox.shrink();

    final exam = exams.first;
    final date =
        DateTime.tryParse(exam['exam_date'] ?? '')?.toLocal() ?? DateTime.now();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(date.year, date.month, date.day);

    final diffRaw = examDay.difference(today).inDays;
    final isPast = diffRaw < 0;
    final diff = diffRaw.abs();

    return CPPressable(
          onTap: () => context.go('/student/exam-calendar'),
          child: _neoContainer(
            isDark: isDark,
            bgColor: AppColors.elitePrimary,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.moltenAmber,
                          border: Border.all(color: Colors.black, width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isPast ? 'COMPLETED' : 'UPCOMING',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        exam['title'] ?? 'Upcoming Exam',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exam['subject'] ?? 'All Subjects',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        diff.toString().padLeft(2, '0'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.elitePrimary,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPast ? 'AGO' : 'DAYS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.coralRed,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(delay: 300.ms)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.08, end: 0);
  }

  // ═══════════════════════════════════════════════════════
  // EXPLORE MORE — 8-item quick action grid
  // ═══════════════════════════════════════════════════════
  Widget _buildExploreMore(BuildContext context, bool isDark) {
    final items = [
      {
        'icon': Icons.quiz_rounded,
        'label': 'Tests',
        'color': AppColors.elitePrimary,
        'route': '/student/quiz',
      },
      {
        'icon': Icons.play_circle_filled_rounded,
        'label': 'Videos',
        'color': const Color(0xFF5C7CFA),
        'route': '/student/video-lectures',
      },
      {
        'icon': Icons.menu_book_rounded,
        'label': 'Notes',
        'color': AppColors.moltenAmber,
        'route': '/student/materials',
      },
      {
        'icon': Icons.assignment_rounded,
        'label': 'Assign.',
        'color': AppColors.coralRed,
        'route': '/student/assignment-submit',
      },
      {
        'icon': Icons.class_rounded,
        'label': 'Batches',
        'color': AppColors.elitePurple,
        'route': '/student/batches',
      },
      {
        'icon': Icons.assessment_rounded,
        'label': 'Results',
        'color': AppColors.mintGreen,
        'route': '/student/results',
      },
      {
        'icon': Icons.history_edu_rounded,
        'label': 'Exams',
        'color': const Color(0xFF7048E8),
        'route': '/student/exam-calendar',
      },
      {
        'icon': Icons.receipt_long_rounded,
        'label': 'Fees',
        'color': AppColors.softAmber,
        'route': '/student/fee-history',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return CPPressable(
              onTap: () => context.go(item['route'] as String),
              child: _neoContainer(
                isDark: isDark,
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (item['color'] as Color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        size: 20,
                        color: item['color'] as Color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['label'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.elitePrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            )
            .animate(delay: Duration(milliseconds: 30 * index))
            .fadeIn(duration: 250.ms);
      },
    ).animate(delay: 400.ms).fadeIn(duration: 400.ms);
  }

  // ═══════════════════════════════════════════════════════
  // STATS ROW
  // ═══════════════════════════════════════════════════════
  Widget _buildStatsRow(BuildContext context, bool isDark) {
    final stats = _dashboardData?['stats'] ?? {};
    final attPct = (stats['attendance_percentage'] ?? 0) / 100.0;

    return Row(
      children: [
        _statCircle(
          context,
          '${(attPct * 100).toInt()}%',
          'Attendance',
          attPct,
          AppColors.mintGreen,
          isDark,
        ),
        const SizedBox(width: 12),
        _statCircle(
          context,
          '${stats['pending_doubts'] ?? 0}',
          'Open Doubts',
          0.5,
          AppColors.moltenAmber,
          isDark,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CPPressable(
            onTap: () => context.go('/student/results'),
            child: _neoContainer(
              isDark: isDark,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.elitePrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      size: 22,
                      color: AppColors.elitePrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${stats['upcoming_exams_count'] ?? 0}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.elitePrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Upcoming',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.elitePrimary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate(delay: 500.ms).fadeIn(duration: 400.ms);
  }

  Widget _statCircle(
    BuildContext ctx,
    String val,
    String label,
    double pct,
    Color c,
    bool isDark,
  ) => Expanded(
    child: CPPressable(
      onTap: () => ctx.push('/student/performance'),
      child: _neoContainer(
        isDark: isDark,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            CPAnimatedRing(
              progress: pct,
              color: c,
              size: 52,
              strokeWidth: 5,
              child: Text(
                val,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.elitePrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.elitePrimary.withValues(alpha: 0.6),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════
  // FEE BANNER
  // ═══════════════════════════════════════════════════════
  Widget _buildFeeBanner(BuildContext context, bool isDark) {
    final pendingFees = _dashboardData?['pending_fees'] as List? ?? [];
    if (pendingFees.isEmpty) return const SizedBox.shrink();

    final totalVal = _dashboardData?['stats']?['pending_fees_total'] ?? 0;

    return CPPressable(
      onTap: () => context.go('/student/fee-history'),
      child: _neoContainer(
        isDark: isDark,
        bgColor: AppColors.coralRed,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 24,
                color: AppColors.coralRed,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹$totalVal Pending Fees',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pendingFees.length} record(s) need attention',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    ).animate(delay: 600.ms).fadeIn(duration: 400.ms);
  }

  // ═══════════════════════════════════════════════════════
  // ANNOUNCEMENTS
  // ═══════════════════════════════════════════════════════
  Widget _buildAnnouncements(BuildContext context, bool isDark) {
    final list = _dashboardData?['announcements'] as List? ?? [];
    if (list.isEmpty) return _emptyCard("No recent announcements", isDark);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: list
            .take(3)
            .map(
              (a) => Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _annItem(
                  context,
                  a['title'] ?? 'Announcement',
                  a['body'] ?? '',
                  'Recent',
                  Icons.campaign_rounded,
                  AppColors.elitePrimary,
                  isDark,
                ),
              ),
            )
            .toList(),
      ),
    ).animate(delay: 800.ms).fadeIn(duration: 400.ms);
  }

  Widget _emptyCard(String text, bool isDark) => _neoContainer(
    isDark: isDark,
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 24,
            color: AppColors.elitePrimary.withValues(alpha: 0.26),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.deepNavy.withValues(alpha: 0.45),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _annItem(
    BuildContext ctx,
    String title,
    String body,
    String time,
    IconData ic,
    Color c,
    bool isDark,
  ) => CPPressable(
    onTap: () => ctx.push('/student/announcements'),
    child: _neoContainer(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 250,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(ic, size: 20, color: c),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.elitePrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
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
    ),
  );

  // ═══════════════════════════════════════════════════════
  // CONNECT WITH US
  // ═══════════════════════════════════════════════════════
  Widget _buildConnectWithUs(BuildContext context, bool isDark) {
    return _neoContainer(
      isDark: isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _socialBtn(
                context,
                Icons.play_circle_filled_rounded,
                'YouTube',
                const Color(0xFFFF0000),
                isDark,
              ),
              const SizedBox(width: 12),
              _socialBtn(
                context,
                Icons.facebook_rounded,
                'Facebook',
                const Color(0xFF1877F2),
                isDark,
              ),
              const SizedBox(width: 12),
              _socialBtn(
                context,
                Icons.camera_alt_rounded,
                'Instagram',
                const Color(0xFFE4405F),
                isDark,
              ),
              const SizedBox(width: 12),
              _socialBtn(
                context,
                Icons.language_rounded,
                'Website',
                AppColors.elitePrimary,
                isDark,
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: 900.ms).fadeIn(duration: 400.ms);
  }

  Widget _socialBtn(
    BuildContext ctx,
    IconData icon,
    String label,
    Color color,
    bool isDark,
  ) => Expanded(
    child: CPPressable(
      onTap: () {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('$label link not configured yet'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            maxLines: 1,
          ),
        ],
      ),
    ),
  );
}
