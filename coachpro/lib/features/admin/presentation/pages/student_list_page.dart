import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_glass_card.dart';

class StudentListPage extends StatefulWidget {
  const StudentListPage({super.key});

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  final _adminRepo = sl<AdminRepository>();
  List<_Student> _students = [];
  bool _loadingStudents = true;
  String _error = '';
  int _selectedFilter = 0;
  final _searchController = TextEditingController();
  List<String> _filters = ['All'];
  bool _loadingBatches = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadBatchFilters();
  }

  Future<void> _loadBatchFilters() async {
    if (!mounted) return;
    try {
      final batches = await _adminRepo.getBatches();
      if (mounted) {
        setState(() {
          _filters = [
            'All',
            ...batches
                .where((b) {
                  final isActive = b['is_active'] ?? b['isActive'];
                  return isActive == true || isActive == null;
                })
                .map((b) => b['name'] as String? ?? 'Batch')
          ];
          _loadingBatches = false;
        });
      }
      _loadStudents();
    } catch (_) {
      if (mounted) setState(() => _loadingBatches = false);
    }
  }

  Future<void> _loadStudents() async {
    if (!mounted) return;
    setState(() {
      _loadingStudents = true;
      _error = '';
    });
    try {
      final docs = await _adminRepo.getStudents();
      if (mounted) {
        setState(() {
          _students = docs.map(_Student.fromMap).toList();
          _loadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Oversight sync failed';
          _loadingStudents = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(top: -100, left: -50, child: _glow(300, AppColors.elitePrimary.withValues(alpha: 0.1))),
            Positioned(bottom: 100, right: -100, child: _glow(350, AppColors.elitePurple.withValues(alpha: 0.05))),
          ],
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, isDark),
                Expanded(
                  child: _loadingStudents 
                    ? const Center(child: CircularProgressIndicator(color: AppColors.elitePrimary))
                    : _error.isNotEmpty
                      ? _buildErrorState(isDark)
                      : _buildContents(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: size / 2)]));

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          CPPressable(onTap: () => Navigator.pop(context), child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : AppColors.deepNavy)),
          const SizedBox(width: 16),
          Expanded(child: Text('Student Directory', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.8))),
          _appBarAction(Icons.person_add_rounded, () => context.go('/admin/add-student'), isDark, primary: true),
        ],
      ),
    );
  }

  Widget _appBarAction(IconData icon, VoidCallback onTap, bool isDark, {bool primary = false}) {
    return CPPressable(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(gradient: primary ? AppColors.premiumEliteGradient : null, color: !primary ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)) : null, borderRadius: BorderRadius.circular(16), boxShadow: primary ? [BoxShadow(color: AppColors.elitePrimary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : null),
        child: Icon(icon, size: 22, color: primary ? Colors.white : (isDark ? Colors.white : AppColors.deepNavy)),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(_error, style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          CPPressable(onTap: _loadStudents, child: Text('Retry Sync', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.elitePrimary))),
        ],
      ),
    );
  }

  Widget _buildContents() {
    final isDark = CT.isDark(context);
    final students = _students;
    final selectedBatch = _selectedFilter == 0 ? null : _filters[_selectedFilter];
    final query = _searchController.text.trim().toLowerCase();

    final filtered = students.where((student) {
      final batchMatch = selectedBatch == null || student.batchNames.any((b) => b.toLowerCase().contains(selectedBatch.toLowerCase()));
      final searchMatch = query.isEmpty || student.name.toLowerCase().contains(query) || student.id.toLowerCase().contains(query) || student.rollNumber.toLowerCase().contains(query) || student.phone.contains(query);
      return batchMatch && searchMatch;
    }).toList();

    final activeDocs = students.where((s) => s.status == 'active').length;
    final totalPending = students.where((s) => s.feeStatus != 'PAID').length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  _statChip('TOTAL', '${students.length}', AppColors.elitePrimary, isDark),
                  const SizedBox(width: 12),
                  _statChip('ACTIVE', '$activeDocs', AppColors.mintGreen, isDark),
                  const SizedBox(width: 12),
                  _statChip('DUE', '$totalPending', AppColors.moltenAmber, isDark),
                ],
              ),
              const SizedBox(height: 24),
              CPGlassCard(
                isDark: isDark, padding: EdgeInsets.zero, borderRadius: 20,
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : AppColors.deepNavy, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID, or phone...',
                    hintStyle: GoogleFonts.inter(color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26), fontWeight: FontWeight.w600),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? Colors.white38 : Colors.black38),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: _loadingBatches
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        physics: const BouncingScrollPhysics(),
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => CPPressable(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedFilter = i);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: _selectedFilter == i ? AppColors.premiumEliteGradient : null,
                              color: _selectedFilter == i ? null : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _selectedFilter == i ? Colors.transparent : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))),
                            ),
                            child: Center(
                              child: Text(_filters[i], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _selectedFilter == i ? Colors.white : (isDark ? Colors.white54 : Colors.black54))),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Active Records (${filtered.length})', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  Icon(Icons.sort_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.elitePrimary,
            onRefresh: _loadStudents,
            child: filtered.isEmpty
                ? _buildEmptyState(isDark, students.isEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: filtered.length,
                    physics: const BouncingScrollPhysics(),
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _buildStudentCard(filtered[i], i, isDark),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _statChip(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: CPGlassCard(
        isDark: isDark, padding: const EdgeInsets.symmetric(vertical: 16), borderRadius: 24,
        child: Column(
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26), letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, bool isFullEmpty) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03), shape: BoxShape.circle), child: Icon(Icons.people_alt_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.2))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(isFullEmpty ? 'The student directory is currently empty' : 'No scholars match your current search criteria', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white38 : Colors.black38, height: 1.5), textAlign: TextAlign.center),
          ),
          if (isFullEmpty) ...[
            const SizedBox(height: 24),
            _appBarAction(Icons.person_add_rounded, () => context.go('/admin/add-student'), isDark, primary: true),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentCard(_Student student, int index, bool isDark) {
    final attColor = student.attendance >= 80 ? AppColors.mintGreen : (student.attendance >= 70 ? AppColors.warning : AppColors.error);
    final feeColor = student.feeStatus == 'PAID' ? AppColors.mintGreen : (student.feeStatus == 'PENDING' ? AppColors.moltenAmber : AppColors.coralRed);

    return CPPressable(
      onTap: () => context.go('/admin/students/${student.docId}'),
      child: CPGlassCard(
        isDark: isDark, padding: const EdgeInsets.all(16), borderRadius: 28,
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.elitePrimary.withValues(alpha: 0.1), AppColors.elitePurple.withValues(alpha: 0.1)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.elitePrimary.withValues(alpha: 0.15))),
              child: Center(child: Text(student.initials, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.elitePrimary))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.4)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.badge_rounded, size: 12, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26)),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${student.rollNumber} • ${student.batchNames.join(", ")}', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone_iphone_rounded, size: 12, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26)),
                      const SizedBox(width: 6),
                      Text(student.phone.isNotEmpty ? student.phone : 'No contact info', style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _badge('${student.attendance}% ATT.', attColor, isDark),
                const SizedBox(height: 6),
                _badge(student.feeStatus, feeColor, isDark),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.12), size: 24),
          ],
        ),
      ),
    ).animate(delay: (30 * index).ms).fadeIn(duration: 500.ms).slideX(begin: 0.05);
  }

  Widget _badge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Text(text, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
    );
  }
}

