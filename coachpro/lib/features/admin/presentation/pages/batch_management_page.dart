import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
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

  bool _isLoading = true;
  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _teachers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _adminRepo.getBatches(),
        _adminRepo.getTeachers(),
      ]);
      if (!mounted) return;
      setState(() {
        _batches = List<Map<String, dynamic>>.from(results[0] as List);
        _teachers = List<Map<String, dynamic>>.from(results[1] as List);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CPToast.error(context, 'Unable to load batches: $e');
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

    if (endDate != null && endDate.isBefore(DateTime(now.year, now.month, now.day))) {
      return 'Completed';
    }
    if (!isActive) return 'Suspended';
    if (capacity > 0 && currentStudents >= capacity) return 'Full';
    if (capacity > 0 && currentStudents / capacity >= 0.8) return 'Filling Fast';
    return 'Active';
  }

  Color _badgeColor(String badge) {
    switch (badge) {
      case 'Full':
      case 'Completed':
        return const Color(0xFFD71313);
      case 'Filling Fast':
        return const Color(0xFFF0DE36);
      case 'Suspended':
        return Colors.grey;
      default:
        return const Color(0xFF0D1282);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    final active = _batches.where((b) => (b['is_active'] ?? b['isActive']) == true).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(isDark),
            Expanded(
              child: _isLoading
                  ? ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, __) => const CPShimmer(width: double.infinity, height: 160, borderRadius: 22),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF0D1282),
                      onRefresh: _loadData,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                        children: [
                          Row(
                            children: [
                              _summaryStat('ACTIVE', '$active', const Color(0xFF0D1282), isDark),
                              const SizedBox(width: 10),
                              _summaryStat('TOTAL', '${_batches.length}', const Color(0xFF0D1282), isDark),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (_batches.isEmpty)
                            _buildEmptyState(isDark)
                          else
                            ..._batches.asMap().entries.map((entry) {
                              final batch = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _batchCard(batch, entry.key, isDark),
                              );
                            }),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 14, 10),
      child: Row(
        children: [
          CPPressable(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0D1282)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Batches',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0D1282),
                letterSpacing: -0.7,
              ),
            ),
          ),
          CPPressable(
            onTap: () => _showCreateBatchSheet(context),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF0DE36),
                border: Border.all(color: const Color(0xFF0D1282), width: 3),
                boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3))],
              ),
              child: const Icon(Icons.add_rounded, color: Color(0xFF0D1282)),
            ),
          ),
        ],
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
            Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white54 : Colors.black54,
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
    final badgeColor = _badgeColor(badge);
    final name = (batch['name'] ?? 'Batch').toString();
    final subject = (batch['subject'] ?? 'General').toString();
    final capacity = _toInt(batch['capacity'], fallback: 0);
    final currentStudents = _toInt(batch['current_students']);
    final fee = _toDouble(batch['monthly_fee'] ?? batch['fee']);
    final isActive = (batch['is_active'] ?? batch['isActive']) == true;

    final assignedTeachers = ((batch['assigned_teachers'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final teacherText = assignedTeachers.isNotEmpty
        ? assignedTeachers.map((t) => (t['name'] ?? 'Teacher').toString()).join(', ')
        : ((batch['teacher'] is Map && (batch['teacher'] as Map)['name'] != null)
            ? (batch['teacher'] as Map)['name'].toString()
            : 'No teacher assigned');

    return CPPressable(
      onTap: () => context.push('/admin/batches/${batch['id']}'),
      child: CPGlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(18),
        borderRadius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0D1282),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEDED),
                    border: Border.all(color: badgeColor, width: 2),
                    boxShadow: [BoxShadow(color: badgeColor, offset: const Offset(2, 2))],
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 10, color: const Color(0xFF0D1282)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(subject, style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.groups_rounded, size: 16, color: isDark ? Colors.white60 : Colors.black54),
                const SizedBox(width: 6),
                Text(
                  capacity > 0 ? '$currentStudents / $capacity' : '$currentStudents enrolled',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const Spacer(),
                if (fee > 0)
                  Text(
                    '₹${fee.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              teacherText,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.black54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _inlineAction(
                  icon: isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                  label: isActive ? 'Suspend' : 'Resume',
                  onTap: () => _toggleBatchStatus(batch),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _inlineAction(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Migrate',
                  onTap: () => _showMigrateSheet(batch),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _inlineAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  onTap: () => _confirmDelete(batch),
                  isDark: isDark,
                  danger: true,
                ),
              ],
            ),
          ],
        ),
      ).animate(delay: (80 * index).ms).fadeIn(duration: 400.ms).slideX(begin: 0.06),
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
            color: const Color(0xFFEEEDED),
            border: Border.all(color: const Color(0xFF0D1282), width: 2),
            boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: danger ? const Color(0xFFD71313) : const Color(0xFF0D1282)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: danger ? const Color(0xFFD71313) : const Color(0xFF0D1282),
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
          Icon(Icons.layers_clear_rounded, size: 58, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 14),
          Text(
            'No batches created yet',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 14),
          CustomButton(text: 'Create New Batch', onPressed: () => _showCreateBatchSheet(context)),
        ],
      ),
    );
  }

  Future<void> _toggleBatchStatus(Map<String, dynamic> batch) async {
    final isActive = (batch['is_active'] ?? batch['isActive']) == true;
    try {
      await _adminRepo.toggleBatchStatus(batchId: (batch['id'] ?? '').toString(), isActive: !isActive);
      if (!mounted) return;
      CPToast.success(context, !isActive ? 'Batch resumed' : 'Batch suspended');
      _loadData();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Failed to update status: $e');
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> batch) async {
    final name = (batch['name'] ?? 'this batch').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Batch', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text('Delete "$name" permanently?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await _adminRepo.deleteBatch((batch['id'] ?? '').toString());
      if (!mounted) return;
      CPToast.success(context, 'Batch deleted');
      _loadData();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Delete failed: $e');
    }
  }

  Future<void> _showMigrateSheet(Map<String, dynamic> sourceBatch) async {
    String? targetBatchId;
    final sourceId = (sourceBatch['id'] ?? '').toString();
    final candidates = _batches.where((b) => (b['id'] ?? '').toString() != sourceId).toList();
    if (candidates.isEmpty) {
      CPToast.warning(context, 'Create another batch first for migration');
      return;
    }

    final shouldMigrate = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFEEEDED),
              border: Border(top: BorderSide(color: Color(0xFF0D1282), width: 3), left: BorderSide(color: Color(0xFF0D1282), width: 3), right: BorderSide(color: Color(0xFF0D1282), width: 3)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Promote / Migrate Students', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF0D1282))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: targetBatchId,
                  decoration: const InputDecoration(labelText: 'Target batch'),
                  items: candidates
                      .map((b) => DropdownMenuItem(
                            value: (b['id'] ?? '').toString(),
                            child: Text((b['name'] ?? 'Batch').toString()),
                          ))
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
        });
      },
    );

    if (shouldMigrate != true || targetBatchId == null || targetBatchId!.isEmpty) return;

    try {
      final result = await _adminRepo.migrateBatchStudents(
        sourceBatchId: sourceId,
        targetBatchId: targetBatchId!,
      );
      if (!mounted) return;
      CPToast.success(context, 'Migrated ${result['migrated_count'] ?? 0} students');
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

    DateTime? startDate;
    DateTime? endDate;
    final selectedTeacherIds = <String>{};
    final selectedDays = <int>{1, 3, 5};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
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
              color: Color(0xFFEEEDED),
              border: Border(top: BorderSide(color: Color(0xFF0D1282), width: 3), left: BorderSide(color: Color(0xFF0D1282), width: 3), right: BorderSide(color: Color(0xFF0D1282), width: 3)),
            ),
            padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create New Batch', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282))),
                  const SizedBox(height: 14),
                  _field(nameCtrl, 'Batch Name'),
                  const SizedBox(height: 10),
                  _field(subjectCtrl, 'Class / Subject'),
                  const SizedBox(height: 10),
                  _field(capacityCtrl, 'Enrollment Limit', keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  _field(feeCtrl, 'Monthly Fee', keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  _field(roomCtrl, 'Room (optional)'),
                  const SizedBox(height: 10),
                  _field(descCtrl, 'Description', maxLines: 3),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pickDate(true),
                          child: Text(startDate == null ? 'Start Date' : startDate!.toIso8601String().substring(0, 10)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pickDate(false),
                          child: Text(endDate == null ? 'End Date' : endDate!.toIso8601String().substring(0, 10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Faculty assignment (multiple)', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
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
                  Text('Class Days', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
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
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        CPToast.warning(ctx, 'Batch name is required');
                        return;
                      }
                      if (subjectCtrl.text.trim().isEmpty) {
                        CPToast.warning(ctx, 'Class/Subject is required');
                        return;
                      }

                      try {
                        final teacherIds = selectedTeacherIds.toList();
                        final payload = <String, dynamic>{
                          'name': nameCtrl.text.trim(),
                          'subject': subjectCtrl.text.trim(),
                          'capacity': int.tryParse(capacityCtrl.text.trim()) ?? 60,
                          'room': roomCtrl.text.trim().isEmpty ? null : roomCtrl.text.trim(),
                          'start_date': startDate?.toIso8601String(),
                          'end_date': endDate?.toIso8601String(),
                          'days_of_week': selectedDays.toList()..sort(),
                          'teacher_id': teacherIds.isNotEmpty ? teacherIds.first : null,
                          'teacher_ids': teacherIds,
                          'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        };
                        payload.removeWhere((key, value) => value == null);

                        final created = await _adminRepo.createBatch(payload);

                        final batchId = (created['id'] ?? '').toString();
                        final monthlyFee = double.tryParse(feeCtrl.text.trim()) ?? 0;
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
                        if (!mounted) return;
                        HapticFeedback.mediumImpact();
                        CPToast.success(context, 'Batch created successfully');
                        _loadData();
                      } catch (e) {
                        if (ctx.mounted) {
                          CPToast.error(ctx, 'Create failed: $e');
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        });
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
