import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../../../core/services/download_registry.dart';
import '../../../../core/utils/file_opener.dart';
import '../../../../core/utils/stable_token.dart';
import '../../../../core/widgets/download_status_icon.dart';
import '../../data/repositories/teacher_repository.dart';
import '../../../../core/theme/theme_aware.dart';
class TeacherBatchPanelPage extends StatefulWidget {
  final String batchId;
  final int initialTabIndex;

  const TeacherBatchPanelPage({
    super.key,
    required this.batchId,
    this.initialTabIndex = 0,
  });

  @override
  State<TeacherBatchPanelPage> createState() => _TeacherBatchPanelPageState();
}

class _TeacherBatchPanelPageState extends State<TeacherBatchPanelPage> with ThemeAware<TeacherBatchPanelPage> {
  final _teacherRepo = sl<TeacherRepository>();

  bool _loading = true;
  Map<String, dynamic>? _batch;
  Map<String, dynamic> _execution = {};
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _doubts = [];
  List<Map<String, dynamic>> _allBatchDoubts = [];
  List<Map<String, dynamic>> _practiceQuizzes = [];
  List<Map<String, dynamic>> _scheduledTests = [];
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _assignments = [];
  final Set<String> _completedTopicIds = {};
  final Set<String> _manualWeakIds = {};
  final Set<String> _removedWeakIds = {};
  String _studentFilter = 'all';
  String? _selectedSubject;
  List<String> _subjects = [];
  bool _isDeletingQuiz = false;
  final Set<String> _deletingContentIds = {};
  final Set<String> _updatingResultReleaseQuizIds = {};
  String _doubtsView = 'pending';
  DateTime _selectedAttendanceDate = DateTime.now();
  DateTime _selectedQuizMonth = DateTime.now();
  StreamSubscription? _syncSub;

