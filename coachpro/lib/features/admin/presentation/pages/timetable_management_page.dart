import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';

class TimetableManagementPage extends StatefulWidget {
  const TimetableManagementPage({super.key});

  @override
  State<TimetableManagementPage> createState() => _TimetableManagementPageState();
}

class _TimetableManagementPageState extends State<TimetableManagementPage> {
  final AdminRepository _adminRepo = sl<AdminRepository>();

  bool _isLoading = true;
  String _activeDay = 'Monday';
  final _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _teachers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final batches = await _adminRepo.getBatches();
      final teachers = await _adminRepo.getTeachers();

      if (mounted) {
        setState(() {
          _batches = batches;
          _teachers = teachers;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _dayIndex(String day) {
    switch (day) {
      case 'Sunday':
        return 0;
      case 'Monday':
        return 1;
      case 'Tuesday':
        return 2;
      case 'Wednesday':
        return 3;
      case 'Thursday':
        return 4;
      case 'Friday':
        return 5;
      default:
        return 6;
    }
  }

  List<Map<String, dynamic>> _slotsForDay() {
    final index = _dayIndex(_activeDay);
    return _batches.where((batch) {
      final days = _normalizeDaysOfWeek(batch['days_of_week']);
      return days.contains(index);
    }).toList();
  }

  List<int> _normalizeDaysOfWeek(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((value) {
          if (value is int) return value;
          if (value is num) return value.toInt();
          return int.tryParse(value.toString());
        })
        .whereType<int>()
        .toList();
  }

  String _formatTimeLabel(dynamic raw) {
    final source = (raw ?? '').toString().trim();
    if (source.isEmpty) return '--:--';

    final parsed = DateTime.tryParse(source);
    if (parsed != null) {
      return DateFormat('hh:mm a').format(parsed);
    }

    final parts = source.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        return DateFormat('hh:mm a').format(DateTime(2000, 1, 1, hour, minute));
      }
    }

    return source;
  }

  Future<void> _addSlot() async {
    String? selectedBatchId;
    String? selectedTeacherId;
    TimeOfDay? selectedStartTime;
    TimeOfDay? selectedEndTime;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: CT.bg(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Slot for $_activeDay', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedBatchId,
                decoration: InputDecoration(
                  labelText: 'Select Batch',
                  filled: true,
                  fillColor: CT.card(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _batches
                    .map((batch) => DropdownMenuItem(
                          value: (batch['id'] ?? '').toString(),
                          child: Text((batch['name'] ?? 'Batch').toString()),
                        ))
                    .toList(),
                onChanged: (value) => setS(() => selectedBatchId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedTeacherId,
                decoration: InputDecoration(
                  labelText: 'Select Teacher',
                  filled: true,
                  fillColor: CT.card(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _teachers.map((teacher) {
                  final user = teacher['user'] is Map<String, dynamic>
                      ? teacher['user'] as Map<String, dynamic>
                      : <String, dynamic>{};
                  final name = (teacher['name'] ?? user['name'] ?? 'Teacher').toString();
                  return DropdownMenuItem(value: (teacher['id'] ?? '').toString(), child: Text(name));
                }).toList(),
                onChanged: (value) => setS(() => selectedTeacherId = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CPPressable(
                      onTap: () async {
                        final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                        if (time != null) setS(() => selectedStartTime = time);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(color: CT.card(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: CT.border(context))),
                        child: Text(selectedStartTime?.format(ctx) ?? 'Start Time', style: GoogleFonts.dmSans(color: CT.textH(context))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CPPressable(
                      onTap: () async {
                        final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                        if (time != null) setS(() => selectedEndTime = time);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(color: CT.card(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: CT.border(context))),
                        child: Text(selectedEndTime?.format(ctx) ?? 'End Time', style: GoogleFonts.dmSans(color: CT.textH(context))),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.dmSans(color: CT.textM(context)))),
            ElevatedButton(
              onPressed: () async {
                if (selectedBatchId == null || selectedStartTime == null || selectedEndTime == null) return;
                Navigator.pop(ctx);
                setState(() => _isLoading = true);

                final batch = _batches.firstWhere(
                  (b) => (b['id'] ?? '').toString() == selectedBatchId,
                  orElse: () => <String, dynamic>{},
                );
                if (batch.isEmpty) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected batch is no longer available')));
                  }
                  return;
                }
                final days = _normalizeDaysOfWeek(batch['days_of_week']).toSet();
                days.add(_dayIndex(_activeDay));

                await _adminRepo.updateBatch(
                  batchId: selectedBatchId!,
                  data: {
                    'days_of_week': days.toList()..sort(),
                    'start_time': '${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}:00',
                    'end_time': '${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}:00',
                    if (selectedTeacherId != null && selectedTeacherId!.isNotEmpty) 'teacher_id': selectedTeacherId,
                  },
                );
                _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: CT.accent(context), foregroundColor: Colors.white),
              child: const Text('Add Slot'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSlot(String batchId) async {
    final batch = _batches.firstWhere(
      (b) => (b['id'] ?? '').toString() == batchId,
      orElse: () => <String, dynamic>{},
    );
    if (batch.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot could not be removed because the batch was not found')));
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete slot?'),
        content: const Text('This will remove the batch from the selected day.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    final activeIndex = _dayIndex(_activeDay);
    final days = _normalizeDaysOfWeek(batch['days_of_week'])
        .where((d) => d != activeIndex)
        .toList();

    try {
      setState(() => _isLoading = true);
      await _adminRepo.updateBatch(batchId: batchId, data: {'days_of_week': days});
      await _loadData();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove slot: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSlots = _slotsForDay();

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        leading: CPPressable(
          onTap: () => context.pop(),
          child: Icon(Icons.arrow_back_ios, size: 18, color: CT.textH(context)),
        ),
        title: Text('Timetable Manager', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
        backgroundColor: CT.bg(context),
        elevation: 0,
        actions: [
          CPPressable(
            onTap: _addSlot,
            child: Container(
              margin: const EdgeInsets.only(right: AppDimensions.pagePaddingH),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: CT.accent(context), borderRadius: BorderRadius.circular(20)),
              child: Text('Add Slot', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH, vertical: 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _days.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = _days[index];
                final isActive = _activeDay == day;
                return CPPressable(
                  onTap: () => setState(() => _activeDay = day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? CT.accent(context) : CT.card(context),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: isActive ? CT.accent(context) : CT.border(context)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      day.substring(0, 3),
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: isActive ? Colors.white : CT.textH(context)),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: CT.accent(context)))
                : currentSlots.isEmpty
                    ? Center(child: Text('No classes scheduled for $_activeDay', style: GoogleFonts.dmSans(color: CT.textM(context))))
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
                        itemCount: currentSlots.length,
                        itemBuilder: (context, index) {
                          final slot = currentSlots[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(AppDimensions.md),
                            decoration: CT.cardDecor(context),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(color: CT.accent(context).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Text(
                                    _formatTimeLabel(slot['start_time']),
                                    style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: CT.accent(context)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text((slot['name'] ?? 'Unknown Batch').toString(), style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
                                      const SizedBox(height: 4),
                                      Text((slot['teacher_name'] ?? 'Unknown Teacher').toString(), style: GoogleFonts.dmSans(fontSize: 13, color: CT.textS(context))),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteSlot((slot['id'] ?? '').toString()),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: (20 * index).ms).slideX(begin: 0.1);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}


