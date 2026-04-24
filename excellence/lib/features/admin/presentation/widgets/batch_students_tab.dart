import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'batch_detail_common_widgets.dart';
import '../../../../core/theme/theme_aware.dart';

class BatchStudentsTab extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final Map<String, dynamic>? batch;
  final double Function(Map<String, dynamic>) getStudentAttendance;
  final String Function(String) getStudentFeeStatus;
  final VoidCallback onAddStudent;
  final Function(String) onViewStudent;
  final VoidCallback onRefresh;

  const BatchStudentsTab({
    super.key,
    required this.students,
    required this.batch,
    required this.getStudentAttendance,
    required this.getStudentFeeStatus,
    required this.onAddStudent,
    required this.onViewStudent,
    required this.onRefresh,
  });

  @override
  State<BatchStudentsTab> createState() => _BatchStudentsTabState();
}

class _BatchStudentsTabState extends State<BatchStudentsTab> {
  String _studentFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.students.where((student) {
      if (_studentFilter == 'All') return true;
      if (_studentFilter == 'Low attendance') {
        return widget.getStudentAttendance(student) < 70;
      }

      final status = (student['status'] ?? student['is_active'])
          ?.toString()
          .toLowerCase();
      final active = status == null || status == 'active' || status == 'true';

      if (_studentFilter == 'Active') return active;
      if (_studentFilter == 'Inactive') return !active;
      if (_studentFilter == 'Paid') {
        return widget.getStudentFeeStatus((student['id'] ?? '').toString()) == 'Paid';
      }
      if (_studentFilter == 'Unpaid') {
        return widget.getStudentFeeStatus((student['id'] ?? '').toString()) == 'Pending';
      }
      return true;
    }).toList();

    return Column(
      key: const ValueKey('students-tab'),
      children: [
        sectionCard(
          context,
          title: 'Students',
          trailing: TextButton.icon(
            onPressed: widget.onAddStudent,
            icon: const Icon(Icons.person_add_alt_rounded, size: 16),
            label: const Text('Add Student'),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children:
                      [
                            'All',
                            'Paid',
                            'Unpaid',
                            'Active',
                            'Inactive',
                            'Low attendance',
                          ]
                          .map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(f),
                                selected: _studentFilter == f,
                                onSelected: (_) =>
                                    setState(() => _studentFilter = f),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                Text(
                  'No students match this filter',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: CT.textS(context),
                  ),
                )
              else
                ...filtered.map((student) {
                  final attendance = widget.getStudentAttendance(student);
                  final feeStatus = widget.getStudentFeeStatus(
                    (student['id'] ?? '').toString(),
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFF354388),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      onTap: () => widget.onViewStudent((student['id'] ?? '').toString()),
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text(
                          ((student['name'] ?? 'S').toString())
                              .substring(0, 1)
                              .toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF354388),
                          ),
                        ),
                      ),
                      title: Text(
                        (student['name'] ?? 'Student').toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        'Batch: ${(widget.batch?['name'] ?? 'Batch')} • Attendance ${attendance.toStringAsFixed(0)}%',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          statusTag(
                            feeStatus,
                            feeStatus == 'Paid'
                                ? const Color(0xFFE5A100)
                                : const Color(0xFFB6231B),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            attendance < 70 ? 'Low' : 'Good',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
}
