import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'batch_detail_common_widgets.dart';

class BatchOverviewTab extends StatelessWidget {
  final Map<String, dynamic>? batch;
  final List<Map<String, dynamic>> timetable;
  final List<Map<String, dynamic>> lectures;
  final List<Map<String, dynamic>> quizzes;
  final List<Map<String, dynamic>> feeRecords;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> materials;
  final List<Map<String, dynamic>> announcements;
  final List<Map<String, dynamic>> attendanceSessions;
  final Map<String, dynamic> attendanceStats;
  final String Function(dynamic) dateLabel;

  const BatchOverviewTab({
    super.key,
    required this.batch,
    required this.timetable,
    required this.lectures,
    required this.quizzes,
    required this.feeRecords,
    required this.students,
    required this.assignments,
    required this.materials,
    required this.announcements,
    required this.attendanceSessions,
    required this.attendanceStats,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final upcoming = [...timetable]
      ..sort(
        (a, b) => _toDate(a['scheduled_at'] ?? a['date']).compareTo(
          _toDate(b['scheduled_at'] ?? b['date']),
        ),
      );
    final nextSlot = upcoming.isEmpty ? null : upcoming.first;

    final allActivities = [
      ...lectures.map((e) => {
            'title': 'Lecture uploaded',
            'subtitle': (e['title'] ?? 'Lecture').toString(),
            'date': _toDate(e['created_at'] ?? e['scheduled_at']),
            'time': dateLabel(e['created_at'] ?? e['scheduled_at']),
          }),
      ...quizzes.map((e) => {
            'title': e['item_type'] == 'exam' ? 'Exam created' : 'Test created',
            'subtitle': (e['title'] ?? e['name'] ?? 'Test').toString(),
            'date': _toDate(e['created_at'] ?? e['scheduled_at'] ?? e['exam_date']),
            'time': dateLabel(e['created_at'] ?? e['scheduled_at'] ?? e['exam_date']),
          }),
      ...feeRecords.map((e) => {
            'title': 'Fee collected',
            'subtitle': ((e['student'] as Map?)?['name'] ?? 'Student').toString(),
            'date': _toDate(e['updated_at'] ?? e['created_at']),
            'time': dateLabel(e['updated_at'] ?? e['created_at']),
          }),
      ...assignments.map((e) => {
            'title': 'Assignment added',
            'subtitle': (e['title'] ?? 'Assignment').toString(),
            'date': _toDate(e['created_at']),
            'time': dateLabel(e['created_at']),
          }),
      ...materials.map((e) => {
            'title': 'Material uploaded',
            'subtitle': (e['title'] ?? 'Material').toString(),
            'date': _toDate(e['created_at']),
            'time': dateLabel(e['created_at']),
          }),
      ...announcements.map((e) => {
            'title': 'Announcement',
            'subtitle': (e['title'] ?? 'Message').toString(),
            'date': _toDate(e['created_at']),
            'time': dateLabel(e['created_at']),
          }),
      ...attendanceSessions.map((e) => {
            'title': 'Attendance marked',
            'subtitle': (e['subject'] ?? 'General').toString(),
            'date': _toDate(e['date'] ?? e['created_at']),
            'time': dateLabel(e['date'] ?? e['created_at']),
          }),
    ];

    allActivities.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    final timelineItems = allActivities.take(8).map((e) => {
      'title': e['title'].toString(),
      'subtitle': e['subtitle'].toString(),
      'time': e['time'].toString(),
    }).toList();

    return Column(
      key: const ValueKey('overview-tab'),
      children: [
        sectionCard(
          context,
          title: 'Batch Snapshot',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ((batch?['description'] ?? '').toString().trim().isEmpty)
                    ? 'No description added yet.'
                    : (batch?['description'] ?? '').toString(),
                style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  pill(
                    Icons.calendar_month_rounded,
                    '${dateLabel(batch?['start_date'])} → ${dateLabel(batch?['end_date'])}',
                  ),
                  pill(
                    Icons.class_rounded,
                    (batch?['subject'] ?? 'General').toString(),
                  ),
                  pill(
                    Icons.location_on_rounded,
                    (batch?['room'] ?? 'Room TBD').toString(),
                  ),
                  if (nextSlot != null)
                    pill(
                      Icons.schedule_rounded,
                      'Next: ${dateLabel(nextSlot['scheduled_at'] ?? nextSlot['date'])}',
                    ),
                ],
              ),
            ],
          ),
        ),
        sectionCard(
          context,
          title: 'Recent Activity',
          child: timelineItems.isEmpty
              ? Text(
                  'No recent activity recorded.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                )
              : Column(
                  children: timelineItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE5A100),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  item['subtitle']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            item['time']!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF354388),
                            ),
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

  DateTime _toDate(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return DateTime(0);
    return DateTime.tryParse(value.toString()) ?? DateTime(0);
  }
}
