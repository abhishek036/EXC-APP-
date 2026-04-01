import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../features/teacher/data/repositories/teacher_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class AttendanceMarkingPage extends StatefulWidget {
  final String? initialBatchId;
  final DateTime? initialDate;
  final String? initialSubject;

  const AttendanceMarkingPage({
    super.key,
    this.initialBatchId,
    this.initialDate,
    this.initialSubject,
  });

  @override
  State<AttendanceMarkingPage> createState() => _AttendanceMarkingPageState();
}

class _AttendanceMarkingPageState extends State<AttendanceMarkingPage> {
  final TeacherRepository _teacherRepo = sl<TeacherRepository>();

  bool _notifyParents = true;
  bool _isSubmitting = false;
  bool _isLoading = false;
  List<_AttStudent> _students = [];
  List<Map<String, dynamic>> _batches = [];
  String? _selectedBatchId;
  String? _selectedSubject;
  List<String> _subjects = [];
  DateTime _selectedDate = DateTime.now();
  String? get _safeSelectedBatchId {
    if (_selectedBatchId == null || _selectedBatchId!.isEmpty) return null;
    final hasSelected = _batches.any(
      (b) => ((b['id'] ?? b['batch_id'] ?? '').toString() == _selectedBatchId),
    );
    return hasSelected ? _selectedBatchId : null;
  }

