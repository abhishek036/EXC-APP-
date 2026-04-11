import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import '../../../../core/services/cloud_storage_service.dart';
import '../../../../core/utils/file_opener.dart';
import '../../data/repositories/student_repository.dart';

class AssignmentSubmissionPage extends StatefulWidget {
  final String? initialAssignmentId;
  final String? initialFileUrl;

  const AssignmentSubmissionPage({
    super.key,
    this.initialAssignmentId,
    this.initialFileUrl,
  });

  @override
  State<AssignmentSubmissionPage> createState() =>
      _AssignmentSubmissionPageState();
}

class _AssignmentSubmissionPageState extends State<AssignmentSubmissionPage> {
  final _studentRepo = sl<StudentRepository>();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isDraftSaving = false;
  bool _isFileUploaded = false;
  String? _error;

  final _fileUrlCtrl = TextEditingController();
  final _submissionTextCtrl = TextEditingController();

  List<Map<String, dynamic>> _assignments = [];
  Map<String, dynamic>? _selectedAssignment;
  PlatformFile? _selectedFile;
  Map<String, dynamic>? _mySubmission;
  Timer? _draftTimer;
  DateTime? _lastDraftSavedAt;
  String _lastDraftSignature = '';

  @override
  void initState() {
    super.initState();
    _assignmentFileUrl = widget.initialFileUrl;
    _submissionTextCtrl.addListener(_onDraftInputChanged);
    _startDraftTimer();
    _loadAssignments();
  }

  String? _assignmentFileUrl;

  @override
  void dispose() {
    _draftTimer?.cancel();
    _submissionTextCtrl.removeListener(_onDraftInputChanged);
    _fileUrlCtrl.dispose();
    _submissionTextCtrl.dispose();
    super.dispose();
  }

