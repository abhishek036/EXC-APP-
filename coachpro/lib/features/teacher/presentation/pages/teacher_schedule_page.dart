import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../../../core/widgets/cp_role_shell.dart';
import '../../data/repositories/teacher_repository.dart';

class TeacherSchedulePage extends StatefulWidget {
  const TeacherSchedulePage({super.key});

  @override
  State<TeacherSchedulePage> createState() => _TeacherSchedulePageState();
}

class _TeacherSchedulePageState extends State<TeacherSchedulePage> {
  final _repo = sl<TeacherRepository>();
  final _realtime = sl<RealtimeSyncService>();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _batches = [];
  StreamSubscription<Map<String, dynamic>>? _syncSub;

  String _dateKey(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool _matchesSelectedDate(dynamic rawDate) {
    final parsed = DateTime.tryParse((rawDate ?? '').toString());
    if (parsed == null) return false;
    return _dateKey(parsed) == _dateKey(_selectedDate);
  }

  String _formatSelectedDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Map<String, dynamic> _decorateEntryWithBatch(Map<String, dynamic> entry) {
    final batchId = (entry['batch_id'] ?? '').toString();
    if (batchId.isEmpty || entry['batch'] is Map<String, dynamic>) {
      return entry;
    }

    final batch = _batches.cast<Map<String, dynamic>?>().firstWhere(
      (item) => (item?['id'] ?? '').toString() == batchId,
      orElse: () => null,
    );

    if (batch == null) return entry;

    return {
      ...entry,
      'batch': {
        'name': batch['name'],
        'subject': batch['subject'],
      },
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
    _initRealtime();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _initRealtime() async {
    await _realtime.connect();
    _syncSub?.cancel();
    _syncSub = _realtime.updates.listen((event) {
      if (!mounted) return;
      final reason = (event['reason'] ?? '').toString();
      if (reason.startsWith('lecture_schedule_') || reason.contains('lecture_')) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getMyScheduleEntries(date: _selectedDate),
        _repo.getMyBatches(),
      ]);

      final entries = List<Map<String, dynamic>>.from(results[0] as List);
      final batches = List<Map<String, dynamic>>.from(results[1] as List);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _batches = batches;
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
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);
    const yellow = Color(0xFFF0DE36);

    return Scaffold(
      backgroundColor: blue,
      appBar: AppBar(
        backgroundColor: blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
          onPressed: _handleBack,
        ),
        title: Text('DAILY SCHEDULE', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1.2)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : () => _openScheduleSheet(),
        backgroundColor: yellow,
        foregroundColor: blue,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black, width: 3)),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
      body: RefreshIndicator(
        color: yellow,
        backgroundColor: blue,
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: yellow))
            : _error != null
                ? _buildErrorState(blue, yellow)
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildWeekStrip(blue, surface, yellow),
                      const SizedBox(height: 32),
                      _buildSectionTitle('CLASSES • ${_formatSelectedDate(_selectedDate)}', yellow),
                      const SizedBox(height: 16),
                      if (_entries.isEmpty)
                        _buildEmptyState(blue, surface)
                      else
                        ..._entries.asMap().entries.map((entry) => _buildClassCard(entry.value, entry.key, blue, surface, yellow)),
                      const SizedBox(height: 40),
                      _buildAlertsCard(blue, surface, yellow),
                    ],
                  ),
      ),
    );
  }

  Widget _buildWeekStrip(Color blue, Color surface, Color yellow) {
    final base = _selectedDate;
    final days = List.generate(7, (i) => base.add(Duration(days: i - base.weekday + 1)));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: Colors.black, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                  });
                  _load();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.chevron_left_rounded, color: blue, size: 20),
                ),
              ),
              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked == null) return;
                      setState(() {
                        _selectedDate = DateTime(picked.year, picked.month, picked.day);
                      });
                      _load();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Text(
                        _formatSelectedDate(_selectedDate),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: blue,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 7));
                  });
                  _load();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.chevron_right_rounded, color: blue, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((d) {
              final isSelected = d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day;
              return Column(
                children: [
                  Text(_dayShort(d.weekday), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: blue.withValues(alpha: 0.5))),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      setState(() => _selectedDate = DateTime(d.year, d.month, d.day));
                      _load();
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected ? yellow : Colors.transparent,
                        border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text('${d.day}', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: blue)),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildSectionTitle(String title, Color yellow) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: yellow),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildClassCard(Map<String, dynamic> item, int index, Color blue, Color surface, Color yellow) {
    final scheduled = DateTime.tryParse((item['scheduled_at'] ?? '').toString());
    final start = scheduled != null
        ? '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}'
        : '--';
    final duration = (item['duration_minutes'] ?? 60) as num;
    final endTime = scheduled?.add(Duration(minutes: duration.toInt()));
    final end = endTime == null
      ? '--'
      : '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

    final batch = item['batch'] as Map?;
    final name = (batch?['name'] ?? item['name'] ?? item['batch_name'] ?? 'BATCH').toString().toUpperCase();
    final subject = (batch?['subject'] ?? item['subject'] ?? 'SUBJECT').toString().toUpperCase();

    return InkWell(
      onTap: _isSaving ? null : () => _openScheduleSheet(item: item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: Colors.black, width: 3),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(4, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: yellow, border: Border.all(color: Colors.black, width: 2), borderRadius: BorderRadius.circular(8)),
              child: Text(start, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: blue)),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: blue)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(subject, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w900, color: blue.withValues(alpha: 0.5))),
                      const SizedBox(width: 12),
                      Text('$start - $end', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: blue.withValues(alpha: 0.5))),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: blue, size: 20),
          ],
        ),
      ),
    ).animate(delay: (50 * index).ms).fadeIn().slideX(begin: 0.1);
  }

  Future<void> _openScheduleSheet({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final titleCtrl = TextEditingController(text: (item?['title'] ?? '').toString());
    final durationCtrl = TextEditingController(text: ((item?['duration_minutes'] ?? 60)).toString());
    String? selectedBatchId = (item?['batch_id'] ?? '').toString();
    if (selectedBatchId.isEmpty && _batches.isNotEmpty) {
      selectedBatchId = (_batches.first['id'] ?? '').toString();
    }
    final now = DateTime.now();
    DateTime scheduledAt = DateTime.tryParse((item?['scheduled_at'] ?? '').toString())
      ?? DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, now.hour, now.minute);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEDED),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isEdit ? 'EDIT SCHEDULE' : 'NEW SCHEDULE', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF0D1282))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBatchId,
                    decoration: const InputDecoration(labelText: 'Batch', border: OutlineInputBorder()),
                    onChanged: (v) => setModal(() => selectedBatchId = v),
                    items: _batches
                        .map((b) => DropdownMenuItem<String>(
                              value: (b['id'] ?? '').toString(),
                              child: Text((b['name'] ?? 'Batch').toString()),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Duration (minutes)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: scheduledAt,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date == null) return;
                            if (!ctx.mounted) return;
                            final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(scheduledAt));
                            if (time == null) return;
                            setModal(() {
                              scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          },
                          child: Text('${scheduledAt.day.toString().padLeft(2, '0')}/${scheduledAt.month.toString().padLeft(2, '0')} ${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (isEdit)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () async {
                                      final lectureId = (item['id'] ?? '').toString();
                                    if (lectureId.isEmpty) return;
                                    await _deleteSchedule(lectureId);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                            child: const Text('DELETE'),
                          ),
                        ),
                      if (isEdit) const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  final title = titleCtrl.text.trim();
                                  final duration = int.tryParse(durationCtrl.text.trim()) ?? 60;
                                  if (title.isEmpty || selectedBatchId == null || selectedBatchId!.isEmpty) return;
                                  if (duration <= 0) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(content: Text('Duration must be greater than 0 minutes')),
                                      );
                                    }
                                    return;
                                  }
                                  bool success = false;
                                  if (isEdit) {
                                    success = await _updateSchedule(
                                      lectureId: (item['id'] ?? '').toString(),
                                      batchId: selectedBatchId!,
                                      title: title,
                                      scheduledAt: scheduledAt,
                                      durationMinutes: duration,
                                    );
                                  } else {
                                    success = await _createSchedule(
                                      batchId: selectedBatchId!,
                                      title: title,
                                      scheduledAt: scheduledAt,
                                      durationMinutes: duration,
                                    );
                                  }
                                  if (success && ctx.mounted) Navigator.pop(ctx);
                                },
                          child: Text(isEdit ? 'UPDATE' : 'CREATE'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
                );
          },
        );
      },
    );

    titleCtrl.dispose();
    durationCtrl.dispose();
  }

  Future<bool> _createSchedule({
    required String batchId,
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    setState(() {
      _isSaving = true;
      _selectedDate = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
    });
    try {
      final created = await _repo.createMyScheduleEntry(
        batchId: batchId,
        title: title,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
      );
      if (!mounted) return true;
      await _load();
      if (!mounted) return true;

      if (_entries.isEmpty && _matchesSelectedDate(created['scheduled_at'])) {
        final optimistic = _decorateEntryWithBatch(Map<String, dynamic>.from(created));
        setState(() {
          _entries = [optimistic, ..._entries];
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule created')));
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _updateSchedule({
    required String lectureId,
    required String batchId,
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    if (lectureId.isEmpty) return false;
    setState(() {
      _isSaving = true;
      _selectedDate = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
    });
    try {
      await _repo.updateMyScheduleEntry(
        lectureId: lectureId,
        batchId: batchId,
        title: title,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
      );
      if (!mounted) return true;
      await _load();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule updated')));
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _deleteSchedule(String lectureId) async {
    setState(() => _isSaving = true);
    try {
      await _repo.deleteMyScheduleEntry(lectureId);
      if (!mounted) return true;
      await _load();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule deleted')));
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAlertsCard(Color blue, Color surface, Color yellow) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), border: Border.all(color: Colors.white24, width: 2), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.notifications_active_rounded, color: yellow, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'REMAINDERS: ALL CLASSES FOR TODAY ARE ON TRACK. NO SUBSTITUTIONS ASSIGNED.',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.7), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color blue, Color surface) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: surface.withValues(alpha: 0.1), border: Border.all(color: Colors.white24, width: 2, style: BorderStyle.solid), borderRadius: BorderRadius.circular(16)),
      child: Center(
        child: Text(
          'NO CLASSES SCHEDULED FOR ${_formatSelectedDate(_selectedDate)}',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildErrorState(Color blue, Color yellow) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline_rounded, color: Colors.white, size: 48),
      const SizedBox(height: 16),
      Text('FAILED TO LOAD SCHEDULE', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900)),
      const SizedBox(height: 24),
      _btn('RETRY', _load, yellow, blue),
    ]));
  }

  Widget _btn(String label, VoidCallback onTap, Color bg, Color fg) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(color: bg, border: Border.all(color: Colors.black, width: 2.5), borderRadius: BorderRadius.circular(8), boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(3, 3))]),
        child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: fg)),
      ),
    );
  }

  String _dayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'MON';
      case DateTime.tuesday: return 'TUE';
      case DateTime.wednesday: return 'WED';
      case DateTime.thursday: return 'THU';
      case DateTime.friday: return 'FRI';
      case DateTime.saturday: return 'SAT';
      default: return 'SUN';
    }
  }
}
