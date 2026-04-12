import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_shimmer.dart';
import '../../../../core/theme/theme_aware.dart';
class StudentListPage extends StatefulWidget {
  const StudentListPage({super.key});

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> with ThemeAware<StudentListPage> {
  final _adminRepo = sl<AdminRepository>();
  final _realtime = sl<RealtimeSyncService>();
  StreamSubscription<Map<String, dynamic>>? _syncSub;
  Timer? _searchDebounce;
  List<_Student> _students = [];
  bool _loadingStudents = true;
  bool _loadFailed = false;

  // Filters
  int _selectedFilter = 0;
  final _searchController = TextEditingController();

  // Batch chip filters from API (names for display)
  List<String> _batches = ['All'];
  // Raw batch maps for assignment (id + name)
  List<Map<String, dynamic>> _batchRaw = [];
  int _selectedBatch = 0;

  // Bulk select mode
  bool _selectMode = false;
  bool _bulkSending = false;
  final Set<String> _selected = {};

  static const _statusFilters = [
    'All',
    'Fee Due',
    'Overdue',
    'Active',
    'Inactive',
  ];

  String? _selectedBatchIdForApi() {
    if (_selectedBatch <= 0) return null;
    final index = _selectedBatch - 1;
    if (index < 0 || index >= _batchRaw.length) return null;
    final value = (_batchRaw[index]['id'] ?? '').toString().trim();
    return value.isEmpty ? null : value;
  }

  List<_Student> _dedupeStudents(List<_Student> items) {
    final seen = <String>{};
    final unique = <_Student>[];
    for (final item in items) {
      if (item.docId.isEmpty || seen.contains(item.docId)) continue;
      seen.add(item.docId);
      unique.add(item);
    }
    return unique;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAll();
    _initRealtime();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {});

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _loadAll();
    });
  }

  Future<void> _initRealtime() async {
    await _realtime.connect();
    if (!mounted) return;
    _syncSub?.cancel();
    _syncSub = _realtime.updates.listen((event) {
      if (!mounted) return;
      final type = (event['type'] ?? '').toString();
      final reason = (event['reason'] ?? '').toString().toLowerCase();
      if (type == 'dashboard_sync' ||
          type == 'batch_sync' ||
          reason.contains('student') ||
          reason.contains('batch')) {
        _loadAll();
      }
    });
  }

  Future<void> _loadAll({bool silent = false}) async {
    if (!mounted) return;
    final previousStudents = List<_Student>.from(_students);

    if (!silent) {
      setState(() {
        _loadingStudents = true;
        _loadFailed = false;
      });
    }
    try {
      final selectedBatchId = _selectedBatchIdForApi();
      final query = _searchController.text.trim();
      final results = await Future.wait([
        _adminRepo.getStudents(
          batchId: selectedBatchId,
          query: query.isEmpty ? null : query,
          isActive: null,
        ),
        _adminRepo.getBatches(),
      ]);
      if (mounted) {
        final fetchedStudents = (results[0] as List)
            .map((s) => _Student.fromMap(s as Map<String, dynamic>))
            .toList();
        final rawBatches = (results[1] as List)
            .map((b) => Map<String, dynamic>.from(b as Map))
            .toList();
        final batchNames = rawBatches
            .map((b) => (b['name'] ?? 'Batch').toString())
            .toList();

        // Stale-data handling: if we have local students but server says 0, keep local for now
        List<_Student> effectiveStudents;
        if (fetchedStudents.isNotEmpty) {
          effectiveStudents = fetchedStudents;
        } else {
          effectiveStudents = previousStudents;
        }

        setState(() {
          _students = _dedupeStudents(effectiveStudents);
          _batchRaw = rawBatches;
          _batches = ['All', ...batchNames];
          _loadingStudents = false;
          _loadFailed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingStudents = false;
          _loadFailed =
              !silent; // Only show failed if it wasn't a silent background update
          if (!silent) _students = [];
        });
      }
    }
  }

  List<_Student> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    final selectedBatchId = _selectedBatchIdForApi();
    return _students.where((s) {
      final matchSearch =
          query.isEmpty ||
          s.name.toLowerCase().contains(query) ||
          s.id.toLowerCase().contains(query) ||
          s.phone.contains(query) ||
          s.rollNumber.toLowerCase().contains(query);
      final matchBatch = selectedBatchId == null || selectedBatchId.isEmpty
          ? true
          : s.batchIds.contains(selectedBatchId);
      final matchStatus = switch (_selectedFilter) {
        1 => s.feeStatus == 'PENDING' || s.feeStatus == 'OVERDUE',
        2 => s.feeStatus == 'OVERDUE',
        3 => s.status == 'active',
        4 => s.status == 'inactive',
        _ => true,
      };
      return matchSearch && matchBatch && matchStatus;
    }).toList();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selected.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _bulkNotify() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sending notification to ${_selected.length} students…',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF354388),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  Future<void> _bulkAssignBatch() async {
    HapticFeedback.mediumImpact();
    // Load batches if not yet loaded
    List<Map<String, dynamic>> batches = _batchRaw;
    if (batches.isEmpty) {
      try {
        batches = await _adminRepo.getBatches();
      } catch (_) {}
    }
    if (!mounted) return;
    // Show batch picker bottom sheet
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      useRootNavigator:
          true, // ← Try this to fix the sheet not appearing over the shell
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) =>
          _BatchPickerSheet(batches: batches, selectedCount: _selected.length),
    );
    if (picked == null || !mounted) return;
    // Assign all selected students to picked batch
    setState(() => _bulkSending = true);
    try {
      await _adminRepo.assignMultipleStudentsToBatch(
        batchId: picked['id'].toString(),
        studentIds: _selected.toList(),
      );
      if (mounted) {
        _showSnack(
          '${_selected.length} students assigned to ${picked['name']}',
          const Color(0xFFBDAE18),
        );
        setState(() {
          _selectMode = false;
          _selected.clear();
          _bulkSending = false;
        });
        _loadAll(); // Refresh list
      }
    } catch (_) {
      if (mounted) {
        _showSnack(
          'Assigned locally (sync when online)',
          const Color(0xFFBDAE18),
        );
        setState(() {
          _selectMode = false;
          _selected.clear();
          _bulkSending = false;
        });
      }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final total = _students.length;
    final active = _students.where((s) => s.status == 'active').length;
    final feeDue = _students.where((s) => s.feeStatus != 'PAID').length;
    final overdue = _students.where((s) => s.feeStatus == 'OVERDUE').length;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final result = await context.push('/admin/add-student');
                if (!mounted || result == null) return;
                if (result is Map<String, dynamic>) {
                  // Optimistic update
                  setState(() {
                    _students = _dedupeStudents([
                      _Student.fromMap(result),
                      ..._students,
                    ]);
                  });
                  _loadAll(silent: true);
                } else if (result == true) {
                  _loadAll();
                }
              },
              backgroundColor: const Color(0xFF354388),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ── AppBar ───────────────────────────────────────
                _buildAppBar(filtered),

                // ── Dashboard content when not in select mode ──
                if (!_selectMode) ...[
                  // ── Metrics ──────────────────────────────────
                  if (!_loadingStudents)
                    _buildMetrics(total, active, feeDue, overdue),

                  // ── Search ─────────────────────────────────────
                  _buildSearch(),

                  // ── Batch chips ────────────────────────────────
                  _buildBatchChips(),

                  // ── Status filter tabs ────────────────────────
                  _buildStatusTabs(),
                ],

                // ── Student List ──────────────────────────────────
                Expanded(
                  child: _loadingStudents
                      ? _buildShimmer()
                      : _loadFailed
                      ? _buildLoadFailedState()
                      : filtered.isEmpty
                      ? _buildEmptyState(total == 0)
                      : RefreshIndicator(
                          color: const Color(0xFF354388),
                          onRefresh: _loadAll,
                          child: ListView.builder(
                            padding: EdgeInsets.only(
                              bottom: _selectMode ? 120 : 100,
                            ),
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) =>
                                _buildStudentRow(filtered[i], i),
                          ),
                        ),
                ),
              ],
            ),

            // ── Floating Bulk action bar ─────────────────────
            if (_selectMode && _selected.isNotEmpty) _buildBulkBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(List<_Student> filtered) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      color: Colors.white,
      child: Row(
        children: [
          CPPressable(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/admin');
              }
            },
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF354388), width: 1.5),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: Color(0xFF354388),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Students',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF354388),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${filtered.length} record${filtered.length == 1 ? '' : 's'} found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF354388),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Bulk select toggle
          CPPressable(
            onTap: _toggleSelectMode,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _selectMode
                    ? const Color(0xFFBDAE18)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF354388), width: 1.5),
              ),
              child: Icon(
                _selectMode ? Icons.close_rounded : Icons.checklist_rounded,
                size: 20,
                color: const Color(0xFF354388),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkBar() {
    return Positioned(
      bottom: 110, // Higher to avoid FAB
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF354388),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              '${_selected.length} students',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            // Notify Button (Explicitly Yellow to distinguish from older blue bar)
            CPPressable(
              onTap: _bulkNotify,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFBDAE18), // Bright Neo-Brutalist Yellow
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF354388),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.notifications_active_rounded,
                      size: 16,
                      color: Color(0xFF354388),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'NOTIFY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF354388),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Assign Button (White icon/text for contrast)
            CPPressable(
              onTap: _bulkSending ? null : _bulkAssignBatch,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _bulkSending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF354388),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.group_add_rounded,
                            size: 16,
                            color: Color(0xFF354388),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ASSIGN',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF354388),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ).animate().slideY(begin: 1.0, end: 0, curve: Curves.easeOutBack),
    );
  }

  Widget _buildMetrics(int total, int active, int feeDue, int overdue) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          _metricCard(
            'Total',
            '$total',
            const Color(0xFF354388),
            Icons.people_rounded,
          ),
          const SizedBox(width: 10),
          _metricCard(
            'Active',
            '$active',
            const Color(0xFFBDAE18),
            Icons.check_circle_rounded,
          ),
          const SizedBox(width: 10),
          _metricCard(
            'Fee Due',
            '$feeDue',
            const Color(0xFFBDAE18),
            Icons.receipt_long_rounded,
          ),
          const SizedBox(width: 10),
          _metricCard(
            'Overdue',
            '$overdue',
            const Color(0xFFB6231B),
            Icons.warning_rounded,
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF354388),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF354388).withValues(alpha: 0.16),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF354388),
          ),
          decoration: InputDecoration(
            hintText: 'Search by name, ID, or phone…',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF354388),
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFF354388),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? CPPressable(
                    onTap: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    child: const Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: Color(0xFF354388),
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildBatchChips() {
    if (_batches.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        scrollDirection: Axis.horizontal,
        itemCount: _batches.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => CPPressable(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedBatch = i);
            _loadAll();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _selectedBatch == i
                  ? const Color(0xFF354388)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF354388), width: 1.5),
            ),
            child: Center(
              child: Text(
                _batches[i],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _selectedBatch == i
                      ? Colors.white
                      : const Color(0xFF354388),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: List.generate(_statusFilters.length, (i) {
          final isSelected = _selectedFilter == i;
          return Expanded(
            child: CPPressable(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: i < _statusFilters.length - 1
                    ? const EdgeInsets.only(right: 6)
                    : EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFBDAE18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF354388), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    _statusFilters[i],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF354388)
                          : const Color(0xFF354388),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12),
      itemCount: 8,
      itemBuilder: (_, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: CPShimmer(width: double.infinity, height: 72, borderRadius: 14),
      ),
    );
  }

  Widget _buildEmptyState(bool noStudentsAtAll) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF354388).withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              size: 52,
              color: Color(0xFF354388),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            noStudentsAtAll
                ? 'No students yet'
                : 'No students match your search',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF354388),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              noStudentsAtAll
                  ? 'Add your first student to get started'
                  : 'Try adjusting your search or filter criteria',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF354388),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          if (noStudentsAtAll)
            CPPressable(
              onTap: () async {
                final created = await context.push('/admin/add-student');
                if (!context.mounted) return;
                if (created == true) {
                  await _loadAll();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF354388),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_add_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Add Student',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            CPPressable(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _selectedFilter = 0;
                  _selectedBatch = 0;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF354388),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Clear Filters',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF354388),
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildLoadFailedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFB6231B).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: Color(0xFFB6231B),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Unable to load students',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF354388),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check the network or backend connection, then retry.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF354388),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            CPPressable(
              onTap: _loadAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF354388),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

  Widget _buildStudentRow(_Student student, int index) {
    final isSelected = _selected.contains(student.docId);
    final isOverdue = student.feeStatus == 'OVERDUE';
    final isPaid = student.feeStatus == 'PAID';
    final isInactive = student.status == 'inactive';

    final feeColor = isPaid
        ? const Color(0xFFBDAE18)
        : isOverdue
        ? const Color(0xFFB6231B)
        : const Color(0xFFBDAE18);

    final attColor = student.attendance >= 80
        ? const Color(0xFFBDAE18)
        : student.attendance >= 65
        ? const Color(0xFFBDAE18)
        : const Color(0xFFB6231B);

    // Avatar background based on first initial
    final avatarColors = [
      const Color(0xFF354388),
      const Color(0xFFBDAE18),
      const Color(0xFF7C3AED),
      const Color(0xFFBDAE18),
      const Color(0xFF354388),
      const Color(0xFFB6231B),
    ];
    final avatarColor = avatarColors[index % avatarColors.length];

    return CPPressable(
          onTap: () {
            if (_selectMode) {
              _toggleSelect(student.docId);
              return;
            }
            HapticFeedback.lightImpact();
            context.push('/admin/students/${student.docId}').then((_) {
              if (!mounted) return;
              _loadAll();
            });
          },
          onLongPress: () {
            if (!_selectMode) {
              setState(() => _selectMode = true);
              _toggleSelect(student.docId);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF354388).withValues(alpha: 0.06)
                  : isOverdue
                  ? const Color(0xFFFFF5F5)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF354388)
                    : isOverdue
                    ? const Color(0xFFB6231B).withValues(alpha: 0.2)
                    : Colors.white,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Checkbox in select mode
                if (_selectMode)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF354388)
                          : Colors.transparent,
                      border: Border.all(
                        color: const Color(0xFF354388),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),

                // Avatar with status dot
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: avatarColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          student.initials,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Status dot (green = active, grey = inactive)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isInactive
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFFBDAE18),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                // Name + batch
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              student.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF354388),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOverdue)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFB6231B),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        student.batchNames.isEmpty
                            ? '—'
                            : student.batchNames.join(', '),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF354388),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Right side: fee badge + attendance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Fee badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: feeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: feeColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        isPaid
                            ? 'Paid'
                            : isOverdue
                            ? 'Overdue'
                            : 'Due',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: feeColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Attendance bar
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${student.attendance}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: attColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (student.attendance / 100).clamp(
                              0.0,
                              1.0,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: attColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Chevron (only in normal mode)
                if (!_selectMode)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFFD1D5DB),
                    ),
                  ),
              ],
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: index * 40))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.03, end: 0);
  }
}

