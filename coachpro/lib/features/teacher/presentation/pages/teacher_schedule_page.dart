import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../../../core/widgets/cp_role_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_toast.dart';
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
  Timer? _reloadDebounce;

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
      'batch': {'name': batch['name'], 'subject': batch['subject']},
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
    _reloadDebounce?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _initRealtime() async {
    await _realtime.connect();
    _syncSub?.cancel();
    _syncSub = _realtime.updates.listen((event) {
      if (!mounted) return;
      final reason = (event['reason'] ?? '').toString();
      if (reason.startsWith('lecture_schedule_') ||
          reason.contains('lecture_')) {
        _scheduleSilentReload();
      }
    });
  }

  void _scheduleSilentReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _load(silent: true, refreshBatches: false);
    });
  }

  Future<void> _load({bool silent = false, bool refreshBatches = false}) async {
    if (!mounted) return;
    final previousEntries = List<Map<String, dynamic>>.from(_entries);
    final shouldShowInitialLoader = _isLoading && _entries.isEmpty;

    if (shouldShowInitialLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else if (!silent) {
      setState(() {
        _error = null;
      });
    } else {
      _error = null;
    }

    try {
      final scheduleFuture = _repo.getMyScheduleEntries(date: _selectedDate);
      final batchesFuture = refreshBatches || _batches.isEmpty
          ? _repo.getMyBatches()
          : Future<List<Map<String, dynamic>>>.value(_batches);
      final results = await Future.wait([scheduleFuture, batchesFuture]);

      final fetched = List<Map<String, dynamic>>.from(results[0] as List);
      final batches = List<Map<String, dynamic>>.from(results[1] as List);

      // Merge logic: prefer newly fetched data, but don't lose recent optimistic additions
      // if the fetched list is empty (potentially stale secondary read).
      List<Map<String, dynamic>> effectiveEntries;
      if (fetched.isNotEmpty) {
        effectiveEntries = fetched;
      } else {
        // If server returns empty, keep what we have if it matches the current date
        effectiveEntries = previousEntries
            .where((entry) => _matchesSelectedDate(entry['scheduled_at']))
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _entries = effectiveEntries;
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 22,
          ),
          onPressed: _handleBack,
        ),
        title: Text(
          'DAILY SCHEDULE',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showClearPastConfirm,
            icon: const Icon(
              Icons.cleaning_services_rounded,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Clear Past',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : () => _openScheduleSheet(),
        backgroundColor: yellow,
        foregroundColor: blue,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: blue, width: 3),
        ),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
      body: _isLoading && _entries.isEmpty
          ? const Center(child: CircularProgressIndicator(color: yellow))
          : _error != null
          ? _buildErrorState(blue, yellow)
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildWeekStrip(blue, surface, yellow),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      'CLASSES • ${_formatSelectedDate(_selectedDate)}',
                      yellow,
                    ),
                    const SizedBox(height: 16),
                    if (_entries.isEmpty)
                      _buildEmptyState(blue, surface)
                    else
                      ..._entries.asMap().entries.map(
                        (entry) => _buildClassCard(
                          entry.value,
                          entry.key,
                          blue,
                          surface,
                          yellow,
                        ),
                      ),
                    const SizedBox(height: 40),
                    _buildAlertsCard(blue, surface, yellow),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildWeekStrip(Color blue, Color surface, Color yellow) {
    final base = _selectedDate;
    final days = List.generate(
      7,
      (i) => base.add(Duration(days: i - base.weekday + 1)),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(
                      const Duration(days: 7),
                    );
                  });
                  _load(silent: true);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: blue,
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked == null) return;
                      setState(() {
                        _selectedDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                        );
                      });
                      _load(silent: true);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
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
                  _load(silent: true);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: blue,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((d) {
              final isSelected =
                  d.year == _selectedDate.year &&
                  d.month == _selectedDate.month &&
                  d.day == _selectedDate.day;
              return Column(
                children: [
                  Text(
                    _dayShort(d.weekday),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: blue.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      setState(
                        () => _selectedDate = DateTime(d.year, d.month, d.day),
                      );
                      _load(silent: true);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected ? yellow : Colors.transparent,
                        border: isSelected
                            ? Border.all(color: blue, width: 2)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${d.day}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: blue,
                        ),
                      ),
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
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildClassCard(
    Map<String, dynamic> item,
    int index,
    Color blue,
    Color surface,
    Color yellow,
  ) {
    final scheduled = DateTime.tryParse(
      (item['scheduled_at'] ?? '').toString(),
    );
    final start = scheduled != null
        ? '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}'
        : '--';
    final duration = (item['duration_minutes'] ?? 60) as num;
    final endTime = scheduled?.add(Duration(minutes: duration.toInt()));
    final end = endTime == null
        ? '--'
        : '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

    final batch = item['batch'] as Map?;
    final name =
        (batch?['name'] ?? item['name'] ?? item['batch_name'] ?? 'BATCH')
            .toString()
            .toUpperCase();
    final subject = (batch?['subject'] ?? item['subject'] ?? 'SUBJECT')
        .toString()
        .toUpperCase();

    return InkWell(
      onTap: _isSaving ? null : () => _openScheduleSheet(item: item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: blue, width: 3),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: yellow,
                border: Border.all(color: blue, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                start,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: blue,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        subject,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: blue.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$start - $end',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: blue.withValues(alpha: 0.5),
                        ),
                      ),
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
    final titleCtrl = TextEditingController(
      text: (item?['title'] ?? '').toString(),
    );
    final durationCtrl = TextEditingController(
      text: ((item?['duration_minutes'] ?? 60)).toString(),
    );
    String? selectedBatchId = (item?['batch_id'] ?? '').toString();
    if (selectedBatchId.isEmpty && _batches.isNotEmpty) {
      selectedBatchId = (_batches.first['id'] ?? '').toString();
    }
    final now = DateTime.now();
    // Round to next hour for cleaner default timing
    DateTime scheduledAt;
    if (item != null) {
      scheduledAt = DateTime.tryParse(item['scheduled_at']?.toString() ?? '') ?? now;
    } else {
      // Default to the next full hour (e.g., if it's 7:07 PM, default to 8:00 PM)
      scheduledAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        now.hour + 1,
        0,
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            const blue = Color(0xFF0D1282);
            const offWhite = Color(0xFFEEEDED);

            return Container(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                32 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: offWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(color: blue, width: 4),
                  left: BorderSide(color: blue, width: 4),
                  right: BorderSide(color: blue, width: 4),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 6,
                        decoration: BoxDecoration(
                          color: blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isEdit ? 'REFINE LECTURE' : 'NEW SESSION',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: blue,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _sheetLabel('LECTURE TOPIC'),
                    const SizedBox(height: 8),
                    _sheetTextField(
                      titleCtrl,
                      'e.g., Organic Chemistry Basics',
                      blue,
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sheetLabel('TARGET BATCH'),
                              const SizedBox(height: 8),
                              _sheetDropdown(
                                selectedBatchId,
                                (v) => setModal(() => selectedBatchId = v),
                                blue,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sheetLabel('DURATION (MIN)'),
                              const SizedBox(height: 8),
                              _sheetTextField(
                                durationCtrl,
                                '60',
                                blue,
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    _sheetLabel('SCHEDULED TIME'),
                    const SizedBox(height: 8),
                    CPPressable(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: scheduledAt,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: blue,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (date == null) return;
                        if (!ctx.mounted) return;
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(scheduledAt),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: blue,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (time == null) return;
                        setModal(() {
                          scheduledAt = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: blue, width: 2),
                          boxShadow: const [
                            BoxShadow(color: blue, offset: Offset(3, 3)),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: blue,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${scheduledAt.day.toString().padLeft(2, '0')}/${scheduledAt.month.toString().padLeft(2, '0')} @ ${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: blue,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.edit_rounded,
                              size: 16,
                              color: blue,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      children: [
                        if (isEdit) ...[
                          Expanded(
                            flex: 1,
                            child: CPPressable(
                              onTap: _isSaving
                                  ? null
                                  : () async {
                                      final confirm =
                                          await _showDeleteConfirm();
                                      if (confirm == true && ctx.mounted) {
                                        Navigator.pop(ctx);
                                        await _deleteSchedule(
                                          (item['id'] ?? '').toString(),
                                        );
                                      }
                                    },
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD71313),
                                  border: Border.all(color: blue, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: blue,
                                      offset: Offset(3, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 3,
                          child: CustomButton(
                            text: isEdit
                                ? 'UPDATE SESSION'
                                : 'CONFIRM SCHEDULE',
                            isLoading: _isSaving,
                            onPressed: () async {
                              final title = titleCtrl.text.trim();
                              final dur = int.tryParse(durationCtrl.text) ?? 60;
                              if (title.isEmpty || selectedBatchId == null) {
                                CPToast.warning(
                                  ctx,
                                  'Title and Batch required',
                                );
                                return;
                              }
                              if (isEdit) {
                                final success = await _updateSchedule(
                                  lectureId: (item['id'] ?? '').toString(),
                                  batchId: selectedBatchId!,
                                  title: title,
                                  scheduledAt: scheduledAt,
                                  durationMinutes: dur,
                                );
                                if (success && ctx.mounted) Navigator.pop(ctx);
                              } else {
                                final success = await _createSchedule(
                                  batchId: selectedBatchId!,
                                  title: title,
                                  scheduledAt: scheduledAt,
                                  durationMinutes: dur,
                                );
                                if (success && ctx.mounted) Navigator.pop(ctx);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    durationCtrl.dispose();
  }

  Future<void> _showClearPastConfirm() async {
    const blue = Color(0xFF0D1282);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFEEEDED),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: blue, width: 3),
        ),
        title: Text(
          'CLEAR PAST?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            color: blue,
          ),
        ),
        content: Text(
          'THIS WILL HIDE ALL COMPLETED LECTURES FROM YOUR LIST. CONTINUE?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: blue.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: blue,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'CLEAR',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: const Color(0xFFD71313),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _clearPast();
    }
  }

  Future<void> _clearPast() async {
    setState(() => _isSaving = true);
    try {
      await _repo.clearPastSchedules();
      if (mounted) {
        CPToast.success(context, 'Past schedules cleared');
        await _load(silent: true);
      }
    } catch (e) {
      if (mounted) CPToast.error(context, 'Failed to clear: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool?> _showDeleteConfirm() async {
    const blue = Color(0xFF0D1282);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFEEEDED),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: blue, width: 3),
        ),
        title: Text(
          'DELETE LECTURE?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            color: blue,
          ),
        ),
        content: Text(
          'THIS ACTION CANNOT BE UNDONE. REMOVE FROM SCHEDULE?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: blue.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: blue,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'DELETE',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: const Color(0xFFD71313),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetLabel(String text) => Text(
    text,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 10,
      fontWeight: FontWeight.w900,
      color: const Color(0xFF0D1282),
      letterSpacing: 0.5,
    ),
  );

  Widget _sheetTextField(
    TextEditingController ctrl,
    String hint,
    Color blue, {
    TextInputType? keyboardType,
  }) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: blue, width: 2),
      boxShadow: [BoxShadow(color: blue, offset: const Offset(3, 3))],
    ),
    child: TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: blue,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: blue.withValues(alpha: 0.3),
          fontWeight: FontWeight.w600,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    ),
  );

  Widget _sheetDropdown(
    String? value,
    ValueChanged<String?> onChanged,
    Color blue,
  ) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: blue, width: 2),
      boxShadow: [BoxShadow(color: blue, offset: const Offset(3, 3))],
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF0D1282),
        ),
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: blue,
        ),
        items: _batches
            .map(
              (b) => DropdownMenuItem<String>(
                value: (b['id'] ?? '').toString(),
                child: Text((b['name'] ?? 'Batch').toString().toUpperCase()),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );

  Future<bool> _createSchedule({
    required String batchId,
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    setState(() {
      _isSaving = true;
      _selectedDate = DateTime(
        scheduledAt.year,
        scheduledAt.month,
        scheduledAt.day,
      );
    });
    try {
      final created = await _repo.createMyScheduleEntry(
        batchId: batchId,
        title: title,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
      );
      if (!mounted) return true;

      // 1. Immediately update UI locally (Optimistic / Realtime backup)
      if (_matchesSelectedDate(created['scheduled_at'])) {
        final entry = _decorateEntryWithBatch(
          Map<String, dynamic>.from(created),
        );
        setState(() {
          // Check if already exists (might have come via silent load or socket)
          final exists = _entries.any(
            (e) => e['id']?.toString() == entry['id']?.toString(),
          );
          if (!exists) {
            _entries = [..._entries, entry];
            // Sort by time
            _entries.sort((a, b) {
              final da =
                  DateTime.tryParse((a['scheduled_at'] ?? '').toString()) ??
                  DateTime(2000);
              final db =
                  DateTime.tryParse((b['scheduled_at'] ?? '').toString()) ??
                  DateTime(2000);
              return da.compareTo(db);
            });
          }
        });
      }

      // 2. Trigger a silent reload to ensure all relations (like batch subject) are fully fetched
      await _load(silent: true, refreshBatches: false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Schedule created')));
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
      _selectedDate = DateTime(
        scheduledAt.year,
        scheduledAt.month,
        scheduledAt.day,
      );
    });
    try {
      final updated = await _repo.updateMyScheduleEntry(
        lectureId: lectureId,
        batchId: batchId,
        title: title,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
      );
      if (!mounted) return true;

      // Optimistically update local entry
      setState(() {
        final index = _entries.indexWhere(
          (e) => e['id']?.toString() == lectureId,
        );
        if (index != -1) {
          _entries[index] = _decorateEntryWithBatch(
            Map<String, dynamic>.from(updated),
          );
          // Resort in case time changed
          _entries.sort((a, b) {
            final da =
                DateTime.tryParse((a['scheduled_at'] ?? '').toString()) ??
                DateTime(2000);
            final db =
                DateTime.tryParse((b['scheduled_at'] ?? '').toString()) ??
                DateTime(2000);
            return da.compareTo(db);
          });
        }
      });

      await _load(silent: true, refreshBatches: false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Schedule updated')));
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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

      // Optimistically remove local entry
      setState(() {
        _entries.removeWhere((e) => e['id']?.toString() == lectureId);
      });

      await _load(silent: true, refreshBatches: false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Schedule deleted')));
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAlertsCard(Color blue, Color surface, Color yellow) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.white24, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_rounded, color: yellow, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'REMAINDERS: ALL CLASSES FOR TODAY ARE ON TRACK. NO SUBSTITUTIONS ASSIGNED.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color blue, Color surface) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.1),
        border: Border.all(
          color: Colors.white24,
          width: 2,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'NO CLASSES SCHEDULED FOR ${_formatSelectedDate(_selectedDate)}',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white54,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Color blue, Color yellow) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'FAILED TO LOAD SCHEDULE',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          _btn('RETRY', () => _load(silent: true), yellow, blue, blue),
        ],
      ),
    );
  }

  Widget _btn(
    String label,
    VoidCallback onTap,
    Color bg,
    Color fg,
    Color blue,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: blue, width: 2.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: blue, offset: const Offset(3, 3))],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: fg,
          ),
        ),
      ),
    );
  }

  String _dayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'MON';
      case DateTime.tuesday:
        return 'TUE';
      case DateTime.wednesday:
        return 'WED';
      case DateTime.thursday:
        return 'THU';
      case DateTime.friday:
        return 'FRI';
      case DateTime.saturday:
        return 'SAT';
      default:
        return 'SUN';
    }
  }
}