  String? _resolveSubjectForBatch(List<String> subjects) {
    if (subjects.isEmpty) return null;
    final selected = _selectedSubject?.trim();
    if (selected == null || selected.isEmpty) {
      // Default to "all subjects" to avoid accidentally filtering out
      // quizzes/assignments/schedules when batch meta has multiple subjects.
      return null;
    }

    for (final subject in subjects) {
      if (subject.toLowerCase() == selected.toLowerCase()) {
        return subject;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    DownloadRegistry.instance.ensureLoaded();
    _load();
    _initRealtime();
  }

  void _initRealtime() {
    final sync = sl<RealtimeSyncService>();
    sync.joinBatch(widget.batchId);
    _syncSub = sync.updates.listen((event) {
      final type = event['type'] as String?;
      final eventBatchId = (event['batch_id'] ?? '') as String;

      if (type == 'batch_sync' || type == 'dashboard_sync') {
        if (eventBatchId.isEmpty || eventBatchId == widget.batchId) {
          if (mounted) _load();
        }
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  void _openAssignmentReview({String? assignmentId, String? assignmentTitle}) {
    context
        .pushNamed(
          'teacher-batch-assignment-review',
          pathParameters: {'id': widget.batchId},
          extra: {
            'initialAssignmentId': assignmentId,
            'initialAssignmentTitle': assignmentTitle,
          },
        )
        .then((_) => _load());
  }

  Future<void> _openPendingAssignmentReview(int pendingCount) async {
    if (_assignments.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assignments available to review.')),
      );
      return;
    }

    if (pendingCount <= 0) {
      if (_assignments.isEmpty) return;
      final first = _assignments.first;
      _openAssignmentReview(
        assignmentId: (first['id'] ?? '').toString(),
        assignmentTitle: (first['title'] ?? '').toString(),
      );
      return;
    }

    for (final assignment in _assignments) {
      final assignmentId = (assignment['id'] ?? '').toString();
      if (assignmentId.isEmpty) continue;

      try {
        final submissions = await _teacherRepo.getAssignmentSubmissions(
          assignmentId,
        );
        final hasPending = submissions.any((submission) {
          final status = (submission['status'] ?? '').toString().toLowerCase();
          return status == 'submitted' || status == 'late_submission';
        });

        if (hasPending) {
          if (!mounted) return;
          _openAssignmentReview(
            assignmentId: assignmentId,
            assignmentTitle: (assignment['title'] ?? '').toString(),
          );
          return;
        }
      } catch (_) {
        // Keep trying other assignments; fallback to first assignment below.
      }
    }

    // Final fallback - check again if list is not empty
    if (_assignments.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assignments available to review.')),
      );
      return;
    }
    final fallback = _assignments.first;
    if (!mounted) return;
    _openAssignmentReview(
      assignmentId: (fallback['id'] ?? '').toString(),
      assignmentTitle: (fallback['title'] ?? '').toString(),
    );
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
    try {
      final batches = await _teacherRepo.getMyBatches();
      final selected = batches
          .where((b) => (b['id'] ?? '').toString() == widget.batchId)
          .toList();
      if (selected.isEmpty) {
        if (!mounted) return;
        setState(() {
          _batch = null;
          _execution = {};
          _students = [];
          _doubts = [];
          _allBatchDoubts = [];
          _practiceQuizzes = [];
          _scheduledTests = [];
          _notes = [];
          _assignments = [];
          _loading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This batch is no longer assigned to you.'),
            ),
          );
          GoRouter.of(context).go('/teacher/batches');
        });
        return;
      }

      final batchData = selected.first;

      // Parse subjects from meta
      final meta = batchData['meta'] ?? {};
      final subs = meta['subjects'];
      List<String> subjects = [];
      if (subs is List) {
        subjects = subs.map((e) => e.toString()).toList();
      } else if (subs is String && subs.isNotEmpty) {
        subjects = subs
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      final resolvedSubject = _resolveSubjectForBatch(subjects);
      _selectedSubject = resolvedSubject;

      final studentsFuture = _teacherRepo.getBatchStudents(widget.batchId);
      final executionFuture = _teacherRepo.getBatchExecutionSummary(
        widget.batchId,
        subject: resolvedSubject,
      );
      final practiceQuizzesFuture = _teacherRepo.getBatchQuizzes(
        widget.batchId,
        assessmentType: 'QUIZ',
        subject: resolvedSubject,
      );
      final scheduledTestsFuture = _teacherRepo.getBatchQuizzes(
        widget.batchId,
        assessmentType: 'TEST',
        subject: resolvedSubject,
      );
      final notesFuture = _teacherRepo.getBatchNotes(
        widget.batchId,
        subject: resolvedSubject,
      );
      final assignmentsFuture = _teacherRepo.getAssignments(
        batchId: widget.batchId,
        subject: resolvedSubject,
      );
      final pendingDoubtsFuture = _loadBatchPendingDoubts();
      final allDoubtsFuture = _loadBatchDoubts();

      final execution = await executionFuture;
      final students = await studentsFuture;
      final practiceQuizzes = await practiceQuizzesFuture;
      final scheduledTests = await scheduledTestsFuture;
      final notes = await notesFuture;
      final assignments = await assignmentsFuture;
      final apiPendingDoubts = await pendingDoubtsFuture;
      final apiAllDoubts = await allDoubtsFuture;

      final executionPendingDoubts =
          (((execution['doubts'] as Map?)?['pending_items']) as List? ??
                  const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where(_matchesSelectedSubject)
              .toList();

      final pendingDoubts =
          apiPendingDoubts.isNotEmpty ? apiPendingDoubts : executionPendingDoubts;
        final batchDoubts = apiAllDoubts.isNotEmpty
          ? apiAllDoubts
          : pendingDoubts;

      final topics =
          (((execution['syllabus'] as Map?)?['topics']) as List? ?? const [])
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
        _batch = batchData;
        _subjects = subjects;
        _selectedSubject = resolvedSubject;
        _execution = execution;
        _students = students;
        _doubts = pendingDoubts;
        _allBatchDoubts = batchDoubts;
        _practiceQuizzes = practiceQuizzes;
        _scheduledTests = scheduledTests;
        _notes = notes;
        _assignments = assignments;
        _completedTopicIds
          ..clear()
          ..addAll(completedTopicIds);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadBatchPendingDoubts() async {
    try {
      final pending = await _loadBatchDoubts(status: 'pending');
      return pending
          .where(_isDoubtInCurrentBatch)
          .where(_matchesSelectedSubject)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadBatchDoubts({String? status}) async {
    try {
      final doubts = await _teacherRepo.getDoubts(status: status);
      final filtered = doubts
          .where(_isDoubtInCurrentBatch)
          .where(_matchesSelectedSubject)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      filtered.sort((a, b) {
        final aDate = DateTime.tryParse(
          (a['created_at'] ?? a['createdAt'] ?? '').toString(),
        );
        final bDate = DateTime.tryParse(
          (b['created_at'] ?? b['createdAt'] ?? '').toString(),
        );
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      return filtered;
    } catch (_) {
      return const [];
    }
  }

  bool _isDoubtInCurrentBatch(Map<String, dynamic> doubt) {
    final directBatchId =
        (doubt['batch_id'] ?? doubt['batchId'] ?? '').toString();
    final nestedBatchId = ((doubt['batch'] as Map?)?['id'] ?? '').toString();

    if (directBatchId.isEmpty && nestedBatchId.isEmpty) {
      // Some APIs omit batch metadata in batch-scoped responses.
      return true;
    }

    return directBatchId == widget.batchId || nestedBatchId == widget.batchId;
  }

  bool _matchesSelectedSubject(Map<String, dynamic> doubt) {
    final selectedSubject = _selectedSubject?.trim().toLowerCase();
    if (selectedSubject == null || selectedSubject.isEmpty) return true;

    final doubtSubject =
        (doubt['subject'] ??
                doubt['subject_name'] ??
                ((doubt['batch'] as Map?)?['subject']) ??
                '')
            .toString()
            .trim()
            .toLowerCase();

    if (doubtSubject.isEmpty) return true;
    return doubtSubject == selectedSubject;
  }

  bool _isResultReleased(Map<String, dynamic> quiz) {
    if (quiz['show_instant_result'] is bool) {
      return quiz['show_instant_result'] == true;
    }
    final assessmentType =
        (quiz['assessment_type'] ?? 'QUIZ').toString().toUpperCase();
    return assessmentType == 'QUIZ';
  }

  Future<void> _toggleResultRelease(
    Map<String, dynamic> quiz, {
    required String kindLabel,
  }) async {
    final quizId = (quiz['id'] ?? '').toString();
    if (quizId.isEmpty) return;

    final isPublished = quiz['is_published'] == true;
    if (!isPublished) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$kindLabel must be published before releasing results.'),
        ),
      );
      return;
    }

    final title = (quiz['title'] ?? kindLabel).toString();
    final currentlyReleased = _isResultReleased(quiz);
    final targetRelease = !currentlyReleased;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(targetRelease ? 'Release results?' : 'Hold results?'),
        content: Text(
          targetRelease
              ? 'Students will be able to see scores and solutions for "$title".'
              : 'Students will no longer see scores and solutions for "$title".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(targetRelease ? 'Release' : 'Hold'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _updatingResultReleaseQuizIds.add(quizId));
    try {
      await _teacherRepo.updateQuizResultVisibility(
        quizId: quizId,
        showInstantResult: targetRelease,
        allowRetry:
            quiz['allow_retry'] is bool ? (quiz['allow_retry'] as bool) : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetRelease
                ? 'Results released for "$title".'
                : 'Results hidden for "$title".',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update result visibility: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingResultReleaseQuizIds.remove(quizId));
      }
    }
  }

  void _showSubjectPicker(
    BuildContext context,
    Color accentYellow,
    Color surfaceWhite,
    Color primaryBlue,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: const Border(
              top: BorderSide(color: Colors.black, width: 3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SELECT SUBJECT',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: primaryBlue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ...<String?>[null, ..._subjects].map((sub) {
                final isSel = _selectedSubject == sub;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      if (_selectedSubject != sub) {
                        setState(() {
                          _selectedSubject = sub;
                        });
                        _load();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSel ? accentYellow : Colors.white,
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: isSel
                            ? null
                            : const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(4, 4),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            (sub ?? 'All Subjects').toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: primaryBlue,
                            ),
                          ),
                          if (isSel)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.blue,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Force Neo-Brutalist Colors
    const primaryBlue = AppColors.elitePrimary;
    const surfaceWhite = AppColors.offWhite;
    const accentYellow = AppColors.moltenAmber;

    final name = (_batch?['name'] ?? 'Batch Panel').toString();

    return DefaultTabController(
      length: 6,
      initialIndex: widget.initialTabIndex.clamp(0, 5),
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
            onPressed: () => Navigator.pop(context),
          ),
          title: GestureDetector(
            onTap: _subjects.isNotEmpty
                ? () {
                    // Show subject bottom sheet or menu
                    _showSubjectPicker(
                      context,
                      accentYellow,
                      surfaceWhite,
                      primaryBlue,
                    );
                  }
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                if (_subjects.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (_selectedSubject ?? 'All Subjects').toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: accentYellow,
                        ),
                      ),
                      if (_subjects.isNotEmpty)
                        const Icon(
                          Icons.arrow_drop_down,
                          color: accentYellow,
                          size: 18,
                        ),
                    ],
                  ),
              ],
            ),
          ),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: accentYellow,
            indicatorWeight: 4,
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
              Tab(text: 'OVERVIEW'),
              Tab(text: 'CONTENT'),
              Tab(text: 'STUDENTS'),
              Tab(text: 'QUIZ & TESTS'),
              Tab(text: 'ATTENDANCE'),
              Tab(text: 'DOUBTS'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_subjects.isNotEmpty)
                    _buildSubjectSelector(
                      accentYellow,
                      primaryBlue,
                      surfaceWhite,
                    ),
                  Expanded(
                    child: TabBarView(
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
                ],
              ),
      ),
    );
  }

  Widget _overviewTab(Color bg, Color yellow, Color blue) {
    final subject = (_batch?['subject'] ?? 'Subject').toString();
    final overview = Map<String, dynamic>.from(
      (_execution['overview'] as Map?) ?? const {},
    );
    final progress = _toNum(overview['teaching_progress_percent']).round();
    final lastLecture = Map<String, dynamic>.from(
      (overview['last_lecture'] as Map?) ?? const {},
    );
    final lastLectureSummary = (lastLecture['title'] ?? 'No lecture yet')
        .toString();
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
                  Text(
                    'STATUS',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      color: blue,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                subject.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: blue,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SYLLABUS PROGRESS',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: blue.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: blue, width: 2),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress / 100,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: yellow,
                        borderRadius: BorderRadius.circular(1),
                        border: Border.all(color: blue, width: 1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$progress% Completed',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: blue,
                    ),
                  ),
                  Text(
                    'Target: 100%',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: blue.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.pushNamed(
                    'teacher-batch-youtube-live',
                    pathParameters: {'id': widget.batchId},
                  ),
                  icon: const Icon(Icons.videocam, color: Colors.black),
                  label: Text(
                    'GO LIVE ON YOUTUBE',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Colors.black,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: blue, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _StatBox(
                label: 'STUDENTS',
                value: '$studentCount',
                icon: Icons.people_outline,
                blue: blue,
                yellow: yellow,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatBox(
                label: 'DOUBTS',
                value: '${_doubts.length}',
                icon: Icons.help_outline,
                blue: blue,
                yellow: yellow,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LATEST LECTURE',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  color: blue,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                lastLectureSummary,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lastLecture['created_at'] != null
                    ? 'Uploaded ${_formatRelativeDate(lastLecture['created_at'])} • ${_students.isNotEmpty ? '${_students.length} students enrolled' : ''}'
                    : 'No upload date available',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: blue.withValues(alpha: 0.6),
                ),
              ),
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
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
              tabs: const [
                Tab(text: 'SYLLABUS'),
                Tab(text: 'VIDEOS'),
                Tab(text: 'NOTES'),
                Tab(text: 'ASSIGNMENTS'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _lecturesPane(bg, yellow, blue), // Syllabus Tracker
                _simpleListPane('Videos', bg, yellow, blue),
                _simpleListPane('Notes', bg, yellow, blue),
                _assignmentsPane(bg, yellow, blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lecturesPane(Color bg, Color yellow, Color blue) {
    final topics =
        (((_execution['syllabus'] as Map?)?['topics']) as List? ?? const [])
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
              Text(
                'SYLLABUS TRACKER',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: blue,
                ),
              ),
              const SizedBox(height: 16),
              if (topics.isEmpty)
                Text(
                  'No topics configured.',
                  style: GoogleFonts.plusJakartaSans(
                    color: blue.withValues(alpha: 0.5),
                  ),
                )
              else
                ...topics.map((topic) {
                  final topicId = (topic['id'] ?? '').toString();
                  final chapter = (topic['chapter_name'] ?? '').toString();
                  final topicName = (topic['topic_name'] ?? 'Topic').toString();
                  final completed = _completedTopicIds.contains(topicId);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: completed
                          ? yellow.withValues(alpha: 0.1)
                          : Colors.transparent,
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
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      activeColor: blue,
                      checkColor: yellow,
                      title: Text(
                        chapter.isEmpty ? topicName : '$chapter: $topicName',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: blue,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      subtitle: Text(
                        'BATCH COMPLETION: ${_toNum(topic['completion_percent']).round()}%',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: blue.withValues(alpha: 0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
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

  Widget _simpleListPane(String title, Color bg, Color yellow, Color blue) {
    final contentType = title.toLowerCase() == 'videos' ? 'video' : 'note';

    // Filter notes based on the current tab type
    final items = _notes.where((n) {
      final type = (n['file_type'] ?? '').toString().toLowerCase();
      if (contentType == 'video') return type == 'video';
      // For Notes tab, only show things that are NOT videos and NOT assignments
      return type != 'video' && type != 'assignment';
    }).toList();

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
                  Text(
                    title.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: blue,
                    ),
                  ),
                  _ActionBtn(
                    label: 'ADD NEW',
                    icon: Icons.add,
                    blue: blue,
                    yellow: yellow,
                    onPressed: () => context
                        .pushNamed(
                          'teacher-batch-upload-material',
                          pathParameters: {'id': widget.batchId},
                          extra: {
                            'initialType': contentType,
                            'initialSubject': (
                              _batch?['subject'] ??
                              ''
                            ).toString(),
                          },
                        )
                        .then((_) => _load()),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (items.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 48,
                        color: blue.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No $title uploaded yet',
                        style: GoogleFonts.plusJakartaSans(
                          color: blue.withValues(alpha: 0.4),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...items.map((item) {
                  final itemId = (item['id'] ?? '').toString();
                  final isDeleting = _deletingContentIds.contains(itemId);
                  final canDownload = contentType != 'video';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: blue.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          contentType == 'video'
                              ? Icons.play_circle_fill
                              : Icons.description,
                          color: blue,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (item['title'] ?? 'Untitled').toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: blue,
                                ),
                              ),
                              if ((item['description'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text(
                                  item['description'].toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                    color: blue.withValues(alpha: 0.6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                          const SizedBox(width: 8),
                          if (canDownload)
                            IconButton(
                              onPressed: isDeleting ? null : () => _downloadAndOpenNote(item),
                              icon: DownloadStatusIcon(
                                downloadKey: _noteDownloadKey(item),
                                idleIcon: Icons.file_download_outlined,
                                downloadedIcon: Icons.check_circle_rounded,
                                idleColor: blue,
                                downloadedColor: AppColors.success,
                                size: 20,
                                spinnerSize: 20,
                                strokeWidth: 2,
                              ),
                            ),
                          if (canDownload) const SizedBox(width: 4),
                          isDeleting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: blue,
                                  ),
                                )
                              : PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded, color: blue),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openEditContentItem(item, type: contentType);
                                      return;
                                    }
                                    if (value == 'delete') {
                                      _deleteContentItem(
                                        item,
                                        type: contentType,
                                        label: contentType == 'video'
                                            ? 'Video'
                                            : 'Note',
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _assignmentsPane(Color bg, Color yellow, Color blue) {
    final assignmentsSummary = Map<String, dynamic>.from(
      (_execution['assignments'] as Map?) ?? const {},
    );
    final pending = _toNum(
      assignmentsSummary['pending_evaluation_count'],
    ).toInt();
    final late = _toNum(assignmentsSummary['late_submissions_count']).toInt();

    final items = _assignments;

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
                  Text(
                    'ASSIGNMENTS',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: blue,
                    ),
                  ),
                  _ActionBtn(
                    label: 'NEW',
                    icon: Icons.add,
                    blue: blue,
                    yellow: yellow,
                    onPressed: () => context
                        .pushNamed(
                          'teacher-batch-upload-material',
                          pathParameters: {'id': widget.batchId},
                          extra: {
                            'initialType': 'assignment',
                            'initialSubject': (
                              _batch?['subject'] ??
                              ''
                            ).toString(),
                          },
                        )
                        .then((_) => _load()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _openPendingAssignmentReview(pending),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: yellow,
                    border: Border.all(color: blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: blue, offset: const Offset(3, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pending_actions_rounded,
                        color: AppColors.elitePrimary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$pending SUBMISSIONS NEED REVIEW',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: blue,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: blue,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'LATE SUBMISSIONS: $late',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: blue.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'ASSIGNMENT DOCUMENTS',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: blue,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'NO ASSIGNMENTS UPLOADED',
                      style: GoogleFonts.plusJakartaSans(
                        color: blue.withValues(alpha: 0.4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                ...items.map((item) {
                  final assignmentId = (item['id'] ?? '').toString();
                  final isDeleting = _deletingContentIds.contains(assignmentId);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: blue.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      onTap: () => _openAssignmentReview(
                        assignmentId: (item['id'] ?? '').toString(),
                        assignmentTitle: (item['title'] ?? '').toString(),
                      ),
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.assignment_ind_rounded,
                        color: blue,
                        size: 30,
                      ),
                      title: Text(
                        (item['title'] ?? 'Assignment').toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: blue,
                        ),
                      ),
                      subtitle: Text(
                        (item['description'] ?? 'Tap to review submissions')
                            .toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.rate_review_rounded, color: blue),
                            onPressed: () => _openAssignmentReview(
                              assignmentId: assignmentId,
                              assignmentTitle: (item['title'] ?? '').toString(),
                            ),
                          ),
                          isDeleting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: blue,
                                  ),
                                )
                              : PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded, color: blue),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openEditContentItem(
                                        item,
                                        type: 'assignment',
                                      );
                                      return;
                                    }
                                    if (value == 'delete') {
                                      _deleteContentItem(
                                        item,
                                        type: 'assignment',
                                        label: 'Assignment',
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
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

  Widget _studentsTab(Color bg, Color yellow, Color blue) {
    final attendance = Map<String, dynamic>.from(
      (_execution['attendance'] as Map?) ?? const {},
    );
    final tests = Map<String, dynamic>.from(
      (_execution['tests'] as Map?) ?? const {},
    );
    final lowAttendanceIds =
        (((attendance['low_attendance_students'] as List?) ?? const [])
                .whereType<Map>()
                .map((e) => (e['student_id'] ?? '').toString())
                .where((e) => e.isNotEmpty))
            .toSet();
    final weakIds =
        (((tests['weak_students'] as List?) ?? const [])
                .whereType<Map>()
                .map((e) => (e['student_id'] ?? '').toString())
                .where((e) => e.isNotEmpty))
            .toSet();
    final effectiveWeakIds = ({...weakIds, ..._manualWeakIds}
      ..removeAll(_removedWeakIds));
    final pendingWorkIds =
        (_doubts
                .map((e) => ((e['student'] as Map?)?['id'] ?? '').toString())
                .where((e) => e.isNotEmpty))
            .toSet();

    final filtered = _students.where((s) {
      final id = (s['id'] ?? '').toString();
      if (_studentFilter == 'low_attendance') {
        return lowAttendanceIds.contains(id);
      }
      if (_studentFilter == 'weak') return effectiveWeakIds.contains(id);
      if (_studentFilter == 'pending_work') return pendingWorkIds.contains(id);
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip('ALL', 'all', blue, yellow),
              _filterChip('LOW ATTN', 'low_attendance', blue, yellow),
              _filterChip('WEAK', 'weak', blue, yellow),
              _filterChip('PENDING', 'pending_work', blue, yellow),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final s = filtered[index];
              final name = (s['name'] ?? 'Student').toString();
              final id = (s['id'] ?? '').toString();
              final tag = lowAttendanceIds.contains(id)
                  ? 'LOW ATTN'
                  : effectiveWeakIds.contains(id)
                  ? 'WEAK'
                  : pendingWorkIds.contains(id)
                  ? 'PENDING'
                  : 'OK';
              return _PremiumCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: yellow,
                        border: Border.all(color: blue, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        name.isNotEmpty ? name[0] : 'S',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          color: blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: blue,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            'STATUS: $tag',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: blue.withValues(alpha: 0.5),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: blue),
                      onSelected: (value) {
                        if (value == 'view_profile') {
                          _showStudentProfileDialog(s, blue, yellow);
                          return;
                        }
                        if (value == 'view_attendance') {
                          GoRouter.of(context).push('/teacher/attendance');
                          return;
                        }
                        if (value == 'mark_weak') {
                          setState(() {
                            _manualWeakIds.add(id);
                            _removedWeakIds.remove(id);
                          });
                          _showActionSnack(
                            '${name.toUpperCase()} marked as WEAK',
                          );
                          return;
                        }
                        if (value == 'remove_weak') {
                          setState(() {
                            _manualWeakIds.remove(id);
                            _removedWeakIds.add(id);
                          });
                          _showActionSnack(
                            '${name.toUpperCase()} removed from WEAK',
                          );
                          return;
                        }
                        if (value == 'message_parent') {
                          GoRouter.of(context).push('/teacher/chat-list');
                        }
                      },
                      itemBuilder: (ctx) {
                        final isWeak = effectiveWeakIds.contains(id);
                        return [
                          const PopupMenuItem(
                            value: 'view_profile',
                            child: Text('View Profile'),
                          ),
                          const PopupMenuItem(
                            value: 'view_attendance',
                            child: Text('View Attendance'),
                          ),
                          PopupMenuItem(
                            value: isWeak ? 'remove_weak' : 'mark_weak',
                            child: Text(
                              isWeak ? 'Remove Weak Tag' : 'Mark as Weak',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'message_parent',
                            child: Text('Message Parent'),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showActionSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, dynamic> _resolvePrimaryNoteFile(Map<String, dynamic> note) {
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

  String _noteDownloadKey(Map<String, dynamic> note) {
    final noteId = (note['id'] ?? '').toString();
    final primary = _resolvePrimaryNoteFile(note);
    final fileId = (primary['id'] ?? '').toString();

    if (noteId.isNotEmpty && fileId.isNotEmpty) {
      return 'note:$noteId:$fileId';
    }

    final fallbackUrl = (primary['file_url'] ?? note['file_url'] ?? '').toString().trim();
    if (fallbackUrl.isNotEmpty) {
      return 'note-url:${stableToken(fallbackUrl)}';
    }

    final fallbackTitle = (note['title'] ?? 'note').toString();
    return 'note:${stableToken(fallbackTitle)}';
  }

  Future<void> _downloadAndOpenNote(Map<String, dynamic> note) async {
    try {
      final noteId = (note['id'] ?? '').toString();
      final primary = _resolvePrimaryNoteFile(note);
      final fileId = (primary['id'] ?? '').toString();

      String targetUrl = '';
      String? fileName;
      String? mimeType;

      if (noteId.isNotEmpty && fileId.isNotEmpty) {
        final access = await _teacherRepo.getStudyMaterialAccess(
          noteId: noteId,
          fileId: fileId,
          action: 'download',
        );
        targetUrl = (access['access_url'] ?? '').toString().trim();
        fileName = (access['file_name'] ?? '').toString().trim();
        mimeType = (access['mime_type'] ?? '').toString().trim();
      }

      if (targetUrl.isEmpty) {
        targetUrl =
            (primary['file_url'] ?? note['file_url'] ?? '').toString().trim();
      }

      if (targetUrl.isEmpty) {
        throw Exception('No file URL available');
      }

      await downloadAndOpenFromUrl(
        url: targetUrl,
        fileName: fileName?.isEmpty ?? true
            ? (primary['file_name'] ?? note['title'] ?? 'note').toString()
            : fileName,
        mimeType: mimeType?.isEmpty ?? true ? null : mimeType,
        downloadKey: noteId.isNotEmpty && fileId.isNotEmpty
          ? 'note:$noteId:$fileId'
          : (targetUrl.isNotEmpty ? 'note-url:${stableToken(targetUrl)}' : null),
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

  Future<void> _openEditContentItem(
    Map<String, dynamic> item, {
    required String type,
  }) async {
    await context.pushNamed(
      'teacher-batch-upload-material',
      pathParameters: {'id': widget.batchId},
      extra: {
        'initialType': type,
        'initialSubject': (_batch?['subject'] ?? '').toString(),
        'initialItem': item,
      },
    );
    await _load();
  }

  Future<void> _deleteContentItem(
    Map<String, dynamic> item, {
    required String type,
    required String label,
  }) async {
    final itemId = (item['id'] ?? '').toString();
    if (itemId.isEmpty) return;

    final title = (item['title'] ?? label).toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $label?'),
        content: Text('"$title" will be permanently deleted from this batch.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingContentIds.add(itemId));
    try {
      await _teacherRepo.deleteMaterial(itemId: itemId, type: type);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label deleted successfully.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingContentIds.remove(itemId));
      }
    }
  }

  void _showStudentProfileDialog(
    Map<String, dynamic> student,
    Color blue,
    Color yellow,
  ) {
    final name = (student['name'] ?? 'Student').toString();
    final id = (student['id'] ?? '-').toString();
    final status = (student['is_active'] == false) ? 'INACTIVE' : 'ACTIVE';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.offWhite,
        title: Text(
          'STUDENT PROFILE',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            color: blue,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: blue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'STATUS: $status',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: blue.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ID: $id',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: blue.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: blue,
              backgroundColor: yellow,
            ),
            child: Text(
              'CLOSE',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _testsTab(Color bg, Color yellow, Color blue) {
    final tests = Map<String, dynamic>.from(
      (_execution['tests'] as Map?) ?? const {},
    );
    final avg = _toNum(tests['avg_score']).toStringAsFixed(1);
    final topper = Map<String, dynamic>.from(
      (tests['topper'] as Map?) ?? const {},
    );

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
    ][_selectedQuizMonth.month - 1];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        InkWell(
          onTap: () async {
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
            int tempYear = _selectedQuizMonth.year;
            int tempMonth = _selectedQuizMonth.month;

            final result = await showDialog<DateTime>(
              context: context,
              builder: (ctx) => StatefulBuilder(
                builder: (ctx, setDialogState) {
                  return AlertDialog(
                    backgroundColor: bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: blue, width: 3),
                    ),
                    title: Text(
                      'FILTER BY MONTH',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        color: blue,
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
                                color: blue,
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
                                onTap: () =>
                                    setDialogState(() => tempMonth = i + 1),
                                child: Container(
                                  alignment: Alignment.center,
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? yellow : Colors.white,
                                    border: Border.all(color: blue),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    months[i].substring(0, 3).toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      color: blue,
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
                        style: ElevatedButton.styleFrom(backgroundColor: blue),
                        child: const Text(
                          'FILTER',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
            if (result != null) {
              setState(() => _selectedQuizMonth = result);
              _load();
            }
          },
          child: _PremiumCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month, color: blue, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '$monthName ${_selectedQuizMonth.year}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: blue,
                      ),
                    ),
                  ],
                ),
                Text(
                  'CHANGE MONTH',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    color: blue.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        _PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PERFORMANCE OVERVIEW',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: blue,
                ),
              ),
              const SizedBox(height: 20),
              _InfoRow(label: 'CLASS AVERAGE', value: '$avg%', blue: blue),
              _InfoRow(
                label: 'BATCH TOPPER',
                value: (topper['student_name'] ?? 'N/A')
                    .toString()
                    .toUpperCase(),
                blue: blue,
              ),
              _InfoRow(
                label: 'QUIZZES TAKEN',
                value: '${(tests['total_quizzes'] ?? 0)}',
                blue: blue,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final firstQuizId = _practiceQuizzes.isNotEmpty
                        ? (_practiceQuizzes.first['id'] ?? '').toString()
                        : '';
                    final firstTestId = _scheduledTests.isNotEmpty
                        ? (_scheduledTests.first['id'] ?? '').toString()
                        : '';
                    final targetId = firstQuizId.isNotEmpty
                        ? firstQuizId
                        : firstTestId;
                    if (targetId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Create a quiz or test first to view analytics.',
                          ),
                        ),
                      );
                      return;
                    }
                    context.pushNamed(
                      'teacher-batch-quiz-results',
                      pathParameters: {
                        'id': widget.batchId,
                        'quizId': targetId,
                      },
                      queryParameters: const {'title': 'BATCH ANALYTICS'},
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yellow,
                    foregroundColor: blue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: blue, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'VIEW DETAILED ANALYTICS',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'QUIZ (PRACTICE MODE)',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
            _ActionBtn(
              label: 'NEW QUIZ',
              icon: Icons.add,
              blue: blue,
              yellow: yellow,
              onPressed: () async {
                await context.pushNamed(
                  'teacher-batch-create-quiz',
                  pathParameters: {'id': widget.batchId},
                  extra: {
                    'initialSubject': (_batch?['subject'] ?? '').toString(),
                    'initialAssessmentType': 'QUIZ',
                  },
                );
                await _load();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'TOPIC-WISE • DAILY CHALLENGE • 5-20 QUESTIONS • RETRY ALLOWED',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        if (_practiceQuizzes.isEmpty)
          _PremiumCard(
            child: Text(
              'NO QUIZZES CREATED FOR THIS BATCH YET',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: blue.withValues(alpha: 0.6),
              ),
            ),
          )
        else
          ..._practiceQuizzes.map((quiz) {
            final quizId = (quiz['id'] ?? '').toString();
            final title = (quiz['title'] ?? 'QUIZ').toString().toUpperCase();
            final subject = (quiz['subject'] ?? _batch?['subject'] ?? 'GENERAL')
                .toString()
                .toUpperCase();
            final totalQuestions =
                ((quiz['questions'] as List?)?.length ??
                _toNum((quiz['_count'] as Map?)?['questions']).toInt());
            final timeLimit = _toNum(quiz['time_limit_min']).toInt();
            final isPublished = quiz['is_published'] == true;
            final isResultReleased = _isResultReleased(quiz);
            final isUpdatingRelease =
              _updatingResultReleaseQuizIds.contains(quizId);

            return _PremiumCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: blue,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPublished ? blue : yellow,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: blue, width: 1.5),
                        ),
                        child: Text(
                          isPublished ? 'PUBLISHED' : 'DRAFT',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            color: isPublished ? Colors.white : blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$subject • $totalQuestions QUESTIONS • ${timeLimit > 0 ? '$timeLimit MIN' : 'NO LIMIT'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: blue.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: quizId.isEmpty
                              ? null
                              : () => context.pushNamed(
                                  'teacher-batch-quiz-results',
                                  pathParameters: {
                                    'id': widget.batchId,
                                    'quizId': quizId,
                                  },
                                  queryParameters: {'title': title},
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'RESULTS',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: quizId.isEmpty
                              ? null
                              : () async {
                                  await context.pushNamed(
                                    'teacher-batch-create-quiz',
                                    pathParameters: {'id': widget.batchId},
                                    extra: {
                                      'initialSubject': (_batch?['subject'] ?? '')
                                          .toString(),
                                      'quizId': quizId,
                                      'initialAssessmentType': 'QUIZ',
                                    },
                                  );
                                  await _load();
                                },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: blue, width: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'EDIT',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                color: blue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_isDeletingQuiz || quizId.isEmpty)
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Quiz?'),
                                      content: const Text(
                                        'This will remove the quiz and related attempts for this batch.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;

                                  setState(() => _isDeletingQuiz = true);
                                  try {
                                    await _teacherRepo.deleteQuiz(quizId);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Quiz deleted'),
                                      ),
                                    );
                                    await _load();
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Delete failed: $e'),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isDeletingQuiz = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.coralRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'DELETE',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isPublished) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (quizId.isEmpty || isUpdatingRelease)
                            ? null
                            : () => _toggleResultRelease(
                                quiz,
                                kindLabel: 'Quiz',
                              ),
                        icon: isUpdatingRelease
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isResultReleased ? blue : Colors.white,
                                ),
                              )
                            : Icon(
                                isResultReleased
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 16,
                              ),
                        label: Text(
                          isResultReleased
                              ? 'HOLD RESULTS'
                              : 'RELEASE RESULTS',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isResultReleased
                              ? yellow
                              : AppColors.mintGreen,
                          foregroundColor: blue,
                          side: BorderSide(color: blue, width: 2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TEST (EXAM MODE)',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
            _ActionBtn(
              label: 'NEW TEST',
              icon: Icons.add_task_rounded,
              blue: blue,
              yellow: yellow,
              onPressed: () async {
                await context.pushNamed(
                  'teacher-batch-create-quiz',
                  pathParameters: {'id': widget.batchId},
                  extra: {
                    'initialSubject': (_batch?['subject'] ?? '').toString(),
                    'initialAssessmentType': 'TEST',
                  },
                );
                await _load();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'SCHEDULED TESTS • 50-200 QUESTIONS • STRICT TIMER • ONE ATTEMPT • RANK SYSTEM',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        if (_scheduledTests.isEmpty)
          _PremiumCard(
            child: Text(
              'NO TESTS CREATED FOR THIS BATCH YET',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: blue.withValues(alpha: 0.6),
              ),
            ),
          )
        else
          ..._scheduledTests.map((test) {
            final testId = (test['id'] ?? '').toString();
            final title = (test['title'] ?? 'TEST').toString().toUpperCase();
            final subject = (test['subject'] ?? _batch?['subject'] ?? 'GENERAL')
                .toString()
                .toUpperCase();
            final totalQuestions =
                ((test['questions'] as List?)?.length ??
                _toNum((test['_count'] as Map?)?['questions']).toInt());
            final timeLimit = _toNum(test['time_limit_min']).toInt();
            final isPublished = test['is_published'] == true;
            final isResultReleased = _isResultReleased(test);
            final isUpdatingRelease =
              _updatingResultReleaseQuizIds.contains(testId);

            return _PremiumCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: blue,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPublished ? blue : yellow,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: blue, width: 1.5),
                        ),
                        child: Text(
                          isPublished ? 'PUBLISHED' : 'DRAFT',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            color: isPublished ? Colors.white : blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$subject • $totalQuestions QUESTIONS • ${timeLimit > 0 ? '$timeLimit MIN' : 'NO TIMER'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: blue.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: testId.isEmpty
                              ? null
                              : () => context.pushNamed(
                                  'teacher-batch-quiz-results',
                                  pathParameters: {
                                    'id': widget.batchId,
                                    'quizId': testId,
                                  },
                                  queryParameters: {'title': title},
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'RESULTS',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: testId.isEmpty
                              ? null
                              : () async {
                                  await context.pushNamed(
                                    'teacher-batch-create-quiz',
                                    pathParameters: {'id': widget.batchId},
                                    extra: {
                                      'initialSubject': (_batch?['subject'] ?? '')
                                          .toString(),
                                      'quizId': testId,
                                      'initialAssessmentType': 'TEST',
                                    },
                                  );
                                  await _load();
                                },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: blue, width: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'EDIT',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                color: blue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_isDeletingQuiz || testId.isEmpty)
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Test?'),
                                      content: const Text(
                                        'This will remove the test and related attempts for this batch.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;

                                  setState(() => _isDeletingQuiz = true);
                                  try {
                                    await _teacherRepo.deleteQuiz(testId);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Test deleted'),
                                      ),
                                    );
                                    await _load();
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Delete failed: $e'),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isDeletingQuiz = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.coralRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'DELETE',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isPublished) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (testId.isEmpty || isUpdatingRelease)
                            ? null
                            : () => _toggleResultRelease(
                                test,
                                kindLabel: 'Test',
                              ),
                        icon: isUpdatingRelease
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isResultReleased ? blue : Colors.white,
                                ),
                              )
                            : Icon(
                                isResultReleased
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 16,
                              ),
                        label: Text(
                          isResultReleased
                              ? 'HOLD RESULTS'
                              : 'RELEASE RESULTS',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isResultReleased
                              ? yellow
                              : AppColors.mintGreen,
                          foregroundColor: blue,
                          side: BorderSide(color: blue, width: 2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
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
              Text(
                'ATTENDANCE WORKFLOW',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: blue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Track and mark attendance for your students daily.',
                style: GoogleFonts.plusJakartaSans(
                  color: blue.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedAttendanceDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: blue,
                            onPrimary: Colors.white,
                            surface: bg,
                            onSurface: blue,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => _selectedAttendanceDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: blue,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'DATE: ${_selectedAttendanceDate.day}/${_selectedAttendanceDate.month}/${_selectedAttendanceDate.year}',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: blue,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.edit_calendar_rounded, color: blue, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await context.pushNamed(
                      'teacher-batch-attendance',
                      pathParameters: {'id': widget.batchId},
                      extra: {
                        'initialDate': _selectedAttendanceDate,
                        'initialSubject': _selectedSubject,
                      },
                    );
                    _load();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: blue, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'OPEN ATTENDANCE PORTAL',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _doubtsTab(Color bg, Color yellow, Color blue) {
    final visibleDoubts = _allBatchDoubts.where((doubt) {
      final status = (doubt['status'] ?? 'pending').toString().toLowerCase();
      if (_doubtsView == 'pending') return status == 'pending';
      return status != 'pending';
    }).toList();

    final emptyLabel = _doubtsView == 'pending'
        ? 'NO PENDING DOUBTS'
        : 'NO DOUBT HISTORY FOUND';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDoubtFilterChip(
                label: 'PENDING',
                value: 'pending',
                blue: blue,
                yellow: yellow,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDoubtFilterChip(
                label: 'HISTORY',
                value: 'history',
                blue: blue,
                yellow: yellow,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visibleDoubts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: _PremiumCard(
                child: Text(
                  emptyLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    color: blue,
                  ),
                ),
              ),
            ),
          )
        else
          ...visibleDoubts.map((d) {
            final student = ((d['student'] as Map?)?['name'] ?? 'Student')
                .toString();
            final batch = ((d['batch'] as Map?)?['name'] ?? 'Batch').toString();
            final preview = _buildDoubtPreviewText(d);
            final status = (d['status'] ?? 'pending').toString().toLowerCase();
            final statusLabel = status == 'pending' ? 'PENDING' : status.toUpperCase();
            final studentInitial = student.trim().isEmpty
                ? 'S'
                : student.trim().substring(0, 1).toUpperCase();

            String timeAgo = 'JUST NOW';
            final createdAt = (d['created_at'] ?? '').toString();
            if (createdAt.isNotEmpty) {
              final dt = DateTime.tryParse(createdAt);
              if (dt != null) {
                final diff = DateTime.now().difference(dt);
                if (diff.inMinutes < 1) {
                  timeAgo = 'JUST NOW';
                } else if (diff.inHours < 1) {
                  timeAgo = '${diff.inMinutes}M AGO';
                } else if (diff.inDays < 1) {
                  timeAgo = '${diff.inHours}H AGO';
                } else {
                  timeAgo = '${diff.inDays}D AGO';
                }
              }
            }

            return _PremiumCard(
              margin: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () => _openDoubtChat(d),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: yellow,
                        border: Border.all(color: blue, width: 2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        studentInitial,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          color: blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  student.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    color: blue,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeAgo,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  color: blue.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            batch.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: blue.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: status == 'pending'
                                      ? yellow.withValues(alpha: 0.4)
                                      : AppColors.mintGreen.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: blue, width: 1),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    color: blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            preview,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: blue,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chat_rounded, color: blue),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDoubtFilterChip({
    required String label,
    required String value,
    required Color blue,
    required Color yellow,
  }) {
    final selected = _doubtsView == value;
    return InkWell(
      onTap: () => setState(() => _doubtsView = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? yellow : Colors.white,
          border: Border.all(color: blue, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [BoxShadow(color: blue, offset: const Offset(2, 2))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            color: blue,
          ),
        ),
      ),
    );
  }

  String _buildDoubtPreviewText(Map<String, dynamic> doubt) {
    final question = (doubt['question_text'] ?? doubt['questionText'] ?? '')
        .toString()
        .trim();
    if (question.isEmpty) return 'Open chat';

    final lines = question
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (line.startsWith('[') && line.endsWith(']')) continue;
      if (line.toLowerCase().startsWith('image:')) continue;
      final normalized = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized.isNotEmpty) return normalized;
    }

    return 'Open chat';
  }

  Future<void> _openDoubtChat(Map<String, dynamic> doubt) async {
    final result = await context.pushNamed<bool>(
      'doubt-response',
      extra: doubt,
    );
    if (!mounted) return;
    if (result == true) {
      await _load();
    }
  }

  num _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  String _formatRelativeDate(dynamic dateValue) {
    if (dateValue == null) return 'recently';
    final date = DateTime.tryParse(dateValue.toString());
    if (date == null) return 'recently';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).round()} week(s) ago';
    return '${(diff.inDays / 30).round()} month(s) ago';
  }

  Widget _filterChip(String label, String value, Color blue, Color yellow) {
    final selected = _studentFilter == value;
    return InkWell(
      onTap: () => setState(() => _studentFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? yellow : Colors.white,
          border: Border.all(color: blue, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 10,
            color: blue,
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectSelector(Color yellow, Color blue, Color bg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: blue, width: 2)),
      ),
      child: Row(
        children: [
          Icon(Icons.subject_rounded, color: yellow, size: 20),
          const SizedBox(width: 12),
          Text(
            'SELECT SUBJECT:',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: blue, width: 2),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedSubject,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  icon: Icon(Icons.arrow_drop_down_circle_rounded, color: blue),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'ALL SUBJECTS',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: blue,
                        ),
                      ),
                    ),
                    ..._subjects.map((s) {
                      return DropdownMenuItem<String?>(
                        value: s,
                        child: Text(
                          s.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: blue,
                          ),
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    if (_selectedSubject != val) {
                      setState(() {
                        _selectedSubject = val;
                      });
                      _load();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  const _PremiumCard({
    required this.child,
    this.margin = EdgeInsets.zero,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.elitePrimary;
    const surface = AppColors.offWhite;
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: blue, offset: Offset(4, 4))],
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

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.blue,
    required this.yellow,
  });

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
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: blue,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 10,
              color: blue.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color blue;
  const _InfoRow({
    required this.label,
    required this.value,
    required this.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: blue.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: blue,
            ),
          ),
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

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.blue,
    required this.yellow,
    required this.onPressed,
  });

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
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 10,
                color: blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}





