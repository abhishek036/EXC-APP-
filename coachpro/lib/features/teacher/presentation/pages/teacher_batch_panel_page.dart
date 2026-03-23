import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/teacher_repository.dart';
import 'attendance_marking_page.dart';
import 'quiz_results_page.dart';

class TeacherBatchPanelPage extends StatefulWidget {
  final String batchId;

  const TeacherBatchPanelPage({super.key, required this.batchId});

  @override
  State<TeacherBatchPanelPage> createState() => _TeacherBatchPanelPageState();
}

class _TeacherBatchPanelPageState extends State<TeacherBatchPanelPage> {
  final _teacherRepo = sl<TeacherRepository>();

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
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final batchesFuture = _teacherRepo.getMyBatches();
      final studentsFuture = _teacherRepo.getBatchStudents(widget.batchId);
      final executionFuture = _teacherRepo.getBatchExecutionSummary(widget.batchId);

      final batches = await batchesFuture;
      final students = await studentsFuture;
      final execution = await executionFuture;

      final selected = batches.where((b) => (b['id'] ?? '').toString() == widget.batchId).toList();
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
    // Force Neo-Brutalist Colors
    const primaryBlue = Color(0xFF0D1282);
    const surfaceWhite = Color(0xFFEEEDED);
    const accentYellow = Color(0xFFF0DE36);
    
