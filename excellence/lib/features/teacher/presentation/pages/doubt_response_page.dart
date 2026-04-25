import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../data/repositories/teacher_repository.dart';

class _ThreadMessage {
  final String label;
  final String text;
  final String? imageUrl;
  final DateTime? timestamp;
  final bool isStudent;

  const _ThreadMessage({
    required this.label,
    required this.text,
    required this.timestamp,
    required this.isStudent,
    this.imageUrl,
  });

  _ThreadMessage copyWith({
    String? label,
    String? text,
    String? imageUrl,
    DateTime? timestamp,
    bool? isStudent,
  }) {
    return _ThreadMessage(
      label: label ?? this.label,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      isStudent: isStudent ?? this.isStudent,
    );
  }
}

class DoubtResponsePage extends StatefulWidget {
  final Map<String, dynamic> doubt;

  const DoubtResponsePage({super.key, required this.doubt});

  @override
  State<DoubtResponsePage> createState() => _DoubtResponsePageState();
}

class _DoubtResponsePageState extends State<DoubtResponsePage> with ThemeAware<DoubtResponsePage> {
  final _teacherRepo = sl<TeacherRepository>();
  final _answerController = TextEditingController();
  bool _isSubmitting = false;

  String get _doubtId {
    return (widget.doubt['id'] ?? widget.doubt['doubt_id'] ?? '').toString();
  }

  bool _labelRepresentsStudent(String label, bool defaultIsStudent) {
    final l = label.toLowerCase();
    if (l.contains('teacher') || l.contains('instructor')) return false;
    if (l.contains('student')) return true;
    return defaultIsStudent;
  }