class _Student {
  final String docId;
  final String name;
  final String id;
  final String rollNumber;
  final String phone;
  final List<String> batchNames;
  final int attendance;
  final String feeStatus;
  final String status;

  const _Student({
    required this.docId,
    required this.name,
    required this.id,
    required this.rollNumber,
    required this.phone,
    required this.batchNames,
    required this.attendance,
    required this.feeStatus,
    required this.status,
  });

  String get initials => name.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join();

  factory _Student.fromMap(Map<String, dynamic> map) {
    final batchIds = (map['batch_ids'] ?? map['batchIds']) as List<dynamic>?;
    final batches = map['batches'] as List<dynamic>?;
    final batchName = (map['batch'] ?? map['batch_name']) as String?;
    List<String> batchNames = [];
    if (batchName != null && batchName.isNotEmpty) {
      batchNames = [batchName];
    } else if (batches != null && batches.isNotEmpty) {
      batchNames = batches.map((e) => e is Map<String, dynamic> ? (e['name'] ?? '').toString() : '').where((e) => e.isNotEmpty).toList();
    } else if (batchIds != null && batchIds.isNotEmpty) {
      batchNames = batchIds.map((e) => e.toString()).toList();
    } else {
      batchNames = ['General'];
    }

    return _Student(
      docId: (map['id'] ?? '').toString(),
      name: (map['name'] ?? 'Student').toString(),
      id: (map['student_code'] ?? map['studentId'] ?? map['id'] ?? '').toString(),
      rollNumber: (map['student_code'] ?? map['rollNumber'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      batchNames: batchNames,
      attendance: (map['attendance_percent'] ?? map['attendancePercent'] ?? 0) is num ? ((map['attendance_percent'] ?? map['attendancePercent'] ?? 0) as num).toInt() : 0,
      feeStatus: (map['fee_status'] ?? map['feeStatus'] ?? 'PENDING').toString().toUpperCase(),
      status: map['status']?.toString() ?? ((map['is_active'] == false || map['isActive'] == false) ? 'inactive' : 'active'),
    );
  }
}

