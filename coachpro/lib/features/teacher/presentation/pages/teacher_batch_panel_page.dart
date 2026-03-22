import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../data/repositories/teacher_repository.dart';

class TeacherBatchPanelPage extends StatefulWidget {
  final String batchId;

  const TeacherBatchPanelPage({super.key, required this.batchId});

  @override
  State<TeacherBatchPanelPage> createState() => _TeacherBatchPanelPageState();
}

class _TeacherBatchPanelPageState extends State<TeacherBatchPanelPage> {
  final _repo = sl<TeacherRepository>();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _batch;
  Map<String, dynamic> _execution = {};
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _doubts = [];
  final Set<String> _completedTopicIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final batchesFuture = _repo.getMyBatches();
      final studentsFuture = _repo.getBatchStudents(widget.batchId);
      final executionFuture = _repo.getBatchExecutionSummary(widget.batchId);

      final batches = await batchesFuture;
      final students = await studentsFuture;
      final execution = await executionFuture;

      final selected = batches.where((b) => (b['id'] ?? '').toString() == widget.batchId).cast<Map<String, dynamic>>().toList();
      final fallbackBatch = selected.isNotEmpty ? selected.first : <String, dynamic>{};
      final batch = Map<String, dynamic>.from((execution['batch'] as Map?) ?? fallbackBatch);