  String _resolveStudentLabel(Map<String, dynamic> doubt) {
    final fromStudent = ((doubt['student'] as Map?)?['name'] ?? '').toString().trim();
    if (fromStudent.isNotEmpty) return fromStudent;

    final direct = (doubt['student_name'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    return 'Student';
  }

  String _resolveTeacherLabel(Map<String, dynamic> doubt) {
    final fromTeacher = ((doubt['teacher'] as Map?)?['name'] ?? '').toString().trim();
    if (fromTeacher.isNotEmpty) return fromTeacher;

    final fromAnsweredBy =
        ((doubt['answered_by'] as Map?)?['name'] ?? '').toString().trim();
    if (fromAnsweredBy.isNotEmpty) return fromAnsweredBy;

    final direct = (doubt['teacher_name'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    return 'Teacher';
  }

  String _normalizeThreadLabel({
    required String rawLabel,
    required bool isStudent,
    required String studentLabel,
    required String teacherLabel,
    required bool usedFallbackLabel,
  }) {
    final trimmed = rawLabel.trim();
    if (trimmed.isEmpty || usedFallbackLabel) {
      return isStudent ? studentLabel : teacherLabel;
    }

    final lower = trimmed.toLowerCase();
    if (isStudent &&
        (lower == 'student' ||
            lower.contains('student question') ||
            lower == 'question' ||
            lower == 'student message')) {
      return studentLabel;
    }

    if (!isStudent &&
        (lower == 'teacher' ||
            lower.contains('teacher reply') ||
            lower.contains('teacher response') ||
            lower.contains('instructor') ||
            lower == 'answer' ||
            lower == 'reply')) {
      return teacherLabel;
    }

    return trimmed;
  }

  List<_ThreadMessage> _parseThreadText({
    required String rawText,
    required bool defaultIsStudent,
    required String fallbackLabel,
    required String studentLabel,
    required String teacherLabel,
    DateTime? fallbackTimestamp,
  }) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return const [];

    final blocks = trimmed.split(RegExp(r'\n\s*\n+'));
    final headerPattern = RegExp(r'^\[(.+?)\s*\|\s*(.+?)\]$');
    final messages = <_ThreadMessage>[];

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
      var usedFallbackLabel = true;

      final headerMatch = headerPattern.firstMatch(rawLines.first.trim());
      if (headerMatch != null) {
        label = headerMatch.group(1)?.trim() ?? fallbackLabel;
        ts = DateTime.tryParse((headerMatch.group(2) ?? '').trim()) ?? ts;
        contentStart = 1;
        usedFallbackLabel = false;
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

      final isStudent = _labelRepresentsStudent(label, defaultIsStudent);
      final resolvedLabel = _normalizeThreadLabel(
        rawLabel: label,
        isStudent: isStudent,
        studentLabel: studentLabel,
        teacherLabel: teacherLabel,
        usedFallbackLabel: usedFallbackLabel,
      );

      messages.add(
        _ThreadMessage(
          label: resolvedLabel,
          text: text,
          imageUrl: imageUrl,
          timestamp: ts,
          isStudent: isStudent,
        ),
      );
    }

    return messages;
  }

  List<_ThreadMessage> _extractThreadMessages(Map<String, dynamic> doubt) {
    final studentLabel = _resolveStudentLabel(doubt);
    final teacherLabel = _resolveTeacherLabel(doubt);

    final createdAt = DateTime.tryParse(
      (doubt['createdAt'] ?? doubt['created_at'] ?? '').toString(),
    );
    final resolvedAt = DateTime.tryParse(
      (doubt['resolvedAt'] ?? doubt['resolved_at'] ?? '').toString(),
    );

    final questionText =
        (doubt['questionText'] ?? doubt['question_text'] ?? '').toString();
    final answerText =
        (doubt['answerText'] ?? doubt['answer_text'] ?? '').toString();
    final questionImg =
        (doubt['questionImg'] ?? doubt['question_img'] ?? '').toString().trim();
    final answerImg =
        (doubt['answerImg'] ?? doubt['answer_img'] ?? '').toString().trim();

    var fromStudent = _parseThreadText(
      rawText: questionText,
      defaultIsStudent: true,
      fallbackLabel: studentLabel,
      studentLabel: studentLabel,
      teacherLabel: teacherLabel,
      fallbackTimestamp: createdAt,
    );

    var fromTeacher = _parseThreadText(
      rawText: answerText,
      defaultIsStudent: false,
      fallbackLabel: teacherLabel,
      studentLabel: studentLabel,
      teacherLabel: teacherLabel,
      fallbackTimestamp: resolvedAt ?? createdAt,
    );

    if (fromStudent.isEmpty && (questionText.isNotEmpty || questionImg.isNotEmpty)) {
      fromStudent = [
        _ThreadMessage(
          label: studentLabel,
          text: questionText,
          imageUrl: questionImg.isEmpty ? null : questionImg,
          timestamp: createdAt,
          isStudent: true,
        ),
      ];
    } else if (questionImg.isNotEmpty &&
        fromStudent.isNotEmpty &&
        !fromStudent.any((m) => (m.imageUrl ?? '').trim().isNotEmpty)) {
      fromStudent[0] = fromStudent[0].copyWith(imageUrl: questionImg);
    }

    if (fromTeacher.isEmpty && (answerText.isNotEmpty || answerImg.isNotEmpty)) {
      fromTeacher = [
        _ThreadMessage(
          label: teacherLabel,
          text: answerText,
          imageUrl: answerImg.isEmpty ? null : answerImg,
          timestamp: resolvedAt ?? createdAt,
          isStudent: false,
        ),
      ];
    } else if (answerImg.isNotEmpty &&
        fromTeacher.isNotEmpty &&
        !fromTeacher.any((m) => (m.imageUrl ?? '').trim().isNotEmpty)) {
      final last = fromTeacher.length - 1;
      fromTeacher[last] = fromTeacher[last].copyWith(imageUrl: answerImg);
    }

    final all = <_ThreadMessage>[...fromStudent, ...fromTeacher];
    all.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return -1;
      if (b.timestamp == null) return 1;
      return a.timestamp!.compareTo(b.timestamp!);
    });
    return all;
  }

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type a reply first.')),
      );
      return;
    }

    final doubtId = _doubtId;
    if (doubtId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid doubt. Please reopen from list.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _teacherRepo.answerDoubt(doubtId: doubtId, answer: answer);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply sent and doubt resolved.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openImagePreview(String imageUrl) async {
    if (imageUrl.trim().isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxHeight: 560),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, stackTrace) {
                        return const Center(
                          child: Text('Failed to load image'),
                        );
                      },
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
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Widget _buildChatBubble(_ThreadMessage message) {
    const blue = AppColors.elitePrimary;
    const yellow = AppColors.moltenAmber;
    final bubbleColor = message.isStudent ? yellow : Colors.white;
    final textColor = blue;
    final align = message.isStudent ? Alignment.centerRight : Alignment.centerLeft;

    final ts = message.timestamp == null
        ? ''
        : DateFormat('MMM d, h:mm a').format(message.timestamp!.toLocal());

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: blue, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      message.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (ts.isNotEmpty)
                    Text(
                      ts,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
              if (message.text.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message.text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.25,
                  ),
                ),
              ],
              if ((message.imageUrl ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _openImagePreview((message.imageUrl ?? '').trim()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: blue.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image_rounded, size: 16, color: blue),
                        const SizedBox(width: 6),
                        Text(
                          'View Attachment',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.elitePrimary;
    const surface = AppColors.offWhite;
    const yellow = AppColors.moltenAmber;

    final d = widget.doubt;
    final subject = (d['subject'] ?? 'General').toString().toUpperCase();
    final studentName =
        ((d['student'] as Map?)?['name'] ?? 'Student').toString().toUpperCase();
    final batchName =
        ((d['batch'] as Map?)?['name'] ?? 'Batch').toString().toUpperCase();
    final messages = _extractThreadMessages(d);

    return Scaffold(
      backgroundColor: blue,
      appBar: AppBar(
        backgroundColor: blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 22,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/teacher');
            }
          },
        ),
        title: Text(
          'DOUBT CHAT',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: blue, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: yellow,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: blue),
                    ),
                    child: Text(
                      subject,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$studentName • $batchName',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: blue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: blue, width: 3),
              ),
              child: messages.isEmpty
                  ? Center(
                      child: Text(
                        'No thread messages found for this doubt.',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: blue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (_, i) => _buildChatBubble(messages[i]),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: blue, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _answerController,
                      minLines: 1,
                      maxLines: 4,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: blue,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type teacher reply...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: blue.withValues(alpha: 0.5),
                        ),
                        isDense: true,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: yellow,
                        foregroundColor: blue,
                        elevation: 0,
                        side: const BorderSide(color: blue, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'SEND',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}




