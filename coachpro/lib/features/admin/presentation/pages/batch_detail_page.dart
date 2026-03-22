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
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _feeRecords = [];
  List<Map<String, dynamic>> _attendanceSessions = [];

  Map<String, dynamic>? _feeStructure;

  bool _isLoading = true;
  String? _error;

  int _activeTab = 0;
  int _activeContentTab = 0;
  String _studentFilter = 'All';
  String _feeFilter = 'All';
  bool _fabExpanded = false;

  static const _tabs = ['Overview', 'Content', 'Students', 'Tests', 'Fees', 'Analytics'];
  static const _contentTabs = ['Lectures', 'Notes', 'Assignments', 'DPP', 'Materials'];

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
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
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
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final batch = await _adminRepo.getBatchById(widget.batchId);
      final now = DateTime.now();

      final results = await Future.wait([
        _adminRepo.getBatchTimetable(widget.batchId).catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo.getLecturesByBatch(widget.batchId).catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo.getQuizzes(batchId: widget.batchId).catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo.getFeeStructure(widget.batchId).catchError((_) => <String, dynamic>{}),
        _adminRepo.getTeachers().catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo.getAssignments(batchId: widget.batchId).catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo.getMaterials().catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo.getFeeRecords(batchId: widget.batchId).catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo
            .getBatchAttendanceMonthly(batchId: widget.batchId, month: now.month, year: now.year)
            .catchError((_) => <Map<String, dynamic>>[]),
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
        _assignments = List<Map<String, dynamic>>.from(results[5] as List);
        _materials = List<Map<String, dynamic>>.from(results[6] as List);
        _feeRecords = List<Map<String, dynamic>>.from(results[7] as List);
        _attendanceSessions = List<Map<String, dynamic>>.from(results[8] as List);
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

  Map<String, dynamic> _feeStats() {
    double total = 0;
    double paid = 0;
    double pending = 0;
    double collectedToday = 0;
    final today = DateTime.now();

    for (final record in _feeRecords) {
      final amount = _toDouble(record['final_amount'] ?? record['amount']);
      final payments = (record['payments'] as List?) ?? const [];
      final paidAmount = payments.fold<double>(0, (sum, item) {
        if (item is! Map) return sum;
        final p = _toDouble(item['amount_paid']);
        final date = _toDate(item['created_at'] ?? item['paid_at']);
        if (date != null && date.year == today.year && date.month == today.month && date.day == today.day) {
          collectedToday += p;
        }
        return sum + p;
      });

      total += amount;
      paid += paidAmount;
      pending += (amount - paidAmount).clamp(0, double.infinity);
    }

    return {
      'total': total,
      'paid': paid,
      'pending': pending,
      'collectedToday': collectedToday,
    };
  }

  Map<String, dynamic> _insights() {
    final fees = _feeStats();
    final lowAttendanceCount = _students.where((s) => _studentAttendance(s) < 70).length;
    final submittedAssignments = _assignments.fold<int>(0, (sum, item) {
      return sum + _toInt(item['submission_count'] ?? item['submissions_count'] ?? item['submitted_count']);
    });

    return {
      'lectures': _lectures.length,
      'notes': _materials.length,
      'tests': _quizzes.length,
      'assignmentsSubmitted': submittedAssignments,
      'feesPaid': fees['paid'],
      'feesPending': fees['pending'],
      'lowAttendance': lowAttendanceCount,
    };
  }

  double _studentAttendance(Map<String, dynamic> student) {
    final studentId = (student['id'] ?? '').toString();
    if (studentId.isEmpty || _attendanceSessions.isEmpty) {
      return _toDouble(student['attendance_percent'], fallback: 0);
    }

    int total = 0;
    int present = 0;

    for (final session in _attendanceSessions) {
      final records = (session['student_records'] as List?) ?? const [];
      for (final entry in records) {
        if (entry is! Map) continue;
        final id = (entry['student_id'] ?? '').toString();
        if (id != studentId) continue;
        total += 1;
        if ((entry['status'] ?? '').toString().toLowerCase() == 'present') present += 1;
      }
    }

    if (total == 0) return _toDouble(student['attendance_percent'], fallback: 0);
    return (present / total) * 100;
  }

  String _studentFeeStatus(String studentId) {
    final related = _feeRecords.where((r) => (r['student_id'] ?? '').toString() == studentId);
    if (related.isEmpty) return 'Pending';

    bool anyPending = false;
    for (final record in related) {
      final amount = _toDouble(record['final_amount'] ?? record['amount']);
      final payments = (record['payments'] as List?) ?? const [];
      final paid = payments.fold<double>(0, (sum, p) => sum + _toDouble((p as Map)['amount_paid']));
      if (paid + 0.01 < amount) {
        anyPending = true;
        break;
      }
    }
    return anyPending ? 'Pending' : 'Paid';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text(
          _batch?['name']?.toString() ?? 'Batch Control Panel',
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
                PopupMenuItem(value: 'toggle', child: Text((_batch?['is_active'] ?? true) ? 'Close batch' : 'Re-open batch')),
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
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroPanel(isDark),
                        _buildLiveInsights(),
                        _buildTabBar(isDark),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _buildTabBody(),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: _buildActionDock(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

  Widget _buildHeroPanel(bool isDark) {
    if (_batch == null) return const SizedBox.shrink();

    final isActive = (_batch!['is_active'] ?? true) == true;
    final fee = _feeStats();
    final totalStudents = _students.length;
    final activeStudents = _students.where((s) {
      final status = (s['status'] ?? s['is_active'])?.toString().toLowerCase();
      return status == null || status == 'active' || status == 'true';
    }).length;

    final statusLabel = _isCompleted ? 'Closed' : (isActive ? 'Active' : 'Paused');
    final statusColor = _isCompleted
        ? const Color(0xFFD71313)
        : (isActive ? const Color(0xFF0D1282) : Colors.black54);
    final pending = _toDouble(fee['pending']);
    final paid = _toDouble(fee['paid']);

    return Container(
      margin: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, 14, AppDimensions.pagePaddingH, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDED),
        border: Border.all(color: const Color(0xFF0D1282), width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(4, 4), blurRadius: 0)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (_batch!['name'] ?? 'Batch').toString(),
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0D1282),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(_batch!['subject'] ?? 'General').toString()} • ${(_batch!['target'] ?? _batch!['class_name'] ?? 'Target').toString()}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: statusColor, width: 2),
                  boxShadow: [BoxShadow(color: statusColor, offset: const Offset(2, 2))],
                ),
                child: Text(
                  statusLabel.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0DE36),
              border: Border.all(color: const Color(0xFF0D1282), width: 2),
              boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3), blurRadius: 0)],
            ),
            child: Row(
              children: [
                const Icon(Icons.currency_rupee_rounded, color: Color(0xFF0D1282), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${paid.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0D1282),
                          letterSpacing: -0.6,
                        ),
                      ),
                      Text('Total Revenue', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD71313), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${pending.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFD71313))),
                      Text('Pending', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFD71313))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _quickStatCard('Total Students', '$totalStudents', Icons.groups_rounded, const Color(0xFF0D1282), width: 154),
              _quickStatCard('Active Students', '$activeStudents', Icons.how_to_reg_rounded, const Color(0xFF0D1282), width: 154),
              _quickStatCard('Monthly Fee', '₹${_toDouble(_feeStructure?['monthly_fee']).toStringAsFixed(0)}', Icons.payments_rounded, const Color(0xFFF0DE36), width: 154),
              _quickStatCard('Duration', '${_dateLabel(_batch!['start_date'])} - ${_dateLabel(_batch!['end_date'])}', Icons.date_range_rounded, const Color(0xFF0D1282), width: 154),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _microTag('Lectures ${_lectures.length}', Icons.ondemand_video_rounded, const Color(0xFF0D1282)),
              _microTag('Notes ${_materials.length}', Icons.description_outlined, const Color(0xFF0D1282)),
              _microTag('Tests ${_quizzes.length}', Icons.quiz_outlined, const Color(0xFF0D1282)),
              _microTag('Low Attendance ${_students.where((s) => _studentAttendance(s) < 70).length}', Icons.warning_amber_rounded, const Color(0xFFD71313)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 360.ms);
  }

  Widget _quickStatCard(String title, String value, IconData icon, Color accent, {double width = 164}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF0D1282), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2), blurRadius: 0)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0D1282)),
          const SizedBox(height: 6),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(width: 8, height: 8, color: accent),
              const SizedBox(width: 6),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 10))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _microTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildLiveInsights() {
    final data = _insights();
    return Container(
      margin: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, 0, AppDimensions.pagePaddingH, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0D1282), width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Insights', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: const Color(0xFF0D1282))),
          Text('Realtime batch health and outcomes', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF0D1282).withValues(alpha: 0.72))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _insightTile('Lectures', '${data['lectures']}', Icons.ondemand_video_rounded, const Color(0xFF0D1282))),
                        const SizedBox(width: 8),
                        Expanded(child: _insightTile('Notes', '${data['notes']}', Icons.description_outlined, const Color(0xFF0D1282))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _insightTile('Tests', '${data['tests']}', Icons.quiz_outlined, const Color(0xFF0D1282))),
                        const SizedBox(width: 8),
                        Expanded(child: _insightTile('Submissions', '${data['assignmentsSubmitted']}', Icons.assignment_turned_in_outlined, const Color(0xFF0D1282))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _wideInsightTile('Fees Paid', '₹${_toDouble(data['feesPaid']).toStringAsFixed(0)}', Icons.payments_rounded, const Color(0xFFF0DE36), emphasized: true),
          const SizedBox(height: 8),
          _wideInsightTile('Fees Pending', '₹${_toDouble(data['feesPending']).toStringAsFixed(0)}', Icons.warning_rounded, const Color(0xFFD71313), emphasized: true),
          const SizedBox(height: 8),
          _wideInsightTile('Low Attendance', '${data['lowAttendance']} Students', Icons.error_outline_rounded, const Color(0xFFD71313)),
        ],
      ),
    );
  }

  Widget _insightTile(String label, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        border: Border.all(color: accent, width: 1.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(height: 8),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15, color: const Color(0xFF0D1282))),
          const SizedBox(height: 3),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
        ],
      ),
    );
  }

  Widget _wideInsightTile(String label, String value, IconData icon, Color accent, {bool emphasized = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: emphasized ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent, width: emphasized ? 1.8 : 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282)))),
          Text(value, style: GoogleFonts.inter(fontSize: emphasized ? 15 : 13, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282))),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final selected = _activeTab == index;
          return InkWell(
            onTap: () => setState(() => _activeTab = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF0D1282) : Colors.white,
                border: Border.all(color: const Color(0xFF0D1282), width: 1.4),
                borderRadius: BorderRadius.circular(10),
                boxShadow: selected ? const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2), blurRadius: 0)] : null,
              ),
              child: Center(
                child: Text(
                  _tabs[index],
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: selected ? const Color(0xFFEEEDED) : const Color(0xFF0D1282),
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: _tabs.length,
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_activeTab) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildContentTab();
      case 2:
        return _buildStudentsTab();
      case 3:
        return _buildTestsTab();
      case 4:
        return _buildFeesTab();
      case 5:
      default:
        return _buildAnalyticsTab();
    }
  }

  Widget _sectionCard({required String title, required Widget child, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, 12, AppDimensions.pagePaddingH, 0),
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
              if (trailing case final Widget item) item,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final assigned = ((_batch?['assigned_teachers'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final upcoming = [..._timetable]..sort((a, b) => (_toDate(a['scheduled_at']) ?? DateTime(0)).compareTo(_toDate(b['scheduled_at']) ?? DateTime(0)));
    final nextSlot = upcoming.isEmpty ? null : upcoming.first;

    final timelineItems = <Map<String, String>>[];
    timelineItems.addAll(_lectures.take(2).map((e) => {
          'title': 'Lecture uploaded',
          'subtitle': (e['title'] ?? 'Lecture').toString(),
          'time': _dateLabel(e['created_at'] ?? e['scheduled_at']),
        }));
    timelineItems.addAll(_quizzes.take(2).map((e) => {
          'title': 'Test created',
          'subtitle': (e['title'] ?? 'Test').toString(),
          'time': _dateLabel(e['created_at'] ?? e['scheduled_at']),
        }));
    timelineItems.addAll(_feeRecords.take(2).map((e) => {
          'title': 'Fee collected',
          'subtitle': ((e['student'] as Map?)?['name'] ?? 'Student').toString(),
          'time': _dateLabel(e['updated_at'] ?? e['created_at']),
        }));

    return Column(
      key: const ValueKey('overview-tab'),
      children: [
        _sectionCard(
          title: 'Batch Snapshot',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ((_batch?['description'] ?? '').toString().trim().isEmpty)
                    ? 'No description added yet.'
                    : (_batch?['description'] ?? '').toString(),
                style: GoogleFonts.inter(fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(Icons.calendar_month_rounded, '${_dateLabel(_batch?['start_date'])} → ${_dateLabel(_batch?['end_date'])}'),
                  _pill(Icons.class_rounded, (_batch?['subject'] ?? 'General').toString()),
                  _pill(Icons.location_on_rounded, (_batch?['room'] ?? 'Room TBD').toString()),
                  if (nextSlot != null)
                    _pill(
                      Icons.schedule_rounded,
                      'Next class ${_dateLabel(nextSlot['scheduled_at'])} ${_timeLabel(nextSlot['scheduled_at'])}',
                    ),
                ],
              ),
            ],
          ),
        ),
        _sectionCard(
          title: 'Faculty Assigned',
          child: assigned.isEmpty
              ? Text('No faculty mapped yet', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context)))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: assigned
                      .map((teacher) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEEDED),
                              border: Border.all(color: const Color(0xFF0D1282), width: 1.2),
                            ),
                            child: Text(
                              (teacher['name'] ?? 'Teacher').toString(),
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF0D1282)),
                            ),
                          ))
                      .toList(),
                ),
        ),
        _sectionCard(
          title: 'Activity Timeline',
          child: timelineItems.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF0D1282), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(color: Color(0xFFF0DE36), shape: BoxShape.circle),
                        child: const Icon(Icons.timeline_rounded, size: 16, color: Color(0xFF0D1282)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Batch created • waiting for first activity', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11)),
                            Text('Add your first lecture or test to start timeline tracking', style: GoogleFonts.inter(fontSize: 10, color: Colors.black54)),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _fabExpanded = true),
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: timelineItems
                      .map((entry) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFF0D1282), width: 1),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4), color: const Color(0xFFF0DE36)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(entry['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12)),
                                      Text(entry['subtitle'] ?? '', style: GoogleFonts.inter(fontSize: 11, color: Colors.black87)),
                                    ],
                                  ),
                                ),
                                Text(entry['time'] ?? '--', style: GoogleFonts.inter(fontSize: 10, color: Colors.black54)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildContentTab() {
    return Column(
      key: const ValueKey('content-tab'),
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
            scrollDirection: Axis.horizontal,
            itemCount: _contentTabs.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final selected = _activeContentTab == index;
              return InkWell(
                onTap: () => setState(() => _activeContentTab = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFF0DE36) : Colors.white,
                    border: Border.all(color: const Color(0xFF0D1282), width: 1.2),
                  ),
                  child: Text(
                    _contentTabs[index],
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282)),
                  ),
                ),
              );
            },
          ),
        ),
        if (_activeContentTab == 0) _buildLecturesBlock(),
        if (_activeContentTab == 1) _buildNotesBlock(),
        if (_activeContentTab == 2 || _activeContentTab == 3) _buildAssignmentsBlock(isDpp: _activeContentTab == 3),
        if (_activeContentTab == 4) _buildMaterialsBlock(),
      ],
    );
  }

  Widget _buildLecturesBlock() {
    return _sectionCard(
      title: 'Lectures',
      trailing: TextButton.icon(
        onPressed: () => context.push('/admin/timetable'),
        icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
        label: const Text('Add Lecture'),
      ),
      child: _lectures.isEmpty
          ? Text('No lectures uploaded yet', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context)))
          : Column(
              children: _lectures.take(12).map((lecture) {
                final status = (lecture['status'] ?? lecture['is_live'] == true ? 'Live' : 'Recorded').toString();
                final completion = _toDouble(lecture['completion_percent']);
                final views = _toInt(lecture['views_count'] ?? lecture['view_count']);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF0D1282), width: 1)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text((lecture['title'] ?? 'Lecture').toString(), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                          _statusTag(status, status.toLowerCase() == 'live' ? const Color(0xFFF0DE36) : const Color(0xFF0D1282)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_dateLabel(lecture['scheduled_at'])} ${_timeLabel(lecture['scheduled_at'])} • ${_toInt(lecture['duration_minutes'])} min',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Views: $views', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          Text('Completion: ${completion.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          IconButton(onPressed: () => context.push('/admin/timetable'), icon: const Icon(Icons.edit_outlined, size: 18)),
                          IconButton(onPressed: () => CPToast.info(context, 'Delete from timetable manager'), icon: const Icon(Icons.delete_outline_rounded, size: 18)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildNotesBlock() {
    return _sectionCard(
      title: 'Notes',
      child: _materials.isEmpty
          ? Text('No notes uploaded yet', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context)))
          : Column(
              children: _materials.take(12).map((note) {
                final downloads = _toInt(note['downloads_count'] ?? note['download_count']);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined, color: Color(0xFF0D1282)),
                  title: Text((note['title'] ?? note['file_name'] ?? 'Note').toString(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${(note['subject'] ?? 'General').toString()} • ${_dateLabel(note['created_at'])}',
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$downloads downloads', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
                      const SizedBox(height: 4),
                      InkWell(onTap: () => CPToast.info(context, 'Use material upload flow to replace file'), child: Text('Replace', style: GoogleFonts.inter(fontSize: 10, decoration: TextDecoration.underline))),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildAssignmentsBlock({required bool isDpp}) {
    final title = isDpp ? 'DPP' : 'Assignments';
    final list = _assignments.where((item) {
      final type = (item['type'] ?? '').toString().toLowerCase();
      if (isDpp) return type == 'dpp' || type.contains('practice');
      return type.isEmpty || type == 'assignment';
    }).toList();

    return _sectionCard(
      title: title,
      child: list.isEmpty
          ? Text('No $title found', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context)))
          : Column(
              children: list.take(12).map((item) {
                final submissions = _toInt(item['submission_count'] ?? item['submissions_count'] ?? item['submitted_count']);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF0D1282), width: 1)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((item['title'] ?? title).toString(), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Due: ${_dateLabel(item['due_date'])} • Submissions: $submissions', style: GoogleFonts.inter(fontSize: 11, color: Colors.black54)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(onPressed: () => CPToast.info(context, 'Submission viewer will open here'), child: const Text('View Submissions')),
                          OutlinedButton(onPressed: () => CPToast.info(context, 'Grading console will open here'), child: const Text('Grade')),
                          OutlinedButton(onPressed: () => context.push('/admin/whatsapp-broadcast'), child: const Text('Send Reminder')),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildMaterialsBlock() {
    return _sectionCard(
      title: 'Materials Library',
      child: _materials.isEmpty
          ? Text('No materials available', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context)))
          : Column(
              children: _materials.take(10).map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF0D1282), width: 1)),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open_rounded, color: Color(0xFF0D1282)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text((item['title'] ?? item['file_name'] ?? 'Material').toString(), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                      Text((item['type'] ?? 'File').toString(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildStudentsTab() {
    final filtered = _students.where((student) {
      if (_studentFilter == 'All') return true;
      if (_studentFilter == 'Low attendance') return _studentAttendance(student) < 70;

      final status = (student['status'] ?? student['is_active'])?.toString().toLowerCase();
      final active = status == null || status == 'active' || status == 'true';

      if (_studentFilter == 'Active') return active;
      if (_studentFilter == 'Inactive') return !active;
      if (_studentFilter == 'Paid') return _studentFeeStatus((student['id'] ?? '').toString()) == 'Paid';
      if (_studentFilter == 'Unpaid') return _studentFeeStatus((student['id'] ?? '').toString()) == 'Pending';
      return true;
    }).toList();

    return Column(
      key: const ValueKey('students-tab'),
      children: [
        _sectionCard(
          title: 'Students',
          trailing: TextButton.icon(
            onPressed: () => context.push('/admin/add-student'),
            icon: const Icon(Icons.person_add_alt_rounded, size: 16),
            label: const Text('Add Student'),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['All', 'Paid', 'Unpaid', 'Active', 'Inactive', 'Low attendance']
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(f),
                              selected: _studentFilter == f,
                              onSelected: (_) => setState(() => _studentFilter = f),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                Text('No students match this filter', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context)))
              else
                ...filtered.map((student) {
                  final attendance = _studentAttendance(student);
                  final feeStatus = _studentFeeStatus((student['id'] ?? '').toString());
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF0D1282), width: 1)),
                    child: ListTile(
                      onTap: () {
                        context.push('/admin/students/${student['id']}').then((_) {
                          if (!mounted) return;
                          _loadBatch();
                        });
                      },
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEEEDED),
                        child: Text(
                          ((student['name'] ?? 'S').toString()).substring(0, 1).toUpperCase(),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF0D1282)),
                        ),
                      ),
                      title: Text((student['name'] ?? 'Student').toString(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        'Batch: ${(_batch?['name'] ?? 'Batch')} • Attendance ${attendance.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _statusTag(feeStatus, feeStatus == 'Paid' ? const Color(0xFFF0DE36) : const Color(0xFFD71313)),
                          const SizedBox(height: 4),
                          Text(attendance < 70 ? 'Low' : 'Good', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestsTab() {
    return Column(
      key: const ValueKey('tests-tab'),
      children: [
        _sectionCard(
          title: 'Tests',
          trailing: TextButton.icon(
            onPressed: () => context.push('/admin/exams'),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Test'),
          ),
          child: _quizzes.isEmpty
              ? Text('No tests available', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context)))
              : Column(
                  children: _quizzes.take(12).map((quiz) {
                    final attempts = _toInt(quiz['attempt_count'] ?? quiz['attempts']);
                    final questions = _toInt(quiz['question_count'] ?? quiz['questions']);
                    final marks = _toDouble(quiz['total_marks'] ?? quiz['marks']);
                    final avg = _toDouble(quiz['average_score']);
                    final failure = _toDouble(quiz['failure_percent'] ?? quiz['failure_rate']);
                    final topper = (quiz['topper_name'] ?? 'N/A').toString();

                    String status = 'Upcoming';
                    if ((quiz['is_published'] ?? false) == true) status = 'Live';
                    if ((quiz['status'] ?? '').toString().toLowerCase() == 'completed') status = 'Completed';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF0D1282), width: 1)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text((quiz['title'] ?? 'Test').toString(), style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12))),
                              _statusTag(status, status == 'Completed' ? const Color(0xFF0D1282) : const Color(0xFFF0DE36)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Questions: $questions • Marks: ${marks.toStringAsFixed(0)} • Attempts: $attempts', style: GoogleFonts.inter(fontSize: 11, color: Colors.black54)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              Text('Avg: ${avg > 0 ? avg.toStringAsFixed(1) : '--'}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                              Text('Topper: $topper', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                              Text('Failure: ${failure > 0 ? '${failure.toStringAsFixed(0)}%' : '--'}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFD71313))),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildFeesTab() {
    final fee = _feeStats();
    final rows = _feeRecords.where((record) {
      if (_feeFilter == 'All') return true;
      final status = _recordStatus(record);
      if (_feeFilter == 'Paid') return status == 'Paid';
      if (_feeFilter == 'Pending') return status == 'Pending';
      return true;
    }).toList();

    return Column(
      key: const ValueKey('fees-tab'),
      children: [
        _sectionCard(
          title: 'Fee Summary',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _feeMetric('Total Revenue', '₹${_toDouble(fee['total']).toStringAsFixed(0)}', const Color(0xFF0D1282)),
              _feeMetric('Pending Fees', '₹${_toDouble(fee['pending']).toStringAsFixed(0)}', const Color(0xFFD71313)),
              _feeMetric('Collected Today', '₹${_toDouble(fee['collectedToday']).toStringAsFixed(0)}', const Color(0xFFF0DE36)),
              _feeMetric('Monthly Fee', '₹${_toDouble(_feeStructure?['monthly_fee']).toStringAsFixed(0)}', const Color(0xFF0D1282)),
            ],
          ),
        ),
        _sectionCard(
          title: 'Student Fee Table',
          trailing: OutlinedButton(
            onPressed: () => context.push('/admin/whatsapp-broadcast'),
            child: const Text('Send WhatsApp Reminder'),
          ),
          child: Column(
            children: [
              Row(
                children: ['All', 'Paid', 'Pending']
                    .map((label) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _feeFilter == label,
                            onSelected: (_) => setState(() => _feeFilter = label),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                Text('No fee records for selected filter', style: GoogleFonts.inter(fontSize: 12, color: CT.textS(context)))
              else
                ...rows.take(20).map((record) {
                  final status = _recordStatus(record);
                  final amount = _toDouble(record['final_amount'] ?? record['amount']);
                  final paidAmount = _recordPaidAmount(record);
                  final studentName = ((record['student'] as Map?)?['name'] ?? record['student_name'] ?? 'Student').toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF0D1282), width: 1)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(studentName, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12))),
                            _statusTag(status, status == 'Paid' ? const Color(0xFFF0DE36) : const Color(0xFFD71313)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Paid ₹${paidAmount.toStringAsFixed(0)} / ₹${amount.toStringAsFixed(0)} • Due ${_dateLabel(record['due_date'])}', style: GoogleFonts.inter(fontSize: 11, color: Colors.black54)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: status == 'Paid'
                                  ? null
                                  : () => _markAsPaid(record),
                              child: const Text('Mark paid'),
                            ),
                            OutlinedButton(
                              onPressed: () => context.push('/admin/whatsapp-broadcast'),
                              child: const Text('Send reminder'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _feeMetric(String label, String value, Color accent) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: accent, width: 1.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF0D1282))),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final attendanceTrend = _attendanceTrend();
    final revenueTrend = _revenueTrend();
    final performanceTrend = _performanceTrend();

    return Column(
      key: const ValueKey('analytics-tab'),
      children: [
        _sectionCard(title: 'Attendance Graph', child: _miniBarGraph(attendanceTrend, const Color(0xFF0D1282))),
        _sectionCard(title: 'Performance Graph', child: _miniBarGraph(performanceTrend, const Color(0xFFF0DE36))),
        _sectionCard(title: 'Revenue Graph', child: _miniBarGraph(revenueTrend, const Color(0xFFD71313))),
      ],
    );
  }

  List<double> _attendanceTrend() {
    if (_attendanceSessions.isEmpty) return [0, 0, 0, 0, 0, 0];
    final sorted = [..._attendanceSessions]..sort((a, b) => (_toDate(a['date']) ?? DateTime(0)).compareTo(_toDate(b['date']) ?? DateTime(0)));
    final recent = sorted.take(6).toList();

    return recent.map((session) {
      final records = (session['student_records'] as List?) ?? const [];
      if (records.isEmpty) return 0.0;
      final present = records.where((e) => (e as Map)['status']?.toString().toLowerCase() == 'present').length;
      return (present / records.length) * 100;
    }).toList();
  }

  List<double> _performanceTrend() {
    if (_quizzes.isEmpty) return [0, 0, 0, 0, 0, 0];
    final recent = _quizzes.take(6).toList();
    return recent.map((q) => _toDouble(q['average_score'])).toList();
  }

  List<double> _revenueTrend() {
    if (_feeRecords.isEmpty) return [0, 0, 0, 0, 0, 0];
    final monthMap = <int, double>{};
    for (final record in _feeRecords) {
      final payments = (record['payments'] as List?) ?? const [];
      for (final item in payments) {
        if (item is! Map) continue;
        final dt = _toDate(item['created_at'] ?? item['paid_at']);
        if (dt == null) continue;
        monthMap[dt.month] = (monthMap[dt.month] ?? 0) + _toDouble(item['amount_paid']);
      }
    }

    final now = DateTime.now();
    final result = <double>[];
    for (var i = 5; i >= 0; i--) {
      final m = now.month - i;
      final month = m > 0 ? m : m + 12;
      result.add(monthMap[month] ?? 0);
    }
    return result;
  }

  Widget _miniBarGraph(List<double> values, Color color) {
    final fixed = values.isEmpty ? [0.0] : values;
    final maxValue = fixed.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: fixed.map((value) {
        final height = maxValue <= 0 ? 6.0 : ((value / maxValue) * 70).clamp(6, 70).toDouble();
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(value.toStringAsFixed(0), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(height: height, color: color),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionDock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: !_fabExpanded
              ? const SizedBox.shrink()
              : Container(
                  key: const ValueKey('fab-menu'),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEDED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0D1282), width: 1.6),
                    boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3), blurRadius: 0)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _fabMenuItem('Lecture', Icons.ondemand_video_rounded, () => context.push('/admin/timetable')),
                      _fabMenuItem('Test', Icons.quiz_rounded, () => context.push('/admin/exams')),
                      _fabMenuItem('Student', Icons.person_add_alt_rounded, () => context.push('/admin/add-student')),
                      _fabMenuItem('Fee', Icons.payments_rounded, () => context.push('/admin/fees')),
                    ],
                  ),
                ),
        ),
        FloatingActionButton.extended(
          heroTag: '${widget.batchId}_fab_menu',
          onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
          backgroundColor: const Color(0xFF0D1282),
          foregroundColor: const Color(0xFFEEEDED),
          icon: Icon(_fabExpanded ? Icons.close_rounded : Icons.add_rounded, size: 18),
          label: Text(_fabExpanded ? 'Close' : 'Add', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _fabMenuItem(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() => _fabExpanded = false);
          onTap();
        },
        icon: Icon(icon, size: 16),
        label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF0D1282), width: 1.2),
          foregroundColor: const Color(0xFF0D1282),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF0D1282), width: 1.2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0D1282)),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
        ],
      ),
    );
  }

  Widget _statusTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: color, width: 1.2)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
    );
  }

  String _recordStatus(Map<String, dynamic> record) {
    final amount = _toDouble(record['final_amount'] ?? record['amount']);
    final paid = _recordPaidAmount(record);
    return paid + 0.01 >= amount ? 'Paid' : 'Pending';
  }

  double _recordPaidAmount(Map<String, dynamic> record) {
    final payments = (record['payments'] as List?) ?? const [];
    return payments.fold<double>(0, (sum, p) => sum + _toDouble((p as Map)['amount_paid']));
  }

  Future<void> _markAsPaid(Map<String, dynamic> record) async {
    final feeRecordId = (record['id'] ?? '').toString();
    if (feeRecordId.isEmpty) {
      CPToast.error(context, 'Invalid fee record');
      return;
    }

    final amount = _toDouble(record['final_amount'] ?? record['amount']);
    final paid = _recordPaidAmount(record);
    final remaining = (amount - paid).clamp(0, double.infinity);
    if (remaining <= 0) {
      CPToast.info(context, 'Already fully paid');
      return;
    }

    try {
      await _adminRepo.recordFeePayment(
        feeRecordId: feeRecordId,
        amountPaid: remaining,
        paymentMode: 'Cash',
        note: 'Marked paid from batch control panel',
      );
      if (!mounted) return;
      CPToast.success(context, 'Fee marked paid');
      _loadBatch();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Payment failed: $e');
    }
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
    if (!mounted) return;
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
              border: Border(
                top: BorderSide(color: Color(0xFF0D1282), width: 3),
                left: BorderSide(color: Color(0xFF0D1282), width: 3),
                right: BorderSide(color: Color(0xFF0D1282), width: 3),
              ),
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

    final faqs = ((_batch!['faqs'] as List?) ?? const [])
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
              border: Border(
                top: BorderSide(color: Color(0xFF0D1282), width: 3),
                left: BorderSide(color: Color(0xFF0D1282), width: 3),
                right: BorderSide(color: Color(0xFF0D1282), width: 3),
              ),
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
                        faqs.add({'question': faqQuestionCtrl.text.trim(), 'answer': faqAnswerCtrl.text.trim()});
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