  @override
  void initState() {
    super.initState();
    _selectedBatchId = widget.initialBatchId;
    _selectedSubject = widget.initialSubject;
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final batches = await _teacherRepo.getMyBatches();
      if (!mounted) return;
      setState(() {
        _batches = batches;
        if (batches.isEmpty) {
          _selectedBatchId = null;
        } else {
          // If a batch is already selected (from constructor), check if it's in the list
          final hasSelected = _batches.any(
            (b) =>
                ((b['id'] ?? b['batch_id'] ?? '').toString() ==
                _selectedBatchId),
          );

          if (!hasSelected) {
            final firstValid = batches
                .map((b) => (b['id'] ?? b['batch_id'] ?? '').toString())
                .firstWhere((id) => id.isNotEmpty, orElse: () => '');
            _selectedBatchId = firstValid.isNotEmpty ? firstValid : null;
          }
        }
      });
      if (_safeSelectedBatchId != null) {
        _updateSubjects();
        await _loadStudents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load batches: $e')));
      }
    }
  }

  void _updateSubjects() {
    final batch = _batches.firstWhere(
      (b) =>
          (b['id'] ?? b['batch_id'] ?? '').toString() == _safeSelectedBatchId,
      orElse: () => {},
    );
    final meta = batch['meta'] ?? {};
    final subs = meta['subjects'];

    _subjects = [];
    if (subs is List) {
      _subjects = subs.map((e) => e.toString()).toList();
    } else if (subs is String && subs.isNotEmpty) {
      _subjects = subs
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (_subjects.isNotEmpty) {
      if (!_subjects.contains(_selectedSubject)) {
        _selectedSubject = _subjects.first;
      }
    } else {
      _selectedSubject = null;
    }
  }

  Future<void> _loadStudents() async {
    final batchId = _safeSelectedBatchId;
    if (!mounted || batchId == null) return;
    setState(() => _isLoading = true);
    try {
      final studentsData = await _teacherRepo.getBatchStudents(batchId);
      final monthAttendance = await _teacherRepo.getBatchAttendance(
        batchId: batchId,
        month: _selectedDate.month,
        year: _selectedDate.year,
        subject: _selectedSubject,
      );

      if (!mounted) return;

      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      // Find session for the specific day
      final sessionForDay = monthAttendance.firstWhere((s) {
        final sVal = s['session_date'];
        if (sVal == null) return false;
        final sDate = DateTime.tryParse(sVal.toString());
        if (sDate == null) return false;
        // Compare year/month/day in local time for consistent UI matching
        final localSDate = sDate.toLocal();
        return localSDate.year == _selectedDate.year &&
            localSDate.month == _selectedDate.month &&
            localSDate.day == _selectedDate.day;
      }, orElse: () => <String, dynamic>{});

      final existingRecords = (sessionForDay['records'] as List?) ?? [];

      setState(() {
        _students = studentsData.map((e) {
          final student = _AttStudent.fromMap(e);
          // Check if this student has an existing status for this date
          final matchingRecord = existingRecords.firstWhere(
            (r) => r['student_id']?.toString() == student.id,
            orElse: () => null,
          );
          if (matchingRecord != null) {
            final s = matchingRecord['status']?.toString().toLowerCase();
            if (s == 'present')
              student.status = 'P';
            else if (s == 'absent')
              student.status = 'A';
            else if (s == 'late')
              student.status = 'L';
            else if (s == 'excused')
              student.status = 'Lv';
          }
          return student;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load students: $e')));
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF0D1282),
              onPrimary: Colors.white,
              surface: const Color(0xFFEEEDED),
              onSurface: const Color(0xFF0D1282),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _students = [];
      });
      _loadStudents();
    }
  }

  int get _presentCount => _students.where((s) => s.status == 'P').length;
  int get _absentCount => _students.where((s) => s.status == 'A').length;
  int get _lateCount => _students.where((s) => s.status == 'L').length;

  Future<void> _submitAttendance(String teacherUid) async {
    final batchId = _safeSelectedBatchId;
    if (batchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a batch first')),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    final sessionDate = _selectedDate.toUtc().toIso8601String();
    
    const statusMap = {
      'P': 'present',
      'A': 'absent',
      'L': 'late',
      'Lv': 'excused',
    };

    try {
      final records = _students
          .map(
            (s) => {
              'student_id': s.id,
              'status': statusMap[s.status] ?? 'present',
            },
          )
          .toList();

      await _teacherRepo.markAttendance(
        batchId: batchId,
        sessionDate: sessionDate,
        subject: _selectedSubject,
        records: records,
        notifyParents: _notifyParents,
      );

      if (!mounted) return;
      await _loadStudents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved and refreshed successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to submit: ${e.toString().split(':').last.trim()}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);
    const yellow = Color(0xFFF0DE36);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final teacherUid = authState is AuthAuthenticated
            ? authState.user.id
            : '';

        return Scaffold(
          backgroundColor: blue,
          appBar: AppBar(
            backgroundColor: blue,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'ATTENDANCE',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
          body: Column(
            children: [
              _buildControlPanel(blue, surface, yellow),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: yellow),
                      )
                    : _students.isEmpty
                    ? Center(
                        child: _PremiumCard(
                          child: Text(
                            'NO STUDENTS FOUND',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              color: blue,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        itemCount: _students.length,
                        itemBuilder: (ctx, i) =>
                            _studentRow(_students[i], i, blue, surface, yellow),
                      ),
              ),
              _buildBottomBar(teacherUid, blue, surface, yellow),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlPanel(Color blue, Color surface, Color yellow) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: Color(0xFF0D1282)),
              const SizedBox(width: 12),
              Expanded(
                child: _batches.isEmpty
                    ? Text(
                        'LOADING BATCHES...',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _safeSelectedBatchId,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF0D1282),
                          ),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: blue,
                          ),
                          items: _batches.map((b) {
                            final id = (b['id'] ?? b['batch_id'] ?? '')
                                .toString();
                            final name = (b['name'] ?? 'Batch')
                                .toString()
                                .toUpperCase();
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val == null || val == _selectedBatchId) return;
                            setState(() {
                              _selectedBatchId = val;
                              _updateSubjects();
                              _students = [];
                            });
                            _loadStudents();
                          },
                        ),
                      ),
              ),
            ],
          ),
          if (_subjects.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.subject_rounded, color: Color(0xFF0D1282)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSubject,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF0D1282),
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: blue,
                      ),
                      items: _subjects.map((s) {
                        return DropdownMenuItem<String>(
                          value: s,
                          child: Text(s.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null || val == _selectedSubject) return;
                        setState(() {
                          _selectedSubject = val;
                          _students = [];
                        });
                        _loadStudents();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: blue.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: blue, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    'DATE: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.w900,
                      color: blue,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.edit_calendar_rounded, color: blue, size: 18),
                ],
              ),
            ),
          ),
          const Divider(height: 24, thickness: 1.5, color: Color(0xFF0D1282)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _SummaryCount(
                    label: 'P',
                    count: _presentCount,
                    color: AppColors.mintGreen,
                    blue: blue,
                  ),
                  const SizedBox(width: 8),
                  _SummaryCount(
                    label: 'A',
                    count: _absentCount,
                    color: AppColors.coralRed,
                    blue: blue,
                  ),
                  const SizedBox(width: 8),
                  _SummaryCount(
                    label: 'L',
                    count: _lateCount,
                    color: Color(0xFFC0A000),
                    blue: blue,
                  ),
                ],
              ),
              _ActionBtn(
                label: 'ALL PRESENT',
                icon: Icons.check_circle_outline,
                blue: blue,
                yellow: yellow,
                onPressed: () => setState(() {
                  for (var s in _students) {
                    s.status = 'P';
                  }
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _studentRow(
    _AttStudent student,
    int index,
    Color blue,
    Color surface,
    Color yellow,
  ) {
    return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: blue, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  student.name.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: blue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusToggle(
                status: 'P',
                current: student.status,
                color: AppColors.mintGreen,
                blue: blue,
                onTap: () => setState(() => student.status = 'P'),
              ),
              const SizedBox(width: 6),
              _StatusToggle(
                status: 'A',
                current: student.status,
                color: AppColors.coralRed,
                blue: blue,
                onTap: () => setState(() => student.status = 'A'),
              ),
              const SizedBox(width: 6),
              _StatusToggle(
                status: 'L',
                current: student.status,
                color: yellow,
                blue: blue,
                onTap: () => setState(() => student.status = 'L'),
              ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: 30 * index))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.1);
  }

  Widget _buildBottomBar(
    String teacherUid,
    Color blue,
    Color surface,
    Color yellow,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: blue, width: 3)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: _notifyParents,
                  onChanged: (v) => setState(() => _notifyParents = v ?? true),
                  activeColor: blue,
                  checkColor: yellow,
                ),
                Expanded(
                  child: Text(
                    'SEND WHATSAPP ALERTS TO ABSENTEES',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      color: blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting || teacherUid.isEmpty
                    ? null
                    : () => _submitAttendance(teacherUid),
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: yellow,
                  elevation: 0,
                  side: BorderSide(color: blue, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'SUBMIT ATTENDANCE',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCount extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color blue;
  const _SummaryCount({
    required this.label,
    required this.count,
    required this.color,
    required this.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 10,
            color: blue.withValues(alpha: 0.5),
          ),
        ),
        Text(
          '$count',
          style: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StatusToggle extends StatelessWidget {
  final String status;
  final String current;
  final Color color;
  final Color blue;
  final VoidCallback onTap;

  const _StatusToggle({
    required this.status,
    required this.current,
    required this.color,
    required this.blue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = status == current;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          border: Border.all(color: blue, width: 2),
          borderRadius: BorderRadius.circular(4),
          boxShadow: active
              ? [BoxShadow(color: blue, offset: const Offset(2, 2))]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          status,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: active
                ? (status == 'L' ? blue : Colors.white)
                : blue.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final Widget child;
  const _PremiumCard({required this.child});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0D1282);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFEEEDED),
        border: Border.all(color: blue, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
      ),
      child: child,
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color blue;
  final Color yellow;
  final VoidCallback onPressed;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.blue,
    required this.yellow,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: yellow,
          border: Border.all(color: blue, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: blue),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 10,
                color: blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttStudent {
  final String id;
  final String name;
  final String batch;
  final int attPct;
  String status;

  _AttStudent({
    required this.id,
    required this.name,
    required this.batch,
    required this.attPct,
    this.status = 'P',
  });

  factory _AttStudent.fromMap(Map<String, dynamic> map) {
    final studentBatches = (map['student_batches'] as List<dynamic>? ?? []);
    final firstBatch = studentBatches.isNotEmpty
        ? studentBatches.first as Map<dynamic, dynamic>?
        : null;
    final batchName =
        (firstBatch?['batch'] as Map<dynamic, dynamic>?)?['name'] ??
        map['batch'] ??
        'General';
    return _AttStudent(
      id: (map['id'] ?? map['studentId'] ?? map['student_id'] ?? '').toString(),
      name: (map['name'] ?? 'Student').toString(),
      batch: batchName.toString(),
      attPct: (map['attendancePercent'] as num?)?.toInt() ?? 0,
      status: 'P',
    );
  }
}
