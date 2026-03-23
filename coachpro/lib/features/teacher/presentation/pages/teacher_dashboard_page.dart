import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/teacher_repository.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../../../core/services/secure_storage_service.dart';
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
      _loadDashboard();
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
        _loadDashboard();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    if (!mounted || _isLoadInFlight) return;
    _isLoadInFlight = true;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _teacherRepo.getDashboardStats(),
        _teacherRepo.getPendingDoubts(),
      ]);
      final data = Map<String, dynamic>.from(results[0] as Map<String, dynamic>);
      final doubts = List<Map<String, dynamic>>.from(results[1] as List<Map<String, dynamic>>);
      if (!mounted) return;
      setState(() {
        _dashboardData = data;
        _pendingDoubts = doubts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
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
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);
    const yellow = Color(0xFFF0DE36);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: blue,
      drawer: _buildDrawer(blue, surface, yellow),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActionMenu,
        backgroundColor: yellow,
        foregroundColor: blue,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black, width: 3)),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: yellow,
          backgroundColor: blue,
          onRefresh: _loadDashboard,
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: yellow))
            : _error != null
              ? _buildErrorState(blue, surface, yellow)
              : _buildContent(blue, surface, yellow),
        ),
      ),
    );
  }

  Widget _buildErrorState(Color blue, Color surface, Color yellow) {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 48),
        const SizedBox(height: 16),
        Text('FAILED TO LOAD', style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 24),
        _ActionBtn('RETRY', _loadDashboard, yellow, blue),
      ],
    ));
  }

  Widget _buildContent(Color blue, Color surface, Color yellow) {
    final authState = context.read<AuthBloc>().state;
    final userName = _dashboardData?['teacher']?['name']?.toString().toUpperCase() ?? (authState is AuthAuthenticated ? authState.user.name.toUpperCase() : 'TEACHER');

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(userName, blue, yellow),
          const SizedBox(height: 32),
          _buildSummaryStats(blue, surface, yellow),
          const SizedBox(height: 32),
          _sectionLabel('TODAY\'S BATCHES', yellow),
          const SizedBox(height: 16),
          _buildScheduleList(blue, surface, yellow),
          const SizedBox(height: 32),
          _sectionLabel('DOUBTS ALERTS', yellow),
          const SizedBox(height: 16),
          _buildDoubtsSection(blue, surface, yellow),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeader(String name, Color blue, Color yellow) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: yellow, border: Border.all(color: Colors.black, width: 2.5), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.menu_rounded, color: Colors.black, size: 24),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: yellow.withValues(alpha: 0.8), letterSpacing: 1)),
              Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
            ],
          ),
        ),
        GestureDetector(
          onTap: _loadDashboard,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: yellow, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2.5)),
            child: const Icon(Icons.refresh_rounded, color: Colors.black, size: 22),
          ),
        ),
        const SizedBox(width: 10),
        _circleBtn(Icons.notifications_none_rounded, yellow),
      ],
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _circleBtn(IconData icon, Color yellow) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: yellow, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2.5)),
    child: Icon(icon, color: Colors.black, size: 22),
  );

  Widget _sectionLabel(String text, Color yellow) => Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: yellow, letterSpacing: 2));

  Widget _buildSummaryStats(Color blue, Color surface, Color yellow) {
    final stats = _dashboardData?['stats'] ?? {};
    return Row(
      children: [
        _statCard('STUDENTS', '${stats['total_students'] ?? 0}', blue, surface, yellow),
        const SizedBox(width: 16),
        _statCard('BATCHES', '${stats['total_batches'] ?? 0}', blue, surface, yellow),
      ],
    );
  }

  Widget _statCard(String label, String val, Color blue, Color surface, Color yellow) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: Colors.black, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(5, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(val, style: GoogleFonts.jetBrainsMono(fontSize: 32, fontWeight: FontWeight.w900, color: blue)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: blue.withValues(alpha: 0.5))),
        ],
      ),
    ),
  );

  Widget _buildScheduleList(Color blue, Color surface, Color yellow) {
    final batches = _dashboardData?['batches'] as List? ?? [];
    if (batches.isEmpty) return _emptyStatus('NO CLASSES TODAY', blue, surface);

    return Column(
      children: batches.map((b) => _scheduleCard(b, blue, surface, yellow)).toList(),
    );
  }

  Widget _scheduleCard(Map<String, dynamic> b, Color blue, Color surface, Color yellow) {
    final batchId = (b['id'] ?? '').toString();
    return InkWell(
      onTap: batchId.isEmpty ? null : () => context.go('/teacher/batches/$batchId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: Colors.black, width: 3),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: yellow, offset: const Offset(4, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: blue, borderRadius: BorderRadius.circular(8)),
              child: Text((b['start_time'] ?? '10:00 AM').toString().split(' ')[0], style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b['name'] ?? 'BATCH', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: blue)),
                  Text(b['subject'] ?? 'SUBJECT', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: blue.withValues(alpha: 0.6))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _emptyStatus(String msg, Color blue, Color surface) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Center(child: Text(msg, style: GoogleFonts.plusJakartaSans(color: Colors.white30, fontWeight: FontWeight.w900, fontSize: 14))),
  );

  Widget _buildDoubtsSection(Color blue, Color surface, Color yellow) {
    final doubts = _pendingDoubts;
    if (doubts.isEmpty) return _emptyStatus('CLEAN SLATE! NO DOUBTS.', blue, surface);

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: doubts.length,
        itemBuilder: (context, i) {
          final d = doubts[i];
          return _doubtCard(d, blue, surface, yellow);
        },
      ),
    );
  }

  Widget _doubtCard(Map<String, dynamic> d, Color blue, Color surface, Color yellow) {
    final studentName = ((d['student'] as Map?)?['name'] ?? d['student_name'] ?? 'STUDENT').toString();
    final questionText = (d['question_text'] ?? d['question'] ?? '').toString();
    return InkWell(
      onTap: () => context.go('/teacher/doubts'),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: Colors.black, width: 3),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(4, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 12, backgroundColor: blue, child: Text(studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                Text(studentName.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: blue)),
              ],
            ),
            const SizedBox(height: 12),
            Text(questionText, style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.3, fontWeight: FontWeight.w600, color: blue.withValues(alpha: 0.8)), maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text('ANSWER NOW →', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900, color: blue)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(Color blue, Color surface, Color yellow) {
    return Drawer(
      backgroundColor: surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            color: blue,
            child: Row(
              children: [
                Container(width: 60, height: 60, decoration: BoxDecoration(color: yellow, border: Border.all(color: Colors.black, width: 3), shape: BoxShape.circle), alignment: Alignment.center, child: const Icon(Icons.person_rounded, size: 32)),
                const SizedBox(width: 16),
                Expanded(child: Text('FACULTY\nPANEL', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1))),
              ],
            ),
          ),
          _drawerTile(Icons.dashboard_rounded, 'DASHBOARD', blue, () => Navigator.pop(context)),
          _drawerTile(Icons.schedule_rounded, 'SCHEDULE', blue, () {
            Navigator.pop(context);
            context.go('/teacher/schedule');
          }),
          _drawerTile(Icons.notifications_rounded, 'NOTICES', blue, () {
            Navigator.pop(context);
            context.go('/teacher/notifications');
          }),
          _drawerTile(Icons.person_rounded, 'PROFILE', blue, () {
            Navigator.pop(context);
            context.go('/teacher/profile');
          }),
          const Spacer(),
          const Divider(thickness: 3, color: Colors.black),
          _drawerTile(Icons.logout_rounded, 'SIGN OUT', const Color(0xFFD71313), () async {
            final storage = sl<SecureStorageService>();
            await storage.clearAll();
            if (mounted) context.go('/login');
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _drawerTile(IconData icon, String label, Color color, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: color, size: 28),
    title: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: color, fontSize: 16)),
    onTap: onTap,
  );

  void _showQuickActionMenu() {
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: Colors.black, width: 4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('COMMAND CENTER', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: blue, letterSpacing: 1)),
            const SizedBox(height: 24),
            _actionTile('UP ATTENDANCE', Icons.check_circle_rounded, blue, () { Navigator.pop(ctx); context.push('/teacher/attendance'); }),
            _actionTile('UP MATERIAL', Icons.cloud_upload_rounded, blue, () { Navigator.pop(ctx); context.push('/teacher/upload-material'); }),
            _actionTile('CREATE QUIZ', Icons.quiz_rounded, blue, () { Navigator.pop(ctx); context.push('/teacher/create-quiz'); }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(String label, IconData icon, Color blue, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 2.5), borderRadius: BorderRadius.circular(12), boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(4, 4))]),
        child: Row(
          children: [
            Icon(icon, color: blue),
            const SizedBox(width: 16),
            Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: blue)),
            const Spacer(),
            const Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;
  const _ActionBtn(this.label, this.onTap, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(color: bg, border: Border.all(color: Colors.black, width: 3), borderRadius: BorderRadius.circular(12), boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(4, 4))]),
        child: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: fg)),
      ),
    );
  }
}
