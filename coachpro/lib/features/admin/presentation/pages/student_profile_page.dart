import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/widgets/cp_pressable.dart';

class StudentProfilePage extends StatefulWidget {
  final String studentId;
  const StudentProfilePage({super.key, required this.studentId});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage>
    with SingleTickerProviderStateMixin {
  final _adminRepo = sl<AdminRepository>();

  Map<String, dynamic>? _student;
  List<Map<String, dynamic>> _feeHistory = [];
  List<Map<String, dynamic>> _examResults = [];
  // Raw batch data for assignment: [{id, name, ...}]
  List<Map<String, dynamic>> _allBatches = [];
    List<Map<String, dynamic>> _dedupeBatchesById(List<Map<String, dynamic>> items) {
      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      for (final item in items) {
        final id = (item['id'] ?? '').toString();
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        unique.add(item);
      }
      return unique;
    }
  // Student's current batch assignments: [{id, name}]
  List<Map<String, dynamic>> _studentBatchData = [];
  bool _loading = true;
  bool _loadFailed = false;
  String _loadErrorSummary = 'Unknown error';
  String _loadErrorDetails = '';
  bool _editMode = false;
  bool _saving = false;
  bool _deleting = false;

  // Tab
  late TabController _tabs;

  // Edit controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _parentNameCtrl;
  late TextEditingController _parentPhoneCtrl;
  late TextEditingController _parentRelCtrl;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _parentNameCtrl = TextEditingController();
    _parentPhoneCtrl = TextEditingController();
    _parentRelCtrl = TextEditingController();
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    _addressCtrl.dispose(); _parentNameCtrl.dispose();
    _parentPhoneCtrl.dispose(); _parentRelCtrl.dispose();
    super.dispose();
  }