      final pendingDoubts = (((execution['doubts'] as Map?)?['pending_items']) as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final topics = (((execution['syllabus'] as Map?)?['topics']) as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final completedTopicIds = topics
          .where((topic) => _toNum(topic['completion_percent']) >= 100)
          .map((topic) => (topic['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      if (!mounted) return;
      setState(() {
        _batch = batch;
        _execution = execution;
        _students = students;
        _doubts = pendingDoubts;
        _completedTopicIds
          ..clear()
          ..addAll(completedTopicIds);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_batch?['name'] ?? 'Batch Panel').toString();
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: CT.bg(context),
        appBar: AppBar(
          title: Text(name, style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
          bottom: TabBar(
            isScrollable: true,
            labelColor: const Color(0xFF0D1282),
            unselectedLabelColor: CT.textM(context),
            indicatorColor: const Color(0xFF0D1282),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Content'),
              Tab(text: 'Students'),
              Tab(text: 'Tests'),
              Tab(text: 'Attendance'),
              Tab(text: 'Doubts'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: GoogleFonts.dmSans(color: CT.textM(context))))
                : TabBarView(
                    children: [
                      _overviewTab(),
                      _contentTab(),
                      _studentsTab(),
                      _testsTab(),
                      _attendanceTab(),
                      _doubtsTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _overviewTab() {
    final subject = (_batch?['subject'] ?? 'Subject').toString();
    final nextClass = (_batch?['start_time'] ?? '--').toString();
    final overview = Map<String, dynamic>.from((_execution['overview'] as Map?) ?? const {});
    final progress = _toNum(overview['teaching_progress_percent']).round();
    final lastLecture = Map<String, dynamic>.from((overview['last_lecture'] as Map?) ?? const {});
    final lastLectureSummary = (lastLecture['title'] ?? lastLecture['description'] ?? 'No lecture summary yet').toString();
    final studentsCount = _toNum(_batch?['student_count']).toInt();

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
      children: [
        _card(child: Text('Batch Info', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context)))),
        const SizedBox(height: 10),
        _infoCard('Your Subject', subject),
        _infoCard('Total Students', '${studentsCount > 0 ? studentsCount : _students.length}'),
        _infoCard('Teaching Progress', '$progress%'),
        _infoCard('Last Lecture Summary', lastLectureSummary),
        _infoCard('Upcoming Class', nextClass),
      ],
    );
  }

  Widget _contentTab() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFF0D1282),
            unselectedLabelColor: Color(0xFF6B7280),
            indicatorColor: Color(0xFF0D1282),
            tabs: [
              Tab(text: 'Lectures'),
              Tab(text: 'Notes'),
              Tab(text: 'Assignments'),
              Tab(text: 'Materials'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _lecturesPane(),
                _notesPane(),
                _assignmentsPane(),
                _materialsPane(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lecturesPane() {
    final topics = (((_execution['syllabus'] as Map?)?['topics']) as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final selectedTopic = topics.isNotEmpty ? topics.first : null;
    final selectedTopicName = selectedTopic == null
        ? 'N/A'
        : ((selectedTopic['topic_name'] ?? 'Topic').toString());
    final selectedTopicCompletion = selectedTopic == null ? 0 : _toNum(selectedTopic['completion_percent']).round();

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Syllabus Tracker', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
              const SizedBox(height: 8),
              if (topics.isEmpty)
                Text('No syllabus topics configured for this batch yet.', style: GoogleFonts.dmSans(color: CT.textM(context)))
              else
              ...topics.map((topic) {
                final topicId = (topic['id'] ?? '').toString();
                final chapter = (topic['chapter_name'] ?? '').toString();
                final topicName = (topic['topic_name'] ?? 'Topic').toString();
                final completed = _completedTopicIds.contains(topicId);
                final completion = _toNum(topic['completion_percent']).round();
                return CheckboxListTile(
                  value: completed,
                  dense: true,
                  onChanged: (v) {
                    if (topicId.isEmpty) return;
                    setState(() {
                      if (v == true) {
                        _completedTopicIds.add(topicId);
                      } else {
                        _completedTopicIds.remove(topicId);
                      }
                    });
                  },
                  activeColor: const Color(0xFF0D1282),
                  checkColor: const Color(0xFFEEEDED),
                  title: Text(chapter.isEmpty ? topicName : '$chapter → $topicName', style: GoogleFonts.dmSans(color: CT.textH(context))),
                  subtitle: Text('Class completion: $completion%', style: GoogleFonts.dmSans(fontSize: 11, color: CT.textM(context))),
                  secondary: completed ? const Icon(Icons.check_circle, color: Color(0xFF0D1282), size: 18) : null,
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lecture Execution', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
              const SizedBox(height: 8),
              _miniLine('YouTube Link', 'https://youtu.be/...'),
              _miniLine('Views', '126'),
              _miniLine('Completion', '$selectedTopicCompletion%'),
              _miniLine('Linked Topic', selectedTopicName),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _chip('Start Class', bg: const Color(0xFF0D1282), fg: const Color(0xFFEEEDED)),
                  _chip('Mark Complete', bg: const Color(0xFFF0DE36), fg: const Color(0xFF0D1282)),
                  _chip('Edit', bg: const Color(0xFFEEEDED), fg: const Color(0xFF0D1282), bordered: true),
                ],
              ),
              const SizedBox(height: 12),
              Text('Live Class System', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
              const SizedBox(height: 6),
              Text('Pre-class: Start Class • During: Focus mode (student count/chat/mute) • Post: upload recording + add notes', style: GoogleFonts.dmSans(color: CT.textM(context))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notesPane() => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        children: [
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Notes', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
            const SizedBox(height: 8),
            _miniLine('Upload', 'PDF'),
            _miniLine('Replace', 'Enabled'),
            _miniLine('Downloads', '84'),
          ])),
        ],
      );

  Widget _assignmentsPane() => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        children: [
          Builder(builder: (context) {
            final assignments = Map<String, dynamic>.from((_execution['assignments'] as Map?) ?? const {});
            final pending = _toNum(assignments['pending_evaluation_count']).toInt();
            final late = _toNum(assignments['late_submissions_count']).toInt();
            return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Assignments', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
              const SizedBox(height: 8),
              _miniLine('Pending Evaluation', '$pending'),
              _miniLine('Late Submissions', '$late'),
              _miniLine('Deadline', 'Configured per assignment'),
              const SizedBox(height: 8),
              Text('Grading UX: left submission + right marks/remarks, swipe next student without reload.', style: GoogleFonts.dmSans(color: CT.textM(context))),
            ]));
          }),
        ],
      );

  Widget _materialsPane() => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        children: [
          _card(child: Text('Upload and organize class materials quickly from this tab.', style: GoogleFonts.dmSans(color: CT.textH(context)))),
        ],
      );

  Widget _studentsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final s = _students[index];
        final name = (s['name'] ?? 'Student').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: CT.cardDecor(context),
          child: Row(
            children: [
              Expanded(child: Text(name, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: CT.textH(context)))),
              Text('Attendance 84%', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textM(context))),
              const SizedBox(width: 8),
              Text('Pending 1', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFD71313))),
            ],
          ),
        );
      },
    );
  }

  Widget _testsTab() => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        children: [
          Builder(builder: (context) {
            final tests = Map<String, dynamic>.from((_execution['tests'] as Map?) ?? const {});
            final avg = _toNum(tests['avg_score']);
            final topper = Map<String, dynamic>.from((tests['topper'] as Map?) ?? const {});
            final topperName = (topper['student_name'] ?? 'N/A').toString();
            final topperScore = _toNum(topper['score']).toInt();
            final weak = ((tests['weak_students'] as List?) ?? const []).length;

            return Column(
              children: [
                _infoCard('Average Score', avg.toStringAsFixed(1)),
                _infoCard('Topper', '$topperName ($topperScore)'),
                _infoCard('Weak Students', '$weak students'),
              ],
            );
          }),
        ],
      );

  Widget _attendanceTab() => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        children: [
          Builder(builder: (context) {
            final attendance = Map<String, dynamic>.from((_execution['attendance'] as Map?) ?? const {});
            final low = ((attendance['low_attendance_students'] as List?) ?? const []).length;
            return Column(
              children: [
                _infoCard('Today Attendance', 'Mark in attendance tab'),
                _infoCard('Low Attendance', '$low students highlighted'),
              ],
            );
          }),
          _infoCard('Quick Notify', 'Enabled for low attendance'),
        ],
      );

  Widget _doubtsTab() {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
      children: [
        ..._doubts.map((d) {
          final student = ((d['student'] as Map?)?['name'] ?? 'Student').toString();
          final question = (d['question_text'] ?? '').toString();
          final topic = (d['topic'] ?? (_batch?['subject'] ?? 'Topic')).toString();
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: CT.cardDecor(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$student • $topic', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
                const SizedBox(height: 6),
                Text(question.isEmpty ? 'No question text' : question, style: GoogleFonts.dmSans(color: CT.textH(context))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('Resolved', bg: const Color(0xFFEEEDED), fg: const Color(0xFF0D1282), bordered: true),
                    _chip('Pending', bg: const Color(0xFFF0DE36), fg: const Color(0xFF0D1282)),
                    _chip('Discuss in class', bg: const Color(0xFFD71313), fg: const Color(0xFFEEEDED)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  num _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: CT.cardDecor(context),
        child: child,
      );

  Widget _infoCard(String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: CT.cardDecor(context),
        child: Row(
          children: [
            Expanded(child: Text(label, style: GoogleFonts.dmSans(color: CT.textM(context)))),
            Text(value, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: CT.textH(context))),
          ],
        ),
      );

  Widget _miniLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: GoogleFonts.dmSans(color: CT.textM(context)))),
            Text(value, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: CT.textH(context))),
          ],
        ),
      );

  Widget _chip(String label, {required Color bg, required Color fg, bool bordered = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: bordered ? Border.all(color: const Color(0xFF0D1282).withValues(alpha: 0.25)) : null,
        ),
        child: Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 11, color: fg)),
      );
}
