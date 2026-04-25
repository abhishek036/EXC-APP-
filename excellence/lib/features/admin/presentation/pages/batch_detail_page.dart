import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../data/repositories/admin_repository.dart';
import '../widgets/batch_overview_tab.dart';
import '../widgets/batch_content_tab.dart';
import '../widgets/batch_students_tab.dart';
import '../widgets/batch_tests_tab.dart';
import '../widgets/batch_fees_tab.dart';
import '../widgets/batch_attendance_tab.dart';
import '../widgets/batch_announcements_tab.dart';
import '../widgets/batch_analytics_tab.dart';

class BatchDetailPage extends StatefulWidget {
  final String batchId;
  const BatchDetailPage({super.key, required this.batchId});

  @override
  State<BatchDetailPage> createState() => _BatchDetailPageState();
}

class _BatchDetailPageState extends State<BatchDetailPage> {
  final _adminRepo = sl<AdminRepository>();
  final _syncService = sl<RealtimeSyncService>();
  StreamSubscription? _syncSubscription;

  Map<String, dynamic>? _batch;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _timetable = [];
  List<Map<String, dynamic>> _lectures = [];
  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _feeRecords = [];
  List<Map<String, dynamic>> _attendanceSessions = [];
  List<Map<String, dynamic>> _announcements = [];

  Map<String, dynamic>? _feeStructure;

  bool _isLoading = true;
  String? _error;

  int _activeTab = 0;
  final int _activeContentTab = 0;
  final String _studentFilter = 'All';
  final String _feeFilter = 'All';
  bool _fabExpanded = false;
  String? _selectedSubject;
  List<String> _batchSubjects = [];

  static const _tabs = [
    'Overview',
    'Content',
    'Students',
    'Tests',
    'Fees',
    'Attendance',
    'Announcements',
    'Analytics',
  ];
  static const _contentTabs = [
    'Lectures',
    'Notes',
    'Assignments',
    'DPP',
    'Materials',
  ];

  @override
  void initState() {
    super.initState();
    _loadBatch();
    _initSync();
  }

