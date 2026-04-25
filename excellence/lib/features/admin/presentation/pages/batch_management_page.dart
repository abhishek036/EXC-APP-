import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_shimmer.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../data/repositories/admin_repository.dart';

class BatchManagementPage extends StatefulWidget {
  const BatchManagementPage({super.key});

  @override
  State<BatchManagementPage> createState() => _BatchManagementPageState();
}

class _BatchManagementPageState extends State<BatchManagementPage> {
  final _adminRepo = sl<AdminRepository>();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  bool _isLoading = true;
  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _teachers = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    final previousBatches = List<Map<String, dynamic>>.from(_batches);

    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait([
        _adminRepo.getBatches(),
        _adminRepo.getTeachers(),
      ]);

      final fetchedBatches = List<Map<String, dynamic>>.from(
        results[0] as List,
      );
      final fetchedTeachers = List<Map<String, dynamic>>.from(
        results[1] as List,
      );

      // Merge: if server returns empty but we previously had batches,
      // it might be a stale read. Keep what we have if server is empty.
      List<Map<String, dynamic>> effectiveBatches;
      if (fetchedBatches.isNotEmpty) {
        effectiveBatches = fetchedBatches;
      } else {
        effectiveBatches = previousBatches;
      }

      if (!mounted) return;
      setState(() {
        _batches = effectiveBatches;
        _teachers = fetchedTeachers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (!silent) CPToast.error(context, 'Unable to load batches: $e');
    }
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  DateTime? _toDate(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _batchBadge(Map<String, dynamic> batch) {
    final isActive = (batch['is_active'] ?? batch['isActive']) == true;
    final currentStudents = _toInt(batch['current_students']);
    final capacity = _toInt(batch['capacity']);
    final endDate = _toDate(batch['end_date']);
    final now = DateTime.now();

    if (endDate != null &&
        endDate.isBefore(DateTime(now.year, now.month, now.day))) {
      return 'Completed';
    }
    if (!isActive) return 'Suspended';
    if (capacity > 0 && currentStudents >= capacity) return 'Full';
    if (capacity > 0 && currentStudents / capacity >= 0.8) {
      return 'Filling Fast';
    }
    return 'Active';
  }

  Color _badgeColor(String badge) {
    switch (badge) {
      case 'Full':
      case 'Completed':
        return const Color(0xFFB6231B);
      case 'Filling Fast':
        return const Color(0xFFE5A100);
      case 'Suspended':
        return Colors.grey;
      default:
        return const Color(0xFF354388);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = AppColors.elitePrimary;
    const surfaceWhite = AppColors.offWhite;
    const accentYellow = AppColors.moltenAmber;
    final active = _batches
        .where((b) => (b['is_active'] ?? b['isActive']) == true)
        .length;
    final visibleBatches = _batches.where((batch) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      final name = (batch['name'] ?? '').toString().toLowerCase();
      final subject = (batch['subject'] ?? '').toString().toLowerCase();
      final teacherLabel = (((batch['assigned_teachers'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => (e['name'] ?? '').toString())
          .join(' '))
          .toLowerCase();
      return name.contains(q) ||
          subject.contains(q) ||
          teacherLabel.contains(q);
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
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              GoRouter.of(context).pop();
            } else {
              GoRouter.of(context).go('/admin');
            }
          },
        ),
        title: Text(
          'BATCHES',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          CPPressable(
            onTap: () => _showCreateBatchSheet(context),
            child: Container(
              width: 46,
              height: 46,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: accentYellow,
                border: Border.all(color: primaryBlue, width: 3),
                boxShadow: const [
                  BoxShadow(color: primaryBlue, offset: Offset(3, 3)),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: primaryBlue),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: accentYellow,
          backgroundColor: primaryBlue,
          onRefresh: _loadData,
          child: _isLoading
              ? ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: 4,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) => const CPShimmer(
                    width: double.infinity,
                    height: 240,
                    borderRadius: 18,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _searchBar(primaryBlue, surfaceWhite),
                    const SizedBox(height: 14),
                    if (visibleBatches.isEmpty)
                      _buildEmptyState(false)
                    else
                      ...visibleBatches.asMap().entries.map((entry) {
                        final batch = entry.value;
                        return _batchCard(batch, entry.key, false);
                      }),
                  ],
                ),
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
          hintText: 'Search batches',
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

  Widget _summaryStat(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: CPGlassCard(
        isDark: isDark,
        padding: const EdgeInsets.symmetric(vertical: 16),
        borderRadius: 18,
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.paleSlate2 : Colors.black54,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _batchCard(Map<String, dynamic> batch, int index, bool isDark) {
    final badge = _batchBadge(batch);
    final name = (batch['name'] ?? 'Batch').toString();
    final subject = (batch['subject'] ?? 'General').toString();
    final capacity = _toInt(batch['capacity'], fallback: 0);
    final currentStudents = _toInt(batch['current_students']);
    final isActive = (batch['is_active'] ?? batch['isActive']) == true;
    final statusText = badge == 'Completed' ? 'COMPLETED' : (isActive ? 'ONGOING' : 'SUSPENDED');
    final startDate = (batch['start_date'] ?? '').toString();
    final teacherText = (((batch['assigned_teachers'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => (e['name'] ?? 'Teacher').toString())
            .join(', '))
        .trim();

    return CPPressable(
      onTap: () {
        GoRouter.of(context).push('/admin/batches/${batch['id']}').then((_) {
          if (!mounted) return;
          _loadData();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          border: Border.all(color: AppColors.elitePrimary, width: 2.5),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 124,
              decoration: const BoxDecoration(
                color: AppColors.moltenAmber,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Text(
                  subject.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                    color: AppColors.elitePrimary,
                    letterSpacing: 0.8,
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
                          name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                            color: AppColors.elitePrimary,
                            letterSpacing: -0.8,
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
                            color: AppColors.elitePrimary.withValues(alpha: 0.35),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'ADMIN',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: AppColors.elitePrimary.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: AppColors.elitePrimary,
                        ),
                        onSelected: (value) {
                          if (value == 'open') {
                            GoRouter.of(context).push('/admin/batches/${batch['id']}').then((_) {
                              if (!mounted) return;
                              _loadData();
                            });
                          } else if (value == 'toggle') {
                            _toggleBatchStatus(batch);
                          } else if (value == 'migrate') {
                            _showMigrateSheet(batch);
                          } else if (value == 'delete') {
                            _confirmDelete(batch);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'open',
                            child: Text('Open batch'),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(isActive ? 'Suspend batch' : 'Resume batch'),
                          ),
                          const PopupMenuItem(
                            value: 'migrate',
                            child: Text('Promote / migrate students'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete batch'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 18,
                        color: AppColors.elitePrimary.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        subject.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.elitePrimary.withValues(alpha: 0.85),
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
                            ? AppColors.elitePrimary
                            : AppColors.coralRed,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$statusText  |  ${batch['start_time'] ?? '--'} - ${batch['end_time'] ?? '--'}${startDate.isNotEmpty ? '  |  Started: $startDate' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.elitePrimary.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (teacherText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      teacherText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.elitePrimary.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            GoRouter.of(context).push('/admin/batches/${batch['id']}').then((_) {
                              if (!mounted) return;
                              _loadData();
                            });
                          },
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.moltenAmber,
                              border: Border.all(color: AppColors.elitePrimary, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'MANAGE BATCH',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: AppColors.elitePrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          GoRouter.of(context).push('/admin/batches/${batch['id']}').then((_) {
                            if (!mounted) return;
                            _loadData();
                          });
                        },
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.elitePrimary, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                            color: AppColors.elitePrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          GoRouter.of(context).push('/admin/batches/${batch['id']}').then((_) {
                            if (!mounted) return;
                            _loadData();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.elitePrimary, width: 2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                currentStudents.toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: AppColors.elitePrimary,
                                ),
                              ),
                              Text(
                                'STUD',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                  color: AppColors.elitePrimary.withValues(alpha: 0.7),
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
      ).animate(delay: (80 * index).ms).fadeIn(duration: 400.ms).slideX(begin: 0.1),
    );
  }

  Widget _inlineAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool danger = false,
  }) {
    return Expanded(
      child: CPPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF354388), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0xFF354388), offset: Offset(2, 2)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: danger
                    ? const Color(0xFFB6231B)
                    : const Color(0xFF354388),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: danger
                        ? const Color(0xFFB6231B)
                        : const Color(0xFF354388),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return CPGlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(32),
      borderRadius: 22,
      child: Column(
        children: [
          Icon(
            Icons.layers_clear_rounded,
            size: 58,
            color: isDark ? AppColors.darkBorder : Colors.black26,
          ),
          const SizedBox(height: 14),
          Text(
            'No batches created yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.paleSlate2 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          CustomButton(
            text: 'Create New Batch',
            onPressed: () => _showCreateBatchSheet(context),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBatchStatus(Map<String, dynamic> batch) async {
    final isActive = (batch['is_active'] ?? batch['isActive']) == true;
    try {
      // Optimistic update
      setState(() {
        final idx = _batches.indexWhere((b) => b['id'] == batch['id']);
        if (idx != -1) {
          _batches[idx] = {..._batches[idx], 'is_active': !isActive};
        }
      });

      await _adminRepo.toggleBatchStatus(
        batchId: (batch['id'] ?? '').toString(),
        isActive: !isActive,
      );
      if (!mounted) return;
      CPToast.success(context, !isActive ? 'Batch resumed' : 'Batch suspended');
      _loadData(silent: true);
    } catch (e) {
      if (!mounted) return;
      // Revert on error
      _loadData(silent: true);
      CPToast.error(context, 'Failed to update status: $e');
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> batch) async {
    final name = (batch['name'] ?? 'this batch').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Batch',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Delete "$name" permanently?',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await _adminRepo.deleteBatch((batch['id'] ?? '').toString());
      if (!mounted) return;

      // Optimistic delete
      setState(() {
        _batches.removeWhere((b) => b['id'] == batch['id']);
      });

      CPToast.success(context, 'Batch deleted');
      _loadData(silent: true);
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Delete failed: $e');
    }
  }

  Future<void> _showMigrateSheet(Map<String, dynamic> sourceBatch) async {
    String? targetBatchId;
    final sourceId = (sourceBatch['id'] ?? '').toString();
    final candidates = _batches
        .where((b) => (b['id'] ?? '').toString() != sourceId)
        .toList();
    if (candidates.isEmpty) {
      CPToast.warning(context, 'Create another batch first for migration');
      return;
    }

    final shouldMigrate = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFF354388), width: 3),
                  left: BorderSide(color: Color(0xFF354388), width: 3),
                  right: BorderSide(color: Color(0xFF354388), width: 3),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Promote / Migrate Students',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF354388),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: targetBatchId,
                    decoration: const InputDecoration(
                      labelText: 'Target batch',
                    ),
                    items: candidates
                        .map(
                          (b) => DropdownMenuItem(
                            value: (b['id'] ?? '').toString(),
                            child: Text((b['name'] ?? 'Batch').toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setS(() => targetBatchId = v),
                  ),
                  const SizedBox(height: 14),
                  CustomButton(
                    text: 'Migrate Now',
                    onPressed: () {
                      if (targetBatchId == null || targetBatchId!.isEmpty) {
                        CPToast.warning(ctx, 'Choose target batch');
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (shouldMigrate != true ||
        targetBatchId == null ||
        targetBatchId!.isEmpty) {
      return;
    }

    try {
      final result = await _adminRepo.migrateBatchStudents(
        sourceBatchId: sourceId,
        targetBatchId: targetBatchId!,
      );
      if (!mounted) return;
      CPToast.success(
        context,
        'Migrated ${result['migrated_count'] ?? 0} students',
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Migration failed: $e');
    }
  }

  Future<void> _showCreateBatchSheet(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '60');
    final feeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    final subjectsCtrl = TextEditingController();

    DateTime? startDate;
    DateTime? endDate;
    final selectedTeacherIds = <String>{};
    final selectedDays = <int>{1, 3, 5};
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> pickDate(bool isStart) async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked == null) return;
              setSheet(() {
                if (isStart) {
                  startDate = picked;
                } else {
                  endDate = picked;
                }
              });
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFF354388), width: 3),
                  left: BorderSide(color: Color(0xFF354388), width: 3),
                  right: BorderSide(color: Color(0xFF354388), width: 3),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Batch',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF354388),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _field(nameCtrl, 'Batch Name'),
                    const SizedBox(height: 10),
                    _field(subjectCtrl, 'Class / Subject'),
                    const SizedBox(height: 10),
                    _field(
                      capacityCtrl,
                      'Enrollment Limit',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    _field(
                      feeCtrl,
                      'Monthly Fee',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    _field(roomCtrl, 'Room (optional)'),
                    const SizedBox(height: 10),
                    _field(
                      subjectsCtrl,
                      'Multiple Subjects (e.g. Physics, Chemistry, Maths)',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    _field(descCtrl, 'Description', maxLines: 3),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pickDate(true),
                            child: Text(
                              startDate == null
                                  ? 'Start Date'
                                  : startDate!.toIso8601String().substring(
                                      0,
                                      10,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pickDate(false),
                            child: Text(
                              endDate == null
                                  ? 'End Date'
                                  : endDate!.toIso8601String().substring(0, 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Faculty assignment (multiple)',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF354388),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _teachers.map((teacher) {
                        final id = (teacher['id'] ?? '').toString();
                        final isSelected = selectedTeacherIds.contains(id);
                        final name = (teacher['name'] ?? 'Teacher').toString();
                        return FilterChip(
                          label: Text(name),
                          selected: isSelected,
                          onSelected: (value) {
                            setSheet(() {
                              if (value) {
                                selectedTeacherIds.add(id);
                              } else {
                                selectedTeacherIds.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Class Days',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF354388),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          [
                            'Sun',
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                          ].asMap().entries.map((entry) {
                            final idx = entry.key;
                            final day = entry.value;
                            final selected = selectedDays.contains(idx);
                            return FilterChip(
                              label: Text(day),
                              selected: selected,
                              onSelected: (value) {
                                setSheet(() {
                                  if (value) {
                                    selectedDays.add(idx);
                                  } else {
                                    selectedDays.remove(idx);
                                  }
                                });
                              },
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Create Batch',
                      isLoading: isSubmitting,
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (isSubmitting) return;
                        if (nameCtrl.text.trim().isEmpty) {
                          CPToast.warning(ctx, 'Batch name is required');
                          return;
                        }
                        if (subjectCtrl.text.trim().isEmpty) {
                          CPToast.warning(ctx, 'Class/Subject is required');
                          return;
                        }

                        setSheet(() => isSubmitting = true);

                        try {
                    final teacherIds = selectedTeacherIds.toList();
                    final payload = <String, dynamic>{
                      'name': nameCtrl.text.trim(),
                      'subject': subjectCtrl.text.trim(),
                      'subjects': subjectsCtrl.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      'capacity': int.tryParse(capacityCtrl.text.trim()) ?? 60,
                      'room': roomCtrl.text.trim().isEmpty
                          ? null
                          : roomCtrl.text.trim(),
                      'start_date': startDate?.toIso8601String(),
                      'end_date': endDate?.toIso8601String(),
                      'days_of_week': selectedDays.toList()..sort(),
                      'teacher_id': teacherIds.isNotEmpty ? teacherIds.first : null,
                      'teacher_ids': teacherIds,
                      'description': descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                    };
                    payload.removeWhere((key, value) => value == null);

                          final created = await _adminRepo.createBatch(payload);
                          final batchId = (created['id'] ?? '').toString();

                          if (!mounted) return;

                          // Optimistic Add
                          setState(() {
                            _batches = [
                              Map<String, dynamic>.from(created),
                              ..._batches,
                            ];
                          });

                          final monthlyFee =
                              double.tryParse(feeCtrl.text.trim()) ?? 0;
                          if (batchId.isNotEmpty && monthlyFee > 0) {
                            await _adminRepo.defineFeeStructure({
                              'batch_id': batchId,
                              'monthly_fee': monthlyFee,
                              'admission_fee': 0,
                              'exam_fee': 0,
                              'late_fee_amount': 0,
                              'late_after_day': 10,
                              'grace_days': 0,
                            });
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!mounted || !ctx.mounted) return;
                          HapticFeedback.mediumImpact();
                          CPToast.success(ctx, 'Batch created successfully');
                          _loadData(silent: true);
                        } catch (e) {
                          if (ctx.mounted) {
                            CPToast.error(ctx, 'Create failed: $e');
                          }
                        } finally {
                          if (ctx.mounted) {
                            setSheet(() => isSubmitting = false);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}


