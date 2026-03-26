import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/teacher_repository.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/widgets/cp_pressable.dart';

import '../../../../core/widgets/cp_shimmer.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  final _teacherRepo = sl<TeacherRepository>();
  final _realtime = sl<RealtimeSyncService>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<Map<String, dynamic>>? _syncSub;
  Timer? _pollingTimer;
  bool _isLoadInFlight = false;
  
  Map<String, dynamic>? _dashboardData;
  List<Map<String, dynamic>> _pendingDoubts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _initRealtime();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted || _isLoadInFlight) return;
      _loadDashboard(silent: true);
    });
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
          reason.contains('batch') ||
          reason.contains('schedule') ||
          reason.contains('lecture') ||
          reason.contains('attendance');
      if (shouldRefresh && !_isLoadInFlight) {
        _loadDashboard(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    if (!mounted || _isLoadInFlight) return;

    final token = await sl<SecureStorageService>().getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = null;
      });
      return;
    }

    _isLoadInFlight = true;
    if (!silent && _dashboardData == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _teacherRepo.getDashboardStats(),
        _teacherRepo.getPendingDoubts(),
      ]);
      final data = Map<String, dynamic>.from(results[0] as Map<String, dynamic>);
      final doubts = List<Map<String, dynamic>>.from(results[1] as List<Map<String, dynamic>>);
      
      if (!mounted) return;
      
      // Merge logic: preserve existing data if server response is surprisingly empty
      final previousSchedules = List.from(_dashboardData?['schedules'] ?? []);
      final currentSchedules = List.from(data['schedules'] ?? []);
      
      // If we had schedules and now server says 0, it might be stale. 
      // Keep old ones for one cycle unless it's a manual refresh.
      if (currentSchedules.isEmpty && previousSchedules.isNotEmpty && silent) {
        data['schedules'] = previousSchedules;
      }

      setState(() {
        _dashboardData = data;
        _pendingDoubts = doubts;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = e.toString();
        _isLoading = false;
      });
    } finally {
      _isLoadInFlight = false;
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'GOOD MORNING';
    if (h < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.eliteLightBg, // Match Admin's light background assumption
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.elitePrimary,
              displacement: 20,
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildAppBar(),
                    if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Center(child: Text(_error!, style: GoogleFonts.plusJakartaSans(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)))),
                    const SizedBox(height: 32),
                    _buildSummaryStats(),
                    const SizedBox(height: 32),
                    _buildQuickActions(),
                    const SizedBox(height: 48),
                    _buildSectionHeader("Command Center", () {}),
                    const SizedBox(height: 16),
                    _buildManagementHub(),
                    const SizedBox(height: 40),
                    _buildSectionHeader("Academic Flow", () => context.push('/teacher/schedule')),
                    const SizedBox(height: 16),
                    _buildScheduleList(),
                    const SizedBox(height: 40),
                    _buildSectionHeader("Pending Doubts Alerts", () => context.push('/teacher/doubts')),
                    const SizedBox(height: 16),
                    _buildDoubtsSection(),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final authState = context.read<AuthBloc>().state;
    String initials = 'F';
    String userName = _dashboardData?['teacher']?['name']?.toString() ?? (authState is AuthAuthenticated ? authState.user.name : 'Faculty');
    
    if (userName.isNotEmpty) {
      final parts = userName.split(' ');
      initials = parts.length > 1 ? (parts[0][0] + parts[1][0]).toUpperCase() : parts[0][0].toUpperCase();
    }

    return Row(
      children: [
        CPPressable(
          onTap: () {
            HapticFeedback.lightImpact();
            _scaffoldKey.currentState?.openDrawer();
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
            child: Icon(Icons.menu_rounded, color: AppColors.elitePrimary, size: 28),
          ),
        ),
        CPPressable(
          onTap: () => context.push('/teacher/profile'),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.elitePrimary, border: Border.all(color: AppColors.elitePrimary, width: 2), boxShadow: const [BoxShadow(color: AppColors.elitePrimary, offset: Offset(2, 2))]),
            child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_greeting, 👋', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
              Text(userName, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.deepNavy, letterSpacing: -0.5), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        _appBarAction(Icons.search_rounded, () { HapticFeedback.mediumImpact(); }),
        const SizedBox(width: 8),
        _appBarAction(Icons.notifications_none_rounded, () { HapticFeedback.mediumImpact(); context.push('/teacher/notifications'); }, badge: _pendingDoubts.isNotEmpty),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }

  Widget _appBarAction(IconData icon, VoidCallback onTap, {bool badge = false}) {
    return CPPressable(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.elitePrimary, width: 2), boxShadow: const [BoxShadow(color: AppColors.elitePrimary, offset: Offset(2, 2))]),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 21, color: AppColors.elitePrimary),
            if (badge) const Positioned(top: 8, right: 8, child: SizedBox(width: 8, height: 8, child: DecoratedBox(decoration: BoxDecoration(color: AppColors.coralRed, shape: BoxShape.circle)))),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStats() {
    if (_isLoading) {
      return SizedBox(height: 120, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: 3, separatorBuilder: (_, _) => const SizedBox(width: 12), itemBuilder: (_, _) => CPShimmer(width: 160, height: 120, borderRadius: 16)));
    }
    final stats = _dashboardData?['stats'] ?? {};
    final batchesCount = stats['total_batches'] ?? 0;
    final studentCount = stats['total_students'] ?? 0;
    final doubtsCount = _pendingDoubts.length;

    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(right: 32),
        children: [
          _heroStat('MY BATCHES', '$batchesCount', AppColors.moltenAmber),
          const SizedBox(width: 14),
          _glassStat('STUDENTS', '$studentCount', AppColors.mintGreen, Icons.people_rounded),
          const SizedBox(width: 14),
          _glassStat('DOUBTS PENDING', '$doubtsCount', AppColors.coralRed, Icons.help_outline_rounded),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _heroStat(String label, String value, Color accent) {
    return Container(
      width: 180, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.elitePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elitePrimary, width: 3),
        boxShadow: const [BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: accent, letterSpacing: 0.5), overflow: TextOverflow.ellipsis)),
                Icon(Icons.star_rounded, size: 16, color: accent),
             ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.2)),
        ],
      ),
    );
  }

  Widget _glassStat(String label, String value, Color color, IconData icon) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elitePrimary, width: 3),
        boxShadow: const [BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.elitePrimary.withValues(alpha: 0.65), letterSpacing: 0.5), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.elitePrimary, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11, fontWeight: FontWeight.w800,
            color: AppColors.elitePrimary.withValues(alpha: 0.65), letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 62,
              child: CPPressable(
                onTap: () => context.push('/teacher/attendance'),
                child: Container(
                  height: 88, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.moltenAmber,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.elitePrimary, width: 3),
                    boxShadow: const [BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4))],
                  ),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), shape: BoxShape.circle), child: const Icon(Icons.fact_check_rounded, color: AppColors.elitePrimary, size: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Take Attendance', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.elitePrimary), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text('Mark class records', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.elitePrimary.withValues(alpha: 0.7)), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 38,
              child: CPPressable(
                onTap: () => context.push('/teacher/upload-material'),
                child: Container(
                  height: 88, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.elitePrimary, width: 3),
                    boxShadow: const [BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_upload_rounded, size: 22, color: AppColors.elitePrimary),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('Upload Material', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.elitePrimary)),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms);
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.deepNavy, letterSpacing: -0.6), overflow: TextOverflow.ellipsis)),
        CPPressable(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppColors.moltenAmber, border: Border.all(color: AppColors.elitePrimary, width: 2), boxShadow: const [BoxShadow(color: AppColors.elitePrimary, offset: Offset(2, 2))]), child: Row(children: [Text('Explore', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.elitePrimary)), const SizedBox(width: 4), const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.elitePrimary)])))
      ],
    );
  }

  Widget _buildManagementHub() {
    final modules = [
      {'label': 'My Batches', 'icon': Icons.groups_2_rounded, 'color': AppColors.elitePrimary, 'route': '/teacher/batches', 'desc': 'Manage classes'}, 
      {'label': 'Create Quiz', 'icon': Icons.quiz_rounded, 'color': AppColors.coralRed, 'route': '/teacher/create-quiz', 'desc': 'Assessments'}, 
      {'label': 'Pending Doubts', 'icon': Icons.help_rounded, 'color': AppColors.moltenAmber, 'route': '/teacher/doubts', 'desc': 'Unresolved'}, 
      {'label': 'Notice Board', 'icon': Icons.campaign_rounded, 'color': AppColors.mintGreen, 'route': '/teacher/notifications', 'desc': 'Announcements'}, 
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
      ),
      itemCount: modules.length,
      itemBuilder: (ctx, i) {
        final m = modules[i];
        final col = m['color'] as Color;
        return CPPressable(
          onTap: () => context.push(m['route'] as String),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.elitePrimary, width: 3),
              boxShadow: const [BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      Container(
                         width: 36, height: 36,
                         decoration: BoxDecoration(color: col.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), 
                         child: Icon(m['icon'] as IconData, color: col, size: 18)
                      ),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.elitePrimary.withValues(alpha: 0.65)),
                   ]
                ),
                const SizedBox(height: 12),
                Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(m['label'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.elitePrimary)))),
                const SizedBox(height: 2),
                Text(m['desc'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.elitePrimary.withValues(alpha: 0.65)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ).animate(delay: (i * 30).ms).fadeIn().slideY(begin: 0.05);
      },
    );
  }

  Widget _buildScheduleList() {
    final batches = _dashboardData?['batches'] as List? ?? [];
    if (batches.isEmpty) return _emptyCard('No classes scheduled for today');

    return Column(
      children: batches.map((b) => _classItem(b)).toList(),
    );
  }

  Widget _classItem(Map<String, dynamic> c) {
    final batchId = (c['id'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CPPressable(
        onTap: batchId.isEmpty ? null : () => context.go('/teacher/batches/$batchId'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.elitePrimary, width: 3),
            boxShadow: const [BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4))],
          ),
          child: Row(
            children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.elitePrimary, borderRadius: BorderRadius.circular(12)), child: Center(child: Text((c['start_time'] ?? '10:00 AM').toString().split(' ')[0], style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.w900)))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['name'] ?? 'BATCH', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.deepNavy), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(c['subject'] ?? 'SUBJECT', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ])),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.elitePrimary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoubtsSection() {
    final doubts = _pendingDoubts;
    if (doubts.isEmpty) return _emptyCard('All doubts are cleared!');

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: doubts.length,
        itemBuilder: (context, i) {
          final d = doubts[i];
          final studentName = ((d['student'] as Map?)?['name'] ?? d['student_name'] ?? 'STUDENT').toString();
          final qText = (d['question_text'] ?? d['question'] ?? '').toString();
          return InkWell(
            onTap: () => context.go('/teacher/doubts'),
            child: Container(
              width: 240, margin: const EdgeInsets.only(right: 14), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.elitePrimary, width: 3), borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 12, backgroundColor: AppColors.elitePrimary, child: Text(studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(studentName.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.elitePrimary), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(qText, style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.3, fontWeight: FontWeight.w600, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Text('ANSWER NOW →', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.coralRed)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyCard(String text) => Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.elitePrimary, width: 3), boxShadow: const [BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4))]), child: Center(child: Column(children: [Icon(Icons.inventory_2_outlined, size: 24, color: AppColors.elitePrimary.withValues(alpha: 0.26)), const SizedBox(height: 12), Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.deepNavy.withValues(alpha: 0.45), fontWeight: FontWeight.w600))])));

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.eliteLightBg,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(width: 54, height: 54, decoration: BoxDecoration(color: AppColors.moltenAmber, border: Border.all(color: AppColors.elitePrimary, width: 3), shape: BoxShape.circle), alignment: Alignment.center, child: const Icon(Icons.person_rounded, size: 28)),
                  const SizedBox(width: 16),
                  Expanded(child: Text('FACULTY\nPANEL', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.elitePrimary, height: 1.1))),
                ],
              ),
            ),
            const Divider(color: AppColors.elitePrimary, thickness: 2, height: 1),
            _drawerTile(Icons.dashboard_rounded, 'DASHBOARD', AppColors.elitePrimary, () => Navigator.pop(context)),
            _drawerTile(Icons.schedule_rounded, 'SCHEDULE', AppColors.elitePrimary, () { Navigator.pop(context); context.go('/teacher/schedule'); }),
            _drawerTile(Icons.groups_2_rounded, 'MY BATCHES', AppColors.elitePrimary, () { Navigator.pop(context); context.go('/teacher/batches'); }),
            _drawerTile(Icons.notifications_rounded, 'NOTICES', AppColors.elitePrimary, () { Navigator.pop(context); context.go('/teacher/notifications'); }),
            _drawerTile(Icons.person_rounded, 'PROFILE', AppColors.elitePrimary, () { Navigator.pop(context); context.go('/teacher/profile'); }),
            const Spacer(),
            const Divider(thickness: 2, color: AppColors.elitePrimary, height: 1),
            _drawerTile(Icons.logout_rounded, 'SIGN OUT', AppColors.coralRed, () async {
              Navigator.pop(context);
              await sl<SecureStorageService>().clearAll();
              if (mounted) context.go('/login');
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(IconData icon, String label, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: color, fontSize: 16)),
        ],
      ),
    ),
  );
}
