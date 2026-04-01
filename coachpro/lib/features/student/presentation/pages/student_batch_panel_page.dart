import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../data/repositories/student_repository.dart';

class StudentBatchPanelPage extends StatefulWidget {
  final String batchId;
  final Map<String, dynamic> batchInfo;
  final int initialTabIndex;
  final List<String>? subjects;

  const StudentBatchPanelPage({
    super.key,
    required this.batchId,
    this.batchInfo = const {},
    this.initialTabIndex = 0,
    this.subjects,
  });

  @override
  State<StudentBatchPanelPage> createState() => _StudentBatchPanelPageState();
}

class _StudentBatchPanelPageState extends State<StudentBatchPanelPage> {
  static const primaryBlue = AppColors.elitePrimary;
  static const surfaceWhite = AppColors.offWhite;
  static const accentYellow = AppColors.moltenAmber;

  String? _selectedSubject;
  List<String> _subjects = [];
  int _refreshKey = 0;
  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    _parseSubjects();
    _subscribeToRealtimeSync();
  }

  void _subscribeToRealtimeSync() {
    final sync = sl<RealtimeSyncService>();
    sync.joinBatch(widget.batchId);
    _syncSub = sync.updates.listen((event) {
      final type = event['type'] as String?;
      final reason = (event['reason'] ?? '') as String;
      final eventBatchId = (event['batch_id'] ?? '') as String;

      // Reload on relevant batch_sync or dashboard_sync events
      if (type == 'batch_sync' || type == 'dashboard_sync') {
        if (eventBatchId.isEmpty || eventBatchId == widget.batchId) {
          if (reason.contains('lecture') ||
              reason.contains('schedule') ||
              reason.contains('attendance') ||
              reason.contains('assignment') ||
              reason.contains('doubt') ||
              reason.contains('quiz') ||
              reason.contains('note') ||
              reason.contains('material') ||
              reason.contains('content')) {
            if (mounted) setState(() => _refreshKey++);
          }
        }
      }
    });
  }

  void _parseSubjects() {
    final meta = widget.batchInfo['meta'] ?? {};
    final subs = meta['subjects'];
    if (subs is List) {
      _subjects = subs.map((e) => e.toString()).toList();
    } else if (subs is String && subs.isNotEmpty) {
      _subjects = subs
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_subjects.isNotEmpty && _selectedSubject == null) {
      return _buildSubjectSelector();
    }

    final name = (widget.batchInfo['name'] ?? 'Batch').toString();
    return DefaultTabController(
      length: 7,
      initialIndex: widget.initialTabIndex.clamp(0, 6),
      child: Scaffold(
        backgroundColor: primaryBlue,
        appBar: AppBar(
          backgroundColor: primaryBlue,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              if (_subjects.isNotEmpty && _selectedSubject != null) {
                setState(() => _selectedSubject = null);
              } else {
                context.pop();
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              if (_selectedSubject != null)
                Text(
                  _selectedSubject!.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: accentYellow,
                  ),
                ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: accentYellow,
            indicatorWeight: 4,
            labelPadding: const EdgeInsets.symmetric(horizontal: 24),
            labelColor: accentYellow,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            labelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'CONTENT'),
              Tab(text: 'SCHEDULE'),
              Tab(text: 'ASSIGNMENTS'),
              Tab(text: 'QUIZZES'),
              Tab(text: 'ATTENDANCE'),
              Tab(text: 'RESULTS'),
              Tab(text: 'DOUBTS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ContentTab(
              key: ValueKey('content_$_refreshKey'),
              batchId: widget.batchId,
              batchInfo: widget.batchInfo,
              selectedSubject: _selectedSubject,
            ),
            _ScheduleTab(
              key: ValueKey('schedule_$_refreshKey'),
              batchId: widget.batchId,
              selectedSubject: _selectedSubject,
            ),
            _AssignmentsPane(
              key: ValueKey('assignments_$_refreshKey'),
              batchId: widget.batchId,
              teacherName: widget.batchInfo['teacher_name'],
              selectedSubject: _selectedSubject,
            ),
            _QuizPane(
              key: ValueKey('quiz_$_refreshKey'),
              batchId: widget.batchId,
              selectedSubject: _selectedSubject,
            ),
            _AttendanceTab(
              key: ValueKey('attendance_$_refreshKey'),
              batchId: widget.batchId,
              selectedSubject: _selectedSubject,
            ),
            _ResultsTab(
              key: ValueKey('results_$_refreshKey'),
              batchId: widget.batchId,
              selectedSubject: _selectedSubject,
            ),
            _DoubtsTab(
              key: ValueKey('doubts_$_refreshKey'),
              batchId: widget.batchId,
              batchInfo: widget.batchInfo,
              selectedSubject: _selectedSubject,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectSelector() {
    final name = (widget.batchInfo['name'] ?? 'Batch').toString();
    return Scaffold(
      backgroundColor: primaryBlue,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'SELECT SUBJECT',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Batch: ${name.toUpperCase()}',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _subjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final sub = _subjects[i];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _selectedSubject = sub);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(6, 6)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accentYellow,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: const Icon(
                            Icons.folder_rounded,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            sub.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: primaryBlue,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab Implementations ───────────────────────────────────────

class _ContentTab extends StatelessWidget {
  final String batchId;
  final Map<String, dynamic> batchInfo;
  final String? selectedSubject;

  const _ContentTab({
    required this.batchId,
    required this.batchInfo,
    this.selectedSubject,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: _StudentBatchPanelPageState.primaryBlue.withValues(
              alpha: 0.5,
            ),
            child: TabBar(
              indicatorColor: _StudentBatchPanelPageState.accentYellow,
              labelColor: _StudentBatchPanelPageState.accentYellow,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
              tabs: const [
                Tab(text: 'VIDEOS'),
                Tab(text: 'NOTES'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _LecturesPane(
                  batchId: batchId,
                  selectedSubject: selectedSubject,
                ),
                _NotesPane(
                  batchId: batchId,
                  teacherName: batchInfo['teacher_name'],
                  selectedSubject: selectedSubject,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LecturesPane extends StatefulWidget {
  final String batchId;
  final String? selectedSubject;
  const _LecturesPane({required this.batchId, this.selectedSubject});

  @override
  State<_LecturesPane> createState() => _LecturesPaneState();
}

class _LecturesPaneState extends State<_LecturesPane> {
  final _repo = sl<StudentRepository>();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = Future.wait([
      _repo.getLectures(
        batchId: widget.batchId,
        subject: widget.selectedSubject,
      ),
      _repo
          .getStudyMaterials(
            batchId: widget.batchId,
            subject: widget.selectedSubject,
          )
          .then((list) {
            return list
                .where(
                  (item) =>
                      (item['file_type'] ?? '').toString().toLowerCase() ==
                      'video',
                )
                .toList();
          }),
    ]).then((lists) => [...lists[0], ...lists[1]]);
  }

  @override
  void didUpdateWidget(_LecturesPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubject != widget.selectedSubject) {
      setState(() => _load());
    }
  }

  Future<void> _refresh() async {
    setState(() => _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: _StudentBatchPanelPageState.accentYellow,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load lectures.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
          );
        }
        final lectures = snapshot.data ?? [];
        if (lectures.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            color: _StudentBatchPanelPageState.accentYellow,
            child: ListView(
              children: [
                _EmptyState(
                  message: 'No lectures available.',
                  icon: Icons.videocam_off_rounded,
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          color: _StudentBatchPanelPageState.accentYellow,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lectures.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final lec = lectures[i];
              final title = (lec['title'] ?? 'Lecture ${i + 1}').toString();
              final teacher = (lec['teacher_name'] ?? 'Teacher').toString();
              final date = (lec['date'] ?? 'Upcoming')
                  .toString()
                  .split('T')
                  .first;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final url = (lec['video_url'] ?? lec['url'] ?? lec['file_url'] ?? '').toString();
                  final isYoutube = url.contains('youtube.com') || url.contains('youtu.be');
                  
                  if (isYoutube) {
                    context.push(
                      '/student/youtube-player',
                      extra: {
                        'videoId': url,
                        'title': title,
                      },
                    );
                  } else {
                    context.push(
                      '/student/video-player',
                      extra: {
                        'videoUrl': url,
                        'title': title,
                        'lectureId': lec['id']?.toString() ?? '',
                      },
                    );
                  }
                },
                child: _PremiumCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _StudentBatchPanelPageState.primaryBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: _StudentBatchPanelPageState.primaryBlue,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'By $teacher',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                color: _StudentBatchPanelPageState.primaryBlue
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 12,
                                  color:
                                      _StudentBatchPanelPageState.primaryBlue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  date,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color:
                                        _StudentBatchPanelPageState.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _StudentBatchPanelPageState.accentYellow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _StudentBatchPanelPageState.primaryBlue,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: _StudentBatchPanelPageState.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _NotesPane extends StatefulWidget {
  final String batchId;
  final String? teacherName;
  final String? selectedSubject;
  const _NotesPane({
    required this.batchId,
    this.teacherName,
    this.selectedSubject,
  });

  @override
  State<_NotesPane> createState() => _NotesPaneState();
}

class _NotesPaneState extends State<_NotesPane> {
  final _repo = sl<StudentRepository>();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _repo
        .getStudyMaterials(
          batchId: widget.batchId,
          subject: widget.selectedSubject,
        )
        .then((list) {
          return list.where((item) {
            final type = (item['file_type'] ?? '').toString().toLowerCase();
            final title = (item['title'] ?? '').toString().toLowerCase();
            // Strictly exclude non-notes
            return type != 'video' && 
                   type != 'assignment' && 
                   !title.contains('assignment') && 
                   !title.contains('test') &&
                   !title.contains('quiz');
          }).toList();
        });
  }

  @override
  void didUpdateWidget(_NotesPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubject != widget.selectedSubject) {
      setState(() => _load());
    }
  }

  Future<void> _refresh() async {
    setState(() => _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: _StudentBatchPanelPageState.accentYellow,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading notes.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
          );
        }
        final notes = snapshot.data ?? [];
        if (notes.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            color: _StudentBatchPanelPageState.accentYellow,
            child: ListView(
              children: [
                _EmptyState(
                  message: 'No notes uploaded yet.',
                  icon: Icons.description_outlined,
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          color: _StudentBatchPanelPageState.accentYellow,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final note = notes[i];
              return _buildItemCard(
                context: context,
                icon: Icons.picture_as_pdf_rounded,
                title: (note['title'] ?? 'Note ${i + 1}').toString(),
                subtitle: 'By ${widget.teacherName ?? "Teacher"}',
                meta: note['file_size_kb'] != null
                    ? '${note['file_size_kb']} KB'
                    : 'PDF',
                onTap: () async {
                  final url = note['file_url']?.toString();
                  if (url != null && url.isNotEmpty) {
                    final uri = Uri.tryParse(url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                      return;
                    }
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No valid link available for this note.'),
                      ),
                    );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _AssignmentsPane extends StatefulWidget {
  final String batchId;
  final String? teacherName;
  final String? selectedSubject;
  const _AssignmentsPane({
    required this.batchId,
    this.teacherName,
    this.selectedSubject,
  });

  @override
  State<_AssignmentsPane> createState() => _AssignmentsPaneState();
}

class _AssignmentsPaneState extends State<_AssignmentsPane> {
  final _repo = sl<StudentRepository>();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _repo
        .getAssignments(
          batchId: widget.batchId,
          subject: widget.selectedSubject,
        );
  }

  @override
  void didUpdateWidget(_AssignmentsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubject != widget.selectedSubject) {
      setState(() => _load());
    }
  }

  Future<void> _refresh() async {
    setState(() => _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: _StudentBatchPanelPageState.accentYellow,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading assignments.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
          );
        }
        final assignments = snapshot.data ?? [];
        if (assignments.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            color: _StudentBatchPanelPageState.accentYellow,
            child: ListView(
              children: [
                _EmptyState(
                  message: 'No assignments uploaded.',
                  icon: Icons.assignment_outlined,
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          color: _StudentBatchPanelPageState.accentYellow,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: assignments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final assignment = assignments[i];
              return _buildItemCard(
                context: context,
                icon: Icons.assignment_rounded,
                title: (assignment['title'] ?? 'Assignment ${i + 1}')
                    .toString(),
                subtitle:
                    (assignment['description'] ?? 'Download to view details')
                        .toString(),
                meta: 'SUBMIT',
                onTap: () {
                  context.push(
                    '/student/assignment-submit',
                    extra: {
                      'assignmentId': assignment['id']?.toString() ?? '',
                      'title': assignment['title']?.toString() ?? 'Assignment',
                      'fileUrl': assignment['file_url']?.toString(),
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _QuizPane extends StatefulWidget {
  final String batchId;
  final String? selectedSubject;
  const _QuizPane({required this.batchId, this.selectedSubject});

  @override
  State<_QuizPane> createState() => _QuizPaneState();
}

class _QuizPaneState extends State<_QuizPane> {
  final _repo = sl<StudentRepository>();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _repo.getAvailableQuizzes(subject: widget.selectedSubject).then((
      list,
    ) {
      if (widget.batchId.isEmpty) return list;
      return list
          .where((q) => (q['batch_id'] ?? '').toString() == widget.batchId)
          .toList();
    });
  }

  @override
  void didUpdateWidget(_QuizPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubject != widget.selectedSubject) {
      setState(() => _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: _StudentBatchPanelPageState.accentYellow,
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _EmptyState(
            message: 'No quizzes available for this batch.',
            icon: Icons.quiz_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final q = items[i];
            return _buildItemCard(
              context: context,
              icon: Icons.timer_outlined,
              title: (q['title'] ?? 'Quiz').toString(),
              subtitle:
                  '${q['questions_count'] ?? q['_count']?['questions'] ?? 0} Questions • ${q['time_limit_min'] ?? 0} mins',
              meta: 'START',
              onTap: () {
                final quizId = q['id']?.toString() ?? '';
                if (quizId.isEmpty) return;
                context.push('/student/quiz/$quizId');
              },
            );
          },
        );
      },
    );
  }
}

class _ScheduleTab extends StatefulWidget {
  final String batchId;
  final String? selectedSubject;
  const _ScheduleTab({required this.batchId, this.selectedSubject});

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  final _repo = sl<StudentRepository>();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _repo.getTodaySchedule(
      batchId: widget.batchId,
      subject: widget.selectedSubject,
    );
  }

  @override
  void didUpdateWidget(_ScheduleTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubject != widget.selectedSubject) {
      setState(() => _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: _StudentBatchPanelPageState.accentYellow,
            ),
          );
        }
        final schedule = snapshot.data ?? [];
        if (schedule.isEmpty) {
          return _EmptyState(
            message: 'No classes scheduled for today.',
            icon: Icons.event_available_rounded,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: schedule.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final item = schedule[i];
            return _PremiumCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C7CFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _StudentBatchPanelPageState.primaryBlue,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['subject'] ?? 'Class').toString().toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: _StudentBatchPanelPageState.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item['start_time'] ?? 'TBA'} - ${item['end_time'] ?? 'TBA'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: _StudentBatchPanelPageState.primaryBlue
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => context.push(
                      '/student/live-session',
                      extra: {
                        'batchId': widget.batchId,
                        'sessionId': item['id'],
                        'subject': item['subject'],
                      },
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _StudentBatchPanelPageState.accentYellow,
                      foregroundColor: _StudentBatchPanelPageState.primaryBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(
                          color: _StudentBatchPanelPageState.primaryBlue,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      'JOIN',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ResultsTab extends StatefulWidget {
  final String batchId;
  final String? selectedSubject;
  const _ResultsTab({required this.batchId, this.selectedSubject});

  @override
  State<_ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends State<_ResultsTab> {
  final _repo = sl<StudentRepository>();
  late Future<List<Map<String, dynamic>>> _future;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _repo.getMyResults(
      batchId: widget.batchId,
      month: _selectedMonth.month,
      year: _selectedMonth.year,
      subject: widget.selectedSubject,
    );
  }

  @override
  void didUpdateWidget(_ResultsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubject != widget.selectedSubject) {
      setState(() => _load());
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final first = DateTime(2024);
    final last = DateTime(now.year + 1);

    // Using a simple list for month selection as a quick solution
    final List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    int tempYear = _selectedMonth.year;
    int tempMonth = _selectedMonth.month;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: _StudentBatchPanelPageState.surfaceWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: _StudentBatchPanelPageState.primaryBlue,
                  width: 3,
                ),
              ),
              title: Text(
                'SELECT MONTH',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  color: _StudentBatchPanelPageState.primaryBlue,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setDialogState(() => tempYear--),
                      ),
                      Text(
                        '$tempYear',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: _StudentBatchPanelPageState.primaryBlue,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setDialogState(() => tempYear++),
                      ),
                    ],
                  ),
                  const Divider(),
                  SizedBox(
                    height: 200,
                    width: 300,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1.5,
                          ),
                      itemCount: 12,
                      itemBuilder: (ctx, i) {
                        final isSelected = tempMonth == i + 1;
                        return InkWell(
                          onTap: () => setDialogState(() => tempMonth = i + 1),
                          child: Container(
                            alignment: Alignment.center,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _StudentBatchPanelPageState.accentYellow
                                  : Colors.white,
                              border: Border.all(
                                color: _StudentBatchPanelPageState.primaryBlue,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              months[i].substring(0, 3).toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: _StudentBatchPanelPageState.primaryBlue,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(ctx, DateTime(tempYear, tempMonth)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _StudentBatchPanelPageState.primaryBlue,
                  ),
                  child: const Text(
                    'SELECT',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedMonth = result;
        _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ][_selectedMonth.month - 1];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            onTap: _pickMonth,
            child: _PremiumCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        color: _StudentBatchPanelPageState.primaryBlue,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$monthName ${_selectedMonth.year}',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: _StudentBatchPanelPageState.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'CHANGE',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: _StudentBatchPanelPageState.primaryBlue.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: _StudentBatchPanelPageState.accentYellow,
                  ),
                );
              }
              final allResults = snapshot.data ?? [];
              final results = allResults.where((r) {
                final exam = r['exam'] as Map<String, dynamic>? ?? {};
                return (exam['batch_id'] ?? '').toString() == widget.batchId;
              }).toList();
              if (results.isEmpty) {
                return _EmptyState(
                  message: 'No test results available for this month.',
                  icon: Icons.analytics_outlined,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final res = results[i];
                  final exam = res['exam'] as Map<String, dynamic>? ?? {};
                  final marks = (res['marks_obtained'] ?? res['score'] ?? 0)
                      .toDouble();
                  final total =
                      (exam['total_marks'] ?? res['total_questions'] ?? 100)
                          .toDouble();
                  final pct = total > 0 ? (marks / total * 100) : 0.0;
                  final grade =
                      res['grade']?.toString() ??
                      (pct >= 90
                          ? 'A+'
                          : pct >= 80
                          ? 'A'
                          : pct >= 70
                          ? 'B+'
                          : pct >= 60
                          ? 'B'
                          : pct >= 50
                          ? 'C'
                          : 'D');
                  final isPassed = pct >= 50;
                  return _buildItemCard(
                    context: context,
                    icon: Icons.assignment_turned_in_rounded,
                    title:
                        (res['quiz_title'] ?? exam['title'] ?? 'Test ${i + 1}')
                            .toString(),
                    subtitle: 'Score: ${marks.round()} / ${total.round()}',
                    meta: isPassed ? grade : 'Needs Improvement',
                    onTap: () {},
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AttendanceTab extends StatefulWidget {
  final String batchId;
  final String? selectedSubject;
  const _AttendanceTab({required this.batchId, this.selectedSubject});

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  final _repo = sl<StudentRepository>();
  late Future<Map<String, dynamic>> _future;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _repo.getMyAttendance(
      batchId: widget.batchId,
      month: _selectedMonth.month,
      year: _selectedMonth.year,
      subject: widget.selectedSubject,
    );
  }

  @override
  void didUpdateWidget(_AttendanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubject != widget.selectedSubject) {
      setState(() => _load());
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final first = DateTime(2024);
    final last = DateTime(now.year + 1);

    final List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    int tempYear = _selectedMonth.year;
    int tempMonth = _selectedMonth.month;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: _StudentBatchPanelPageState.surfaceWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: _StudentBatchPanelPageState.primaryBlue,
                  width: 3,
                ),
              ),
              title: Text(
                'ATTENDANCE MONTH',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  color: _StudentBatchPanelPageState.primaryBlue,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setDialogState(() => tempYear--),
                      ),
                      Text(
                        '$tempYear',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: _StudentBatchPanelPageState.primaryBlue,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setDialogState(() => tempYear++),
                      ),
                    ],
                  ),
                  const Divider(),
                  SizedBox(
                    height: 200,
                    width: 300,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1.5,
                          ),
                      itemCount: 12,
                      itemBuilder: (ctx, i) {
                        final isSelected = tempMonth == i + 1;
                        return InkWell(
                          onTap: () => setDialogState(() => tempMonth = i + 1),
                          child: Container(
                            alignment: Alignment.center,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _StudentBatchPanelPageState.accentYellow
                                  : Colors.white,
                              border: Border.all(
                                color: _StudentBatchPanelPageState.primaryBlue,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              months[i].substring(0, 3).toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: _StudentBatchPanelPageState.primaryBlue,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(ctx, DateTime(tempYear, tempMonth)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _StudentBatchPanelPageState.primaryBlue,
                  ),
                  child: const Text(
                    'SELECT',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedMonth = result;
        _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: _StudentBatchPanelPageState.accentYellow,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading attendance',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final summary = data['summary'] ?? {};
        final history = data['history'] as List? ?? [];
        final percentage = (summary['percentage'] ?? 0).toString();
        final present = (summary['present'] ?? 0).toString();
        final total = (summary['total'] ?? 0).toString();

        final monthName = [
          'JANUARY',
          'FEBRUARY',
          'MARCH',
          'APRIL',
          'MAY',
          'JUNE',
          'JULY',
          'AUGUST',
          'SEPTEMBER',
          'OCTOBER',
          'NOVEMBER',
          'DECEMBER',
        ][_selectedMonth.month - 1];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: InkWell(
                  onTap: _pickMonth,
                  child: _PremiumCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              color: _StudentBatchPanelPageState.primaryBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$monthName ${_selectedMonth.year}',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: _StudentBatchPanelPageState.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'CHANGE MONTH',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: _StudentBatchPanelPageState.primaryBlue
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _PremiumCard(
                  child: Column(
                    children: [
                      Text(
                        'ATTENDANCE OVERVIEW',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: _StudentBatchPanelPageState.primaryBlue,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatBox('$percentage%', 'ATTENDANCE'),
                          Container(
                            width: 2,
                            height: 40,
                            color: _StudentBatchPanelPageState.primaryBlue
                                .withValues(alpha: 0.1),
                          ),
                          _buildStatBox(present, 'PRESENT'),
                          Container(
                            width: 2,
                            height: 40,
                            color: _StudentBatchPanelPageState.primaryBlue
                                .withValues(alpha: 0.1),
                          ),
                          _buildStatBox(total, 'TOTAL'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'ATTENDANCE HISTORY',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (history.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: _EmptyState(
                      message: 'No attendance records yet.',
                      icon: Icons.history_rounded,
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final record = history[index];
                    final session = record['session'] ?? {};
                    final rawDate = session['session_date'] as String?;
                    final date = rawDate != null
                        ? rawDate.split('T').first
                        : 'Unknown Date';
                    final status = (record['status'] ?? 'absent')
                        .toString()
                        .toLowerCase();
                    final isPresent = status == 'present';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PremiumCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isPresent
                                    ? AppColors.mintGreen
                                    : AppColors.coralRed,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      _StudentBatchPanelPageState.primaryBlue,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                isPresent
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.cancel_outlined,
                                color: _StudentBatchPanelPageState.primaryBlue,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    date,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: _StudentBatchPanelPageState
                                          .primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    status.toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: isPresent
                                          ? AppColors.mintGreen.withValues(
                                              alpha: 0.8,
                                            )
                                          : AppColors.coralRed.withValues(
                                              alpha: 0.8,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }, childCount: history.length),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: _StudentBatchPanelPageState.primaryBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            color: _StudentBatchPanelPageState.primaryBlue.withValues(
              alpha: 0.6,
            ),
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _DoubtsTab extends StatefulWidget {
  final String batchId;
  final Map<String, dynamic> batchInfo;
  final String? selectedSubject;
  const _DoubtsTab({
    required this.batchId,
    required this.batchInfo,
    this.selectedSubject,
  });

  @override
  State<_DoubtsTab> createState() => _DoubtsTabState();
}

class _DoubtsTabState extends State<_DoubtsTab> {
  final _repo = sl<StudentRepository>();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _repo.getMyDoubts(subject: widget.selectedSubject);
  }

  @override
  void didUpdateWidget(_DoubtsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubject != widget.selectedSubject) {
      setState(() => _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _future = _repo.getMyDoubts(subject: widget.selectedSubject);
        });
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await context.push(
                    '/student/doubts/ask',
                    extra: {
                      'batchId': widget.batchId,
                      'subject':
                          widget.selectedSubject ?? widget.batchInfo['subject'],
                    },
                  );
                  if (mounted) {
                    setState(() {
                      _future = _repo.getMyDoubts(
                        subject: widget.selectedSubject,
                      );
                    });
                  }
                },
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.black,
                ),
                label: Text(
                  'ASK A NEW DOUBT',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _StudentBatchPanelPageState.accentYellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(
                      color: _StudentBatchPanelPageState.primaryBlue,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _StudentBatchPanelPageState.accentYellow,
                    ),
                  );
                }
                final allDoubts = snapshot.data ?? [];
                // Filter locally by batchId just in case
                final doubts = allDoubts
                    .where(
                      (e) => (e['batch_id'] ?? '').toString() == widget.batchId,
                    )
                    .toList();

                if (doubts.isEmpty) {
                  return _EmptyState(
                    message: 'No pending doubts in this batch.',
                    icon: Icons.question_answer_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: doubts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final doubt = doubts[i];
                    return _PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (doubt['status'] == 'resolved'
                                      ? AppColors.mintGreen
                                      : _StudentBatchPanelPageState
                                            .accentYellow),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color:
                                        _StudentBatchPanelPageState.primaryBlue,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  (doubt['status'] ?? 'PENDING')
                                      .toString()
                                      .toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    color:
                                        _StudentBatchPanelPageState.primaryBlue,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                (doubt['created_at'] ?? '')
                                    .toString()
                                    .split('T')
                                    .first,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: _StudentBatchPanelPageState.primaryBlue
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (doubt['question_text'] ?? 'Question').toString(),
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _StudentBatchPanelPageState.primaryBlue,
                            ),
                          ),
                          if (doubt['answer_text'] != null &&
                              doubt['answer_text'].toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _StudentBatchPanelPageState.primaryBlue
                                    .withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _StudentBatchPanelPageState.primaryBlue
                                      .withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'RESPONSE',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      color: _StudentBatchPanelPageState
                                          .primaryBlue,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    doubt['answer_text'],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: _StudentBatchPanelPageState
                                          .primaryBlue
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────

Widget _buildItemCard({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required String meta,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: _PremiumCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _StudentBatchPanelPageState.accentYellow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _StudentBatchPanelPageState.primaryBlue,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: _StudentBatchPanelPageState.primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: _StudentBatchPanelPageState.primaryBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: _StudentBatchPanelPageState.primaryBlue.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                meta,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: _StudentBatchPanelPageState.primaryBlue,
                ),
              ),
              const SizedBox(height: 4),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: _StudentBatchPanelPageState.primaryBlue,
                size: 14,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const _PremiumCard({required this.child, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _StudentBatchPanelPageState.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _StudentBatchPanelPageState.primaryBlue,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: _StudentBatchPanelPageState.primaryBlue,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: _StudentBatchPanelPageState.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _StudentBatchPanelPageState.primaryBlue,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: _StudentBatchPanelPageState.primaryBlue,
                offset: Offset(6, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _StudentBatchPanelPageState.accentYellow,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _StudentBatchPanelPageState.primaryBlue,
                    width: 2,
                  ),
                ),
                child: Icon(icon, size: 40, color: _StudentBatchPanelPageState.primaryBlue),
              ),
              const SizedBox(height: 24),
              Text(
                message.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: _StudentBatchPanelPageState.primaryBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Checking for updates...',
                style: GoogleFonts.plusJakartaSans(
                  color: _StudentBatchPanelPageState.primaryBlue.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
