import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';

import '../../../student/data/repositories/student_repository.dart';

class ExamCalendarPage extends StatefulWidget {
  const ExamCalendarPage({super.key});

  @override
  State<ExamCalendarPage> createState() => _ExamCalendarPageState();
}

class _ExamCalendarPageState extends State<ExamCalendarPage> {
  final _repo = sl<StudentRepository>();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _exams = [];

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final exams = await _repo.getUpcomingExams();
      if (!mounted) return;
      setState(() {
        _exams = exams;
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

  Color _subjectColor(String? subject) {
    switch (subject?.toLowerCase()) {
      case 'physics':
        return AppColors.physics;
      case 'chemistry':
        return AppColors.chemistry;
      case 'mathematics':
      case 'maths':
        return AppColors.mathematics;
      case 'english':
        return AppColors.english;
      case 'biology':
        return AppColors.biology;
      default:
        return AppColors.electricBlue;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      return DateFormat('d MMM').format(d);
    } catch (_) {
      return date.toString();
    }
  }

  String _formatTime(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      return DateFormat('h:mm a').format(d);
    } catch (_) {
      return '';
    }
  }

  String _daysUntil(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      final diff = d.difference(DateTime.now()).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      return 'In $diff days';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text(
          'Exam Calendar',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadExams,
                  child: _exams.isEmpty
                      ? _buildEmpty()
                      : Column(
                          children: [
                            _buildExamCount(),
                            Expanded(child: _buildExamTimeline()),
                          ],
                        ),
                ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: CT.textM(context)),
            const SizedBox(height: 12),
            Text('Failed to load exams',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadExams, child: const Text('Retry')),
          ],
        ),
      );

  Widget _buildEmpty() => ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 56, color: CT.textM(context)),
                  const SizedBox(height: 12),
                  Text('No upcoming exams',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16, fontWeight: FontWeight.w600, color: CT.textS(context))),
                  const SizedBox(height: 4),
                  Text('Enjoy the break!',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: CT.textM(context))),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _buildExamCount() {
    final nextExam = _exams.isNotEmpty ? _daysUntil(_exams.first['exam_date']) : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${_exams.length} exam${_exams.length == 1 ? '' : 's'} ',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context)),
                ),
                TextSpan(
                  text: 'upcoming',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: CT.textS(context)),
                ),
              ],
            ),
          ),
          if (nextExam.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.moltenAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.moltenAmber),
                  const SizedBox(width: 4),
                  Text(
                    nextExam,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.moltenAmber),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate(delay: 100.ms).fadeIn();
  }

  Widget _buildExamTimeline() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: _exams.length,
        itemBuilder: (ctx, i) => _buildTimelineCard(_exams[i], i, i == _exams.length - 1),
      );

  Widget _buildTimelineCard(Map<String, dynamic> exam, int index, bool isLast) {
    final subject = (exam['subject'] ?? '').toString();
    final color = _subjectColor(subject);
    final day = _formatDate(exam['exam_date']).split(' ').first;
    final title = exam['title'] ?? 'Exam';
    final batchNames = (exam['batches'] is List) ? (exam['batches'] as List).join(', ') : '';
    final time = _formatTime(exam['exam_date']);
    final duration = exam['duration_min'] ?? exam['duration'] ?? 60;
    final totalMarks = exam['total_marks'] ?? '';

    return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline column
              SizedBox(
                width: 52,
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          day,
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 12, fontWeight: FontWeight.w700, color: color),
                        ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: CT.border(context),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Card
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: CT.cardDecor(context, radius: AppDimensions.radiusMD),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toString(),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context)),
                      ),
                      const SizedBox(height: 4),
                      if (batchNames.isNotEmpty)
                        Text(
                          batchNames,
                          style:
                              GoogleFonts.plusJakartaSans(fontSize: 12, color: CT.textS(context)),
                        ),
                      if (subject.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subject,
                          style:
                              GoogleFonts.plusJakartaSans(fontSize: 12, color: color),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (time.isNotEmpty)
                            _chipInfo(Icons.access_time_outlined, time),
                          if (time.isNotEmpty) const SizedBox(width: 14),
                          _chipInfo(Icons.timer_outlined, '$duration min'),
                          if (totalMarks.toString().isNotEmpty) ...[
                            const SizedBox(width: 14),
                            _chipInfo(Icons.grade_outlined, '$totalMarks marks'),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: 200 + index * 80))
        .fadeIn()
        .slideX(begin: 0.08, end: 0);
  }

  Widget _chipInfo(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 13, color: CT.textM(context)),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textS(context)),
          ),
        ],
      );
}
