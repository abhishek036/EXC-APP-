import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'batch_detail_common_widgets.dart';
import '../../../../core/theme/theme_aware.dart';

class BatchAttendanceTab extends StatelessWidget {
  final Map<String, dynamic> attendanceStats;
  final List<Map<String, dynamic>> attendanceSessions;
  final String Function(dynamic) dateLabel;
  final String Function(dynamic) timeLabel;
  final VoidCallback onMarkAttendance;
  final Function(Map<String, dynamic>) onEditAttendance;

  const BatchAttendanceTab({
    super.key,
    required this.attendanceStats,
    required this.attendanceSessions,
    required this.dateLabel,
    required this.timeLabel,
    required this.onMarkAttendance,
    required this.onEditAttendance,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('attendance-tab'),
      children: [
        sectionCard(
          context,
          title: 'Attendance Overview',
          trailing: TextButton.icon(
            onPressed: onMarkAttendance,
            icon: const Icon(Icons.add_task_rounded, size: 16),
            label: const Text('Mark Attendance'),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metric('Avg Present', attendanceStats['avg'].toString(), const Color(0xFF354388)),
              _metric('Students', attendanceStats['count'].toString(), const Color(0xFFE5A100)),
              _metric('Status', attendanceStats['status'].toString(), const Color(0xFF354388)),
            ],
          ),
        ),
        sectionCard(
          context,
          title: 'Past Sessions',
          child: attendanceSessions.isEmpty
              ? Text(
                  'No sessions recorded yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: CT.textS(context),
                  ),
                )
              : Column(
                  children: attendanceSessions.take(15).map((session) {
                    final date = dateLabel(session['session_date'] ?? session['date']);
                    final subject = (session['subject'] ?? 'General').toString();
                    final records = (session['records'] as List?) ?? (session['student_records'] as List?) ?? const [];
                    final presentCount = records.where((r) => r['status'] == 'present' || r['status'] == 'late').length;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFF354388), width: 1),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          '$date • $subject',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        subtitle: Text(
                          'Present: $presentCount / ${records.length}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => onEditAttendance(session),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