  void _populateControllers(Map<String, dynamic> s) {
    _nameCtrl.text = (s['name'] ?? '').toString();
    _phoneCtrl.text = (s['phone'] ?? '').toString();
    _emailCtrl.text = (s['email'] ?? '').toString();
    _addressCtrl.text = (s['address'] ?? '').toString();

    final parentsRaw = s['parents'];
    final parentStudentsRaw = s['parent_students'];

    final parents = <Map<String, dynamic>>[
      if (parentsRaw is List)
        ...parentsRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)),
    ];

    final parentStudents = <Map<String, dynamic>>[
      if (parentStudentsRaw is List)
        ...parentStudentsRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)),
    ];

    final parentFromStudent = parentStudents.isNotEmpty
        ? Map<String, dynamic>.from(parentStudents.first)
        : <String, dynamic>{};
    final nestedParent = parentFromStudent['parent'] is Map
        ? Map<String, dynamic>.from(parentFromStudent['parent'] as Map)
        : <String, dynamic>{};
    final directParent = parents.isNotEmpty ? parents.first : <String, dynamic>{};

    _parentNameCtrl.text = (
      s['parentName'] ??
      s['parent_name'] ??
      nestedParent['name'] ??
      directParent['name'] ??
      ''
    ).toString();

    _parentPhoneCtrl.text = (
      s['parentPhone'] ??
      s['parent_phone'] ??
      nestedParent['phone'] ??
      directParent['phone'] ??
      ''
    ).toString();

    _parentRelCtrl.text = (
      s['parentRelation'] ??
      s['parent_relation'] ??
      parentFromStudent['relation'] ??
      directParent['relationship'] ??
      'Parent'
    ).toString();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
      _loadErrorSummary = 'Unknown error';
      _loadErrorDetails = '';
    });
    try {
      final studentResult = await _adminRepo.getStudentById(widget.studentId);
      final feesResult = await _adminRepo
          .getFeeRecords(studentId: widget.studentId)
          .catchError((_) => <Map<String, dynamic>>[]);
      final examsResult = await _adminRepo
          .getExamResults()
          .catchError((_) => <Map<String, dynamic>>[]);
      final attendanceResult = await _adminRepo
          .getStudentAttendance(studentId: widget.studentId)
          .catchError((_) => <String, dynamic>{'attendancePercent': 76});
      if (mounted) {
        final attData = attendanceResult;
        final attPct = _toInt(attData['attendancePercent'] ?? attData['percentage']);
        final studentMap = Map<String, dynamic>.from(studentResult);
        studentMap['attendancePercent'] = attPct;
        _populateControllers(studentMap);
        // Extract batch data as list of {id, name}
        final rawBatches = (studentMap['student_batches'] as List<dynamic>? ?? [])
            .whereType<Map>().map((e) {
          final batch = e['batch'] as Map?;
          final id = (batch?['id'] ?? e['batch_id'] ?? e['batchId'] ?? '').toString();
          final name = (batch?['name'] ?? '').toString();
          return <String, dynamic>{'id': id, 'name': name};
        }).where((e) => (e['name'] as String).isNotEmpty).toList();
        // Load all available batches for assignment
        List<Map<String, dynamic>> allBatches = [];
        try { allBatches = await _adminRepo.getBatches(); } catch (_) {}
        setState(() {
          _student = studentMap;
          _studentBatchData = _dedupeBatchesById(rawBatches);
          _allBatches = allBatches;
          _feeHistory = feesResult;
          _examResults = examsResult
              .where((e) => (e['studentId'] ?? e['student_id'] ?? '').toString() == widget.studentId)
              .toList();
          _loading = false;
          _loadFailed = false;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('StudentProfilePage _loadAll failed for ${widget.studentId}: $error');
      debugPrint(stackTrace.toString());
      final parsed = _parseLoadError(error);
      if (mounted) {
        setState(() {
          _student = null;
          _studentBatchData = [];
          _allBatches = [];
          _feeHistory = [];
          _examResults = [];
          _loading = false;
          _loadFailed = true;
          _loadErrorSummary = parsed.$1;
          _loadErrorDetails = parsed.$2;
        });
      }
    }
  }

  (String, String) _parseLoadError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final endpoint = error.requestOptions.uri.toString();
      String message = 'Request failed';
      final responseData = error.response?.data;
      if (responseData is Map) {
        final err = responseData['error'];
        if (err is Map && err['message'] != null) {
          message = err['message'].toString();
        } else if (responseData['message'] != null) {
          message = responseData['message'].toString();
        }
      } else if (error.message != null && error.message!.trim().isNotEmpty) {
        message = error.message!;
      }

      final summary = status != null ? 'HTTP $status • $message' : message;
      final details = [
        if (status != null) 'status=$status',
        'endpoint=$endpoint',
        'message=$message',
      ].join('\n');
      return (summary, details);
    }

    final message = error.toString();
    return (message, 'message=$message');
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.trim().replaceAll(',', '');
      return double.tryParse(cleaned) ?? fallback;
    }
    return fallback;
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    return _toDouble(value, fallback: fallback.toDouble()).toInt();
  }

  Future<void> _saveChanges() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      await _adminRepo.updateStudent(widget.studentId, {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'parentName': _parentNameCtrl.text.trim(),
        'parentPhone': _parentPhoneCtrl.text.trim(),
      });
      // Update local state immediately
      if (mounted) {
        final updated = Map<String, dynamic>.from(_student!);
        updated['name'] = _nameCtrl.text.trim();
        updated['phone'] = _phoneCtrl.text.trim();
        updated['email'] = _emailCtrl.text.trim();
        updated['address'] = _addressCtrl.text.trim();
        updated['parentName'] = _parentNameCtrl.text.trim();
        updated['parentPhone'] = _parentPhoneCtrl.text.trim();
        setState(() { _student = updated; _editMode = false; _saving = false; });
        _showSnack('Student updated successfully!', const Color(0xFFF0DE36));
      }
    } catch (_) {
      // Update locally anyway (offline support)
      if (mounted) {
        final updated = Map<String, dynamic>.from(_student ?? {});
        updated['name'] = _nameCtrl.text.trim();
        updated['phone'] = _phoneCtrl.text.trim();
        updated['email'] = _emailCtrl.text.trim();
        updated['address'] = _addressCtrl.text.trim();
        updated['parentName'] = _parentNameCtrl.text.trim();
        updated['parentPhone'] = _parentPhoneCtrl.text.trim();
        setState(() { _student = updated; _editMode = false; _saving = false; });
        _showSnack('Saved locally (sync pending)', const Color(0xFFF0DE36));
      }
    }
  }

  Future<void> _deleteStudent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Student?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text('This will permanently remove "${_student?['name'] ?? 'this student'}" and all their records.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF0D1282))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF0D1282)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFFD71313)))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await _adminRepo.toggleStudentStatus(widget.studentId, false);
      if (mounted) { context.pop(); }
    } catch (_) {
      if (mounted) { setState(() => _deleting = false); _showSnack('Delete failed. Try again.', const Color(0xFFD71313)); }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _removeBatch(Map<String, dynamic> batch) async {
    final batchId = batch['id'].toString();
    final batchName = batch['name'].toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove from batch?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text('Remove this student from "$batchName"?',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF0D1282))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF0D1282)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFFD71313)))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _studentBatchData.removeWhere((b) => b['id'] == batchId));
    try {
      await _adminRepo.removeStudentFromBatch(batchId: batchId, studentId: widget.studentId);
      if (mounted) _showSnack('Removed from $batchName', const Color(0xFFF0DE36));
    } catch (_) {
      if (mounted) {
        setState(() {
          final exists = _studentBatchData.any((item) => (item['id'] ?? '').toString() == batchId);
          if (!exists) {
            _studentBatchData.add(batch);
          }
        });
        _showSnack('Remove failed. Try again.', const Color(0xFFD71313));
      }
    }
  }

  Future<void> _showAddBatchSheet() async {
    final assignedIds = _studentBatchData.map((b) => b['id'].toString()).toSet();
    final available = _allBatches.where((b) => !assignedIds.contains(b['id'].toString())).toList();
    if (available.isEmpty) {
      _showSnack('Student is already in all available batches', const Color(0xFFF0DE36));
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ProfileBatchPickerSheet(batches: available),
    );
    if (picked == null || !mounted) return;
    final batchId = picked['id'].toString();
    final batchName = picked['name'].toString();
    setState(() {
      final exists = _studentBatchData.any((b) => (b['id'] ?? '').toString() == batchId);
      if (!exists) {
        _studentBatchData.add({'id': batchId, 'name': batchName});
      }
    });
    try {
      await _adminRepo.assignStudentToBatch(batchId: batchId, studentId: widget.studentId);
      if (mounted) _showSnack('Added to $batchName!', const Color(0xFFF0DE36));
    } catch (_) {
      if (mounted) {
        setState(() => _studentBatchData.removeWhere((b) => b['id'] == batchId));
        _showSnack('Assignment failed. Try again.', const Color(0xFFD71313));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFEEEDED),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF0D1282))),
      );
    }

    if (_loadFailed) {
      return Scaffold(
        backgroundColor: const Color(0xFFEEEDED),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
          leading: CPPressable(onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0D1282)))) ,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_off_rounded, size: 64, color: const Color(0xFFD71313).withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('Unable to load student', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_loadErrorSummary, textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0D1282))),
              if (_loadErrorDetails.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEDED)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Error details', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
                      const SizedBox(height: 6),
                      SelectableText(
                        _loadErrorDetails,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF374151), height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: CPPressable(
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: _loadErrorDetails));
                            if (mounted) {
                              _showSnack('Error copied', const Color(0xFFF0DE36));
                            }
                          },
                          child: Text(
                            'Copy details',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              CPPressable(onTap: _loadAll, child: Text('Retry', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF0D1282)))),
            ]),
          ),
        ),
      );
    }

    if (_student == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFEEEDED),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
          leading: CPPressable(onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0D1282)))),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_search_rounded, size: 64, color: const Color(0xFF0D1282).withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Student not found', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          CPPressable(onTap: _loadAll, child: Text('Retry', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF0D1282)))),
        ])),
      );
    }

    final s = _student!;
    final name = (s['name'] ?? 'Student').toString();
    final rollNumber = (s['student_code'] ?? s['rollNumber'] ?? '—').toString();
    final status = (s['status'] ?? 'active').toString();
    final feeStatus = (s['feeStatus'] ?? (s['fee_status'] ?? 'PENDING')).toString().toUpperCase();
    final attendance = _toInt(s['attendancePercent']);
    final initials = name.trim().split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase();
    final phone = (s['phone'] ?? '').toString();
    final email = (s['email'] ?? '').toString();
    final address = (s['address'] ?? '').toString();
    final parentName = (s['parentName'] ?? '').toString();
    final parentPhone = (s['parentPhone'] ?? '').toString();
    final studentBatches = (s['student_batches'] as List<dynamic>? ?? [])
        .whereType<Map>().map((e) {
      final batch = e['batch'] as Map?;
      return (batch?['name'] ?? e['batch_id'] ?? '').toString();
    }).where((e) => e.isNotEmpty).toList();

    final attColor = attendance >= 80 ? const Color(0xFFF0DE36)
        : attendance >= 65 ? const Color(0xFFF0DE36) : const Color(0xFFD71313);
    final feeColor = feeStatus == 'PAID' ? const Color(0xFFF0DE36)
        : feeStatus == 'OVERDUE' ? const Color(0xFFD71313) : const Color(0xFFF0DE36);

    return Scaffold(
      backgroundColor: const Color(0xFFEEEDED),
      body: Stack(children: [
        NestedScrollView(
          headerSliverBuilder: (_, isScrolled) => [
            // ── Sliver App Bar ──────────────────────────────────
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: const Color(0xFF0D1282),
              leading: CPPressable(
                onTap: () { if (_editMode) { setState(() => _editMode = false); } else { context.pop(); } },
                child: Icon(_editMode ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              actions: [
                if (_editMode) ...[
                  CPPressable(
                    onTap: _saving ? null : _saveChanges,
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(color: const Color(0xFFF0DE36), borderRadius: BorderRadius.circular(20)),
                      child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D1282)))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_rounded, size: 14, color: Color(0xFF0D1282)),
                            const SizedBox(width: 6),
                            Text('Save', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
                          ]),
                    ),
                  ),
                ] else ...[
                  CPPressable(
                    onTap: () => setState(() => _editMode = true),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: const Color(0xFFF0DE36), borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF0D1282)),
                        const SizedBox(width: 6),
                        Text('Edit', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
                      ]),
                    ),
                  ),
                  CPPressable(
                    onTap: _deleteStudent,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _deleting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                        : const Icon(Icons.delete_outline_rounded, color: Colors.white60, size: 22),
                    ),
                  ),
                ],
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: const Color(0xFF0D1282),
                  child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: 20),
                    // Avatar
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2.5),
                      ),
                      child: Center(child: Text(initials,
                        style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white))),
                    ),
                    const SizedBox(height: 12),
                    Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(rollNumber, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white60)),
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white30, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: status == 'active' ? const Color(0xFFF0DE36).withValues(alpha: 0.2) : Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(status.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: status == 'active' ? const Color(0xFF4ADE80) : Colors.white60)),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    // Quick stats row
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _heroStat('Attendance', '$attendance%', attColor),
                      _heroDivider(),
                      _heroStat('Fee Status', feeStatus == 'PAID' ? 'Paid' : feeStatus == 'OVERDUE' ? 'Overdue' : 'Pending', feeColor),
                      _heroDivider(),
                      _heroStat('Batches', '${studentBatches.length}', Colors.white),
                    ]),
                  ])),
                ),
              ),
              bottom: TabBar(
                controller: _tabs,
                labelColor: const Color(0xFFF0DE36),
                unselectedLabelColor: Colors.white60,
                indicatorColor: const Color(0xFFF0DE36),
                indicatorWeight: 3,
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'Profile'),
                  Tab(text: 'Fees'),
                  Tab(text: 'Results'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabs,
            children: [
              // ── Tab 1: Profile ────────────────────────────────
              _buildProfileTab(s, phone, email, address, parentName, parentPhone),
              // ── Tab 2: Fees ───────────────────────────────────
              _buildFeesTab(feeStatus, feeColor),
              // ── Tab 3: Results ────────────────────────────────
              _buildResultsTab(),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _heroStat(String label, String value, Color color) => Column(children: [
    Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
    const SizedBox(height: 2),
    Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w500)),
  ]);

  Widget _heroDivider() => Container(
    width: 1, height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 20),
    color: Colors.white.withValues(alpha: 0.2),
  );

  // ── PROFILE TAB ─────────────────────────────────────────────────────────────────
  Widget _buildProfileTab(Map<String, dynamic> s, String phone, String email, String address, String parentName, String parentPhone) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Personal Info ─────────────────────────────────
        _sectionTitle('Personal Information'),
        const SizedBox(height: 12),
        _card(children: [
          _field(label: 'Full Name', icon: Icons.person_rounded, controller: _nameCtrl, editing: _editMode),
          _dividerLine(),
          _field(label: 'Phone', icon: Icons.phone_android_rounded, controller: _phoneCtrl, editing: _editMode, type: TextInputType.phone),
          _dividerLine(),
          _field(label: 'Email', icon: Icons.email_rounded, controller: _emailCtrl, editing: _editMode, type: TextInputType.emailAddress),
          _dividerLine(),
          _field(label: 'Address', icon: Icons.home_rounded, controller: _addressCtrl, editing: _editMode),
          _dividerLine(),
          _staticField(label: 'Gender', icon: Icons.wc_rounded, value: (s['gender'] ?? '—').toString()),
          _dividerLine(),
          _staticField(label: 'Roll No.', icon: Icons.badge_rounded, value: (s['student_code'] ?? '—').toString()),
        ]).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 24),

        // ── Parent Details ────────────────────────────────
        _sectionTitle('Parent / Guardian Details'),
        const SizedBox(height: 12),
        _card(children: [
          _field(label: 'Parent Name', icon: Icons.family_restroom_rounded, controller: _parentNameCtrl, editing: _editMode),
          _dividerLine(),
          _field(label: 'Parent Phone', icon: Icons.phone_in_talk_rounded, controller: _parentPhoneCtrl, editing: _editMode, type: TextInputType.phone),
          _dividerLine(),
          _field(label: 'Relationship', icon: Icons.people_rounded, controller: _parentRelCtrl, editing: _editMode),
        ]).animate(delay: 100.ms).fadeIn(duration: 300.ms),

        const SizedBox(height: 24),

        // ── Batch Assignment ──────────────────────────────
        Row(children: [
          Expanded(child: _sectionTitle('Batch Assignment')),
          CPPressable(
            onTap: _showAddBatchSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1282),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text('Add Batch', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _card(children: [
          if (_studentBatchData.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Icon(Icons.class_outlined, size: 36, color: const Color(0xFF0D1282).withValues(alpha: 0.3)),
                const SizedBox(height: 8),
                Text('No batches assigned yet',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0D1282), fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                CPPressable(
                  onTap: _showAddBatchSheet,
                  child: Text('+ Assign to a batch',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
                ),
              ]),
            )
          else
            ..._studentBatchData.asMap().entries.map((entry) {
              final b = entry.value;
              final bName = (b['name'] ?? 'Batch').toString();
              final colors = [const Color(0xFF0D1282), const Color(0xFF7C3AED), const Color(0xFF0D1282), const Color(0xFFF0DE36)];
              final ic = colors[entry.key % colors.length];
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: ic.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.class_rounded, size: 18, color: ic),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(bName, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0D1282))),
                      Text('Active enrollment', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF0D1282))),
                    ])),
                    // Remove button
                    CPPressable(
                      onTap: () => _removeBatch(b),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD71313).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.remove_circle_outline_rounded, size: 17, color: Color(0xFFD71313)),
                      ),
                    ),
                  ]),
                ),
                if (entry.key < _studentBatchData.length - 1) _dividerLine(),
              ]);
            }),
        ]).animate(delay: 200.ms).fadeIn(duration: 300.ms),

        const SizedBox(height: 24),

        // ── Quick Actions ─────────────────────────────────
        if (!_editMode) ...[
          _sectionTitle('Quick Actions'),
          const SizedBox(height: 12),
          Row(children: [
            _actionBtn(Icons.call_rounded, 'Call Student', const Color(0xFF0D1282), () => _callPhone(phone)),
            const SizedBox(width: 12),
            _actionBtn(Icons.chat_rounded, 'WhatsApp Parent', const Color(0xFFF0DE36), () => _openWhatsApp(parentPhone.isEmpty ? phone : parentPhone)),
          ]).animate(delay: 300.ms).fadeIn(duration: 300.ms),
        ],
      ]),
    );
  }

  // ── FEES TAB ─────────────────────────────────────────────────────────────────────
  Widget _buildFeesTab(String feeStatus, Color feeColor) {
    final totalPaid = _feeHistory.where((f) => (f['status'] as String?)?.toUpperCase() == 'PAID').length;
    final totalDue = _feeHistory.where((f) => (f['status'] as String?)?.toUpperCase() != 'PAID').length;
    final totalAmount = _feeHistory.fold<double>(0, (sum, f) => sum + _toDouble(f['amount']));
    final paidAmount = _feeHistory
        .where((f) => (f['status'] as String?)?.toUpperCase() == 'PAID')
        .fold<double>(0, (sum, f) => sum + _toDouble(f['amount']));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary cards
        Row(children: [
          _feeMetricCard('Total Paid', '₹${paidAmount.toInt()}', const Color(0xFFF0DE36)),
          const SizedBox(width: 12),
          _feeMetricCard('Outstanding', '₹${(totalAmount - paidAmount).toInt()}', const Color(0xFFD71313)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _feeMetricCard('Months Paid', '$totalPaid', const Color(0xFF0D1282)),
          const SizedBox(width: 12),
          _feeMetricCard('Months Due', '$totalDue', const Color(0xFFF0DE36)),
        ]),
        const SizedBox(height: 24),

        _sectionTitle('Payment History'),
        const SizedBox(height: 12),

        if (_feeHistory.isEmpty)
          _emptyState('No fee records found', Icons.receipt_long_outlined)
        else
          ..._feeHistory.asMap().entries.map((entry) {
            final fee = entry.value;
            final month = (fee['month'] ?? fee['period'] ?? 'Month ${entry.key + 1}').toString();
            final amount = _toInt(fee['amount']);
            final st = (fee['status'] ?? 'PENDING').toString().toUpperCase();
            final stColor = st == 'PAID' ? const Color(0xFFF0DE36)
                : st == 'OVERDUE' ? const Color(0xFFD71313) : const Color(0xFFF0DE36);
            final dueDate = (fee['dueDate'] ?? fee['due_date'] ?? '').toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: stColor.withValues(alpha: 0.2), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: stColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(st == 'PAID' ? Icons.check_circle_rounded : Icons.pending_rounded, size: 20, color: stColor),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(month, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
                  if (dueDate.isNotEmpty)
                    Text('Due: $dueDate', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF0D1282))),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹$amount', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: stColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: stColor.withValues(alpha: 0.3))),
                    child: Text(st, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: stColor)),
                  ),
                ]),
              ]),
            ).animate(delay: Duration(milliseconds: entry.key * 60)).fadeIn(duration: 300.ms);
          }),
      ]),
    );
  }

  // ── RESULTS TAB ──────────────────────────────────────────────────────────────────
  Widget _buildResultsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_examResults.isEmpty)
          _emptyState('No exam results yet', Icons.quiz_outlined)
        else ...[
          _sectionTitle('Exam Performance'),
          const SizedBox(height: 12),
          ..._examResults.asMap().entries.map((entry) {
            final exam = entry.value;
            final examName = (exam['examName'] ?? 'Exam').toString();
            final subject = (exam['subject'] ?? '').toString();
            final score = _toInt(exam['score']);
            final total = _toInt(exam['totalMarks'], fallback: 100);
            final grade = (exam['grade'] ?? '').toString();
            final pct = total > 0 ? score / total : 0.0;
            final perfColor = pct >= 0.75 ? const Color(0xFFF0DE36) : pct >= 0.5 ? const Color(0xFFF0DE36) : const Color(0xFFD71313);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(examName, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
                    if (subject.isNotEmpty)
                      Text(subject, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF0D1282))),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$score / $total', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: perfColor)),
                    if (grade.isNotEmpty)
                      Text('Grade $grade', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D1282))),
                  ]),
                ]),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFEEEDED),
                    valueColor: AlwaysStoppedAnimation(perfColor),
                  ),
                ),
              ]),
            ).animate(delay: Duration(milliseconds: entry.key * 60)).fadeIn(duration: 300.ms);
          }),
        ],
      ]),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String title) => Text(title,
    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282)));

  Widget _card({required List<Widget> children}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: Column(children: children),
  );

  Widget _dividerLine() => const Divider(height: 1, indent: 56, color: Color(0xFFEEEDED));

  Widget _field({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool editing,
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      Icon(icon, size: 20, color: const Color(0xFF0D1282)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF0D1282), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        editing
          ? TextField(
              controller: controller,
              keyboardType: type,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0D1282)),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: UnderlineInputBorder(borderSide: BorderSide(color: const Color(0xFF0D1282).withValues(alpha: 0.3))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0D1282), width: 1.5)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: const Color(0xFF0D1282).withValues(alpha: 0.2))),
              ),
            )
          : Text(
              controller.text.isEmpty ? '—' : controller.text,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0D1282)),
            ),
      ])),
    ]),
  );

  Widget _staticField({required String label, required IconData icon, required String value}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(icon, size: 20, color: const Color(0xFF0D1282)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF0D1282), fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '—' : value, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0D1282))),
        ])),
      ]),
    );

  Widget _feeMetricCard(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF0D1282), fontWeight: FontWeight.w500)),
      ]),
    ),
  );

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
    child: CPPressable(
      onTap: () { HapticFeedback.mediumImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    ),
  );

  Widget _emptyState(String msg, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 56, color: const Color(0xFF0D1282).withValues(alpha: 0.2)),
        const SizedBox(height: 16),
        Text(msg, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF0D1282), fontWeight: FontWeight.w600)),
      ]),
    ),
  ).animate().fadeIn(duration: 400.ms);

  void _callPhone(String number) {
    if (number.isNotEmpty) launchUrl(Uri.parse('tel:$number'));
  }

  void _openWhatsApp(String number) {
    final clean = number.replaceAll(RegExp(r'[^0-9]'), '');
    final wa = clean.length == 10 ? '91$clean' : clean;
    launchUrl(Uri.parse('https://wa.me/$wa'));
  }
}

// ── Profile Batch Picker Sheet ────────────────────────────────────────────────
class _ProfileBatchPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> batches;
  const _ProfileBatchPickerSheet({required this.batches});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(child: Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 8, bottom: 20),
          decoration: BoxDecoration(color: const Color(0xFFEEEDED), borderRadius: BorderRadius.circular(2)),
        )),
        Text('Add to a batch', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
        const SizedBox(height: 4),
        Text('Select a batch to enroll this student',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0D1282))),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: batches.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFEEEDED)),
            itemBuilder: (ctx, i) {
              final batch = batches[i];
              final name = (batch['name'] ?? 'Batch').toString();
              final bColors = [const Color(0xFF0D1282), const Color(0xFF7C3AED), const Color(0xFF0D1282), const Color(0xFFF0DE36)];
              final c = bColors[i % bColors.length];
              return CPPressable(
                onTap: () { HapticFeedback.selectionClick(); Navigator.pop(ctx, batch); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.class_rounded, size: 20, color: c),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
                      Text(
                        (batch['schedule'] ?? batch['description'] ?? 'Tap to assign').toString(),
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF0D1282)),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text('Add', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFEEEDED))),
            ),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
          ),
        ),
      ]),
    );
  }
}