  void _initSync() {
    _syncService.connect();
    _syncService.joinBatch(widget.batchId);
    _syncSubscription = _syncService.updates.listen((event) {
      final type = event['type'] as String?;
      final eventBatchId = (event['batch_id'] ?? event['batchId'] ?? event['id'] ?? '').toString();

      if (type == 'batch_sync' || type == 'dashboard_sync') {
        if (eventBatchId.isEmpty || eventBatchId == widget.batchId) {
          _loadBatch(silent: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  DateTime? _toDate(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _dateLabel(dynamic value) {
    final parsed = _toDate(value);
    if (parsed == null) return '--';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _timeLabel(dynamic value) {
    if (value == null) return '--';
    final text = value.toString();
    if (text.contains('T')) {
      final dt = DateTime.tryParse(text);
      if (dt != null) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }
    if (text.length >= 5) return text.substring(0, 5);
    return text;
  }

  String _sessionDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _defaultBatchSubject() {
    final subject = (_batch?['subject'] ?? '').toString().trim();
    if (subject.isNotEmpty) return subject;
    return 'General';
  }

  String _normalizeSubjectValue(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }

  List<String> _extractSubjectsFromBatchMeta(Map<String, dynamic>? batch) {
    final subjects = <String>[];
    if (batch == null) return subjects;

    final raw = batch['subjects'];
    if (raw is List) {
      for (final item in raw) {
        final text = item.toString().trim();
        if (text.isNotEmpty) subjects.add(text);
      }
    } else if (raw is String) {
      for (final part in raw.split(',')) {
        final text = part.trim();
        if (text.isNotEmpty) subjects.add(text);
      }
    }

    final single = (batch['subject'] ?? '').toString().trim();
    if (single.isNotEmpty) subjects.add(single);

    return subjects;
  }

  List<String> _extractSubjectsFromRecords(List<Map<String, dynamic>> records) {
    final subjects = <String>[];
    for (final record in records) {
      final subject = (record['subject'] ?? '').toString().trim();
      if (subject.isNotEmpty) subjects.add(subject);
    }
    return subjects;
  }

  bool _matchesSubjectFilter(Map<String, dynamic> item) {
    final selected = _normalizeSubjectValue(_selectedSubject);
    if (selected.isEmpty) return true;

    final itemSubject = _normalizeSubjectValue(item['subject']);
    return itemSubject == selected;
  }

  List<Map<String, dynamic>> get _subjectScopedQuizzes {
    if (_selectedSubject == null || _selectedSubject!.trim().isEmpty) {
      return _quizzes;
    }
    return _quizzes.where(_matchesSubjectFilter).toList();
  }

  List<Map<String, dynamic>> get _subjectScopedAttendanceSessions {
    if (_selectedSubject == null || _selectedSubject!.trim().isEmpty) {
      return _attendanceSessions;
    }
    return _attendanceSessions.where(_matchesSubjectFilter).toList();
  }

  bool get _showSubjectScope {
    return _activeTab == 3 || _activeTab == 5;
  }

  String _normalizeNoteType(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();
    switch (raw) {
      case 'pdf':
      case 'image':
      case 'video':
      case 'zip':
      case 'doc':
      case 'docx':
      case 'ppt':
      case 'pptx':
      case 'other':
        return raw;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'image';
      default:
        return 'pdf';
    }
  }

  String _normalizeAttendanceStatus(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();
    if (raw == 'present' || raw == 'absent' || raw == 'late' || raw == 'excused') {
      return raw;
    }
    return 'present';
  }

  Future<void> _replaceNote(Map<String, dynamic> note) async {
    await _showNoteEditor(note: note, replaceLabel: true);
  }

  Future<void> _showNoteEditor({
    Map<String, dynamic>? note,
    bool replaceLabel = false,
  }) async {
    final isEdit = note != null;
    final noteId = (note?['id'] ?? '').toString();
    if (isEdit && noteId.isEmpty) {
      CPToast.error(context, 'Invalid note');
      return;
    }

    String selectedType = _normalizeNoteType(note?['file_type']);
    final titleCtrl = TextEditingController(
      text: (note?['title'] ?? note?['file_name'] ?? '').toString(),
    );
    final subjectCtrl = TextEditingController(
      text: (note?['subject'] ?? _defaultBatchSubject()).toString(),
    );
    final urlCtrl = TextEditingController(
      text: (note?['file_url'] ?? '').toString(),
    );
    final descCtrl = TextEditingController(
      text: (note?['description'] ?? '').toString(),
    );

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: Text(
                replaceLabel
                    ? 'Replace Note'
                    : (isEdit ? 'Edit Note' : 'Add Note'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'File Type'),
                      items: const [
                        DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                        DropdownMenuItem(value: 'image', child: Text('Image')),
                        DropdownMenuItem(value: 'video', child: Text('Video')),
                        DropdownMenuItem(value: 'zip', child: Text('ZIP')),
                        DropdownMenuItem(value: 'doc', child: Text('DOC')),
                        DropdownMenuItem(value: 'docx', child: Text('DOCX')),
                        DropdownMenuItem(value: 'ppt', child: Text('PPT')),
                        DropdownMenuItem(value: 'pptx', child: Text('PPTX')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        setS(() => selectedType = value ?? selectedType);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: urlCtrl,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      keyboardType: TextInputType.url,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(labelText: 'File URL'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(replaceLabel ? 'Replace' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    final title = titleCtrl.text.trim();
    final subjectInput = subjectCtrl.text.trim();
    final newUrl = urlCtrl.text.trim();
    final description = descCtrl.text.trim();

    titleCtrl.dispose();
    subjectCtrl.dispose();
    urlCtrl.dispose();
    descCtrl.dispose();

    if (approved != true) return;

    if (title.length < 2) {
      if (!mounted) return;
      CPToast.error(context, 'Title must be at least 2 characters');
      return;
    }

    final subject = subjectInput.isEmpty ? _defaultBatchSubject() : subjectInput;
    if (newUrl.isEmpty) {
      if (!mounted) return;
      CPToast.error(context, 'File URL is required');
      return;
    }

    try {
      if (isEdit) {
        await _adminRepo.updateNote(
          noteId: noteId,
          title: title,
          subject: subject,
          fileType: selectedType,
          fileUrl: newUrl,
          description: description,
          batchId: widget.batchId,
        );
      } else {
        await _adminRepo.createNote(
          title: title,
          subject: subject,
          fileType: selectedType,
          batchId: widget.batchId,
          fileUrl: newUrl,
          description: description,
        );
      }
      if (!mounted) return;
      CPToast.success(
        context,
        isEdit ? 'Note updated successfully' : 'Note created successfully',
      );
      await _loadBatch();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, e.toString());
    }
  }

  Future<void> _deleteNote(Map<String, dynamic> note) async {
    final noteId = (note['id'] ?? '').toString();
    if (noteId.isEmpty) {
      CPToast.error(context, 'Invalid note');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text(
          'This will remove ${(note['title'] ?? 'this note').toString()} from this batch.',
        ),
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

    if (confirm != true) return;

    try {
      await _adminRepo.deleteNote(noteId);
      if (!mounted) return;
      CPToast.success(context, 'Note deleted');
      await _loadBatch();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Delete failed: $e');
    }
  }

  Future<DateTime?> _pickDateTime({DateTime? initial}) async {
    final now = DateTime.now();
    final seed = initial ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return null;

    if (!mounted) return DateTime(date.year, date.month, date.day);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
    );

    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? seed.hour,
      time?.minute ?? seed.minute,
    );
  }

  Future<void> _showAssignmentEditor({Map<String, dynamic>? assignment}) async {
    final isEdit = assignment != null;
    final assignmentId = (assignment?['id'] ?? '').toString();
    if (isEdit && assignmentId.isEmpty) {
      CPToast.error(context, 'Invalid assignment');
      return;
    }

    final titleCtrl = TextEditingController(
      text: (assignment?['title'] ?? '').toString(),
    );
    final subjectCtrl = TextEditingController(
      text: (assignment?['subject'] ?? _defaultBatchSubject()).toString(),
    );
    final descriptionCtrl = TextEditingController(
      text: (assignment?['description'] ?? '').toString(),
    );
    final instructionsCtrl = TextEditingController(
      text: (assignment?['instructions'] ?? '').toString(),
    );
    final fileUrlCtrl = TextEditingController(
      text: (assignment?['file_url'] ?? '').toString(),
    );

    final initialDueDate = _toDate(assignment?['due_date'])?.toLocal();
    DateTime? dueDate = initialDueDate;
    bool allowLateSubmission = (assignment?['allow_late_submission'] ?? false) == true;
    bool allowTextSubmission = (assignment?['allow_text_submission'] ?? true) != false;
    bool allowFileSubmission = (assignment?['allow_file_submission'] ?? true) != false;
    final lateGraceCtrl = TextEditingController(
      text: _toInt(assignment?['late_grace_minutes']) > 0
          ? _toInt(assignment?['late_grace_minutes']).toString()
          : '',
    );
    final maxAttemptsCtrl = TextEditingController(
      text: _toInt(assignment?['max_attempts']) > 0
          ? _toInt(assignment?['max_attempts']).toString()
          : '',
    );
    final maxMarksCtrl = TextEditingController(
      text: _toDouble(assignment?['max_marks']) > 0
          ? _toDouble(assignment?['max_marks']).toStringAsFixed(0)
          : '',
    );

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Assignment' : 'Add Assignment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: instructionsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Instructions (optional)',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: fileUrlCtrl,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      keyboardType: TextInputType.url,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                        labelText: 'Question/File URL (optional)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: maxMarksCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Max Marks (optional)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await _pickDateTime(initial: dueDate);
                        if (picked == null) return;
                        setS(() => dueDate = picked);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: CT.divider(context)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dueDate == null
                                    ? 'Due date (optional)'
                                    : '${_dateLabel(dueDate)} ${_timeLabel(dueDate)}',
                              ),
                            ),
                            if (dueDate != null)
                              InkWell(
                                onTap: () => setS(() => dueDate = null),
                                child: const Icon(Icons.close_rounded, size: 18),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow late submissions'),
                      value: allowLateSubmission,
                      onChanged: (value) {
                        setS(() => allowLateSubmission = value);
                      },
                    ),
                    if (allowLateSubmission)
                      TextField(
                        controller: lateGraceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Late grace minutes (optional)',
                        ),
                      ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow text submission'),
                      value: allowTextSubmission,
                      onChanged: (value) {
                        setS(() => allowTextSubmission = value);
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow file submission'),
                      value: allowFileSubmission,
                      onChanged: (value) {
                        setS(() => allowFileSubmission = value);
                      },
                    ),
                    TextField(
                      controller: maxAttemptsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max attempts (optional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    final title = titleCtrl.text.trim();
    final subject = subjectCtrl.text.trim().isEmpty
        ? _defaultBatchSubject()
        : subjectCtrl.text.trim();
    final description = descriptionCtrl.text.trim();
    final instructions = instructionsCtrl.text.trim();
    final fileUrl = fileUrlCtrl.text.trim();
    final maxMarksRaw = maxMarksCtrl.text.trim();
    final lateGraceRaw = lateGraceCtrl.text.trim();
    final maxAttemptsRaw = maxAttemptsCtrl.text.trim();

    titleCtrl.dispose();
    subjectCtrl.dispose();
    descriptionCtrl.dispose();
    instructionsCtrl.dispose();
    fileUrlCtrl.dispose();
    lateGraceCtrl.dispose();
    maxAttemptsCtrl.dispose();
    maxMarksCtrl.dispose();

    if (approved != true) return;

    if (title.length < 2) {
      CPToast.error(context, 'Title must be at least 2 characters');
      return;
    }

    if (!allowTextSubmission && !allowFileSubmission) {
      CPToast.error(context, 'Enable text or file submission');
      return;
    }

    final now = DateTime.now();
    final dueDateChanged =
        (initialDueDate == null && dueDate != null) ||
        (initialDueDate != null && dueDate == null) ||
        (initialDueDate != null &&
            dueDate != null &&
        !initialDueDate.isAtSameMomentAs(dueDate!));

    if (!isEdit && dueDate != null && !dueDate!.isAfter(now)) {
      CPToast.error(context, 'Due date must be in the future');
      return;
    }
    if (isEdit && dueDateChanged && dueDate != null && !dueDate!.isAfter(now)) {
      CPToast.error(context, 'Updated due date must be in the future');
      return;
    }

    num? maxMarks;
    if (maxMarksRaw.isNotEmpty) {
      maxMarks = num.tryParse(maxMarksRaw);
      if (maxMarks == null || maxMarks <= 0) {
        CPToast.error(context, 'Max marks should be a positive number');
        return;
      }
    }

    int? lateGrace;
    if (lateGraceRaw.isNotEmpty) {
      lateGrace = int.tryParse(lateGraceRaw);
      if (lateGrace == null || lateGrace < 0) {
        CPToast.error(context, 'Late grace should be 0 or more');
        return;
      }
    }

    int? maxAttempts;
    if (maxAttemptsRaw.isNotEmpty) {
      maxAttempts = int.tryParse(maxAttemptsRaw);
      if (maxAttempts == null || maxAttempts < 1) {
        CPToast.error(context, 'Max attempts should be at least 1');
        return;
      }
    }

    try {
      if (isEdit) {
        await _adminRepo.updateAssignment(
          assignmentId: assignmentId,
          title: title,
          batchId: widget.batchId,
          subject: subject,
          description: description.isEmpty ? null : description,
          instructions: instructions.isEmpty ? null : instructions,
          fileUrl: fileUrl.isEmpty ? null : fileUrl,
          dueDate: dueDateChanged ? dueDate : null,
          maxMarks: maxMarks,
          allowLateSubmission: allowLateSubmission,
          lateGraceMinutes: allowLateSubmission ? lateGrace : null,
          maxAttempts: maxAttempts,
          allowTextSubmission: allowTextSubmission,
          allowFileSubmission: allowFileSubmission,
        );
      } else {
        await _adminRepo.createAssignment(
          title: title,
          batchId: widget.batchId,
          subject: subject,
          description: description.isEmpty ? null : description,
          instructions: instructions.isEmpty ? null : instructions,
          fileUrl: fileUrl.isEmpty ? null : fileUrl,
          dueDate: dueDate,
          maxMarks: maxMarks,
          allowLateSubmission: allowLateSubmission,
          lateGraceMinutes: allowLateSubmission ? lateGrace : null,
          maxAttempts: maxAttempts,
          allowTextSubmission: allowTextSubmission,
          allowFileSubmission: allowFileSubmission,
        );
      }

      if (!mounted) return;
      CPToast.success(
        context,
        isEdit
            ? 'Assignment updated successfully'
            : 'Assignment created successfully',
      );
      await _loadBatch();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, e.toString());
    }
  }

  Future<void> _deleteAssignment(Map<String, dynamic> assignment) async {
    final assignmentId = (assignment['id'] ?? '').toString();
    if (assignmentId.isEmpty) {
      CPToast.error(context, 'Invalid assignment');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete assignment?'),
        content: Text(
          'This will remove ${(assignment['title'] ?? 'this assignment').toString()} from this batch.',
        ),
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

    if (confirm != true) return;

    try {
      await _adminRepo.deleteAssignment(assignmentId);
      if (!mounted) return;
      CPToast.success(context, 'Assignment deleted');
      await _loadBatch();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Delete failed: $e');
    }
  }


  Future<void> _loadBatch({bool silent = false}) async {
    try {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final batch = await _adminRepo.getBatchById(widget.batchId);
      final now = DateTime.now();

      final results = await Future.wait([
        _adminRepo
            .getBatchTimetable(widget.batchId)
            .catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo
            .getLecturesByBatch(widget.batchId)
            .catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo
            .getQuizzes(batchId: widget.batchId)
            .catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo
            .getFeeStructure(widget.batchId)
            .catchError((_) => <String, dynamic>{}),
        _adminRepo.getTeachers().catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo
            .getAssignments(batchId: widget.batchId)
            .catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo
          .getMaterials(batchId: widget.batchId)
          .catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo
            .getFeeRecords(batchId: widget.batchId)
            .catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo
            .getBatchAttendanceMonthly(
              batchId: widget.batchId,
              month: now.month,
              year: now.year,
            )
            .catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo
            .getBatchStudents(widget.batchId)
            .catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo
            .getAnnouncements()
            .catchError((_) => <Map<String, dynamic>>[]),
        _adminRepo
            .getExams()
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      final batchStudents = List<Map<String, dynamic>>.from(batch['students'] as List? ?? []);
      final studentsFromApi = List<Map<String, dynamic>>.from(results[9] as List);
      
      final loadedQuizzes = List<Map<String, dynamic>>.from(results[2] as List);
      for (var q in loadedQuizzes) {
        q['item_type'] = 'quiz';
      }
      
      final loadedExams = List<Map<String, dynamic>>.from(results[11] as List)
          .where((e) => e['batchId'] == widget.batchId || e['batch_id'] == widget.batchId)
          .toList();
      for (var e in loadedExams) {
        e['item_type'] = 'exam';
      }
      
      final quizzes = [...loadedQuizzes, ...loadedExams];
      quizzes.sort((a, b) {
        final dateA = DateTime.tryParse((a['scheduled_at'] ?? a['exam_date'] ?? '').toString()) ?? DateTime(2000);
        final dateB = DateTime.tryParse((b['scheduled_at'] ?? b['exam_date'] ?? '').toString()) ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      final attendanceSessions = List<Map<String, dynamic>>.from(results[8] as List);
      final mergedSubjects = <String>{
        ..._extractSubjectsFromBatchMeta(batch),
        ..._extractSubjectsFromRecords(quizzes),
        ..._extractSubjectsFromRecords(attendanceSessions),
      }.toList();

      setState(() {
        _batch = batch;
        _students = batchStudents.isNotEmpty ? batchStudents : studentsFromApi;
        _timetable = List<Map<String, dynamic>>.from(results[0] as List);
        _lectures = List<Map<String, dynamic>>.from(results[1] as List);
        _quizzes = quizzes;
        _feeStructure = Map<String, dynamic>.from(results[3] as Map);
        _teachers = List<Map<String, dynamic>>.from(results[4] as List);
        _assignments = List<Map<String, dynamic>>.from(results[5] as List);
        _materials = List<Map<String, dynamic>>.from(results[6] as List);
        _feeRecords = List<Map<String, dynamic>>.from(results[7] as List);
        _attendanceSessions = attendanceSessions;
        _batchSubjects = mergedSubjects;
        if (_selectedSubject != null && !_batchSubjects.contains(_selectedSubject)) {
          _selectedSubject = null;
        }
        _announcements = List<Map<String, dynamic>>.from(results[10] as List);
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

  bool get _isCompleted {
    final endDate = _toDate(_batch?['end_date']);
    if (endDate == null) return false;
    final today = DateTime.now();
    return endDate.isBefore(DateTime(today.year, today.month, today.day));
  }

  Map<String, dynamic> _feeStats() {
    double total = 0;
    double paid = 0;
    double pending = 0;
    double collectedToday = 0;
    final today = DateTime.now();

    for (final record in _feeRecords) {
      final amount = _toDouble(record['final_amount'] ?? record['amount']);
      final payments = (record['payments'] as List?) ?? const [];
      final paidAmount = payments.fold<double>(0, (sum, item) {
        if (item is! Map) return sum;
        final p = _toDouble(item['amount_paid']);
        final date = _toDate(item['created_at'] ?? item['paid_at']);
        if (date != null &&
            date.year == today.year &&
            date.month == today.month &&
            date.day == today.day) {
          collectedToday += p;
        }
        return sum + p;
      });

      total += amount;
      paid += paidAmount;
      pending += (amount - paidAmount).clamp(0, double.infinity);
    }

    return {
      'total': total,
      'paid': paid,
      'pending': pending,
      'collectedToday': collectedToday,
    };
  }

  Map<String, dynamic> _insights() {
    final fees = _feeStats();
    final lowAttendanceCount = _students
        .where((s) => _studentAttendance(s) < 70)
        .length;
    final submittedAssignments = _assignments.fold<int>(0, (sum, item) {
      return sum +
          _toInt(
            item['submission_count'] ??
                item['submissions_count'] ??
                item['submitted_count'],
          );
    });

    return {
      'lectures': _lectures.length,
      'notes': _materials.length,
      'tests': _quizzes.length,
      'assignmentsSubmitted': submittedAssignments,
      'feesPaid': fees['paid'],
      'feesPending': fees['pending'],
      'lowAttendance': lowAttendanceCount,
    };
  }

  double _studentAttendance(Map<String, dynamic> student) {
    return _studentAttendanceFromSessions(student, _attendanceSessions);
  }

  double _studentAttendanceFromSessions(
    Map<String, dynamic> student,
    List<Map<String, dynamic>> sessions,
  ) {
    final studentId = (student['id'] ?? '').toString();
    if (studentId.isEmpty || sessions.isEmpty) {
      return _toDouble(student['attendance_percent'], fallback: 0);
    }

    int total = 0;
    int present = 0;

    for (final session in sessions) {
      final records =
          (session['records'] as List?) ??
          (session['student_records'] as List?) ??
          const [];
      for (final entry in records) {
        if (entry is! Map) continue;
        final id = (entry['student_id'] ?? '').toString();
        if (id != studentId) continue;
        total += 1;
        final status = (entry['status'] ?? '').toString().toLowerCase();
        if (status == 'present' || status == 'late') present += 1;
      }
    }

    if (total == 0) {
      return _toDouble(student['attendance_percent'], fallback: 0);
    }
    return (present / total) * 100;
  }

  Map<String, dynamic> _attendanceStatsForSessions(
    List<Map<String, dynamic>> sessions,
  ) {
    if (_students.isEmpty) {
      return {'avg': '0%', 'count': 0, 'status': 'No data'};
    }

    final average = _students.fold<double>(0, (sum, student) {
          return sum + _studentAttendanceFromSessions(student, sessions);
        }) /
        _students.length;
    final lowCount = _students
        .where((student) => _studentAttendanceFromSessions(student, sessions) < 70)
        .length;

    return {
      'avg': '${average.toStringAsFixed(0)}%',
      'count': _students.length,
      'status': lowCount == 0
          ? 'Healthy'
          : (lowCount < (_students.length / 3) ? 'Watch' : 'Risk'),
    };
  }

  String _studentFeeStatus(String studentId) {
    final related = _feeRecords.where(
      (r) => (r['student_id'] ?? '').toString() == studentId,
    );
    if (related.isEmpty) return 'Pending';

    bool anyPending = false;
    for (final record in related) {
      final amount = _toDouble(record['final_amount'] ?? record['amount']);
      final payments = (record['payments'] as List?) ?? const [];
      final paid = payments.fold<double>(
        0,
        (sum, p) => sum + _toDouble((p as Map)['amount_paid']),
      );
      if (paid + 0.01 < amount) {
        anyPending = true;
        break;
      }
    }
    return anyPending ? 'Pending' : 'Paid';
  }

  Map<String, dynamic> get _attendanceStats {
    if (_students.isEmpty) {
      return {'avg': '0%', 'count': 0, 'status': 'No data'};
    }

    final average = _students.fold<double>(0, (sum, student) {
          return sum + _studentAttendance(student);
        }) /
        _students.length;
    final lowCount = _students.where((student) => _studentAttendance(student) < 70).length;

    return {
      'avg': '${average.toStringAsFixed(0)}%',
      'count': _students.length,
      'status': lowCount == 0
          ? 'Healthy'
          : (lowCount < (_students.length / 3) ? 'Watch' : 'Risk'),
    };
  }

  List<double> _attendanceTrend() {
    if (_attendanceSessions.isEmpty) return [0];

    final sessions = _attendanceSessions.reversed.take(6).toList().reversed.toList();
    final trend = sessions.map((session) {
      final records =
          (session['records'] as List?) ??
          (session['student_records'] as List?) ??
          const [];
      if (records.isEmpty) return 0.0;

      final present = records.where((record) {
        if (record is! Map) return false;
        final status = (record['status'] ?? '').toString().toLowerCase();
        return status == 'present' || status == 'late';
      }).length;

      return (present / records.length) * 100;
    }).toList();

    return trend.isEmpty ? [0] : trend;
  }

  List<double> _performanceTrend() {
    final quizTrend = _quizzes.reversed.take(6).toList().reversed.map((quiz) {
      return _toDouble(quiz['average_score'] ?? quiz['avg_score'] ?? quiz['average']);
    }).toList();
    if (quizTrend.any((value) => value > 0)) return quizTrend;

    final assignmentTrend = _assignments.reversed.take(6).toList().reversed.map((assignment) {
      return _toDouble(
        assignment['average_score'] ??
            assignment['avg_score'] ??
            assignment['max_marks'] ??
            assignment['total_marks'],
      );
    }).toList();

    return assignmentTrend.isEmpty ? [0] : assignmentTrend;
  }

  List<double> _revenueTrend() {
    final trend = _feeRecords.reversed.take(6).toList().reversed.map((record) {
      return _recordPaidAmount(record);
    }).toList();
    return trend.isEmpty ? [0] : trend;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.elitePrimary,
      appBar: AppBar(
        backgroundColor: AppColors.elitePrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              GoRouter.of(context).pop();
            } else {
              GoRouter.of(context).go('/admin');
            }
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _batch?['name']?.toString() ?? 'Batch Control Panel',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_batch != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'toggle') {
                  await _toggleBatchStatus();
                } else if (value == 'meta') {
                  await _showMetaEditor();
                } else if (value == 'migrate') {
                  await _showMigrateSheet();
                } else if (value == 'delete') {
                  await _deleteBatch();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(
                    (_batch?['is_active'] ?? true)
                        ? 'Close batch'
                        : 'Re-open batch',
                  ),
                ),
                const PopupMenuItem(value: 'meta', child: Text('Edit details')),
                const PopupMenuItem(
                  value: 'migrate',
                  child: Text('Promote / Migrate students'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete batch'),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadBatch,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroPanel(isDark),
                    _buildLiveInsights(),
                    _buildTabBar(isDark),
                    if (_showSubjectScope) _buildSubjectScopeBar(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _buildTabBody(),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
      floatingActionButton: _buildActionDock(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Color(0xFFB6231B),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unable to load batch',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            CustomButton(text: 'Retry', onPressed: _loadBatch),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroPanel(bool isDark) {
    if (_batch == null) return const SizedBox.shrink();

    final isActive = (_batch!['is_active'] ?? true) == true;
    final fee = _feeStats();
    final totalStudents = _students.length;
    final activeStudents = _students.where((s) {
      final status = (s['status'] ?? s['is_active'])?.toString().toLowerCase();
      return status == null || status == 'active' || status == 'true';
    }).length;

    final statusLabel = _isCompleted
        ? 'Closed'
        : (isActive ? 'Active' : 'Paused');
    final statusColor = _isCompleted
        ? const Color(0xFFB6231B)
        : (isActive ? const Color(0xFF354388) : Colors.black54);
    final pending = _toDouble(fee['pending']);
    final paid = _toDouble(fee['paid']);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.pagePaddingH,
        14,
        AppDimensions.pagePaddingH,
        8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF354388), width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF354388),
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (_batch!['name'] ?? 'Batch').toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF354388),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(_batch!['subject'] ?? 'General').toString()} • ${(_batch!['target'] ?? _batch!['class_name'] ?? 'Target').toString()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: statusColor, width: 2),
                  boxShadow: [
                    BoxShadow(color: statusColor, offset: const Offset(2, 2)),
                  ],
                ),
                child: Text(
                  statusLabel.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF354388),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE5A100),
              border: Border.all(color: const Color(0xFF354388), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF354388),
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.currency_rupee_rounded,
                  color: Color(0xFF354388),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${paid.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF354388),
                          letterSpacing: -0.6,
                        ),
                      ),
                      Text(
                        'Total Revenue',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF354388),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFB6231B),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${pending.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFB6231B),
                        ),
                      ),
                      Text(
                        'Pending',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB6231B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _quickStatCard(
                'Total Students',
                '$totalStudents',
                Icons.groups_rounded,
                const Color(0xFF354388),
                width: 154,
              ),
              _quickStatCard(
                'Active Students',
                '$activeStudents',
                Icons.how_to_reg_rounded,
                const Color(0xFF354388),
                width: 154,
              ),
              _quickStatCard(
                'Monthly Fee',
                '₹${_toDouble(_feeStructure?['monthly_fee']).toStringAsFixed(0)}',
                Icons.payments_rounded,
                const Color(0xFFE5A100),
                width: 154,
              ),
              _quickStatCard(
                'Duration',
                '${_dateLabel(_batch!['start_date'])} - ${_dateLabel(_batch!['end_date'])}',
                Icons.date_range_rounded,
                const Color(0xFF354388),
                width: 154,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _microTag(
                'Lectures ${_lectures.length}',
                Icons.ondemand_video_rounded,
                const Color(0xFF354388),
              ),
              _microTag(
                'Notes ${_materials.length}',
                Icons.description_outlined,
                const Color(0xFF354388),
              ),
              _microTag(
                'Tests ${_quizzes.length}',
                Icons.quiz_outlined,
                const Color(0xFF354388),
              ),
              _microTag(
                'Low Attendance ${_students.where((s) => _studentAttendance(s) < 70).length}',
                Icons.warning_amber_rounded,
                const Color(0xFFB6231B),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 360.ms);
  }

  Widget _quickStatCard(
    String title,
    String value,
    IconData icon,
    Color accent, {
    double width = 164,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF354388), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF354388),
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF354388)),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(width: 8, height: 8, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _microTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveInsights() {
    final data = _insights();
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.pagePaddingH,
        0,
        AppDimensions.pagePaddingH,
        12,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF354388), width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Insights',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: const Color(0xFF354388),
            ),
          ),
          Text(
            'Realtime batch health and outcomes',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF354388).withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _insightTile(
                            'Lectures',
                            '${data['lectures']}',
                            Icons.ondemand_video_rounded,
                            const Color(0xFF354388),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _insightTile(
                            'Notes',
                            '${data['notes']}',
                            Icons.description_outlined,
                            const Color(0xFF354388),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _insightTile(
                            'Tests',
                            '${data['tests']}',
                            Icons.quiz_outlined,
                            const Color(0xFF354388),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _insightTile(
                            'Submissions',
                            '${data['assignmentsSubmitted']}',
                            Icons.assignment_turned_in_outlined,
                            const Color(0xFF354388),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _wideInsightTile(
            'Fees Paid',
            '₹${_toDouble(data['feesPaid']).toStringAsFixed(0)}',
            Icons.payments_rounded,
            const Color(0xFFE5A100),
            emphasized: true,
          ),
          const SizedBox(height: 8),
          _wideInsightTile(
            'Fees Pending',
            '₹${_toDouble(data['feesPending']).toStringAsFixed(0)}',
            Icons.warning_rounded,
            const Color(0xFFB6231B),
            emphasized: true,
          ),
          const SizedBox(height: 8),
          _wideInsightTile(
            'Low Attendance',
            '${data['lowAttendance']} Students',
            Icons.error_outline_rounded,
            const Color(0xFFB6231B),
          ),
        ],
      ),
    );
  }

  Widget _insightTile(String label, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        border: Border.all(color: accent, width: 1.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: const Color(0xFF354388),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF354388),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wideInsightTile(
    String label,
    String value,
    IconData icon,
    Color accent, {
    bool emphasized = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: emphasized ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent, width: emphasized ? 1.8 : 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF354388),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: emphasized ? 15 : 13,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF354388),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.elitePrimary,
        border: Border(
          top: BorderSide(color: AppColors.elitePrimary, width: 2),
          bottom: BorderSide(color: AppColors.elitePrimary, width: 2),
        ),
      ),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pagePaddingH,
          ),
          scrollDirection: Axis.horizontal,
          itemBuilder: (_, index) {
            final selected = _activeTab == index;
            return InkWell(
              onTap: () => setState(() => _activeTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? AppColors.moltenAmber
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    _tabs[index].toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                      fontSize: 12,
                      color: selected
                          ? AppColors.moltenAmber
                          : Colors.white.withValues(alpha: 0.68),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemCount: _tabs.length,
        ),
      ),
    );
  }

  Widget _buildSubjectScopeBar() {
    if (_batchSubjects.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.pagePaddingH,
        8,
        AppDimensions.pagePaddingH,
        4,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _subjectScopeChip(
              label: 'All Subjects',
              selected: _selectedSubject == null,
              onTap: () => setState(() => _selectedSubject = null),
            ),
            ..._batchSubjects.map((subject) {
              final selected = _selectedSubject == subject;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _subjectScopeChip(
                  label: subject,
                  selected: selected,
                  onTap: () => setState(() => _selectedSubject = subject),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _subjectScopeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.moltenAmber : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.elitePrimary, width: 1.5),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.elitePrimary,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_activeTab) {
      case 0:
        return BatchOverviewTab(
          batch: _batch,
          timetable: _timetable,
          lectures: _lectures,
          quizzes: _quizzes,
          feeRecords: _feeRecords,
          students: _students,
          assignments: _assignments,
          materials: _materials,
          announcements: _announcements,
          attendanceSessions: _attendanceSessions,
          attendanceStats: _attendanceStats,
          dateLabel: _dateLabel,
        );
      case 1:
        return BatchContentTab(
          lectures: _lectures,
          materials: _materials,
          assignments: _assignments,
          dateLabel: _dateLabel,
          timeLabel: _timeLabel,
          toDouble: _toDouble,
          toInt: _toInt,
          normalizeNoteType: _normalizeNoteType,
          onAddLecture: () => _showLectureEditor(),
          onEditLecture: (Map<String, dynamic> lecture) => _showLectureEditor(lecture: lecture),
          onDeleteLecture: (String id) => _deleteLecture(id),
          onAddNote: () => _showNoteEditor(),
          onEditNote: (Map<String, dynamic> note) => _showNoteEditor(note: note),
          onReplaceNote: (Map<String, dynamic> note) => _replaceNote(note),
          onDeleteNote: (Map<String, dynamic> note) => _deleteNote(note),
          onAddAssignment: () => _showAssignmentEditor(),
          onEditAssignment: (Map<String, dynamic> assignment) => _showAssignmentEditor(assignment: assignment),
          onDeleteAssignment: (Map<String, dynamic> assignment) => _deleteAssignment(assignment),
          onViewSubmissions: (Map<String, dynamic> assignment) => _showSubmissionsList(assignment),
        );
      case 2:
        return BatchStudentsTab(
          students: _students,
          batch: _batch,
          getStudentAttendance: _studentAttendance,
          getStudentFeeStatus: _studentFeeStatus,
          onAddStudent: () => GoRouter.of(context).push('/admin/add-student').then((_) => _loadBatch()),
          onViewStudent: (id) => GoRouter.of(context).push('/admin/students/$id').then((_) => _loadBatch()),
          onRefresh: _loadBatch,
        );
      case 3:
        return BatchTestsTab(
          quizzes: _subjectScopedQuizzes,
          toInt: _toInt,
          toDouble: _toDouble,
          onAddTest: () => _showExamEditor(),
          onEditTest: (q) => _showExamEditor(exam: q),
          onDeleteTest: (test) => _deleteTest(test),
        );
      case 4:
        return BatchFeesTab(
          feeStats: _feeStats(),
          feeRecords: _feeRecords,
          feeStructure: _feeStructure,
          recordStatus: _recordStatus,
          recordPaidAmount: _recordPaidAmount,
          toDouble: _toDouble,
          dateLabel: _dateLabel,
          onGenerateFees: _showGenerateFeesDialog,
          onMarkAsPaid: _markAsPaid,
          onSendWhatsAppReminder: () => GoRouter.of(context).push('/admin/whatsapp-broadcast'),
          onSendPushReminder: _sendFeeReminder,
        );
      case 5:
        return BatchAttendanceTab(
          attendanceStats: _attendanceStatsForSessions(
            _subjectScopedAttendanceSessions,
          ),
          attendanceSessions: _subjectScopedAttendanceSessions,
          dateLabel: _dateLabel,
          timeLabel: _timeLabel,
          onMarkAttendance: () => _showAttendanceMarker(),
          onEditAttendance: (s) => _showAttendanceMarker(existingSession: s),
        );
      case 6:
        return BatchAnnouncementsTab(
          announcements: _announcements,
          dateLabel: _dateLabel,
          onAddAnnouncement: _showAnnouncementEditor,
          onDeleteAnnouncement: (Map<String, dynamic> announcement) =>
              _deleteAnnouncement((announcement['id'] ?? '').toString()),
        );
      case 7:
        return BatchAnalyticsTab(
          attendanceTrend: _attendanceTrend(),
          performanceTrend: _performanceTrend(),
          revenueTrend: _revenueTrend(),
        );
      default:
        return const SizedBox.shrink();
    }
  }


  Future<void> _showAttendanceMarker({Map<String, dynamic>? existingSession}) async {
    final isEdit = existingSession != null;
    final studentsList = _students; // Use loaded students
    final Map<String, String> statusMap = {};
    
    // Initialize status map
    if (isEdit) {
      final records = (existingSession['records'] as List? ?? []);
      for (var r in records) {
        statusMap[r['student_id'].toString()] = r['status'].toString();
      }
    } else {
      for (var s in studentsList) {
        statusMap[s['id'].toString()] = 'present'; // Default
      }
    }

    final subjectCtrl = TextEditingController(
      text: (existingSession?['subject'] ?? _selectedSubject ?? _defaultBatchSubject()).toString(),
    );
    DateTime sessionDate = _toDate(existingSession?['date']) ?? DateTime.now();

    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.9,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Text(isEdit ? 'Edit Attendance' : 'Mark Attendance', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
                        const Spacer(),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(child: TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject/Topic'))),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(context: context, initialDate: sessionDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                            if (picked != null) setS(() => sessionDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                            child: Text(_dateLabel(sessionDate)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: studentsList.length,
                      separatorBuilder: (ctx, i) => const Divider(),
                      itemBuilder: (ctx, i) {
                        final s = studentsList[i];
                        final id = s['id'].toString();
                        final status = statusMap[id] ?? 'present';
                        
                        return Row(
                          children: [
                            CircleAvatar(radius: 16, child: Text(s['name'].toString().substring(0,1))),
                            const SizedBox(width: 12),
                            Expanded(child: Text(s['name'].toString(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600))),
                            _attendanceToggle('P', status == 'present', () => setS(() => statusMap[id] = 'present')),
                            const SizedBox(width: 4),
                            _attendanceToggle('A', status == 'absent', () => setS(() => statusMap[id] = 'absent')),
                            const SizedBox(width: 4),
                            _attendanceToggle('L', status == 'late', () => setS(() => statusMap[id] = 'late')),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: CustomButton(
                      text: 'Save Attendance',
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (approved != true) return;

    try {
      final attendanceSubject = subjectCtrl.text.trim().isEmpty
          ? (_selectedSubject ?? _defaultBatchSubject())
          : subjectCtrl.text.trim();
      final records = statusMap.entries.map((e) => {'student_id': e.key, 'status': e.value}).toList();
      await _adminRepo.markAttendance(
        batchId: widget.batchId,
        sessionDate: sessionDate.toIso8601String(),
        records: records,
        subject: attendanceSubject,
      );
      CPToast.success(context, 'Attendance updated');
      _loadBatch();
    } catch (e) {
      CPToast.error(context, e.toString());
    }
  }

  Widget _attendanceToggle(String label, bool active, VoidCallback onTap) {
    final color = label == 'P' ? Colors.green : (label == 'A' ? Colors.red : Colors.orange);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          border: Border.all(color: active ? color : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.grey, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Future<void> _showGenerateFeesDialog() async {
    int month = DateTime.now().month;
    int year = DateTime.now().year;
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Generate Monthly Fees'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This will generate fee records for all students in this batch for the selected month.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: month,
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_getMonthName(i + 1)))).toList(),
                      onChanged: (v) => setS(() => month = v ?? month),
                      decoration: const InputDecoration(labelText: 'Month'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: year,
                      items: [year - 1, year, year + 1].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                      onChanged: (v) => setS(() => year = v ?? year),
                      decoration: const InputDecoration(labelText: 'Year'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: dueDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (picked != null) setS(() => dueDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Due Date'),
                  child: Text(_dateLabel(dueDate)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );

    if (approved != true) return;

    try {
      await _adminRepo.generateMonthlyFees(
        batchId: widget.batchId,
        month: month,
        year: year,
        dueDate: dueDate.toIso8601String(),
      );
      CPToast.success(context, 'Fees generated successfully');
      _loadBatch();
    } catch (e) {
      CPToast.error(context, e.toString());
    }
  }

  String _getMonthName(int m) {
    return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
  }



  Future<void> _showLectureEditor({Map<String, dynamic>? lecture}) async {
    final isEdit = lecture != null;
    final lectureId = (lecture?['id'] ?? '').toString();

    final subjectCtrl = TextEditingController(
      text: (lecture?['subject'] ?? _defaultBatchSubject()).toString(),
    );
    final roomCtrl = TextEditingController(
      text: (lecture?['room'] ?? '').toString(),
    );
    final linkCtrl = TextEditingController(
      text: (lecture?['link'] ?? '').toString(),
    );
    final durationCtrl = TextEditingController(
      text: _toInt(lecture?['duration_minutes'] ?? lecture?['duration'], fallback: 60).toString(),
    );

    DateTime scheduledAt = _toDate(lecture?['scheduled_at']) ?? DateTime.now();
    String? selectedTeacherId = (lecture?['teacher_id'] ?? lecture?['teacherId'] ?? '').toString().trim();
    if ((selectedTeacherId ?? '').isEmpty && _teachers.isNotEmpty) {
      selectedTeacherId = (_teachers.first['id'] ?? '').toString();
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Lecture' : 'Schedule Lecture'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: (selectedTeacherId ?? '').isEmpty ? null : selectedTeacherId,
                      decoration: const InputDecoration(labelText: 'Teacher'),
                      items: _teachers.map((t) {
                        return DropdownMenuItem(
                          value: (t['id'] ?? '').toString(),
                          child: Text((t['name'] ?? 'Unknown').toString()),
                        );
                      }).toList(),
                      onChanged: (val) => setS(() => selectedTeacherId = val),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await _pickDateTime(initial: scheduledAt);
                        if (picked != null) setS(() => scheduledAt = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Scheduled At'),
                        child: Text('${_dateLabel(scheduledAt)} ${_timeLabel(scheduledAt)}'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Duration (mins)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: roomCtrl,
                      decoration: const InputDecoration(labelText: 'Room/Location'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: linkCtrl,
                      decoration: const InputDecoration(labelText: 'Online Link (Optional)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (approved != true) return;

    try {
      final data = {
        'batchId': widget.batchId,
        'teacherId': selectedTeacherId,
        'subject': subjectCtrl.text.trim(),
        'scheduledAt': scheduledAt.toIso8601String(),
        'duration': int.tryParse(durationCtrl.text) ?? 60,
        'room': roomCtrl.text.trim(),
        'link': linkCtrl.text.trim(),
      };

      if (isEdit) {
        await _adminRepo.updateLecture(lectureId: lectureId, data: data);
      } else {
        await _adminRepo.scheduleLecture(
          batchId: data['batchId'] as String,
          teacherId: data['teacherId'] as String,
          subject: data['subject'] as String,
          scheduledAt: scheduledAt,
          duration: data['duration'] as int,
          room: data['room'] as String?,
          link: data['link'] as String?,
        );
      }
      CPToast.success(context, isEdit ? 'Lecture updated' : 'Lecture scheduled');
      _loadBatch();
    } catch (e) {
      CPToast.error(context, e.toString());
    }
  }

  Future<void> _deleteLecture(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lecture?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _adminRepo.deleteLecture(id);
      CPToast.success(context, 'Lecture deleted');
      _loadBatch();
    } catch (e) {
      CPToast.error(context, e.toString());
    }
  }

  Future<void> _showExamEditor({Map<String, dynamic>? exam}) async {
    final isEdit = exam != null;
    final examId = (exam?['id'] ?? '').toString();

    final nameCtrl = TextEditingController(text: (exam?['name'] ?? '').toString());
    final subjectCtrl = TextEditingController(
      text: (exam?['subject'] ?? _selectedSubject ?? _defaultBatchSubject()).toString(),
    );
    final marksCtrl = TextEditingController(text: _toInt(exam?['total_marks'] ?? exam?['totalMarks'], fallback: 100).toString());
    final durationCtrl = TextEditingController(text: _toInt(exam?['duration'], fallback: 60).toString());
    DateTime date = _toDate(exam?['date']) ?? DateTime.now();

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Exam' : 'Create Exam'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Exam Name')),
                    const SizedBox(height: 10),
                    TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await _pickDateTime(initial: date);
                        if (picked != null) setS(() => date = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date & Time'),
                        child: Text('${_dateLabel(date)} ${_timeLabel(date)}'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: marksCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Marks')),
                    const SizedBox(height: 10),
                    TextField(controller: durationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (mins)')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (approved != true) return;

    try {
      final examSubject = subjectCtrl.text.trim().isEmpty
          ? (_selectedSubject ?? _defaultBatchSubject())
          : subjectCtrl.text.trim();
      final data = {
        'name': nameCtrl.text.trim(),
        'subject': examSubject,
        'date': date.toIso8601String(),
        'totalMarks': int.tryParse(marksCtrl.text) ?? 100,
        'duration': int.tryParse(durationCtrl.text) ?? 60,
        'batchId': widget.batchId,
      };

      if (isEdit) {
        await _adminRepo.updateExam(examId: examId, data: data);
      } else {
        await _adminRepo.createExam(
          name: data['name'] as String,
          subject: data['subject'] as String,
          date: date,
          totalMarks: data['totalMarks'] as int,
          duration: data['duration'] as int,
          batchId: widget.batchId,
        );
      }
      CPToast.success(context, isEdit ? 'Exam updated' : 'Exam created');
      _loadBatch();
    } catch (e) {
      CPToast.error(context, e.toString());
    }
  }

  Future<void> _deleteTest(Map<String, dynamic> test) async {
    final id = (test['id'] ?? '').toString();
    final isQuiz = test['assessment_type'] != null || test['item_type'] == 'quiz';
    final label = isQuiz ? 'Quiz' : 'Exam';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $label?'),
        content: Text('This will delete the $label and all its results.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      if (isQuiz) {
        await _adminRepo.deleteQuiz(id);
      } else {
        await _adminRepo.deleteExam(id);
      }
      CPToast.success(context, '$label deleted');
      _loadBatch();
    } catch (e) {
      CPToast.error(context, e.toString());
    }
  }

  Future<void> _showAnnouncementEditor({Map<String, dynamic>? announcement}) async {
    final isEdit = announcement != null;
    final id = (announcement?['id'] ?? '').toString();

    final titleCtrl = TextEditingController(text: (announcement?['title'] ?? '').toString());
    final bodyCtrl = TextEditingController(text: (announcement?['body'] ?? '').toString());
    String category = (announcement?['category'] ?? 'Batch').toString();
    bool pinned = (announcement?['pinned'] ?? false) == true;

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Announcement' : 'Post Announcement'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                    const SizedBox(height: 10),
                    TextField(controller: bodyCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Content')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      items: ['Batch', 'Urgent', 'Holiday', 'Exam'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setS(() => category = val ?? category),
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text('Pin to top', style: TextStyle(fontSize: 14)),
                      value: pinned,
                      onChanged: (val) => setS(() => pinned = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Post')),
              ],
            );
          },
        );
      },
    );

    if (approved != true) return;

    try {
      if (isEdit) {
        await _adminRepo.updateAnnouncement(id: id, title: titleCtrl.text.trim(), body: bodyCtrl.text.trim(), category: category, pinned: pinned);
      } else {
        await _adminRepo.createAnnouncement(title: titleCtrl.text.trim(), body: bodyCtrl.text.trim(), category: category, pinned: pinned);
        await _adminRepo.sendNotification(
          title: 'New Announcement: ${titleCtrl.text.trim()}',
          body: bodyCtrl.text.trim(),
          type: 'announcement',
          meta: {'batch_id': widget.batchId},
        );
      }
      CPToast.success(context, 'Announcement published');
      _loadBatch();
    } catch (e) {
      CPToast.error(context, e.toString());
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _adminRepo.deleteAnnouncement(id);
      CPToast.success(context, 'Deleted');
      _loadBatch();
    } catch (e) {
      CPToast.error(context, e.toString());
    }
  }

  Future<void> _showSubmissionsList(Map<String, dynamic> assignment) async {
    final id = (assignment['id'] ?? '').toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: CT.divider(context))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Submissions', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text((assignment['title'] ?? '').toString(), style: GoogleFonts.plusJakartaSans(fontSize: 14, color: CT.textS(context))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _adminRepo.getAssignmentSubmissions(id),
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final submissions = snapshot.data ?? [];
                  if (submissions.isEmpty) return const Center(child: Text('No submissions yet'));

                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: submissions.length,
                    separatorBuilder: (ctx, i) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final sub = submissions[i];
                      final studentName = (sub['student_name'] ?? 'Student').toString();
                      final status = (sub['status'] ?? 'pending').toString();
                      final submittedAt = _toDate(sub['submitted_at']);

                      return ListTile(
                        leading: CircleAvatar(child: Text(studentName.substring(0, 1))),
                        title: Text(studentName),
                        subtitle: Text('Submitted: ${_dateLabel(submittedAt)} ${_timeLabel(submittedAt)}'),
                        trailing: _statusTag(
                          status,
                          status.toLowerCase() == 'reviewed'
                              ? Colors.green
                              : (status.toLowerCase() == 'rejected'
                                  ? Colors.red
                                  : Colors.orange),
                        ),
                        onTap: () => _showSubmissionReviewer(sub),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubmissionReviewer(Map<String, dynamic> submission) async {
    final id = (submission['id'] ?? '').toString();
    final marksCtrl = TextEditingController(text: (submission['marks_obtained'] ?? '').toString());
    final remarksCtrl = TextEditingController(text: (submission['remarks'] ?? '').toString());
    String status = (submission['status'] ?? 'pending').toString();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Review Submission'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: ['pending', 'reviewed', 'rejected'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                  onChanged: (val) => setS(() => status = val ?? status),
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                const SizedBox(height: 10),
                TextField(controller: marksCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Marks Obtained')),
                const SizedBox(height: 10),
                TextField(controller: remarksCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Remarks')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                try {
                  await _adminRepo.reviewAssignmentSubmission(
                    submissionId: id,
                    status: status,
                    marksObtained: double.tryParse(marksCtrl.text),
                    remarks: remarksCtrl.text.trim(),
                  );
                  Navigator.pop(ctx);
                  CPToast.success(context, 'Submission reviewed');
                } catch (e) {
                  CPToast.error(context, e.toString());
                }
              },
              child: const Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildActionDock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: !_fabExpanded
              ? const SizedBox.shrink()
              : Container(
                  key: const ValueKey('fab-menu'),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF354388),
                      width: 1.6,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF354388),
                        offset: Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _fabMenuItem(
                        'Lecture',
                        Icons.ondemand_video_rounded,
                        () => GoRouter.of(context).push('/admin/timetable'),
                      ),
                      _fabMenuItem(
                        'Material',
                        Icons.note_add_outlined,
                        () => _showNoteEditor(),
                      ),
                      _fabMenuItem(
                        'Assignment',
                        Icons.assignment_outlined,
                        () => _showAssignmentEditor(),
                      ),
                      _fabMenuItem(
                        'Attendance',
                        Icons.how_to_reg_rounded,
                        () => _showAttendanceMarker(),
                      ),
                      _fabMenuItem(
                        'Test',
                        Icons.quiz_rounded,
                        () => GoRouter.of(context).push('/admin/exams'),
                      ),
                      _fabMenuItem(
                        'Student',
                        Icons.person_add_alt_rounded,
                        () => GoRouter.of(context).push('/admin/add-student'),
                      ),
                      _fabMenuItem(
                        'Fee',
                        Icons.payments_rounded,
                        () => GoRouter.of(context).push('/admin/fees'),
                      ),
                    ],
                  ),
                ),
        ),
        FloatingActionButton.extended(
          heroTag: '${widget.batchId}_fab_menu',
          onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
          backgroundColor: const Color(0xFF354388),
          foregroundColor: Colors.white,
          icon: Icon(
            _fabExpanded ? Icons.close_rounded : Icons.add_rounded,
            size: 18,
          ),
          label: Text(
            _fabExpanded ? 'Close' : 'Add',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fabMenuItem(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() => _fabExpanded = false);
          onTap();
        },
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF354388), width: 1.2),
          foregroundColor: const Color(0xFF354388),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF354388), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF354388)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF354388),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFeeReminder(Map<String, dynamic> record) async {
    final recordId = (record['id'] ?? '').toString();
    if (recordId.isEmpty) {
      CPToast.error(context, 'Invalid fee record');
      return;
    }

    try {
      await _adminRepo.sendFeeReminder(recordId);
      if (!mounted) return;
      CPToast.success(context, 'Fee reminder notification sent');
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, e.toString());
    }
  }

  Future<void> _markAsPaid(Map<String, dynamic> record) async {
    final amount = _toDouble(record['final_amount'] ?? record['amount']);
    final studentName = ((record['student'] as Map?)?['name'] ?? 'Student').toString();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment?'),
        content: Text('Mark ₹$amount as paid for $studentName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _adminRepo.recordFeePayment(
        feeRecordId: record['id'].toString(),
        amountPaid: amount,
        paymentMode: 'manual_qr_admin',
        note: 'Marked as paid by admin',
      );
      CPToast.success(context, 'Payment recorded');
      _loadBatch();
    } catch (e) {
      CPToast.error(context, e.toString());
    }
  }

  Future<void> _toggleBatchStatus() async {
    final current = (_batch?['is_active'] ?? true) == true;
    try {
      await _adminRepo.toggleBatchStatus(
        batchId: widget.batchId,
        isActive: !current,
      );
      if (!mounted) return;
      CPToast.success(context, !current ? 'Batch resumed' : 'Batch suspended');
      _loadBatch();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Failed: $e');
    }
  }

  Future<void> _deleteBatch() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete batch?'),
        content: const Text('This action cannot be undone.'),
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
    if (ok != true) return;

    try {
      await _adminRepo.deleteBatch(widget.batchId);
      if (!mounted) return;
      CPToast.success(context, 'Batch deleted');
      GoRouter.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Delete failed: $e');
    }
  }

  Future<void> _showMigrateSheet() async {
    final batches = await _adminRepo.getBatches();
    if (!mounted) return;
    final candidates = batches
        .where((b) => (b['id'] ?? '').toString() != widget.batchId)
        .toList();
    if (candidates.isEmpty) {
      if (!mounted) return;
      CPToast.warning(context, 'No target batch available');
      return;
    }

    String? targetId;
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFF354388), width: 3),
                  left: BorderSide(color: Color(0xFF354388), width: 3),
                  right: BorderSide(color: Color(0xFF354388), width: 3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Migrate students',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF354388),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: targetId,
                    decoration: const InputDecoration(
                      labelText: 'Target batch',
                    ),
                    items: candidates
                        .map(
                          (batch) => DropdownMenuItem<String>(
                            value: (batch['id'] ?? '').toString(),
                            child: Text((batch['name'] ?? 'Batch').toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setS(() => targetId = value),
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: 'Migrate',
                    onPressed: () {
                      if (targetId == null || targetId!.isEmpty) {
                        CPToast.warning(ctx, 'Please select target batch');
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (proceed != true || targetId == null || targetId!.isEmpty) return;

    try {
      final result = await _adminRepo.migrateBatchStudents(
        sourceBatchId: widget.batchId,
        targetBatchId: targetId!,
      );
      if (!mounted) return;
      CPToast.success(
        context,
        'Migrated ${result['migrated_count'] ?? 0} students',
      );
      _loadBatch();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Migration failed: $e');
    }
  }

  Future<void> _showMetaEditor() async {
    if (_batch == null) return;

    final descCtrl = TextEditingController(
      text: (_batch!['description'] ?? '').toString(),
    );
    final coverCtrl = TextEditingController(
      text: (_batch!['cover_image_url'] ?? '').toString(),
    );
    final subjectsCtrl = TextEditingController(
      text: ((_batch!['subjects'] as List?) ?? const []).join(', '),
    );
    final faqQuestionCtrl = TextEditingController();
    final faqAnswerCtrl = TextEditingController();

    final teacherIds = <String>{
      ...(((_batch!['teacher_ids'] as List?) ?? const []).map(
        (e) => e.toString(),
      )),
    };

    final faqs = ((_batch!['faqs'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFF354388), width: 3),
                  left: BorderSide(color: Color(0xFF354388), width: 3),
                  right: BorderSide(color: Color(0xFF354388), width: 3),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Batch Details',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: const Color(0xFF354388),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: coverCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cover image URL',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: subjectsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subjects (comma-separated)',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Teachers',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF354388),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _teachers.map((teacher) {
                        final id = (teacher['id'] ?? '').toString();
                        final selected = teacherIds.contains(id);
                        final name = (teacher['name'] ?? 'Teacher').toString();
                        return FilterChip(
                          label: Text(name),
                          selected: selected,
                          onSelected: (value) {
                            setS(() {
                              if (value) {
                                teacherIds.add(id);
                              } else {
                                teacherIds.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'FAQs',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF354388),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...faqs.asMap().entries.map((entry) {
                      final item = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Q: ${(item['question'] ?? '').toString()}\nA: ${(item['answer'] ?? '').toString()}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  setS(() => faqs.removeAt(entry.key)),
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                          ],
                        ),
                      );
                    }),
                    TextField(
                      controller: faqQuestionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'FAQ question',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: faqAnswerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'FAQ answer',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        if (faqQuestionCtrl.text.trim().isEmpty ||
                            faqAnswerCtrl.text.trim().isEmpty) {
                          return;
                        }
                        setS(() {
                          faqs.add({
                            'question': faqQuestionCtrl.text.trim(),
                            'answer': faqAnswerCtrl.text.trim(),
                          });
                          faqQuestionCtrl.clear();
                          faqAnswerCtrl.clear();
                        });
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add FAQ'),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'Save',
                      onPressed: () async {
                        try {
                          await _adminRepo.updateBatchMeta(
                            batchId: widget.batchId,
                            data: {
                              'description': descCtrl.text.trim().isEmpty
                                  ? null
                                  : descCtrl.text.trim(),
                              'cover_image_url': coverCtrl.text.trim().isEmpty
                                  ? null
                                  : coverCtrl.text.trim(),
                              'subjects': subjectsCtrl.text
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList(),
                              'teacher_ids': teacherIds.toList(),
                              'faqs': faqs,
                            },
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!mounted) return;
                          CPToast.success(context, 'Batch details updated');
                          _loadBatch();
                        } catch (e) {
                          if (ctx.mounted) {
                            CPToast.error(ctx, 'Update failed: $e');
                          }
                        }
                      },
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

  Widget _statusTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  String _recordStatus(Map<String, dynamic> record) {
    final amount = _toDouble(record['final_amount'] ?? record['amount']);
    final paid = _recordPaidAmount(record);
    return paid + 0.01 >= amount ? 'Paid' : 'Pending';
  }

  double _recordPaidAmount(Map<String, dynamic> record) {
    final payments = (record['payments'] as List?) ?? const [];
    return payments.fold<double>(
      0,
      (sum, p) => sum + _toDouble((p as Map)['amount_paid']),
    );
  }
}

extension _BatchDetailUtils on _BatchDetailPageState {
  double _toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
  int _toInt(dynamic v, {int fallback = 0}) => int.tryParse(v?.toString() ?? '') ?? fallback;
}


