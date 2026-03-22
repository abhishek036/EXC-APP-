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
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _doubts = [];
  final Set<String> _completedTopics = {'Projectile Motion'};

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
      final batches = await _repo.getMyBatches();
      final selected = batches.where((b) => (b['id'] ?? '').toString() == widget.batchId).cast<Map<String, dynamic>>().toList();
      final batch = selected.isNotEmpty ? selected.first : <String, dynamic>{};
      final students = await _repo.getBatchStudents(widget.batchId);
      final doubts = await _repo.getPendingDoubts();
      if (!mounted) return;
      setState(() {
        _batch = batch;
        _students = students;
        _doubts = doubts.where((d) => ((d['batch'] as Map?)?['id'] ?? '').toString() == widget.batchId).cast<Map<String, dynamic>>().toList();
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
    const progress = 62;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
      children: [
        _card(child: Text('Batch Info', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context)))),
        const SizedBox(height: 10),
        _infoCard('Your Subject', subject),
        _infoCard('Total Students', '${_students.length}'),
        _infoCard('Teaching Progress', '$progress%'),
        _infoCard('Last Lecture Summary', 'Projectile Motion numericals + doubts recap'),
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
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Syllabus Tracker', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
              const SizedBox(height: 8),
              ...[
                'Physics',
                'Mechanics',
                'Kinematics',
                'Projectile Motion',
              ].map((topic) {
                final completed = _completedTopics.contains(topic);
                return CheckboxListTile(
                  value: completed,
                  dense: true,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _completedTopics.add(topic);
                      } else {
                        _completedTopics.remove(topic);
                      }
                    });
                  },
                  activeColor: const Color(0xFF0D1282),
                  checkColor: const Color(0xFFEEEDED),
                  title: Text(topic, style: GoogleFonts.dmSans(color: CT.textH(context))),
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
              _miniLine('Completion', '67%'),
              _miniLine('Linked Topic', 'Projectile Motion'),
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
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Assignments', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
            const SizedBox(height: 8),
            _miniLine('Pending Evaluation', '11'),
            _miniLine('Late Submissions', '4'),
            _miniLine('Deadline', 'Tomorrow 11:59 PM'),
            const SizedBox(height: 8),
            Text('Grading UX: left submission + right marks/remarks, swipe next student without reload.', style: GoogleFonts.dmSans(color: CT.textM(context))),
          ])),
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
          _infoCard('Average Score', '68%'),
          _infoCard('Topper', 'Riya S. (94%)'),
          _infoCard('Weak Students', '5 students'),
        ],
      );

  Widget _attendanceTab() => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        children: [
          _infoCard('Today Attendance', '${_students.isEmpty ? 0 : (_students.length - 2)}/${_students.length} present'),
          _infoCard('Low Attendance', '4 students highlighted'),
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
          final topic = (d['topic'] ?? 'Topic').toString();
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
