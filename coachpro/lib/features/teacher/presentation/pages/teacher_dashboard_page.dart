import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/cp_pressable.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme_aware.dart';

import '../../../../features/teacher/data/repositories/teacher_repository.dart';
import '../../../../core/di/injection_container.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});
  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  final _teacherRepo = sl<TeacherRepository>();
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
      final data = await _teacherRepo.getDashboardStats();
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
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning,';
    if (h < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  String _nextClassCountdown() {
    final batches = (_dashboardData?['batches'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (batches.isEmpty) return 'No class scheduled today';

    DateTime? nextTime;
    Map<String, dynamic>? nextBatch;
    final now = DateTime.now();

    for (final batch in batches) {
      final raw = (batch['start_time'] ?? '').toString().trim();
      if (raw.isEmpty) continue;
      final parsed = _parseLocalTime(raw);
      if (parsed == null) continue;
      if (parsed.isAfter(now) && (nextTime == null || parsed.isBefore(nextTime))) {
        nextTime = parsed;
        nextBatch = batch;
      }
    }

    if (nextTime == null || nextBatch == null) return 'All classes completed for today';
    final diff = nextTime.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final batchName = (nextBatch['name'] ?? 'Next class').toString();
    return '$batchName starts in ${hours}h ${minutes}m';
  }

  DateTime? _parseLocalTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*([APap][Mm])?$').firstMatch(value);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final meridiem = (match.group(3) ?? '').toUpperCase();
    if (meridiem == 'PM' && hour < 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Scaffold(
      backgroundColor: CT.bg(context),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActionMenu,
        backgroundColor: const Color(0xFF0D1282),
        foregroundColor: const Color(0xFFEEEDED),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text('Failed to load dashboard', style: GoogleFonts.sora(fontSize: 18, color: CT.textH(context))),
                    const SizedBox(height: 8),
                    Text(_error!, style: GoogleFonts.dmSans(color: CT.textM(context))),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: _loadDashboard, child: const Text('Retry')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppDimensions.md),
                        _buildAppBar(isDark),
                        const SizedBox(height: AppDimensions.lg),
                        _buildQuickStats(isDark),
                        const SizedBox(height: AppDimensions.lg),
                        _buildNextClassCard(),
                        const SizedBox(height: AppDimensions.lg),
                        _buildTodaySchedule(isDark),
                        const SizedBox(height: AppDimensions.lg),
                        _buildPendingTasks(),
                        const SizedBox(height: AppDimensions.lg),
                        _buildPendingDoubts(isDark),
                        const SizedBox(height: AppDimensions.lg),
                        _buildQuickActions(isDark),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Center(
            child: Icon(Icons.person, color: AppColors.primary, size: 20),
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: CT.textS(context))),
              const SizedBox(height: 2),
              Text('${_dashboardData?['teacher']?['name'] ?? 'Alex Jensen'}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context), letterSpacing: -0.5)),
            ],
          ),
        ),
        CPPressable(
          onTap: () => context.go('/teacher/notifications'),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppColors.glassWhiteCard : AppColors.frostBlue,
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_outlined, size: 20, color: CT.textH(context)),
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.elitePrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: CT.bg(context), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
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

  Widget _buildQuickStats(bool isDark) {
    final stats = _dashboardData?['stats'] ?? {};
    final activeStudents = stats['total_students'] ?? 142;
    final activeBatches = stats['total_batches'] ?? 5;
    final avgProgress = '78%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Overview", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context), letterSpacing: -0.5)),
        const SizedBox(height: AppDimensions.md),
        Row(
          children: [
            // Active Students Card
            Expanded(
              child: _glassContainer(
                isDark: isDark,
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Students', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: CT.textS(context))),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$activeStudents', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: CT.textH(context), letterSpacing: -1)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.mintGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text('+12%', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mintGreen)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            // Active Batches Card (Elite Gradient)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  gradient: AppColors.premiumEliteGradient,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.elitePrimary.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(color: AppColors.elitePurple.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Batches', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$activeBatches', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -1)),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ],
                ),
              ).animate().shimmer(duration: 2000.ms, color: Colors.white24),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        // Progress Card
        _glassContainer(
          isDark: isDark,
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Avg. Student Progress', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: CT.textS(context))),
                  Text(avgProgress, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.elitePrimary)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : AppColors.frostBlue, borderRadius: BorderRadius.circular(4)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.78,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.premiumEliteGradient,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [BoxShadow(color: AppColors.elitePrimary.withValues(alpha: 0.4), blurRadius: 10)],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    ).animate(delay: 100.ms).fadeIn(duration: 500.ms);
  }

  Widget _buildTodaySchedule(bool isDark) {
    final batches = _dashboardData?['batches'] as List? ?? [];
    if (batches.isEmpty) {
       return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Your classes today"),
          const SizedBox(height: AppDimensions.md),
          Container(
            padding: const EdgeInsets.all(AppDimensions.lg),
            decoration: CT.cardDecor(context),
            child: Center(child: Text('No classes scheduled for today', style: GoogleFonts.dmSans(color: CT.textM(context)))),
          ),
        ],
      );
    }

    // Sort batches by start_time to find current/next
    batches.sort((a, b) => (a['start_time'] ?? '').compareTo(b['start_time'] ?? ''));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Upcoming Classes", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context), letterSpacing: -0.5)),
            CPPressable(child: Text('See all', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.elitePrimary))),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        ...batches.take(3).map((b) {
          final subject = b['subject'] ?? 'Subject';
          final name = b['name'] ?? 'Batch';
          final startTime = b['start_time'] ?? '10:00 AM';
          final platform = b['room'] ?? 'Zoom';

          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.sm),
            child: CPPressable(
              child: _glassContainer(
                isDark: isDark,
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Row(
                  children: [
                    // Date block
                    Container(
                      width: 50,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : AppColors.frostBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('TUE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: CT.textS(context))),
                          Text('14', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context))),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$subject $name', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 12, color: CT.textS(context)),
                              const SizedBox(width: 4),
                              Text(startTime, style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context))),
                              const SizedBox(width: 12),
                              Icon(Icons.videocam_outlined, size: 12, color: CT.textS(context)),
                              const SizedBox(width: 4),
                              Text(platform, style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Avatars
                    SizedBox(
                      width: 60,
                      height: 32,
                      child: Stack(
                        children: [
                          Positioned(
                            right: 24,
                            child: CircleAvatar(radius: 16, backgroundColor: CT.bg(context), child: CircleAvatar(radius: 14, backgroundColor: Colors.blue.withValues(alpha: 0.2), child: Text('A', style: TextStyle(fontSize: 10, color: Colors.blue)))),
                          ),
                          Positioned(
                            right: 12,
                            child: CircleAvatar(radius: 16, backgroundColor: CT.bg(context), child: CircleAvatar(radius: 14, backgroundColor: Colors.green.withValues(alpha: 0.2), child: Text('B', style: TextStyle(fontSize: 10, color: Colors.green)))),
                          ),
                          Positioned(
                            right: 0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: CT.bg(context),
                              child: Container(
                                width: 28, height: 28,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1E293B)),
                                child: Center(child: Text('+5', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    ).animate(delay: 200.ms).fadeIn(duration: 500.ms);
  }

  Widget _sectionHeader(String title) {
    return Text(title, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600, color: CT.textH(context)));
  }

  Widget _buildNextClassCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0DE36).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0DE36)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alarm_rounded, color: Color(0xFF0D1282)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _nextClassCountdown(),
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282)),
            ),
          ),
        ],
      ),
    ).animate(delay: 140.ms).fadeIn(duration: 350.ms);
  }

  Widget _buildPendingTasks() {
    final stats = _dashboardData?['stats'] ?? {};
    final doubts = (stats['pending_doubts'] ?? 0).toString();
    final assignments = (stats['assignments_to_review'] ?? 0).toString();
    final tests = (stats['tests_to_review'] ?? 0).toString();

    Widget taskChip(String value, String label, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Column(
            children: [
              Text(value, style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: CT.textM(context))),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Pending Tasks'),
        const SizedBox(height: 10),
        Row(
          children: [
            taskChip(doubts, 'Doubts pending', const Color(0xFF0D1282)),
            const SizedBox(width: 8),
            taskChip(assignments, 'Assignments to check', const Color(0xFFD71313)),
            const SizedBox(width: 8),
            taskChip(tests, 'Tests to review', const Color(0xFFF0DE36)),
          ],
        ),
      ],
    ).animate(delay: 220.ms).fadeIn(duration: 350.ms);
  }

  Widget _buildQuickActions(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: CT.cardDecor(context),
      child: Row(
        children: [
          const Icon(Icons.touch_app_rounded, color: Color(0xFF0D1282), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Quick actions moved to the + button for 2-click execution.',
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: CT.textH(context)),
            ),
          ),
        ],
      ),
    ).animate(delay: 400.ms).fadeIn(duration: 500.ms);
  }

  Future<void> _showQuickActionMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CT.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        Widget actionTile(IconData icon, String label, String route) {
          return CPPressable(
            onTap: () {
              Navigator.pop(ctx);
              context.go(route);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEDED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0D1282).withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFF0D1282), size: 18),
                  const SizedBox(width: 10),
                  Text(label, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick Actions', style: GoogleFonts.sora(fontWeight: FontWeight.w800, color: CT.textH(context))),
              const SizedBox(height: 12),
              actionTile(Icons.fact_check_outlined, 'Take Attendance', '/teacher/attendance'),
              actionTile(Icons.ondemand_video_outlined, 'Upload Lecture', '/teacher/upload-material'),
              actionTile(Icons.assignment_outlined, 'Add Assignment', '/teacher/upload-material'),
              actionTile(Icons.quiz_outlined, 'Create Test', '/teacher/create-quiz'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingDoubts(bool isDark) {
    final stats = _dashboardData?['stats'] ?? {};
    final count = stats['pending_doubts'] ?? 0;
    
    // Parse real doubts from API
    List<dynamic> rawDoubts = _dashboardData?['doubts'] ?? [];
    List<Map<String, dynamic>> doubts = rawDoubts.map((e) => e as Map<String, dynamic>).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
               children: [
                 Text("Pending Doubts", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context), letterSpacing: -0.5)),
                 if (count > 0) ...[
                   const SizedBox(width: 8),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                     decoration: BoxDecoration(color: AppColors.elitePrimary, borderRadius: BorderRadius.circular(10)),
                     child: Text('$count New', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                   ),
                 ],
               ],
            )
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        if (doubts.isEmpty)
          _glassContainer(
            isDark: isDark,
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.success, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("All caught up!", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: CT.textH(context))),
                      const SizedBox(height: 4),
                      Text("No pending doubts to resolve at the moment.", style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context))),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: doubts.map((d) {
                final studentName = d['student_name'] ?? 'Student';
                final msg = d['question_text'] ?? '';
                final timeRaw = d['created_at'];
                String timeStr = 'Recently';
                if (timeRaw != null) {
                  final t = DateTime.tryParse(timeRaw.toString());
                  if (t != null) {
                    final diff = DateTime.now().difference(t);
                    if (diff.inHours > 0) {
                      timeStr = '${diff.inHours}h ago';
                    } else if (diff.inMinutes > 0) {
                      timeStr = '${diff.inMinutes}m ago';
                    }
                  }
                }
                return Padding(
                  padding: const EdgeInsets.only(right: AppDimensions.sm),
                  child: CPPressable(
                    onTap: () => context.go('/teacher/doubts'),
                    child: _glassContainer(
                      isDark: isDark,
                      padding: const EdgeInsets.all(AppDimensions.md),
                      child: SizedBox(
                        width: 240,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(radius: 12, backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: Text(studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S', style: TextStyle(fontSize: 10, color: AppColors.primary))),
                                    const SizedBox(width: 8),
                                    Text(studentName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: CT.textH(context))),
                                  ],
                                ),
                                Text(timeStr, style: GoogleFonts.inter(fontSize: 10, color: CT.textS(context))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(msg, style: GoogleFonts.inter(fontSize: 13, color: CT.textS(context), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(color: AppColors.elitePrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Center(child: Text("Answer Now", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.elitePrimary))),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    ).animate(delay: 400.ms).fadeIn(duration: 500.ms);
  }

  // Weekly stats and exams sections removed to fit premium layout purity, 
  // but can be safely added back below actions.
}
