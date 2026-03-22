import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../data/repositories/admin_repository.dart';

class BatchDetailPage extends StatefulWidget {
  final String batchId;
  const BatchDetailPage({super.key, required this.batchId});

  @override
  State<BatchDetailPage> createState() => _BatchDetailPageState();
}

class _BatchDetailPageState extends State<BatchDetailPage> {
  final _adminRepo = sl<AdminRepository>();

  Map<String, dynamic>? _batch;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _timetable = [];
  List<Map<String, dynamic>> _lectures = [];
  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _teachers = [];
  Map<String, dynamic>? _feeStructure;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBatch();
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

  String _dateLabel(dynamic value) {
    final parsed = _toDate(value);
    if (parsed == null) return '--';
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  String _timeLabel(dynamic value) {
    if (value == null) return '--';
    final text = value.toString();
    if (text.contains('T')) {
      final dt = DateTime.tryParse(text);
      if (dt != null) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }
    if (text.length >= 5) return text.substring(0, 5);
    return text;
  }

  Future<void> _loadBatch() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final batch = await _adminRepo.getBatchById(widget.batchId);

      final results = await Future.wait([
        _adminRepo.getBatchTimetable(widget.batchId).catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo.getLecturesByBatch(widget.batchId).catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo.getQuizzes(batchId: widget.batchId).catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo.getFeeStructure(widget.batchId).catchError((_) => <String, dynamic>{}),
        _adminRepo.getTeachers().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _batch = batch;
        _students = ((batch['students'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _timetable = List<Map<String, dynamic>>.from(results[0] as List);
        _lectures = List<Map<String, dynamic>>.from(results[1] as List);
        _quizzes = List<Map<String, dynamic>>.from(results[2] as List);
        _feeStructure = Map<String, dynamic>.from(results[3] as Map);
        _teachers = List<Map<String, dynamic>>.from(results[4] as List);
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

  bool get _isCompleted {
    final endDate = _toDate(_batch?['end_date']);
    if (endDate == null) return false;
    final today = DateTime.now();
    return endDate.isBefore(DateTime(today.year, today.month, today.day));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text(
          _batch?['name']?.toString() ?? 'Batch Detail',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          if (_batch != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'toggle') {
                  await _toggleBatchStatus();
                } else if (value == 'meta') {
                  await _showMetaEditor();
                } else if (value == 'migrate') {
                  await _showMigrateSheet();
                } else if (value == 'delete') {
                  await _deleteBatch();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'toggle', child: Text((_batch?['is_active'] ?? true) ? 'Suspend batch' : 'Resume batch')),
                const PopupMenuItem(value: 'meta', child: Text('Edit details')),
                const PopupMenuItem(value: 'migrate', child: Text('Promote / Migrate students')),
                const PopupMenuItem(value: 'delete', child: Text('Delete batch')),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadBatch,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeroCard(isDark)),
                      SliverToBoxAdapter(child: _buildStatsRow(isDark)),
                      SliverToBoxAdapter(child: _buildTeachersSection()),
                      SliverToBoxAdapter(child: _buildDescriptionSection()),
                      SliverToBoxAdapter(child: _buildFaqSection()),
                      SliverToBoxAdapter(child: _buildTimetableSection()),
                      SliverToBoxAdapter(child: _buildClassesSection()),
                      SliverToBoxAdapter(child: _buildQuizzesSection()),
                      _buildStudentsHeader(),
                      _buildStudentList(),
                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  ),
                ),
      floatingActionButton: (_batch != null && _isCompleted)
          ? FloatingActionButton.extended(
              onPressed: _showMigrateSheet,
              backgroundColor: const Color(0xFFF0DE36),
              foregroundColor: const Color(0xFF0D1282),
              icon: const Icon(Icons.trending_up_rounded),
              label: const Text('Promote Students'),
            )
          : null,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 52, color: Color(0xFFD71313)),
            const SizedBox(height: 12),
            Text(_error ?? 'Unable to load batch', style: GoogleFonts.inter(fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            CustomButton(text: 'Retry', onPressed: _loadBatch),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(bool isDark) {
    if (_batch == null) return const SizedBox.shrink();

    final coverUrl = (_batch!['cover_image_url'] ?? '').toString();
    final isActive = (_batch!['is_active'] ?? true) == true;
    final statusText = _isCompleted ? 'COMPLETED' : (isActive ? 'ACTIVE' : 'SUSPENDED');
    final statusColor = _isCompleted
        ? const Color(0xFFD71313)
        : (isActive ? const Color(0xFF0D1282) : Colors.grey.shade700);

    return Container(
      margin: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, 14, AppDimensions.pagePaddingH, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDED),
        border: Border.all(color: const Color(0xFF0D1282), width: 3),
        boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            width: double.infinity,
            child: coverUrl.isNotEmpty
                ? Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultCover(),
                  )
                : _defaultCover(),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (_batch!['name'] ?? '').toString(),
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: statusColor, width: 2),
                        boxShadow: [BoxShadow(color: statusColor, offset: const Offset(2, 2))],
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  (_batch!['subject'] ?? 'General').toString(),
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _metaPill(Icons.event_rounded, '${_dateLabel(_batch!['start_date'])} → ${_dateLabel(_batch!['end_date'])}'),
                    _metaPill(Icons.schedule_rounded, '${_timeLabel(_batch!['start_time'])} - ${_timeLabel(_batch!['end_time'])}'),
                    _metaPill(Icons.class_rounded, (_batch!['room'] ?? 'Room TBD').toString()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _defaultCover() {
    final initial = (_batch?['name']?.toString().isNotEmpty ?? false)
        ? _batch!['name'].toString().substring(0, 1).toUpperCase()
        : 'B';
    return Container(
      color: const Color(0xFF0D1282),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.inter(fontSize: 54, fontWeight: FontWeight.w900, color: const Color(0xFFEEEDED)),
      ),
    );
  }

  Widget _metaPill(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF0D1282)),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0D1282), fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildStatsRow(bool isDark) {
    final capacity = _toInt(_batch?['capacity']);
    final enrolled = _students.length;
    final fee = _toDouble(_feeStructure?['monthly_fee']);
    final fill = capacity > 0 ? ((enrolled / capacity) * 100).toStringAsFixed(0) : '--';

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, 0, AppDimensions.pagePaddingH, 10),
      child: Row(
        children: [
          Expanded(child: _statCard('Students', '$enrolled', Icons.groups_rounded, isDark)),
          const SizedBox(width: 8),
          Expanded(child: _statCard('Capacity', capacity > 0 ? '$capacity' : '--', Icons.event_seat_rounded, isDark)),
          const SizedBox(width: 8),
          Expanded(child: _statCard('Fill %', fill, Icons.bar_chart_rounded, isDark)),
          const SizedBox(width: 8),
          Expanded(child: _statCard('Fee', fee > 0 ? '₹${fee.toStringAsFixed(0)}' : '--', Icons.payments_rounded, isDark)),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0D1282), width: 1.4),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0D1282)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: CT.textH(context), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(title, style: GoogleFonts.inter(fontSize: 10, color: CT.textS(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, 0, AppDimensions.pagePaddingH, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0D1282), width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: const Color(0xFF0D1282)),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildTeachersSection() {
    final assigned = ((_batch?['assigned_teachers'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return _sectionCard(
      title: 'Assigned Teachers',
      child: assigned.isEmpty
          ? Text('No teachers assigned', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context)))
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: assigned
                  .map((teacher) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEEDED),
                          border: Border.all(color: const Color(0xFF0D1282), width: 1.5),
                        ),
                        child: Text((teacher['name'] ?? 'Teacher').toString(), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF0D1282))),
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildDescriptionSection() {
    final description = (_batch?['description'] ?? '').toString().trim();
    return _sectionCard(
      title: 'Description',
      child: Text(
        description.isEmpty ? 'No description added yet.' : description,
        style: GoogleFonts.inter(fontSize: 12, color: CT.textH(context), height: 1.35),
      ),
    );
  }

  Widget _buildFaqSection() {
    final faqs = ((_batch?['faqs'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return _sectionCard(
      title: 'FAQs',
      child: faqs.isEmpty
          ? Text('No FAQs added for this batch.', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context)))
          : Column(
              children: faqs
                  .asMap()
                  .entries
                  .map((entry) => Padding(
                        padding: EdgeInsets.only(bottom: entry.key == faqs.length - 1 ? 0 : 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Q. ${(entry.value['question'] ?? '').toString()}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
                            const SizedBox(height: 4),
                            Text('A. ${(entry.value['answer'] ?? '').toString()}', style: GoogleFonts.inter(fontSize: 12, color: CT.textH(context))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildTimetableSection() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _timetable) {
      final dt = _toDate(item['scheduled_at']);
      final key = dt == null
          ? 'Unscheduled'
          : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][(dt.weekday - 1).clamp(0, 6)];
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }

    return _sectionCard(
      title: 'Timetable',
      trailing: TextButton(onPressed: () => context.push('/admin/timetable'), child: const Text('Manage')),
      child: grouped.isEmpty
          ? Text('No timetable entries yet.', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: grouped.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF0D1282))),
                      const SizedBox(height: 4),
                      ...entry.value.map((slot) {
                        final time = _toDate(slot['scheduled_at']);
                        final hhmm = time == null
                            ? '--'
                            : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        final teacher = ((slot['teacher'] as Map?)?['name'] ?? 'Teacher').toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $hhmm  ${(slot['subject'] ?? 'Class').toString()}  •  $teacher', style: GoogleFonts.inter(fontSize: 12, color: CT.textH(context))),
                        );
                      }),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildClassesSection() {
    return _sectionCard(
      title: 'Classes / Schedule List',
      child: _lectures.isEmpty
          ? Text('No lecture schedule found.', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context)))
          : Column(
              children: _lectures.take(8).map((lecture) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_outline_rounded, size: 16, color: Color(0xFF0D1282)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (lecture['title'] ?? lecture['subject'] ?? 'Lecture').toString(),
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: CT.textH(context)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(_dateLabel(lecture['scheduled_at']), style: GoogleFonts.inter(fontSize: 11, color: CT.textS(context))),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildQuizzesSection() {
    return _sectionCard(
      title: 'Quizzes Assigned',
      child: _quizzes.isEmpty
          ? Text('No quizzes assigned yet.', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context)))
          : Column(
              children: _quizzes.take(8).map((quiz) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.quiz_outlined, color: Color(0xFF0D1282), size: 18),
                  title: Text((quiz['title'] ?? 'Quiz').toString(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                  subtitle: Text((quiz['subject'] ?? '').toString(), style: GoogleFonts.inter(fontSize: 11)),
                  trailing: Text(
                    (quiz['is_published'] == true) ? 'Published' : 'Draft',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: quiz['is_published'] == true ? const Color(0xFF0D1282) : const Color(0xFFD71313),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildStudentsHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, 4, AppDimensions.pagePaddingH, 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Enrolled Students (${_students.length})', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: const Color(0xFF0D1282))),
            TextButton.icon(
              onPressed: () => context.push('/admin/add-student'),
              icon: const Icon(Icons.person_add_alt_rounded, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    if (_students.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, 0, AppDimensions.pagePaddingH, 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CT.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0D1282), width: 1.5),
            ),
            child: Text('No students enrolled yet.', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context))),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final student = _students[index];
          final name = (student['name'] ?? 'Student').toString();
          final phone = (student['phone'] ?? '').toString();
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, 0, AppDimensions.pagePaddingH, 8),
            child: Container(
              decoration: BoxDecoration(
                color: CT.card(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0D1282), width: 1.4),
              ),
              child: ListTile(
                onTap: () => context.push('/admin/students/${student['id']}'),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEEEDED),
                  child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF0D1282))),
                ),
                title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: Text(phone, style: GoogleFonts.inter(fontSize: 11)),
              ),
            ),
          );
        },
        childCount: _students.length,
      ),
    );
  }

  Future<void> _toggleBatchStatus() async {
    final current = (_batch?['is_active'] ?? true) == true;
    try {
      await _adminRepo.toggleBatchStatus(batchId: widget.batchId, isActive: !current);
      if (!mounted) return;
      CPToast.success(context, !current ? 'Batch resumed' : 'Batch suspended');
      _loadBatch();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Failed: $e');
    }
  }

  Future<void> _deleteBatch() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete batch?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _adminRepo.deleteBatch(widget.batchId);
      if (!mounted) return;
      CPToast.success(context, 'Batch deleted');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Delete failed: $e');
    }
  }

  Future<void> _showMigrateSheet() async {
    final batches = await _adminRepo.getBatches();
    final candidates = batches.where((b) => (b['id'] ?? '').toString() != widget.batchId).toList();
    if (candidates.isEmpty) {
      if (!mounted) return;
      CPToast.warning(context, 'No target batch available');
      return;
    }

    String? targetId;
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFEEEDED),
              border: Border(top: BorderSide(color: Color(0xFF0D1282), width: 3), left: BorderSide(color: Color(0xFF0D1282), width: 3), right: BorderSide(color: Color(0xFF0D1282), width: 3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Migrate students', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF0D1282))),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: targetId,
                  decoration: const InputDecoration(labelText: 'Target batch'),
                  items: candidates
                      .map((batch) => DropdownMenuItem<String>(
                            value: (batch['id'] ?? '').toString(),
                            child: Text((batch['name'] ?? 'Batch').toString()),
                          ))
                      .toList(),
                  onChanged: (value) => setS(() => targetId = value),
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Migrate',
                  onPressed: () {
                    if (targetId == null || targetId!.isEmpty) {
                      CPToast.warning(ctx, 'Please select target batch');
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

    if (proceed != true || targetId == null || targetId!.isEmpty) return;

    try {
      final result = await _adminRepo.migrateBatchStudents(sourceBatchId: widget.batchId, targetBatchId: targetId!);
      if (!mounted) return;
      CPToast.success(context, 'Migrated ${result['migrated_count'] ?? 0} students');
      _loadBatch();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Migration failed: $e');
    }
  }

  Future<void> _showMetaEditor() async {
    if (_batch == null) return;

    final descCtrl = TextEditingController(text: (_batch!['description'] ?? '').toString());
    final coverCtrl = TextEditingController(text: (_batch!['cover_image_url'] ?? '').toString());
    final faqQuestionCtrl = TextEditingController();
    final faqAnswerCtrl = TextEditingController();

    final teacherIds = <String>{
      ...(((_batch!['teacher_ids'] as List?) ?? const []).map((e) => e.toString())),
    };

    final faqs = (( _batch!['faqs'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: Color(0xFFEEEDED),
              border: Border(top: BorderSide(color: Color(0xFF0D1282), width: 3), left: BorderSide(color: Color(0xFF0D1282), width: 3), right: BorderSide(color: Color(0xFF0D1282), width: 3)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Batch Details', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0D1282))),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description', filled: true, fillColor: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: coverCtrl,
                    decoration: const InputDecoration(labelText: 'Cover image URL', filled: true, fillColor: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text('Teachers', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _teachers.map((teacher) {
                      final id = (teacher['id'] ?? '').toString();
                      final selected = teacherIds.contains(id);
                      final name = (teacher['name'] ?? 'Teacher').toString();
                      return FilterChip(
                        label: Text(name),
                        selected: selected,
                        onSelected: (value) {
                          setS(() {
                            if (value) {
                              teacherIds.add(id);
                            } else {
                              teacherIds.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text('FAQs', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
                  const SizedBox(height: 8),
                  ...faqs.asMap().entries.map((entry) {
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Q: ${(item['question'] ?? '').toString()}\nA: ${(item['answer'] ?? '').toString()}',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setS(() => faqs.removeAt(entry.key)),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextField(
                    controller: faqQuestionCtrl,
                    decoration: const InputDecoration(labelText: 'FAQ question', filled: true, fillColor: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: faqAnswerCtrl,
                    decoration: const InputDecoration(labelText: 'FAQ answer', filled: true, fillColor: Colors.white),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      if (faqQuestionCtrl.text.trim().isEmpty || faqAnswerCtrl.text.trim().isEmpty) return;
                      setS(() {
                        faqs.add({
                          'question': faqQuestionCtrl.text.trim(),
                          'answer': faqAnswerCtrl.text.trim(),
                        });
                        faqQuestionCtrl.clear();
                        faqAnswerCtrl.clear();
                      });
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add FAQ'),
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: 'Save',
                    onPressed: () async {
                      try {
                        await _adminRepo.updateBatchMeta(
                          batchId: widget.batchId,
                          data: {
                            'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                            'cover_image_url': coverCtrl.text.trim().isEmpty ? null : coverCtrl.text.trim(),
                            'teacher_ids': teacherIds.toList(),
                            'faqs': faqs,
                          },
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        CPToast.success(context, 'Batch details updated');
                        _loadBatch();
                      } catch (e) {
                        if (ctx.mounted) CPToast.error(ctx, 'Update failed: $e');
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
}
