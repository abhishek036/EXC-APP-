import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../admin/data/repositories/admin_repository.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class AttendanceMarkingPage extends StatefulWidget {
  const AttendanceMarkingPage({super.key});

  @override
  State<AttendanceMarkingPage> createState() => _AttendanceMarkingPageState();
}

class _AttendanceMarkingPageState extends State<AttendanceMarkingPage> {
  final AdminRepository _adminRepo = sl<AdminRepository>();

  bool _notifyParents = true;
  bool _isSubmitting = false;
  bool _isLoading = false;
  List<_AttStudent> _students = [];
  List<Map<String, dynamic>> _batches = [];
  String? _selectedBatchId;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final batches = await _adminRepo.getBatches();
      if (!mounted) return;
      setState(() {
        _batches = batches;
        if (batches.isNotEmpty) {
          _selectedBatchId = (batches.first['id'] ?? batches.first['batch_id'] ?? '').toString();
        }
      });
    } catch (_) {}
    await _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _adminRepo.getStudents(batchId: _selectedBatchId);
      if (!mounted) return;
      setState(() {
        _students = data.map(_AttStudent.fromMap).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _presentCount => _students.where((s) => s.status == 'P').length;
  int get _absentCount => _students.where((s) => s.status == 'A').length;
  int get _lateCount => _students.where((s) => s.status == 'L').length;

  Future<void> _submitAttendance(String teacherUid) async {
    if (_selectedBatchId == null || _selectedBatchId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a batch first')),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    final sessionDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    const statusMap = {'P': 'present', 'A': 'absent', 'L': 'late', 'Lv': 'excused'};

    try {
      final records = _students
          .map((s) => {'student_id': s.id, 'status': statusMap[s.status] ?? 'present'})
          .toList();

      await _adminRepo.markAttendance(
        batchId: _selectedBatchId!,
        sessionDate: sessionDate,
        records: records,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance submitted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: ${e.toString().split(':').last.trim()}')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final teacherUid = authState is AuthAuthenticated ? authState.user.id : '';

        return Scaffold(
          backgroundColor: CT.bg(context),
          appBar: AppBar(title: Text('Mark Attendance', style: GoogleFonts.sora(fontWeight: FontWeight.w600))),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: CT.card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CT.textM(context)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.class_outlined, size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _batches.isEmpty
                                ? Text('Loading batches...', style: GoogleFonts.sora(fontSize: 14, color: CT.textM(context)))
                                : DropdownButton<String>(
                                    value: _selectedBatchId,
                                    isExpanded: true,
                                    underline: const SizedBox.shrink(),
                                    style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context)),
                                    items: _batches.map((b) {
                                      final id = (b['id'] ?? b['batch_id'] ?? '').toString();
                                      final name = (b['name'] ?? 'Batch').toString();
                                      return DropdownMenuItem<String>(value: id, child: Text(name));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val == null || val == _selectedBatchId) return;
                                      setState(() {
                                        _selectedBatchId = val;
                                        _students = [];
                                      });
                                      _loadStudents();
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                          style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _summaryChip('Present: $_presentCount', AppColors.present),
                        const SizedBox(width: 8),
                        _summaryChip('Absent: $_absentCount', AppColors.absent),
                        const SizedBox(width: 8),
                        _summaryChip('Late: $_lateCount', AppColors.late),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              for (final s in _students) {
                                s.status = 'P';
                              }
                            }),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.success),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('✓ Mark All Present', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              for (final s in _students) {
                                s.status = 'A';
                              }
                            }),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('✗ Mark All Absent', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              Expanded(
                child: _students.isEmpty
                    ? Center(
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Text('No students found in this batch', style: GoogleFonts.dmSans(color: CT.textS(context))),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH, vertical: 8),
                        itemCount: _students.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _studentRow(_students[i], i),
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                decoration: BoxDecoration(
                  color: CT.card(context),
                  boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _notifyParents,
                              onChanged: (v) => setState(() => _notifyParents = v ?? true),
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Notify parents of absent students via WhatsApp', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textS(context))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      CustomButton(
                        text: 'Submit Attendance',
                        icon: Icons.check,
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting || teacherUid.isEmpty ? null : () => _submitAttendance(teacherUid),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryChip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(100)),
        child: Text(text, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _studentRow(_AttStudent student, int index) {
    final attColor = student.attPct >= 80
        ? AppColors.success
        : student.attPct >= 70
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: CT.cardDecor(context, radius: 14),
      child: Row(
        children: [
          Text((index + 1).toString().padLeft(2, '0'), style: GoogleFonts.sora(fontSize: 12, color: CT.textM(context), fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(student.name.isEmpty ? 'S' : student.name[0], style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    Text(student.id, style: GoogleFonts.dmSans(fontSize: 10, color: CT.textM(context))),
                    const SizedBox(width: 6),
                    Text('${student.attPct}% Att.', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: attColor)),
                  ],
                ),
              ],
            ),
          ),
          ..._buildToggles(student),
        ],
      ),
    ).animate(delay: Duration(milliseconds: 30 * index)).fadeIn(duration: 300.ms);
  }

  List<Widget> _buildToggles(_AttStudent student) {
    final options = [
      ('P', AppColors.present),
      ('A', AppColors.absent),
      ('L', AppColors.late),
      ('Lv', const Color(0xFF9CA3AF)),
    ];

    return options.map((option) {
      final selected = student.status == option.$1;
      return CPPressable(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => student.status = option.$1);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: selected ? option.$2 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? option.$2 : CT.textM(context), width: 1.5),
          ),
          child: Center(
            child: Text(
              option.$1,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : CT.textM(context),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _AttStudent {
  final String id;
  final String name;
  final String batch;
  final int attPct;
  String status;

  _AttStudent({required this.id, required this.name, required this.batch, required this.attPct, this.status = 'P'});

  factory _AttStudent.fromMap(Map<String, dynamic> map) {
    final studentBatches = (map['student_batches'] as List<dynamic>? ?? []);
    final firstBatch = studentBatches.isNotEmpty ? studentBatches.first as Map<dynamic, dynamic>? : null;
    final batchName = (firstBatch?['batch'] as Map<dynamic, dynamic>?)?['name'] ?? map['batch'] ?? 'General';
    return _AttStudent(
      id: (map['id'] ?? map['studentId'] ?? map['student_id'] ?? '').toString(),
      name: (map['name'] ?? 'Student').toString(),
      batch: batchName.toString(),
      attPct: (map['attendancePercent'] as num?)?.toInt() ?? 0,
      status: 'P',
    );
  }
}
