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

    final timelineItems = <Map<String, String>>[];
    timelineItems.addAll(
      lectures
          .take(2)
          .map(
            (e) => {
              'title': 'Lecture uploaded',
              'subtitle': (e['title'] ?? 'Lecture').toString(),
              'time': dateLabel(e['created_at'] ?? e['scheduled_at']),
            },
          ),
    );
    timelineItems.addAll(
      quizzes
          .take(2)
          .map(
            (e) => {
              'title': 'Test created',
              'subtitle': (e['title'] ?? 'Test').toString(),
              'time': dateLabel(e['created_at'] ?? e['scheduled_at']),
            },
          ),
    );
    timelineItems.addAll(
      feeRecords
          .take(2)
          .map(
            (e) => {
              'title': 'Fee collected',
              'subtitle': ((e['student'] as Map?)?['name'] ?? 'Student')
                  .toString(),
              'time': dateLabel(e['updated_at'] ?? e['created_at']),
            },
          ),
    );

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
