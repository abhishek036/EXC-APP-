import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../../../core/widgets/cp_role_shell.dart';
import '../../../../core/theme/theme_aware.dart';
class TeacherBatchesPage extends StatefulWidget {
  const TeacherBatchesPage({super.key});

  @override
  State<TeacherBatchesPage> createState() => _TeacherBatchesPageState();
}

class _TeacherBatchesPageState extends State<TeacherBatchesPage> with ThemeAware<TeacherBatchesPage> {
  final _teacherRepo = sl<TeacherRepository>();
  final _realtime = sl<RealtimeSyncService>();
  StreamSubscription<Map<String, dynamic>>? _syncSub;
  List<Map<String, dynamic>> _batches = [];
  bool _isLoading = true;
  String? _error;
  String _query = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _initRealtime();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text;
      });
    });
  }

  Future<void> _initRealtime() async {
    await _realtime.connect();
    _syncSub?.cancel();
    _syncSub = _realtime.updates.listen((event) {
      if (!mounted) return;
      final type = (event['type'] ?? '').toString();
      final reason = (event['reason'] ?? '').toString().toLowerCase();
      if (type == 'dashboard_sync' ||
          type == 'batch_sync' ||
          reason.contains('batch') ||
          reason.contains('attendance')) {
        _loadBatches();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    if (!mounted) return;
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final data = await _teacherRepo.getMyBatches();
      if (!mounted) return;
      setState(() {
        _batches = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _handleBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    final shellBack = CPRoleShellBack.maybeOf(context);
    if (shellBack != null) {
      shellBack.goBack();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = AppColors.elitePrimary;
    const surfaceWhite = AppColors.offWhite;
    const accentYellow = AppColors.moltenAmber;

    final visibleBatches = _batches.where((b) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      final name = (b['name'] ?? '').toString().toLowerCase();
      final subject = (b['subject'] ?? '').toString().toLowerCase();
      return name.contains(q) || subject.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: primaryBlue,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: _handleBack,
        ),
        title: Text(
          'MY BATCHES',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentYellow))
          : _error != null
          ? Center(
              child: _PremiumCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.coralRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: GoogleFonts.plusJakartaSans(
                        color: primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ActionBtn(
                      label: 'RETRY',
                      icon: Icons.refresh,
                      blue: primaryBlue,
                      yellow: accentYellow,
                      onPressed: _loadBatches,
                    ),
                  ],
                ),
              ),
            )
          : _batches.isEmpty
          ? Center(
              child: _PremiumCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.class_outlined,
                      size: 64,
                      color: primaryBlue.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'NO BATCHES ASSIGNED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              color: accentYellow,
              backgroundColor: primaryBlue,
              onRefresh: _loadBatches,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  _searchBar(primaryBlue, surfaceWhite),
                  const SizedBox(height: 14),
                  ...visibleBatches.asMap().entries.map((entry) {
                    final i = entry.key;
                    final b = entry.value;
                    final id = (b['id'] ?? '').toString();
                    return _BatchCard(
                      batch: b,
                      index: i,
                      onManageTap: () {
                        if (id.isEmpty) return;
                        context.go('/teacher/batches/$id?tab=overview');
                      },
                      onArrowTap: () {
                        if (id.isEmpty) return;
                        context.go('/teacher/batches/$id?tab=content');
                      },
                      onStudentsTap: () {
                        if (id.isEmpty) return;
                        context.go('/teacher/batches/$id?tab=students');
                      },
                      blue: primaryBlue,
                      yellow: accentYellow,
                      white: surfaceWhite,
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _searchBar(Color blue, Color surface) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: surface.withValues(alpha: 0.35), width: 2),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: 'Search for batches',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: blue.withValues(alpha: 0.45),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: blue.withValues(alpha: 0.55),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  final Map<String, dynamic> batch;
  final int index;
  final VoidCallback onManageTap;
  final VoidCallback onArrowTap;
  final VoidCallback onStudentsTap;
  final Color blue;
  final Color yellow;
  final Color white;

  const _BatchCard({
    required this.batch,
    required this.index,
    required this.onManageTap,
    required this.onArrowTap,
    required this.onStudentsTap,
    required this.blue,
    required this.yellow,
    required this.white,
  });

  @override
  Widget build(BuildContext context) {
    final name = (batch['name'] ?? 'Batch').toString().toUpperCase();
    final subject = (batch['subject'] ?? 'General').toString().toUpperCase();
    final schedule =
        '${batch['start_time'] ?? '--'} - ${batch['end_time'] ?? '--'}';
    final studentCount =
        (batch['student_count'] ?? batch['enrolled_count'] ?? 0).toString();
    final statusText = (batch['is_active'] == false) ? 'INACTIVE' : 'ONGOING';
    final startDate = (batch['start_date'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: white,
          border: Border.all(color: blue, width: 2.5),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onManageTap,
              child: Container(
                height: 128,
                decoration: BoxDecoration(
                  color: yellow,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
                child: Center(
                  child: Text(
                    subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      color: blue,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 30,
                            color: blue,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: blue.withValues(alpha: 0.4),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'TEACHER',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: blue.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 18,
                        color: blue.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        subject,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: blue.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.fiber_manual_record_rounded,
                        size: 12,
                        color: statusText == 'ONGOING'
                            ? blue
                            : AppColors.coralRed,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$statusText  |  $schedule${startDate.isNotEmpty ? '  |  Started: $startDate' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: blue.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onManageTap,
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: yellow,
                              border: Border.all(color: blue, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'MANAGE BATCH',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: blue,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: onArrowTap,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: white,
                            border: Border.all(color: blue, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                            color: blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: onStudentsTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: white,
                            border: Border.all(color: blue, width: 2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                studentCount,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: blue,
                                ),
                              ),
                              Text(
                                'STUD',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                  color: blue.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate(delay: Duration(milliseconds: 50 * index)).fadeIn().slideX(begin: 0.1),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final Widget child;
  const _PremiumCard({required this.child});

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.elitePrimary;
    const surface = AppColors.offWhite;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
      ),
      child: child,
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color blue;
  final Color yellow;
  final VoidCallback onPressed;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.blue,
    required this.yellow,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: yellow,
          border: Border.all(color: blue, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: blue),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}