    final name = (_batch?['name'] ?? 'Batch Panel').toString();
    
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: primaryBlue,
        appBar: AppBar(
          backgroundColor: primaryBlue,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            name.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: accentYellow,
            indicatorWeight: 4,
            labelColor: accentYellow,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'OVERVIEW'),
              Tab(text: 'CONTENT'),
              Tab(text: 'STUDENTS'),
              Tab(text: 'TESTS'),
              Tab(text: 'ATTENDANCE'),
              Tab(text: 'DOUBTS'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: accentYellow))
            : _error != null
                ? Center(child: _PremiumCard(
                    child: Text(_error!, style: GoogleFonts.plusJakartaSans(color: AppColors.coralRed, fontWeight: FontWeight.bold)),
                  ))
                : TabBarView(
                    children: [
                      _overviewTab(surfaceWhite, accentYellow, primaryBlue),
                      _contentTab(surfaceWhite, accentYellow, primaryBlue),
                      _studentsTab(surfaceWhite, accentYellow, primaryBlue),
                      _testsTab(surfaceWhite, accentYellow, primaryBlue),
                      _attendanceTab(surfaceWhite, accentYellow, primaryBlue),
                      _doubtsTab(surfaceWhite, accentYellow, primaryBlue),
                    ],
                  ),
      ),
    );
  }

  Widget _overviewTab(Color bg, Color yellow, Color blue) {
    final subject = (_batch?['subject'] ?? 'Subject').toString();
    final overview = Map<String, dynamic>.from((_execution['overview'] as Map?) ?? const {});
    final progress = _toNum(overview['teaching_progress_percent']).round();
    final lastLecture = Map<String, dynamic>.from((overview['last_lecture'] as Map?) ?? const {});
    final lastLectureSummary = (lastLecture['title'] ?? 'No lecture yet').toString();
    final studentCount = _students.length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('STATUS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: blue, fontSize: 12, letterSpacing: 1)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: blue, borderRadius: BorderRadius.circular(4)),
                    child: Text('ACTIVE', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(subject.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 24, color: blue, height: 1.1)),
              const SizedBox(height: 8),
              Text('SYLLABUS PROGRESS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: blue.withValues(alpha: 0.6))),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(height: 12, decoration: BoxDecoration(color: blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2), border: Border.all(color: blue, width: 2))),
                  FractionallySizedBox(
                    widthFactor: progress / 100,
                    child: Container(height: 12, decoration: BoxDecoration(color: yellow, borderRadius: BorderRadius.circular(1), border: Border.all(color: blue, width: 1))),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$progress% Completed', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 13, color: blue)),
                  Text('Target: 100%', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 11, color: blue.withValues(alpha: 0.5))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _StatBox(label: 'STUDENTS', value: '$studentCount', icon: Icons.people_outline, blue: blue, yellow: yellow)),
            const SizedBox(width: 16),
            Expanded(child: _StatBox(label: 'DOUBTS', value: '${_doubts.length}', icon: Icons.help_outline, blue: blue, yellow: yellow)),
          ],
        ),
        const SizedBox(height: 20),
        _PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LATEST LECTURE', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: blue, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 12),
              Text(lastLectureSummary, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: blue)),
              const SizedBox(height: 8),
              Text('Uploaded yesterday • 84% student reach', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12, color: blue.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contentTab(Color bg, Color yellow, Color blue) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: blue.withValues(alpha: 0.5),
            child: TabBar(
              indicatorColor: yellow,
              labelColor: yellow,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 11),
              tabs: const [
                Tab(text: 'LECTURES'),
                Tab(text: 'NOTES'),
                Tab(text: 'ASSIGNMENTS'),
                Tab(text: 'SCHEDULES'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _lecturesPane(bg, yellow, blue),
                _simpleListPane('Notes', bg, yellow, blue),
                _assignmentsPane(bg, yellow, blue),
                _simpleListPane('Materials', bg, yellow, blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lecturesPane(Color bg, Color yellow, Color blue) {
    final topics = (((_execution['syllabus'] as Map?)?['topics']) as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SYLLABUS TRACKER', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 16, color: blue)),
              const SizedBox(height: 16),
              if (topics.isEmpty)
                Text('No topics configured.', style: GoogleFonts.plusJakartaSans(color: blue.withValues(alpha: 0.5)))
              else
                ...topics.map((topic) {
                  final topicId = (topic['id'] ?? '').toString();
                  final chapter = (topic['chapter_name'] ?? '').toString();
                  final topicName = (topic['topic_name'] ?? 'Topic').toString();
                  final completed = _completedTopicIds.contains(topicId);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: completed ? yellow.withValues(alpha: 0.1) : Colors.transparent,
                      border: Border.all(color: blue, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CheckboxListTile(
                      value: completed,
                      dense: true,
                      onChanged: (v) async {
                        if (v == null) return;
                        try {
                          setState(() {
                            if (v) {
                              _completedTopicIds.add(topicId);
                            } else {
                              _completedTopicIds.remove(topicId);
                            }
                          });
                          await _teacherRepo.updateSyllabusTopicStatus(
                            batchId: widget.batchId,
                            topicId: topicId,
                            isCompleted: v,
                          );
                        } catch (e) {
                          setState(() {
                            if (v) {
                              _completedTopicIds.remove(topicId);
                            } else {
                              _completedTopicIds.add(topicId);
                            }
                          });
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      activeColor: blue,
                      checkColor: yellow,
                      title: Text(
                        chapter.isEmpty ? topicName : '$chapter: $topicName',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: blue),
                      ),
                      subtitle: Text('BATCH COMPLETION: ${_toNum(topic['completion_percent']).round()}%', 
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 10, color: blue.withValues(alpha: 0.6))),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _simpleListPane(String title, Color bg, Color yellow, Color blue) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 16, color: blue)),
                  _ActionBtn(label: 'ADD NEW', icon: Icons.add, blue: blue, yellow: yellow, onPressed: () {}),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_open_rounded, size: 48, color: blue.withValues(alpha: 0.2)),
                    const SizedBox(height: 12),
                    Text('No $title uploaded yet', style: GoogleFonts.plusJakartaSans(color: blue.withValues(alpha: 0.4), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _assignmentsPane(Color bg, Color yellow, Color blue) {
    final assignments = Map<String, dynamic>.from((_execution['assignments'] as Map?) ?? const {});
    final pending = _toNum(assignments['pending_evaluation_count']).toInt();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ASSIGNMENTS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 16, color: blue)),
                  _ActionBtn(label: 'NEW', icon: Icons.add, blue: blue, yellow: yellow, onPressed: () {}),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: yellow, border: Border.all(color: blue, width: 2), borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: blue, offset: const Offset(3, 3))]),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions_rounded, color: Color(0xFF0D1282)),
                    const SizedBox(width: 12),
                    Expanded(child: Text('$pending SUBMISSIONS NEED REVIEW', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 12, color: blue))),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: blue),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _studentsTab(Color bg, Color yellow, Color blue) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final s = _students[index];
        final name = (s['name'] ?? 'Student').toString();
        return _PremiumCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
               Container(
                 width: 40, height: 40,
                 decoration: BoxDecoration(color: yellow, border: Border.all(color: blue, width: 2), borderRadius: BorderRadius.circular(4)),
                 alignment: Alignment.center,
                 child: Text(name.isNotEmpty ? name[0] : 'S', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: blue)),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(name.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 14, color: blue)),
                     Text('RANK: #${index + 1} • ATTN: 92%', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 10, color: blue.withValues(alpha: 0.5))),
                   ],
                 ),
               ),
               Icon(Icons.more_vert_rounded, color: blue),
            ],
          ),
        );
      },
    );
  }

  Widget _testsTab(Color bg, Color yellow, Color blue) {
    final tests = Map<String, dynamic>.from((_execution['tests'] as Map?) ?? const {});
    final avg = _toNum(tests['avg_score']).toStringAsFixed(1);
    final topper = Map<String, dynamic>.from((tests['topper'] as Map?) ?? const {});

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PERFORMANCE OVERVIEW', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 16, color: blue)),
              const SizedBox(height: 20),
              _InfoRow(label: 'CLASS AVERAGE', value: '$avg%', blue: blue),
              _InfoRow(label: 'BATCH TOPPER', value: (topper['student_name'] ?? 'N/A').toString().toUpperCase(), blue: blue),
              _InfoRow(label: 'QUIZZES TAKEN', value: '${(tests['total_quizzes'] ?? 0)}', blue: blue),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizResultsPage())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yellow,
                    foregroundColor: blue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: blue, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('VIEW DETAILED ANALYTICS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _attendanceTab(Color bg, Color yellow, Color blue) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ATTENDANCE WORKFLOW', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 16, color: blue)),
              const SizedBox(height: 12),
              Text('Track and mark attendance for your students daily.', style: GoogleFonts.plusJakartaSans(color: blue.withValues(alpha: 0.6), fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceMarkingPage())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: blue, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('OPEN ATTENDANCE PORTAL', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _doubtsTab(Color bg, Color yellow, Color blue) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_doubts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: _PremiumCard(child: Text('NO PENDING DOUBTS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: blue))),
            ),
          )
        else
          ..._doubts.map((d) {
            final student = ((d['student'] as Map?)?['name'] ?? 'Student').toString();
            final question = (d['question_text'] ?? '').toString();
            return _PremiumCard(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: blue, borderRadius: BorderRadius.circular(3)), child: Text('PENDING', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900))),
                      const SizedBox(width: 8),
                      Text(student.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 12, color: blue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(question, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: blue)),
                  const SizedBox(height: 16),
                  _ActionBtn(label: 'RESPOND', icon: Icons.reply, blue: blue, yellow: yellow, onPressed: () {}),
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
}

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  const _PremiumCard({required this.child, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: blue, offset: Offset(4, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color blue;
  final Color yellow;

  const _StatBox({required this.label, required this.value, required this.icon, required this.blue, required this.yellow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: blue, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(3, 3))],
      ),
      child: Column(
        children: [
          Icon(icon, color: blue, size: 24),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 24, color: blue)),
          Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 10, color: blue.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color blue;
  const _InfoRow({required this.label, required this.value, required this.blue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: blue.withValues(alpha: 0.6))),
          Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 13, color: blue)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color blue;
  final Color yellow;
  final VoidCallback onPressed;

  const _ActionBtn({required this.label, required this.icon, required this.blue, required this.yellow, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: yellow,
          border: Border.all(color: blue, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: blue),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 10, color: blue)),
          ],
        ),
      ),
    );
  }
}