  void _startDraftTimer() {
    _draftTimer?.cancel();
    _draftTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _autoSaveDraft();
    });
  }

  void _onDraftInputChanged() {
    // Debounced via periodic timer; listener ensures latest text is tracked.
  }

  String _fileExt(String? fileName) {
    final raw = (fileName ?? '').trim().toLowerCase();
    if (raw.isEmpty || !raw.contains('.')) return '';
    return raw.split('.').last;
  }

  String _draftSignature() {
    final assignmentId = (_selectedAssignment?['id'] ?? '').toString();
    final text = _submissionTextCtrl.text.trim();
    final existingFileUrl = (_mySubmission?['file_url'] ?? '').toString().trim();
    final localFile = _selectedFile?.name ?? '';
    return '$assignmentId|$text|$existingFileUrl|$localFile';
  }

  Future<void> _autoSaveDraft({bool force = false}) async {
    if (_isLoading || _isSubmitting || _isDraftSaving) return;
    final assignmentId = (_selectedAssignment?['id'] ?? '').toString();
    if (assignmentId.isEmpty) return;

    final currentText = _submissionTextCtrl.text.trim();
    final existingFileUrl = (_mySubmission?['file_url'] ?? '').toString().trim();
    final hasDraftContent = currentText.isNotEmpty || existingFileUrl.isNotEmpty || _isFileUploaded;
    if (!hasDraftContent) return;

    final signature = _draftSignature();
    if (!force && signature == _lastDraftSignature) return;

    setState(() => _isDraftSaving = true);
    try {
      await _studentRepo.saveAssignmentDraft(
        assignmentId: assignmentId,
        fileUrl: existingFileUrl.isNotEmpty ? existingFileUrl : null,
        submissionText: currentText.isNotEmpty ? currentText : null,
        fileName: _selectedFile?.name,
        fileMimeType: _selectedFile?.extension,
        fileSizeKb: _selectedFile != null ? (_selectedFile!.size / 1024).ceil() : null,
        fileExt: _fileExt(_selectedFile?.name),
        scanStatus: 'pending',
      );
      _lastDraftSignature = signature;
      _lastDraftSavedAt = DateTime.now();
    } catch (_) {
      // Silent failure: autosave should not block user flow.
    } finally {
      if (mounted) setState(() => _isDraftSaving = false);
    }
  }

  Future<void> _loadAssignments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _studentRepo.getAssignments();
      final targetId = (widget.initialAssignmentId ?? '').trim();
      Map<String, dynamic>? selected;
      if (targetId.isNotEmpty) {
        for (final item in list) {
          if ((item['id'] ?? '').toString() == targetId) {
            selected = item;
            break;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _assignments = list;
        _selectedAssignment = selected ?? (list.isNotEmpty ? list.first : null);
        _applySelectedAssignmentState();
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

  void _applySelectedAssignmentState() {
    final assignment = _selectedAssignment;
    if (assignment == null) {
      _assignmentFileUrl = widget.initialFileUrl;
      _mySubmission = null;
      _submissionTextCtrl.clear();
      _selectedFile = null;
      _isFileUploaded = false;
      return;
    }

    _assignmentFileUrl = assignment['file_url']?.toString() ?? widget.initialFileUrl;
    final existing = assignment['my_submission'];
    if (existing is Map) {
      _mySubmission = Map<String, dynamic>.from(existing);
      _submissionTextCtrl.text = (_mySubmission?['submission_text'] ?? '').toString();
    } else {
      _mySubmission = null;
      _submissionTextCtrl.clear();
    }
    _selectedFile = null;
    _isFileUploaded = false;
    _lastDraftSignature = _draftSignature();
  }

  Future<void> _downloadAndOpenFile({
    required String url,
    required String fallbackFileName,
    String? mimeType,
  }) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) return;

    try {
      await downloadAndOpenFromUrl(
        url: trimmedUrl,
        fileName: fallbackFileName,
        mimeType: (mimeType ?? '').trim().isEmpty ? null : mimeType,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to download/open this file right now.'),
        ),
      );
    }
  }

  Future<void> _submitAssignment() async {
    final assignmentId = (_selectedAssignment?['id'] ?? '').toString();
    if (assignmentId.isEmpty) return;

    final existingFileUrl = (_mySubmission?['file_url'] ?? '').toString().trim();
    final existingText = (_mySubmission?['submission_text'] ?? '').toString().trim();
    final currentText = _submissionTextCtrl.text.trim();

    final hasPayload = _isFileUploaded || currentText.isNotEmpty || existingFileUrl.isNotEmpty || existingText.isNotEmpty;

    if (!hasPayload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload a file or add text before submitting'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String? uploadedUrl;
      if (_isFileUploaded && _selectedFile != null) {
        final storage = sl<CloudStorageService>();
        if (_selectedFile!.bytes != null) {
           uploadedUrl = await storage.uploadBytes(_selectedFile!.bytes!.toList(), 'assignments', _selectedFile!.name);
        } else if (_selectedFile!.path != null) {
           uploadedUrl = await storage.uploadFile(File(_selectedFile!.path!), 'assignments');
        }
      }

      final effectiveFileUrl = (uploadedUrl != null && uploadedUrl.trim().isNotEmpty)
          ? uploadedUrl.trim()
          : (existingFileUrl.isNotEmpty ? existingFileUrl : null);

      final effectiveText = currentText.isNotEmpty
          ? currentText
          : (existingText.isNotEmpty ? existingText : null);

      await _studentRepo.submitAssignment(
        assignmentId: assignmentId,
        fileUrl: effectiveFileUrl,
        submissionText: effectiveText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment submitted successfully')),
      );
      await _loadAssignments();
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignment = _selectedAssignment;
    final title = (assignment?['title'] ?? 'No Assignment Available')
        .toString();
    final subject = (assignment?['subject'] ?? 'General').toString();
    final description =
        (assignment?['description'] ?? 'No assignment description provided.')
            .toString();
    final dueDateRaw = (assignment?['due_date'] ?? '').toString();
    final dueLabel = _formatDueLabel(dueDateRaw);

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text(
          'Submit Assignment',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: GoogleFonts.plusJakartaSans(color: CT.textM(context)),
              ),
            )
          : assignment == null
          ? Center(
              child: Text(
                'No assignments found',
                style: GoogleFonts.plusJakartaSans(color: CT.textM(context)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_assignments.length > 1) ...[
                    Text(
                      'Select Assignment',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CT.textH(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: CT.card(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CT.border(context)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: (assignment['id'] ?? '').toString(),
                          isExpanded: true,
                          items: _assignments.map((item) {
                            final id = (item['id'] ?? '').toString();
                            final label = (item['title'] ?? 'Assignment')
                                .toString();
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedAssignment = _assignments.firstWhere(
                                (item) =>
                                    (item['id'] ?? '').toString() == value,
                                orElse: () => _assignments.first,
                              );
                              _applySelectedAssignmentState();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Basic Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.physics.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          subject,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.physics,
                          ),
                        ),
                      ),
                      Text(
                        dueLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          (assignment['progress_label'] ?? 'Not Started').toString(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_isDraftSaving)
                        Text(
                          'Saving draft...',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textM(context)),
                        )
                      else if (_lastDraftSavedAt != null)
                        Text(
                          'Draft saved',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.success),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: CT.textS(context),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_assignmentFileUrl != null && _assignmentFileUrl!.isNotEmpty) ...[
                    CPPressable(
                      onTap: () async {
                        await _downloadAndOpenFile(
                          url: _assignmentFileUrl!,
                          fallbackFileName:
                              (assignment['file_name'] ?? '$title.pdf').toString(),
                          mimeType: (assignment['file_mime_type'] ?? '').toString(),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.moltenAmber,
                          border: Border.all(color: AppColors.elitePrimary, width: 2),
                          boxShadow: const [BoxShadow(color: AppColors.elitePrimary, offset: Offset(3, 3))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.description_rounded, size: 20, color: AppColors.elitePrimary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'DOWNLOAD INSTRUCTION FILE',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: AppColors.elitePrimary,
                                ),
                              ),
                            ),
                            const Icon(Icons.download_for_offline_rounded, size: 20, color: AppColors.elitePrimary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_mySubmission != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CT.card(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Existing submission detected (editable)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Status: ${(_mySubmission?['status'] ?? 'submitted').toString()}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: CT.textS(context),
                            ),
                          ),
                          if (((_mySubmission?['file_url'] ?? '').toString().trim().isNotEmpty)) ...[
                            const SizedBox(height: 8),
                            CPPressable(
                              onTap: () async {
                                final submissionFileName =
                                    (_mySubmission?['file_name'] ??
                                            '${title}_submission.pdf')
                                        .toString();
                                await _downloadAndOpenFile(
                                  url: (_mySubmission?['file_url'] ?? '').toString(),
                                  fallbackFileName: submissionFileName,
                                  mimeType: (_mySubmission?['file_mime_type'] ?? '')
                                      .toString(),
                                );
                              },
                              child: Text(
                                'Open previously submitted file',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const SizedBox(height: 32),

                  // Upload Box
                  Text(
                    'Your Submission',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (!_isFileUploaded)
                    CPPressable(
                          onTap: () async {
                            try {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
                                withData: kIsWeb,
                              );
                              if (result != null && result.files.isNotEmpty) {
                                final picked = result.files.first;
                                if (picked.size > 20 * 1024 * 1024) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('File too large. Max size is 20MB.')),
                                  );
                                  return;
                                }
                                setState(() {
                                  _selectedFile = picked;
                                  _isFileUploaded = true;
                                });
                                await _autoSaveDraft(force: true);
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to pick file: $e')),
                              );
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            decoration: BoxDecoration(
                              color: CT.card(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 1.5,
                              ), // Simulate dashed border
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.cloud_upload_outlined,
                                    color: AppColors.primary,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tap to browse files',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'PDF, DOCX, JPG (Max 20MB)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: CT.textM(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.05, end: 0)
                  else
                    // Uploaded File Card
                    Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: CT.card(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(
                                  alpha: 0.05,
                                ),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Text(
                                        _selectedFile?.name ?? '${title.replaceAll(' ', '_')}.pdf',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedFile != null ? '${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB • Ready to upload' : 'Ready to upload',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: CT.textS(context),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _isFileUploaded = false;
                                    _selectedFile = null;
                                  });
                                },
                                icon: Icon(
                                  Icons.close,
                                  color: CT.textM(context),
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .scaleXY(
                          begin: 0.95,
                          end: 1.0,
                          curve: Curves.easeOutBack,
                        ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: _submissionTextCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Submission note (optional)',
                      hintText: 'Any remarks for teacher...',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Action Buttons
                  Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () { if (context.canPop()) { context.pop(); } else { context.go('/student'); } },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: BorderSide(color: CT.textM(context)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  color: CT.textS(context),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: CustomButton(
                              text: _isSubmitting
                                  ? 'Submitting...'
                                  : 'Turn In Assignment',
                              onPressed: !_isSubmitting
                                  ? _submitAssignment
                                  : null,
                            ),
                          ),
                        ],
                      )
                      .animate(delay: 200.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.05, end: 0),
                ],
              ),
            ),
    );
  }

  String _formatDueLabel(String dueDateRaw) {
    if (dueDateRaw.isEmpty) return 'No due date';
    final due = DateTime.tryParse(dueDateRaw)?.toLocal();
    if (due == null) return 'Due soon';
    final now = DateTime.now();
    final days = due.difference(now).inDays;
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }
}