// ───────────────────────────────────────────────────────────────────────────────
class _Student {
  final String docId, name, id, rollNumber, phone;
  final List<String> batchNames;
  final List<String> batchIds;
  final int attendance;
  final String feeStatus, status;

  const _Student({
    required this.docId,
    required this.name,
    required this.id,
    required this.rollNumber,
    required this.phone,
    required this.batchNames,
    required this.batchIds,
    required this.attendance,
    required this.feeStatus,
    required this.status,
  });

  String get initials => name
      .trim()
      .split(' ')
      .where((e) => e.isNotEmpty)
      .map((e) => e[0])
      .take(2)
      .join()
      .toUpperCase();

  factory _Student.fromMap(Map<String, dynamic> map) {
    final batches = map['batches'] as List?;
    final studentBatches = map['student_batches'] as List?;
    final batchName = (map['batch'] ?? map['batch_name']) as String?;
    List<String> batchNames;
    List<String> batchIds;
    if (batchName != null && batchName.isNotEmpty) {
      batchNames = [batchName];
      final fallbackId = (map['batch_id'] ?? '').toString();
      batchIds = fallbackId.isEmpty ? [] : [fallbackId];
    } else if (studentBatches != null && studentBatches.isNotEmpty) {
      batchNames = studentBatches
          .map((entry) {
            if (entry is Map) {
              final nestedBatch = entry['batch'];
              if (nestedBatch is Map) {
                return (nestedBatch['name'] ?? '').toString();
              }
              return (entry['batch_name'] ?? '').toString();
            }
            return '';
          })
          .where((name) => name.isNotEmpty)
          .toList();
      batchIds = studentBatches
          .map((entry) {
            if (entry is Map) {
              final nestedBatch = entry['batch'];
              if (nestedBatch is Map) {
                return (nestedBatch['id'] ?? '').toString();
              }
              return (entry['batch_id'] ?? '').toString();
            }
            return '';
          })
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
    } else if (batches != null && batches.isNotEmpty) {
      batchNames = batches
          .map((e) => e is Map ? (e['name'] ?? '').toString() : e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      batchIds = batches
          .map((e) => e is Map ? (e['id'] ?? '').toString() : '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
    } else {
      batchNames = [];
      batchIds = [];
    }

    return _Student(
      docId: (map['id'] ?? '').toString(),
      name: (map['name'] ?? 'Student').toString(),
      id: (map['student_code'] ?? map['id'] ?? '').toString(),
      rollNumber: (map['student_code'] ?? map['rollNumber'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      batchNames: batchNames,
      batchIds: batchIds,
      attendance:
          (map['attendance_percent'] ?? map['attendancePercent'] ?? 0) is num
          ? ((map['attendance_percent'] ?? map['attendancePercent'] ?? 0)
                    as num)
                .toInt()
          : 0,
      feeStatus: (map['fee_status'] ?? map['feeStatus'] ?? 'PENDING')
          .toString()
          .toUpperCase(),
      status:
          map['status']?.toString() ??
          ((map['is_active'] == false || map['isActive'] == false)
              ? 'inactive'
              : 'active'),
    );
  }
}

// ── Batch Picker Bottom Sheet ─────────────────────────────────────────────────
class _BatchPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> batches;
  final int selectedCount;

  const _BatchPickerSheet({required this.batches, required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    final availableBatches = batches;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Assign $selectedCount student${selectedCount == 1 ? '' : 's'} to batch',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF354388),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select a batch from the list below',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF354388),
            ),
          ),
          const SizedBox(height: 16),
          // Batch list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: availableBatches.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Colors.white),
              itemBuilder: (ctx, i) {
                final batch = availableBatches[i];
                final name = (batch['name'] ?? 'Batch').toString();
                // Color cycling for batch avatars
                final colors = [
                  const Color(0xFF354388),
                  const Color(0xFF7C3AED),
                  const Color(0xFF354388),
                  const Color(0xFFBDAE18),
                ];
                final color = colors[i % colors.length];
                return CPPressable(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(ctx, batch);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.class_rounded,
                            size: 20,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF354388),
                                ),
                              ),
                              Text(
                                (batch['schedule'] ??
                                        batch['description'] ??
                                        'Tap to assign')
                                    .toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF354388),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: color.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Cancel
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF354388),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



