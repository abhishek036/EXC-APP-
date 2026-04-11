import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../../../core/utils/file_opener.dart';
import '../../data/repositories/student_repository.dart';

class _DoubtThreadMessage {
  final String label;
  final String text;
  final String? imageUrl;
  final DateTime? timestamp;
  final bool isStudent;

  const _DoubtThreadMessage({
    required this.label,
    required this.text,
    required this.timestamp,
    required this.isStudent,
    this.imageUrl,
  });
}

  enum _QuizBucket { newQuiz, resultReady, oldQuiz }

  class _QuizStateView {
    final _QuizBucket bucket;
    final bool hasAttempt;
    final bool isInProgress;
    final bool isSubmitted;
    final bool resultReleased;
    final bool canRetry;
    final String statusLabel;
    final String resultLabel;
    final String actionLabel;
    final String? scoreLabel;
    final Map<String, dynamic>? attempt;

    const _QuizStateView({
    required this.bucket,
    required this.hasAttempt,
    required this.isInProgress,
    required this.isSubmitted,
    required this.resultReleased,
    required this.canRetry,
    required this.statusLabel,
    required this.resultLabel,
    required this.actionLabel,
    required this.scoreLabel,
    required this.attempt,
    });

    static _QuizStateView fromQuiz(Map<String, dynamic> quiz) {
    final attempts = ((quiz['attempts'] as List?) ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
    final attempt = attempts.isNotEmpty ? attempts.first : null;

    final assessmentType = (quiz['assessment_type'] ?? 'QUIZ')
      .toString()
      .toUpperCase();
    final allowRetry = quiz['allow_retry'] == null
      ? assessmentType == 'QUIZ'
      : quiz['allow_retry'] == true;
    final showInstantResult = quiz['show_instant_result'] == null
      ? assessmentType == 'QUIZ'
      : quiz['show_instant_result'] == true;

    final submittedAt = attempt?['submitted_at'];
    final hasAttempt = attempt != null;
    final isSubmitted = submittedAt != null;
    final isInProgress = hasAttempt && !isSubmitted;
    final resultReleased = isSubmitted && showInstantResult;
    final canRetry = isSubmitted && allowRetry;

    final bucket = !hasAttempt
      ? _QuizBucket.newQuiz
      : resultReleased
        ? _QuizBucket.resultReady
        : _QuizBucket.oldQuiz;

    final resultLabel = !hasAttempt
      ? 'Not started'
      : isInProgress
        ? 'In progress'
        : resultReleased
          ? 'Score ready'
          : 'Held by teacher';

    final scoreLabel = resultReleased
      ? '${attempt?['obtained_marks'] ?? 0}/${attempt?['total_marks'] ?? 0}'
      : isInProgress
        ? 'Resume anytime'
        : isSubmitted
          ? 'Awaiting release'
          : 'Tap to start';

    final actionLabel = !hasAttempt
      ? 'START'
      : isInProgress
        ? 'CONTINUE'
        : resultReleased
          ? 'VIEW RESULT'
          : 'LOCKED';

    final statusLabel = !hasAttempt
      ? 'NEW'
      : isInProgress
        ? 'IN PROGRESS'
        : resultReleased
          ? 'RESULT READY'
          : 'OLD';

    return _QuizStateView(
      bucket: bucket,
      hasAttempt: hasAttempt,
      isInProgress: isInProgress,
      isSubmitted: isSubmitted,
      resultReleased: resultReleased,
      canRetry: canRetry,
      statusLabel: statusLabel,
      resultLabel: resultLabel,
      actionLabel: actionLabel,
      scoreLabel: scoreLabel,
      attempt: attempt,
    );
    }
  }

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
              separatorBuilder: (context, index) => const SizedBox(height: 16),
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
    super.key,
    required this.batchId,
    required this.batchInfo,
    this.selectedSubject,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
                Tab(text: 'SYLLABUS'),
                Tab(text: 'VIDEOS'),
                Tab(text: 'NOTES'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SyllabusPane(
                  batchId: batchId,
                  selectedSubject: selectedSubject,
                ),
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
    _future = (() async {
      Future<List<Map<String, dynamic>>> loadLectureItems({String? subject}) {
        return _repo.getLectures(batchId: widget.batchId, subject: subject);
      }

      Future<List<Map<String, dynamic>>> loadVideoMaterials({String? subject}) {
        return _repo
            .getStudyMaterials(batchId: widget.batchId, subject: subject)
            .then((list) {
              return list
                  .where(
                    (item) =>
                        (item['file_type'] ?? '').toString().toLowerCase() ==
                        'video',
                  )
                  .toList();
            });
      }

      final selected = widget.selectedSubject?.trim();
      var lectures = await loadLectureItems(subject: selected);
      var videos = await loadVideoMaterials(subject: selected);

      if ((selected ?? '').isNotEmpty && lectures.isEmpty && videos.isEmpty) {
        lectures = await loadLectureItems();
        videos = await loadVideoMaterials();
      }

      return [...lectures, ...videos];
    })();
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
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final lec = lectures[i];
              final title = (lec['title'] ?? 'Lecture ${i + 1}').toString();
              final teacher = (lec['teacher_name'] ?? 'Teacher').toString();
              final date = (lec['date'] ?? 'Upcoming')
                  .toString()
                  .split('T')
                  .first;

              return GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  var url =
                      (lec['link'] ??
                              lec['video_url'] ??
                              lec['url'] ??
                              lec['file_url'] ??
                              '')
                          .toString();

                  if (url.trim().isEmpty) {
                    try {
                      final noteId = (lec['id'] ?? '').toString();
                      final primaryFile = lec['primary_file'] as Map?;
                      final fileId = (primaryFile?['id'] ?? '').toString();
                      if (noteId.isNotEmpty && fileId.isNotEmpty) {
                        final access = await _repo.getStudyMaterialAccess(
                          noteId: noteId,
                          fileId: fileId,
                          action: 'view',
                        );
                        url = (access['access_url'] ?? '').toString();
                      }
                    } catch (_) {
                      // Keep graceful fallback below.
                    }
                  }

                  if (url.trim().isEmpty) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Video link not available.')),
                    );
                    return;
                  }

                  if (!context.mounted) return;

                  final lowerUrl = url.toLowerCase();
                  final isYoutube =
                      lowerUrl.contains('youtube.com') ||
                      lowerUrl.contains('youtu.be') ||
                      lowerUrl.contains('youtube-nocookie.com');
                  
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
            // Show as Note if it's explicitly 'note' OR if it's not a video/assignment
            if (type == 'note') return true;
            if (type == 'video' || type == 'assignment') return false;
            
            // Fallback: exclude strings that strongly imply other types
            return !title.contains('video') && 
                   !title.contains('assignment') && 
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

  Map<String, dynamic> _resolvePrimaryFile(Map<String, dynamic> note) {
    final primaryRaw = note['primary_file'];
    if (primaryRaw is Map) {
      return Map<String, dynamic>.from(primaryRaw);
    }

    final filesRaw = note['note_files'];
    if (filesRaw is List) {
      for (final item in filesRaw) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
      }
    }

    return <String, dynamic>{};
  }

  Future<void> _openNote(Map<String, dynamic> note) async {
    try {
      final noteId = (note['id'] ?? '').toString();
      final primary = _resolvePrimaryFile(note);
      final fileId = (primary['id'] ?? '').toString();

      String targetUrl = '';
      String? fileName;
      String? mimeType;

      if (noteId.isNotEmpty && fileId.isNotEmpty) {
        final access = await _repo.getStudyMaterialAccess(
          noteId: noteId,
          fileId: fileId,
          action: 'download',
        );
        targetUrl = (access['access_url'] ?? '').toString();
        fileName = (access['file_name'] ?? '').toString();
        mimeType = (access['mime_type'] ?? '').toString();
      }

      if (targetUrl.isEmpty) {
        targetUrl =
            (primary['file_url'] ?? note['file_url'] ?? '').toString().trim();
      }

      if (targetUrl.isEmpty) {
        throw Exception('No secure file URL available');
      }

      await downloadAndOpenFromUrl(
        url: targetUrl,
        fileName: fileName?.trim().isEmpty ?? true
            ? (primary['file_name'] ?? note['title'] ?? 'note').toString()
            : fileName,
        mimeType: mimeType?.trim().isEmpty ?? true ? null : mimeType,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to download/open this note right now.'),
        ),
      );
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
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final note = notes[i];
              final primary = _resolvePrimaryFile(note);
              final sizeKb = primary['file_size_kb'] ?? note['file_size_kb'];
              return _buildItemCard(
                icon: Icons.picture_as_pdf_rounded,
                title: (note['title'] ?? 'Note ${i + 1}').toString(),
                subtitle: 'By ${widget.teacherName ?? "Teacher"}',
                meta: sizeKb != null
                    ? '$sizeKb KB'
                    : 'PDF',
                onTap: () => _openNote(note),
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
    super.key,
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
    _future = (() async {
      final selected = widget.selectedSubject?.trim();
      var items = await _repo.getAssignments(
        batchId: widget.batchId,
        subject: selected,
      );

      if ((selected ?? '').isNotEmpty && items.isEmpty) {
        items = await _repo.getAssignments(batchId: widget.batchId);
      }

      return items;
    })();
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
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final assignment = assignments[i];
              return _buildItemCard(
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
  const _QuizPane({super.key, required this.batchId, this.selectedSubject});

  @override
  State<_QuizPane> createState() => _QuizPaneState();
}

class _QuizPaneState extends State<_QuizPane> {
  final _repo = sl<StudentRepository>();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _newQuizzes = [];
  List<Map<String, dynamic>> _oldQuizzes = [];

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
      List<Map<String, dynamic>> byBatch(List<Map<String, dynamic>> list) {
        if (widget.batchId.isEmpty) return list;
        return list
            .where((q) => (q['batch_id'] ?? '').toString() == widget.batchId)
            .toList();
      }

      final selected = widget.selectedSubject?.trim();
      var filtered = byBatch(await _repo.getAvailableQuizzes(subject: selected));

      if ((selected ?? '').isNotEmpty && filtered.isEmpty) {
        filtered = byBatch(await _repo.getAvailableQuizzes());
      }

      final newQuizzes = <Map<String, dynamic>>[];
      final oldQuizzes = <Map<String, dynamic>>[];

      for (final rawQuiz in filtered.whereType<Map>()) {
        final quiz = Map<String, dynamic>.from(rawQuiz);
        final state = _quizState(quiz);
        switch (state.bucket) {
          case _QuizBucket.newQuiz:
            newQuizzes.add(quiz);
            break;
          case _QuizBucket.resultReady:
            break;
          case _QuizBucket.oldQuiz:
            oldQuizzes.add(quiz);
            break;
        }
      }

      if (!mounted) return;
      setState(() {
        _newQuizzes = newQuizzes;
        _oldQuizzes = oldQuizzes;
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
  void didUpdateWidget(_QuizPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubject != widget.selectedSubject) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _StudentBatchPanelPageState.accentYellow,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 52, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                'Failed to load quizzes',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TabBar(
              isScrollable: true,
              indicatorColor: _StudentBatchPanelPageState.accentYellow,
              indicatorWeight: 3,
              labelColor: _StudentBatchPanelPageState.accentYellow,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.72),
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              tabs: [
                Tab(text: 'NEW (${_newQuizzes.length})'),
                Tab(text: 'OLD (${_oldQuizzes.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCategoryList(
                  context,
                  _newQuizzes,
                  emptyTitle: 'NO NEW QUIZZES',
                  emptySubtitle: 'Fresh quizzes will show here.',
                ),
                _buildCategoryList(
                  context,
                  _oldQuizzes,
                  emptyTitle: 'NO OLD QUIZZES',
                  emptySubtitle: 'In-progress and held quizzes will show here.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _QuizStateView _quizState(Map<String, dynamic> quiz) =>
      _QuizStateView.fromQuiz(quiz);

  String get _returnTo {
    final current = GoRouterState.of(context).uri.toString();
    return current.startsWith('/student/batches')
        ? current
        : '/student/batches';
  }

  String _quizTakingRoute(String quizId) =>
      '/student/quiz/$quizId?returnTo=${Uri.encodeComponent(_returnTo)}';

  String _quizResultRoute(String quizId) =>
      '/student/quiz/$quizId/result?returnTo=${Uri.encodeComponent(_returnTo)}';

  Widget _buildCategoryList(
    BuildContext context,
    List<Map<String, dynamic>> quizzes, {
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (quizzes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 60,
                color: Colors.white.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 12),
              Text(
                emptyTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _StudentBatchPanelPageState.accentYellow,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: quizzes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _quizCard(quizzes[index], index),
      ),
    );
  }

  Widget _quizCard(Map<String, dynamic> quiz, int index) {
    final state = _quizState(quiz);
    final title = (quiz['title'] ?? 'Quiz').toString();
    final subject = (quiz['subject'] ?? 'General').toString();
    final batchName = (quiz['batch']?['name'] ?? 'Batch').toString();
    final timeLimit = (quiz['time_limit_min'] ?? 0).toString();
    final questionCount = (quiz['_count']?['questions'] ?? 0).toString();
    final quizId = (quiz['id'] ?? '').toString();

    return Container(
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleQuizTap(quiz, state),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _StudentBatchPanelPageState.accentYellow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _StudentBatchPanelPageState.primaryBlue,
                    width: 1.6,
                  ),
                ),
                child: const Icon(
                  Icons.quiz_rounded,
                  color: _StudentBatchPanelPageState.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                            color: _StudentBatchPanelPageState.primaryBlue
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            subject.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _StudentBatchPanelPageState.primaryBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: state.resultReleased
                                ? AppColors.mintGreen.withValues(alpha: 0.18)
                                : state.isSubmitted
                                    ? AppColors.moltenAmber
                                        .withValues(alpha: 0.18)
                                    : _StudentBatchPanelPageState.primaryBlue
                                        .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            state.statusLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _StudentBatchPanelPageState.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _StudentBatchPanelPageState.primaryBlue,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Batch: $batchName',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _StudentBatchPanelPageState.primaryBlue
                            .withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _infoChip(Icons.help_outline, '$questionCount Qs'),
                        _infoChip(Icons.timer_outlined, '$timeLimit mins'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RESULT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: _StudentBatchPanelPageState.primaryBlue
                            .withValues(alpha: 0.65),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.scoreLabel ?? state.resultLabel,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _StudentBatchPanelPageState.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: quizId.isEmpty
                            ? null
                            : () => _handleQuizTap(quiz, state),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: state.resultReleased && state.canRetry
                              ? AppColors.moltenAmber
                              : state.isSubmitted && !state.resultReleased
                                  ? AppColors.coralRed
                                  : _StudentBatchPanelPageState.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          state.actionLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (state.resultReleased && state.canRetry) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: quizId.isEmpty
                              ? null
                              : () => _confirmRetake(quiz),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: _StudentBatchPanelPageState.primaryBlue,
                              width: 1.4,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'RETAKE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _StudentBatchPanelPageState.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: _StudentBatchPanelPageState.primaryBlue.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _StudentBatchPanelPageState.primaryBlue.withValues(alpha: 0.75),
            ),
          ),
        ],
      );

  Future<void> _handleQuizTap(
    Map<String, dynamic> quiz,
    _QuizStateView state,
  ) async {
    final quizId = (quiz['id'] ?? '').toString();
    if (quizId.isEmpty) return;

    if (!state.hasAttempt || state.isInProgress) {
      await _confirmStart(quiz);
      return;
    }

    if (state.resultReleased) {
      context.push(_quizResultRoute(quizId));
      return;
    }

    await _showHeldResultSheet(quiz, state);
  }

  Future<void> _confirmStart(Map<String, dynamic> quiz) async {
    final quizId = (quiz['id'] ?? '').toString();
    if (quizId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: _StudentBatchPanelPageState.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ready to start?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _StudentBatchPanelPageState.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Once you start, the timer will begin. Make sure you have a stable internet connection.',
              style: GoogleFonts.plusJakartaSans(
                color: _StudentBatchPanelPageState.primaryBlue.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push(_quizTakingRoute(quizId));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _StudentBatchPanelPageState.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Start Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRetake(Map<String, dynamic> quiz) async {
    final quizId = (quiz['id'] ?? '').toString();
    if (quizId.isEmpty) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _StudentBatchPanelPageState.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Retake quiz?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _StudentBatchPanelPageState.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will reset your submitted attempt and start a fresh run.',
              style: GoogleFonts.plusJakartaSans(
                color: _StudentBatchPanelPageState.primaryBlue.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _StudentBatchPanelPageState.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retake Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await _repo.startQuizAttempt(quizId);
      if (!mounted) return;
      context.push(_quizTakingRoute(quizId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _showHeldResultSheet(
    Map<String, dynamic> quiz,
    _QuizStateView state,
  ) async {
    final quizTitle = (quiz['title'] ?? 'Quiz').toString();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _StudentBatchPanelPageState.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Result is held',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _StudentBatchPanelPageState.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$quizTitle is submitted, but the teacher has not released the score and solution yet.',
              style: GoogleFonts.plusJakartaSans(
                color: _StudentBatchPanelPageState.primaryBlue.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              state.scoreLabel ?? 'Awaiting release',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _StudentBatchPanelPageState.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _StudentBatchPanelPageState.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTab extends StatefulWidget {
  final String batchId;
  final String? selectedSubject;
  const _ScheduleTab({super.key, required this.batchId, this.selectedSubject});

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
          separatorBuilder: (context, index) => const SizedBox(height: 12),
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
  const _ResultsTab({super.key, required this.batchId, this.selectedSubject});

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
    _future = (() async {
      final selected = widget.selectedSubject?.trim();
      final examResultsFuture = _repo.getMyResults(
        batchId: widget.batchId,
        month: _selectedMonth.month,
        year: _selectedMonth.year,
        subject: selected,
      );

      var availableQuizzes = await _repo.getAvailableQuizzes(subject: selected);
      if ((selected ?? '').isNotEmpty && availableQuizzes.isEmpty) {
        availableQuizzes = await _repo.getAvailableQuizzes();
      }

      final releasedQuizResults = <Map<String, dynamic>>[];
      for (final rawQuiz in availableQuizzes.whereType<Map>()) {
        final quiz = Map<String, dynamic>.from(rawQuiz);
        if ((quiz['batch_id'] ?? '').toString() != widget.batchId) continue;

        final state = _QuizStateView.fromQuiz(quiz);
        if (!state.resultReleased) continue;

        final attempt = state.attempt ?? const <String, dynamic>{};
        final submittedAt =
            _tryParseDate(attempt['submitted_at'])?.toLocal();
        if (submittedAt == null) continue;

        if (submittedAt.month != _selectedMonth.month ||
            submittedAt.year != _selectedMonth.year) {
          continue;
        }

        final obtained = (attempt['obtained_marks'] as num?)?.toDouble() ?? 0;
        final total = (attempt['total_marks'] as num?)?.toDouble() ?? 0;
        final assessmentType =
            (quiz['assessment_type'] ?? 'QUIZ').toString().toUpperCase();

        releasedQuizResults.add({
          'kind': 'quiz',
          'quiz_id': (quiz['id'] ?? '').toString(),
            'title':
              (quiz['title'] ??
                  (assessmentType == 'TEST' ? 'Test Result' : 'Quiz Result'))
                .toString(),
          'subtitle': 'Score: ${obtained.round()} / ${total.round()}',
          'meta': assessmentType == 'TEST' ? 'TEST RESULT' : 'QUIZ RESULT',
          'submitted_at': submittedAt.toIso8601String(),
        });
      }

      final examResults = await examResultsFuture;
      final normalizedExamResults = examResults
          .map((raw) {
            final res = Map<String, dynamic>.from(raw);
            final exam = res['exam'] is Map
                ? Map<String, dynamic>.from(res['exam'] as Map)
                : <String, dynamic>{};

            final examBatchId =
                (exam['batch_id'] ?? res['batch_id'] ?? '').toString();
            if (examBatchId != widget.batchId) return null;

            final marks =
                (res['marks_obtained'] as num?)?.toDouble() ??
                (res['score'] as num?)?.toDouble() ??
                0;
            final total =
                (exam['total_marks'] as num?)?.toDouble() ??
                (res['total_questions'] as num?)?.toDouble() ??
                100;
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

            final linkedQuizId =
                (res['quiz_id'] ?? exam['quiz_id'] ?? exam['id'] ?? '')
                    .toString();

            final submittedAt =
                _tryParseDate(
                      res['submitted_at'] ??
                          res['created_at'] ??
                          exam['scheduled_at'],
                    )
                    ?.toLocal() ??
                DateTime(_selectedMonth.year, _selectedMonth.month, 1);

            return <String, dynamic>{
              'kind': 'exam',
              'quiz_id': linkedQuizId,
              'title':
                  (res['quiz_title'] ?? exam['title'] ?? 'Test Result')
                      .toString(),
              'subtitle': 'Score: ${marks.round()} / ${total.round()}',
              'meta': 'TEST RESULT • $grade',
              'submitted_at': submittedAt.toIso8601String(),
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      final combined = <Map<String, dynamic>>[
        ...releasedQuizResults,
        ...normalizedExamResults,
      ];

      combined.sort((a, b) {
        final aDate = _tryParseDate(a['submitted_at']) ?? DateTime(1970);
        final bDate = _tryParseDate(b['submitted_at']) ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      return combined;
    })();
  }

  String get _returnTo {
    final current = GoRouterState.of(context).uri.toString();
    return current.startsWith('/student/batches')
        ? current
        : '/student/batches';
  }

  String _quizResultRoute(String quizId) =>
      '/student/quiz/$quizId/result?returnTo=${Uri.encodeComponent(_returnTo)}';

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  void didUpdateWidget(_ResultsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubject != widget.selectedSubject) {
      setState(() => _load());
    }
  }

  Future<void> _pickMonth() async {
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
              final results = snapshot.data ?? [];
              if (results.isEmpty) {
                return _EmptyState(
                  message: 'No released results available for this month.',
                  icon: Icons.analytics_outlined,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: results.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final res = results[i];
                  final kind = (res['kind'] ?? 'result').toString();
                  final quizId = (res['quiz_id'] ?? '').toString();
                  return _buildItemCard(
                    icon: kind == 'quiz'
                        ? Icons.quiz_rounded
                        : Icons.assignment_turned_in_rounded,
                    title: (res['title'] ?? 'Result ${i + 1}').toString(),
                    subtitle: (res['subtitle'] ?? 'Score unavailable').toString(),
                    meta: (res['meta'] ?? 'RESULT').toString(),
                    onTap: () {
                      if (quizId.isEmpty) return;
                      context.push(_quizResultRoute(quizId));
                    },
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
  const _AttendanceTab({super.key, required this.batchId, this.selectedSubject});

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
    super.key,
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
  bool _isSendingFollowUp = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _repo.getMyDoubts(
      batchId: widget.batchId,
      subject: widget.selectedSubject,
    );
  }

  Future<void> _openFollowUpDialog(Map<String, dynamic> doubt) async {
    final doubtId = (doubt['id'] ?? '').toString();
    if (doubtId.isEmpty) return;

    final ctrl = TextEditingController();
    String? localError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Follow-up',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _StudentBatchPanelPageState.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ctrl,
                      maxLines: 4,
                      minLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Write your follow-up message...',
                        errorText: localError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSendingFollowUp
                            ? null
                            : () async {
                                final text = ctrl.text.trim();
                                if (text.isEmpty) {
                                  setModalState(() => localError = 'Please enter a message');
                                  return;
                                }
                                if (text.length < 3) {
                                  setModalState(() => localError = 'Message is too short');
                                  return;
                                }

                                final parentMessenger = ScaffoldMessenger.of(this.context);
                                setState(() => _isSendingFollowUp = true);
                                try {
                                  await _repo.submitDoubtFollowUp(
                                    doubtId: doubtId,
                                    message: text,
                                  );
                                  if (!mounted || !sheetContext.mounted) return;
                                  setState(() {
                                    _future = _repo.getMyDoubts(
                                      batchId: widget.batchId,
                                      subject: widget.selectedSubject,
                                    );
                                  });
                                  Navigator.of(sheetContext).pop();
                                  parentMessenger.showSnackBar(
                                    const SnackBar(content: Text('Follow-up sent successfully')),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  parentMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceFirst('Exception: ', ''),
                                      ),
                                    ),
                                  );
                                } finally {
                                  if (mounted) setState(() => _isSendingFollowUp = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _StudentBatchPanelPageState.accentYellow,
                          foregroundColor: Colors.black,
                        ),
                        child: _isSendingFollowUp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Submit Follow-up',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _labelRepresentsStudent(String label, bool defaultIsStudent) {
    final l = label.toLowerCase();
    if (l.contains('teacher') || l.contains('instructor')) return false;
    if (l.contains('student')) return true;
    return defaultIsStudent;
  }

  List<_DoubtThreadMessage> _parseThreadText({
    required String rawText,
    required bool defaultIsStudent,
    required String fallbackLabel,
    DateTime? fallbackTimestamp,
  }) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return const [];

    final blocks = trimmed.split(RegExp(r'\n\s*\n+'));
    final headerPattern = RegExp(r'^\[(.+?)\s*\|\s*(.+?)\]$');
    final messages = <_DoubtThreadMessage>[];

    for (final block in blocks) {
      final rawLines = block
          .split('\n')
          .map((line) => line.trimRight())
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (rawLines.isEmpty) continue;

      var label = fallbackLabel;
      var ts = fallbackTimestamp;
      var contentStart = 0;

      final headerMatch = headerPattern.firstMatch(rawLines.first.trim());
      if (headerMatch != null) {
        label = headerMatch.group(1)?.trim() ?? fallbackLabel;
        ts = DateTime.tryParse((headerMatch.group(2) ?? '').trim()) ?? ts;
        contentStart = 1;
      }

      String? imageUrl;
      final textLines = <String>[];
      for (var i = contentStart; i < rawLines.length; i++) {
        final line = rawLines[i].trim();
        if (line.toLowerCase().startsWith('image:')) {
          final maybeUrl = line.substring(6).trim();
          if (maybeUrl.isNotEmpty) imageUrl = maybeUrl;
          continue;
        }
        textLines.add(rawLines[i]);
      }

      final text = textLines.join('\n').trim();
      if (text.isEmpty && (imageUrl == null || imageUrl.isEmpty)) continue;

      messages.add(
        _DoubtThreadMessage(
          label: label,
          text: text,
          imageUrl: imageUrl,
          timestamp: ts,
          isStudent: _labelRepresentsStudent(label, defaultIsStudent),
        ),
      );
    }

    return messages;
  }

  List<_DoubtThreadMessage> _extractThreadMessages(Map<String, dynamic> doubt) {
    final createdAt = DateTime.tryParse(
      (doubt['createdAt'] ?? doubt['created_at'] ?? '').toString(),
    );
    final resolvedAt = DateTime.tryParse(
      (doubt['resolvedAt'] ?? doubt['resolved_at'] ?? '').toString(),
    );

    final questionText = (doubt['questionText'] ?? doubt['question_text'] ?? '')
        .toString();
    final answerText =
        (doubt['answerText'] ?? doubt['answer_text'] ?? '').toString();

    final fromStudent = _parseThreadText(
      rawText: questionText,
      defaultIsStudent: true,
      fallbackLabel: 'Student Question',
      fallbackTimestamp: createdAt,
    );
    final fromTeacher = _parseThreadText(
      rawText: answerText,
      defaultIsStudent: false,
      fallbackLabel: 'Teacher Reply',
      fallbackTimestamp: resolvedAt ?? createdAt,
    );

    final all = <_DoubtThreadMessage>[
      ...fromStudent,
      ...fromTeacher,
    ];

    all.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return -1;
      if (b.timestamp == null) return 1;
      return a.timestamp!.compareTo(b.timestamp!);
    });

    return all;
  }

  Widget _buildThreadBubble(_DoubtThreadMessage msg) {
    final bubbleColor = msg.isStudent
        ? _StudentBatchPanelPageState.accentYellow.withValues(alpha: 0.20)
        : _StudentBatchPanelPageState.primaryBlue.withValues(alpha: 0.05);
    final borderColor = msg.isStudent
        ? _StudentBatchPanelPageState.accentYellow.withValues(alpha: 0.5)
        : _StudentBatchPanelPageState.primaryBlue.withValues(alpha: 0.20);
    final ts = msg.timestamp == null
        ? ''
        : DateFormat('MMM d, h:mm a').format(msg.timestamp!.toLocal());

    return Align(
      alignment: msg.isStudent ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: msg.isStudent
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                msg.label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  color: _StudentBatchPanelPageState.primaryBlue,
                  letterSpacing: 0.8,
                ),
              ),
              if (ts.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  ts,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: _StudentBatchPanelPageState.primaryBlue.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
              if (msg.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  msg.text,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _StudentBatchPanelPageState.primaryBlue,
                    height: 1.35,
                  ),
                ),
              ],
              if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Attachment: ${msg.imageUrl}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: _StudentBatchPanelPageState.primaryBlue,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _belongsToCurrentBatch(Map<String, dynamic> doubt) {
    final directBatchId =
        (doubt['batch_id'] ?? doubt['batchId'] ?? '').toString();
    final nestedBatchId = ((doubt['batch'] as Map?)?['id'] ?? '').toString();

    if (directBatchId.isEmpty && nestedBatchId.isEmpty) {
      return false;
    }

    return directBatchId == widget.batchId || nestedBatchId == widget.batchId;
  }

  String _buildThreadPreview(
    List<_DoubtThreadMessage> threadMessages,
    Map<String, dynamic> doubt,
  ) {
    for (var i = threadMessages.length - 1; i >= 0; i--) {
      final text = threadMessages[i].text.trim();
      if (text.isNotEmpty) {
        return text.replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }
    return (doubt['question_text'] ?? doubt['questionText'] ?? 'Tap to open')
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _openDoubtThreadSheet({
    required Map<String, dynamic> doubt,
    required List<_DoubtThreadMessage> threadMessages,
  }) async {
    final status = (doubt['status'] ?? 'pending').toString().toLowerCase();
    final isResolved = status == 'resolved';
    final createdAt = DateTime.tryParse(
      (doubt['created_at'] ?? doubt['createdAt'] ?? '').toString(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.86,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(
                color: _StudentBatchPanelPageState.primaryBlue,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isResolved
                              ? AppColors.mintGreen
                              : _StudentBatchPanelPageState.accentYellow,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _StudentBatchPanelPageState.primaryBlue,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: _StudentBatchPanelPageState.primaryBlue,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (createdAt != null)
                        Text(
                          DateFormat('MMM d, yyyy').format(createdAt.toLocal()),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: _StudentBatchPanelPageState.primaryBlue
                                .withValues(alpha: 0.65),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: threadMessages.isEmpty
                      ? Center(
                          child: Text(
                            'No messages in this thread yet.',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: _StudentBatchPanelPageState.primaryBlue
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: threadMessages.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _buildThreadBubble(threadMessages[index]),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSendingFollowUp
                          ? null
                          : () async {
                              Navigator.of(sheetContext).pop();
                              await _openFollowUpDialog(doubt);
                            },
                      icon: const Icon(Icons.reply_all_rounded),
                      label: Text(
                        'FOLLOW-UP',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _StudentBatchPanelPageState.accentYellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(
                            color: _StudentBatchPanelPageState.primaryBlue,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
          _future = _repo.getMyDoubts(
            batchId: widget.batchId,
            subject: widget.selectedSubject,
          );
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
                        batchId: widget.batchId,
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
                    .where(_belongsToCurrentBatch)
                    .toList();

                if (doubts.isEmpty) {
                  return _EmptyState(
                    message: 'No doubts found in this batch.',
                    icon: Icons.question_answer_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: doubts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final doubt = doubts[i];
                    final threadMessages = _extractThreadMessages(doubt);
                    final preview = _buildThreadPreview(threadMessages, doubt);
                    final status = (doubt['status'] ?? 'pending')
                        .toString()
                        .toLowerCase();
                    final createdAt = (doubt['created_at'] ?? doubt['createdAt'] ?? '')
                        .toString();

                    return _PremiumCard(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openDoubtThreadSheet(
                          doubt: doubt,
                          threadMessages: threadMessages,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: status == 'resolved'
                                      ? AppColors.mintGreen
                                      : _StudentBatchPanelPageState.accentYellow,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _StudentBatchPanelPageState.primaryBlue,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  status == 'resolved'
                                      ? Icons.check_circle_rounded
                                      : Icons.question_answer_rounded,
                                  color: _StudentBatchPanelPageState.primaryBlue,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: status == 'resolved'
                                                ? AppColors.mintGreen.withValues(alpha: 0.35)
                                                : _StudentBatchPanelPageState.accentYellow
                                                      .withValues(alpha: 0.35),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: _StudentBatchPanelPageState.primaryBlue,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 10,
                                              color: _StudentBatchPanelPageState.primaryBlue,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          createdAt.split('T').first,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10,
                                            color: _StudentBatchPanelPageState.primaryBlue
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      preview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: _StudentBatchPanelPageState.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: _StudentBatchPanelPageState.primaryBlue,
                              ),
                            ],
                          ),
                        ),
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

  const _PremiumCard({
    required this.child,
    this.padding,
    this.margin,
  });

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

  const _EmptyState({
    required this.message,
    required this.icon,
  });

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


class _SyllabusPane extends StatefulWidget {
  final String batchId;
  final String? selectedSubject;
  const _SyllabusPane({required this.batchId, this.selectedSubject});

  @override
  State<_SyllabusPane> createState() => _SyllabusPaneState();
}

class _SyllabusPaneState extends State<_SyllabusPane> {
  final _repo = sl<StudentRepository>();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _repo.getLectures(
      batchId: widget.batchId,
      subject: widget.selectedSubject,
    );
  }

  @override
  void didUpdateWidget(_SyllabusPane oldWidget) {
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
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Text(
              'SYLLABUS NOT CONFIGURED',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: _StudentBatchPanelPageState.primaryBlue.withValues(alpha: 0.5),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() => _load()),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final topic = items[index];
              final chapter = (topic['chapter_name'] ?? '').toString();
              final title = (topic['topic_name'] ?? topic['title'] ?? '').toString();
              final isComp = (topic['is_completed'] == true) || ((topic['progress'] ?? 0) >= 100);

              return _PremiumCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      isComp ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isComp ? Colors.green : _StudentBatchPanelPageState.primaryBlue,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (chapter.isNotEmpty)
                            Text(
                              chapter.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                color: _StudentBatchPanelPageState.primaryBlue.withValues(alpha: 0.5),
                              ),
                            ),
                          Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _StudentBatchPanelPageState.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
