import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_animated_ring.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/shared/presentation/widgets/global_search_overlay.dart';
import '../../../../features/student/data/repositories/student_repository.dart';
import '../../../../core/di/injection_container.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _studentRepo = sl<StudentRepository>();

  int _testimonialPage = 0;
  final _testimonialController = PageController();

  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _studentRepo.getDashboardStats();
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  final _testimonials = [
    {
      'quote':
          'The coaching methodology is amazing. Teachers explain every concept so clearly and my rank improved dramatically.',
      'name': 'Kartik Sharma',
      'batch': 'JEE Advanced 2026',
      'rank': '800',
    },
    {
      'quote':
          'Best study material and doubt solving. The mentors are always available and the mock tests feel like real exams.',
      'name': 'Ananya Gupta',
      'batch': 'NEET UG 2026',
      'rank': '245',
    },
    {
      'quote':
          'I improved so much in physics after joining. The concept videos and practice sets are top notch.',
      'name': 'Rohit Verma',
      'batch': 'JEE Mains 2026',
      'rank': '1200',
    },
    {
      'quote':
          'Weekly tests and detailed analysis helped me identify my weak areas. Feeling much more confident now.',
      'name': 'Priya Nair',
      'batch': 'JEE Advanced 2026',
      'rank': '550',
    },
  ];

  // Time-aware greeting
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
    _testimonialController.dispose();
    super.dispose();
  }

  Widget _glassContainer({required Widget child, bool isDark = true, EdgeInsetsGeometry? padding}) {
    if (!isDark) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppDimensions.shadowSm(false),
        ),
        child: child,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.glassWhiteCard,
            border: Border.all(color: AppColors.glassBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: CT.bg(context),
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: _isLoading
              ? _buildLoadingState(context)
              : _error != null
                  ? _buildErrorState(context)
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.pagePaddingH,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppDimensions.md),
                          _buildAppBar(context),
                          const SizedBox(height: AppDimensions.xs),
                          Text(
                            _formattedDate,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: CT.textM(context),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.lg),
                          _buildQuickAccess(context),
                          const SizedBox(height: AppDimensions.lg),
                          _buildTodaysClasses(context),
                          const SizedBox(height: AppDimensions.lg),
                          _buildExamCountdown(context),
                          const SizedBox(height: AppDimensions.lg),
                          _buildExploreMore(context),
                          const SizedBox(height: AppDimensions.lg),
                          _buildStatsRow(context),
                          const SizedBox(height: AppDimensions.lg),
                          _buildFeeBanner(context),
                          const SizedBox(height: AppDimensions.lg),
                          _buildTestimonials(context),
                          const SizedBox(height: AppDimensions.lg),
                          _buildAnnouncements(context),
                          const SizedBox(height: AppDimensions.lg),
                          _buildConnectWithUs(context),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Failed to load dashboard', style: GoogleFonts.sora(fontSize: 18, color: CT.textH(context))),
          const SizedBox(height: 8),
          Text(_error ?? 'Unknown error', style: GoogleFonts.dmSans(color: CT.textM(context))),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadDashboard, child: const Text('Retry')),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // DRAWER
  // ═══════════════════════════════════════════════════════
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: CT.bg(context),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: CT.border(context), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: CT.accent(context).withValues(alpha: 0.12),
                    child: Text(
                      'P',
                      style: GoogleFonts.sora(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: CT.accent(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dashboardData?['student']?['name'] ?? 'Student User',
                          style: GoogleFonts.sora(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: CT.textH(context),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.xxs),
                        Text(
                          _dashboardData?['student']?['phone'] ?? '+91 XXXXX XXXXX',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: CT.textM(context),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.xs),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            context.go('/student/profile');
                          },
                          child: Text(
                            'View profile ›',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: CT.accent(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                children: [
                  _drawerItem(
                    context,
                    Icons.menu_book_outlined,
                    'Study Material',
                    'Notes, sample papers & more',
                    () {
                      Navigator.pop(context);
                      context.go('/student/materials');
                    },
                  ),
                  _drawerItem(
                    context,
                    Icons.play_circle_outline,
                    'Concept Videos',
                    'Short animated video lessons',
                    () {
                      Navigator.pop(context);
                      context.go('/student/video-player');
                    },
                  ),
                  _drawerItem(
                    context,
                    Icons.bookmark_outline,
                    'My Saved Content',
                    'Saved classes, notes & PDFs',
                    () {
                      Navigator.pop(context);
                      context.go('/student/materials');
                    },
                  ),
                  _drawerItem(
                    context,
                    Icons.calendar_today_outlined,
                    'Exam Calendar',
                    'Upcoming exams & schedule',
                    () {
                      Navigator.pop(context);
                      context.go('/student/exam-calendar');
                    },
                  ),
                  _drawerItem(
                    context,
                    Icons.receipt_long_outlined,
                    'Fee History',
                    'Payment records & receipts',
                    () {
                      Navigator.pop(context);
                      context.go('/student/fee-history');
                    },
                  ),
                  _drawerItem(
                    context,
                    Icons.headset_mic_outlined,
                    'Share Feedback',
                    'Help us improve your experience',
                    () {
                      Navigator.pop(context);
                    },
                  ),
                  Divider(
                    color: CT.border(context),
                    height: AppDimensions.lg,
                    indent: AppDimensions.md,
                    endIndent: AppDimensions.md,
                  ),
                  _drawerItem(
                    context,
                    Icons.settings_outlined,
                    'Settings',
                    'Dark mode, notifications & more',
                    () {
                      Navigator.pop(context);
                      context.go('/student/settings');
                    },
                  ),
                  _drawerItem(
                    context,
                    Icons.logout,
                    'Log Out',
                    'Sign out of your account',
                    () {
                      Navigator.pop(context);
                      context.go('/login');
                    },
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final clr = isDestructive ? AppColors.error : CT.textS(context);
    return ListTile(
      leading: Icon(icon, size: 20, color: clr),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDestructive ? AppColors.error : CT.textH(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(fontSize: 11, color: CT.textM(context)),
      ),
      trailing: Icon(Icons.chevron_right, size: 16, color: CT.textM(context)),
      onTap: onTap,
    );
  }

  // ═══════════════════════════════════════════════════════
  // APP BAR — time-aware greeting
  // ═══════════════════════════════════════════════════════
  Widget _buildAppBar(BuildContext context) {
    final isDark = CT.isDark(context);
    final name = (_dashboardData?['student']?['name']?.split(' ').first) ?? 'Student';
    
    return Row(
      children: [
        GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.glassBorder),
              image: const DecorationImage(
                image: NetworkImage('https://i.pravatar.cc/150?img=11'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: CT.textS(context))),
              const SizedBox(height: 2),
              Text('$name 🙌', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context), letterSpacing: -0.5)),
            ],
          ),
        ),
        CPPressable(
          onTap: () => GlobalSearchOverlay.show(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: isDark ? AppColors.glassWhiteCard : AppColors.frostBlue, shape: BoxShape.circle),
            child: Icon(Icons.search, size: 20, color: CT.textH(context)),
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        CPPressable(
          onTap: () => context.go('/student/notifications'),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: isDark ? AppColors.glassWhiteCard : AppColors.frostBlue, shape: BoxShape.circle),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_outlined, size: 20, color: CT.textH(context)),
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: AppColors.elitePrimary, shape: BoxShape.circle, border: Border.all(color: CT.bg(context), width: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }



  // ═══════════════════════════════════════════════════════
  // QUICK ACCESS — 4 action shortcut row
  // ═══════════════════════════════════════════════════════
  Widget _buildQuickAccess(BuildContext context) => Row(
    children: [
      _qaItem(
        context,
        Icons.trending_up_rounded,
        'Performance',
        AppColors.elitePrimary,
        '/student/performance',
      ),
      const SizedBox(width: AppDimensions.sm),
      _qaItem(
        context,
        Icons.calendar_month_rounded,
        'Timetable',
        const Color(0xFF5C7CFA),
        '/student/timetable',
      ),
      const SizedBox(width: AppDimensions.sm),
      _qaItem(
        context,
        Icons.help_outline_rounded,
        'Doubts',
        AppColors.moltenAmber,
        '/student/ask-doubt',
      ),
      const SizedBox(width: AppDimensions.sm),
      _qaItem(
        context,
        Icons.checklist_rounded,
        'Syllabus',
        AppColors.elitePurple,
        '/student/syllabus',
      ),
    ],
  ).animate(delay: 150.ms).fadeIn(duration: 400.ms);

  Widget _qaItem(
    BuildContext ctx,
    IconData icon,
    String label,
    Color color,
    String route,
  ) => Expanded(
    child: CPPressable(
      onTap: () => ctx.push(route),
      child: _glassContainer(
        isDark: CT.isDark(ctx),
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: CT.textH(ctx),
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
  Widget _buildTodaysClasses(BuildContext context) {
    final batches = _dashboardData?['batches'] as List? ?? [];
    final isDark = CT.isDark(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Classes Today', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context), letterSpacing: -0.5)),
            CPPressable(
              onTap: () => context.push('/student/timetable'),
              child: Text('View all', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.elitePrimary)),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        if (batches.isEmpty)
          _glassContainer(
            isDark: isDark,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('No classes scheduled for today', style: GoogleFonts.inter(fontSize: 14, color: CT.textS(context))),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: batches.length,
              itemBuilder: (context, index) {
                final b = batches[index];
                final subject = b['subject'] ?? 'No Subject';
                final time = '${b['start_time'] ?? ''} - ${b['end_time'] ?? ''}';
                final teacher = b['teacher_name'] ?? 'TBA';
                
                Color c = AppColors.elitePrimary;
                if (subject.toLowerCase().contains('physics')) {
                  c = AppColors.physics;
                } else if (subject.toLowerCase().contains('chemistry')) {
                  c = AppColors.chemistry;
                } else if (subject.toLowerCase().contains('math')) {
                  c = AppColors.mathematics;
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _classCard(context, subject, time, teacher, c, isDark),
                );
              },
            ),
          ),
      ],
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
      child: _glassContainer(
        isDark: isDark,
        padding: const EdgeInsets.all(AppDimensions.md),
        child: SizedBox(
          width: 170,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(subject, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: CT.textH(ctx)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              Text(time, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: CT.textH(ctx), letterSpacing: -0.5)),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 12, color: CT.textS(ctx)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(teacher, style: GoogleFonts.inter(fontSize: 11, color: CT.textS(ctx)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // EXAM COUNTDOWN — hero gradient card
  // ═══════════════════════════════════════════════════════
  Widget _buildExamCountdown(BuildContext context) {
    final exams = _dashboardData?['upcoming_exams'] as List? ?? [];
    if (exams.isEmpty) return const SizedBox.shrink();
    
    final exam = exams.first;
    final date = DateTime.tryParse(exam['exam_date'] ?? '') ?? DateTime.now();
    final diff = date.difference(DateTime.now()).inDays.abs();

    return CPPressable(
          onTap: () => context.go('/student/exam-calendar'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
            decoration: BoxDecoration(
              gradient: AppColors.premiumEliteGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppColors.elitePurple.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: Text('UPCOMING EXAM', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
                      ),
                      const SizedBox(height: 10),
                      Text(exam['title'] ?? 'Mock Test', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text(exam['subject'] ?? 'All Subjects', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Text(diff.toString().padLeft(2, '0'), style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                      Text('DAYS', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white60, letterSpacing: 0.5)),
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
  Widget _buildExploreMore(BuildContext context) {
    final items = [
      {'icon': Icons.quiz_outlined, 'label': 'Tests', 'color': AppColors.elitePrimary, 'route': '/student/quiz'},
      {'icon': Icons.play_circle_outline_rounded, 'label': 'Videos', 'color': const Color(0xFF5C7CFA), 'route': '/student/video-lectures'},
      {'icon': Icons.menu_book_outlined, 'label': 'Notes', 'color': AppColors.moltenAmber, 'route': '/student/materials'},
      {'icon': Icons.assignment_outlined, 'label': 'Assign.', 'color': AppColors.coralRed, 'route': '/student/assignment'},
      {'icon': Icons.class_outlined, 'label': 'Batches', 'color': AppColors.elitePurple, 'route': '/student/batches'},
      {'icon': Icons.assessment_outlined, 'label': 'Results', 'color': AppColors.mintGreen, 'route': '/student/results'},
      {'icon': Icons.history_edu_outlined, 'label': 'Exams', 'color': const Color(0xFF7048E8), 'route': '/student/exam-calendar'},
      {'icon': Icons.receipt_long_outlined, 'label': 'Fees', 'color': AppColors.softAmber, 'route': '/student/fee-history'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick jump', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context), letterSpacing: -0.5)),
        const SizedBox(height: AppDimensions.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return CPPressable(
              onTap: () => context.go(item['route'] as String),
              child: _glassContainer(
                isDark: CT.isDark(context),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: (item['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(item['icon'] as IconData, size: 18, color: item['color'] as Color),
                    ),
                    const SizedBox(height: 6),
                    Text(item['label'] as String, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: CT.textH(context))),
                  ],
                ),
              ),
            ).animate(delay: Duration(milliseconds: 30 * index)).fadeIn(duration: 250.ms);
          },
        ),
      ],
    ).animate(delay: 400.ms).fadeIn(duration: 400.ms);
  }

  // ═══════════════════════════════════════════════════════
  // STATS ROW — with animated progress rings
  // ═══════════════════════════════════════════════════════
  Widget _buildStatsRow(BuildContext context) {
    final stats = _dashboardData?['stats'] ?? {};
    final attPct = (stats['attendance_percentage'] ?? 0) / 100.0;
    final isDark = CT.isDark(context);
    
    return Row(
      children: [
        _statCircle(context, '${(attPct * 100).toInt()}%', 'Attendance', attPct, AppColors.mintGreen, isDark),
        const SizedBox(width: 10),
        _statCircle(context, '${stats['pending_doubts'] ?? 0}', 'Open Doubts', 0.5, AppColors.moltenAmber, isDark),
        const SizedBox(width: 10),
        Expanded(
          child: CPPressable(
            onTap: () => context.go('/student/results'),
            child: _glassContainer(
              isDark: isDark,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.elitePrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.assignment_turned_in_outlined, size: 18, color: AppColors.elitePrimary),
                  ),
                  const SizedBox(height: 8),
                  Text('${stats['upcoming_exams_count'] ?? 0}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.elitePrimary, letterSpacing: -0.5)),
                  Text('Upcoming', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: CT.textM(context))),
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
      child: _glassContainer(
        isDark: isDark,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            CPAnimatedRing(
              progress: pct,
              color: c,
              size: 48,
              strokeWidth: 4,
              child: Text(
                val,
                style: GoogleFonts.sora(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: CT.textM(ctx),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════
  // FEE BANNER — warm amber accent
  // ═══════════════════════════════════════════════════════
  Widget _buildFeeBanner(BuildContext context) {
    final pendingFees = _dashboardData?['pending_fees'] as List? ?? [];
    if (pendingFees.isEmpty) return const SizedBox.shrink();

    final totalVal = _dashboardData?['stats']?['pending_fees_total'] ?? 0;
    
    return CPPressable(
      onTap: () => context.go('/student/fee-history'),
      child: _glassContainer(
        isDark: CT.isDark(context),
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.moltenAmber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppColors.moltenAmber),
            ),
            const SizedBox(width: AppDimensions.step),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('₹$totalVal pending fees', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: CT.textH(context), letterSpacing: -0.5)),
                  Text('${pendingFees.length} record(s) need attention', style: GoogleFonts.inter(fontSize: 11, color: CT.textM(context))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.moltenAmber, borderRadius: BorderRadius.circular(10)),
              child: Text('View', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    ).animate(delay: 600.ms).fadeIn(duration: 400.ms);
  }

  // ═══════════════════════════════════════════════════════
  // TESTIMONIALS — student reviews carousel
  // ═══════════════════════════════════════════════════════
  Widget _buildTestimonials(BuildContext context) {
    final isDark = CT.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('What students say', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context), letterSpacing: -0.5)),
            CPPressable(
              child: Text('+ Add', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.elitePrimary)),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        SizedBox(
          height: 165,
          child: PageView.builder(
            controller: _testimonialController,
            onPageChanged: (i) => setState(() => _testimonialPage = i),
            itemCount: _testimonials.length,
            itemBuilder: (context, index) {
              final t = _testimonials[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _glassContainer(
                  isDark: isDark,
                  padding: const EdgeInsets.all(AppDimensions.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote_rounded, size: 24, color: AppColors.elitePrimary.withValues(alpha: 0.3)),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(t['quote']!, style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context), height: 1.5, fontStyle: FontStyle.italic), maxLines: 3, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          CircleAvatar(radius: 14, backgroundColor: AppColors.elitePrimary.withValues(alpha: 0.1), child: Text(t['name']![0], style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.elitePrimary))),
                          const SizedBox(width: AppDimensions.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t['name']!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: CT.textH(context))),
                                Text(t['batch']!, style: GoogleFonts.inter(fontSize: 10, color: CT.textM(context))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.mintGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                            child: Text('AIR ${t['rank']}', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.mintGreen)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppDimensions.step),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _testimonials.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _testimonialPage == i ? 20 : 6,
              height: 5,
              decoration: BoxDecoration(
                color: _testimonialPage == i
                    ? CT.accent(context)
                    : CT.textM(context).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
            ),
          ),
        ),
      ],
    ).animate(delay: 700.ms).fadeIn(duration: 400.ms);
  }

  // ═══════════════════════════════════════════════════════
  // ANNOUNCEMENTS — recent updates list
  // ═══════════════════════════════════════════════════════
  Widget _buildAnnouncements(BuildContext context) {
    final list = _dashboardData?['announcements'] as List? ?? [];
    final isDark = CT.isDark(context);
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent updates', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context), letterSpacing: -0.5)),
            CPPressable(
              onTap: () => context.go('/student/announcements'),
              child: Text('View All', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.elitePrimary)),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: list.take(3).map((a) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _annItem(context, a['title'] ?? 'Announcement', a['body'] ?? '', 'Recent', Icons.campaign_outlined, AppColors.elitePrimary, isDark),
            )).toList(),
          ),
        ),
      ],
    ).animate(delay: 800.ms).fadeIn(duration: 400.ms);
  }

  Widget _annItem(
    BuildContext ctx,
    String title,
    String body,
    String time,
    IconData ic,
    Color c,
    bool isDark,
  ) => CPPressable(
    onTap: () => ctx.push('/announcements'),
    child: _glassContainer(
      isDark: isDark,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: SizedBox(
        width: 280,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(ic, size: 18, color: c),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: CT.textH(ctx)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(body, style: GoogleFonts.inter(fontSize: 11, color: CT.textM(ctx)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════
  // CONNECT WITH US — social links row
  // ═══════════════════════════════════════════════════════
  Widget _buildConnectWithUs(BuildContext context) {
    return _glassContainer(
      isDark: CT.isDark(context),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect with us', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: CT.textH(context), letterSpacing: -0.5)),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              _socialBtn(context, Icons.play_circle_filled_rounded, 'YouTube', const Color(0xFFFF0000)),
              const SizedBox(width: AppDimensions.sm),
              _socialBtn(context, Icons.facebook_rounded, 'Facebook', const Color(0xFF1877F2)),
              const SizedBox(width: AppDimensions.sm),
              _socialBtn(context, Icons.camera_alt_outlined, 'Instagram', const Color(0xFFE4405F)),
              const SizedBox(width: AppDimensions.sm),
              _socialBtn(context, Icons.language_rounded, 'Website', AppColors.elitePrimary),
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
  ) => Expanded(
    child: CPPressable(
      onTap: () {},
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: CT.textM(ctx)), maxLines: 1),
        ],
      ),
    ),
  );

}
