import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/download_registry.dart';
import '../../../../core/utils/file_opener.dart';
import '../../../../core/utils/stable_token.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/download_status_icon.dart';
import '../../data/repositories/teacher_repository.dart';

class AssignmentReviewPage extends StatefulWidget {
  final String batchId;
  final String? initialAssignmentId;
  final String? initialAssignmentTitle;

  const AssignmentReviewPage({
    super.key,
    required this.batchId,
    this.initialAssignmentId,
    this.initialAssignmentTitle,
  });

  @override
  State<AssignmentReviewPage> createState() => _AssignmentReviewPageState();
}

class _AssignmentReviewPageState extends State<AssignmentReviewPage> with ThemeAware<AssignmentReviewPage> {
  final _repo = sl<TeacherRepository>();

  final _marksCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _assignments = [];
  String? _selectedAssignmentId;
  List<Map<String, dynamic>> _submissions = [];
  int _index = 0;

  String? get _safeSelectedAssignmentId {
    if (_selectedAssignmentId == null || _selectedAssignmentId!.isEmpty) {
      return null;
    }
    final hasSelected = _assignments.any(
      (a) => (a['id'] ?? '').toString() == _selectedAssignmentId,
    );
    return hasSelected ? _selectedAssignmentId : null;
  }

  @override
  void initState() {
    super.initState();
    DownloadRegistry.instance.ensureLoaded();
    _loadAssignments();
  }

  @override
  void dispose() {
    _marksCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAssignments() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final assignments = await _repo.getAssignments(batchId: widget.batchId);
      final selected = widget.initialAssignmentId ?? (assignments.isNotEmpty
          ? (assignments.first['id'] ?? '').toString()
          : null);
      if (!mounted) return;
      setState(() {
        _assignments = assignments;
        _selectedAssignmentId = selected;
      });
      if (selected != null && selected.isNotEmpty) {
        await _loadSubmissions(selected);
      } else {
        setState(() {
          _submissions = [];
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assignments = [];
        _submissions = [];
        _loading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load assignments: $e')));
    }
  }

  Future<void> _loadSubmissions(String assignmentId) async {
    try {
      final items = await _repo.getAssignmentSubmissions(assignmentId);
      if (!mounted) return;
      setState(() {
        _submissions = items;
        _index = 0;
        _loading = false;
      });
      _applyCurrent();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submissions = [];
        _index = 0;
        _loading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load submissions: $e')));
    }
  }

  Map<String, dynamic>? get _current {
    if (_submissions.isEmpty || _index < 0 || _index >= _submissions.length) {
      return null;
    }
    return _submissions[_index];
  }

  void _applyCurrent() {
    final current = _current;
    if (current == null) {
      _marksCtrl.clear();
      _remarksCtrl.clear();
      return;
    }
    _marksCtrl.text = (current['marks_obtained'] ?? '').toString();
    _remarksCtrl.text = (current['remarks'] ?? '').toString();
  }

  Future<void> _openSubmissionFile() async {
    final current = _current;
    if (current == null) return;

    final fileUrl = (current['file_url'] ?? '').toString().trim();
    if (fileUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file uploaded for this submission.')),
      );
      return;
    }

    final fileName = (current['file_name'] ?? 'submission.pdf').toString().trim();
    final mimeType = (current['file_mime_type'] ?? '').toString().trim();

    try {
      await downloadAndOpenFromUrl(
        url: fileUrl,
        fileName: fileName.isEmpty ? null : fileName,
        mimeType: mimeType.isEmpty ? null : mimeType,
        downloadKey: current['id'] != null
            ? 'submission:${current["id"]}'
            : 'submission:${stableToken(fileUrl)}',
      );
    } catch (_) {
      final uri = Uri.tryParse(fileUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open submitted file.')),
      );
    }
  }

  Future<void> _saveAndNext() async {
    final current = _current;
    if (current == null) return;

    final submissionId = (current['id'] ?? '').toString();
    if (submissionId.isEmpty) return;

    final marks = num.tryParse(_marksCtrl.text.trim());

    setState(() => _saving = true);
    try {
      await _repo.reviewAssignmentSubmission(
        submissionId: submissionId,
        status: 'evaluated',
        marksObtained: marks,
        remarks: _remarksCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _submissions[_index] = {
          ..._submissions[_index],
          'status': 'evaluated',
          'marks_obtained': marks,
          'remarks': _remarksCtrl.text.trim(),
        };
        if (_index < _submissions.length - 1) {
          _index += 1;
        }
      });
      _applyCurrent();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reviewed and saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Review failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    if (_index < _submissions.length - 1) {
      setState(() => _index += 1);
      _applyCurrent();
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index -= 1);
      _applyCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.elitePrimary;
    const surface = AppColors.offWhite;
    const yellow = AppColors.moltenAmber;

    return Scaffold(
      backgroundColor: blue,
      appBar: AppBar(
        backgroundColor: blue,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 22,
          ),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              GoRouter.of(context).pop();
            } else {
              GoRouter.of(context).go('/teacher');
            }
          },
        ),
        title: Text(
          'ASSIGNMENT REVIEW',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: yellow))
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: surface,
                    border: Border.all(color: blue, width: 2.5),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: blue, offset: const Offset(4, 4)),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _safeSelectedAssignmentId,
                      isExpanded: true,
                      items: _assignments
                          .map(
                            (a) => DropdownMenuItem<String>(
                              value: (a['id'] ?? '').toString(),
                              child: Text(
                                (a['title'] ?? 'Assignment').toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val == null || val.isEmpty) return;
                        setState(() {
                          _selectedAssignmentId = val;
                          _loading = true;
                        });
                        _loadSubmissions(val);
                      },
                    ),
                  ),
                ),
                if (_submissions.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'NO SUBMISSIONS FOUND',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity == null) return;
                        if (details.primaryVelocity! < 0) {
                          _next();
                        } else {
                          _prev();
                        }
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _leftSubmissionCard(blue, surface, yellow),
                          const SizedBox(height: 12),
                          _rightReviewCard(blue, surface, yellow),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _leftSubmissionCard(Color blue, Color surface, Color yellow) {
    final current = _current ?? {};
    final student = ((current['student'] as Map?)?['name'] ?? 'Student')
        .toString();
    final text = (current['submission_text'] ?? '').toString();
    final fileUrl = (current['file_url'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 2.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
      ),
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
                    color: blue,
                  ),
                ),
              ),
              Text(
                '${_index + 1}/${_submissions.length}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: blue.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Submission',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: blue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text.isEmpty ? 'No text submitted.' : text,
            style: GoogleFonts.plusJakartaSans(
              color: blue.withValues(alpha: 0.8),
            ),
          ),
          if (fileUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _openSubmissionFile,
                  icon: DownloadStatusIcon(
                    downloadKey: 'submission:${stableToken(fileUrl)}',
                    idleIcon: Icons.picture_as_pdf_rounded,
                    downloadedIcon: Icons.check_circle_rounded,
                    idleColor: blue,
                    downloadedColor: AppColors.success,
                    size: 18,
                    spinnerSize: 18,
                    strokeWidth: 2,
                  ),
                  label: const Text('Open Submitted PDF'),
                ),
                SizedBox(
                  width: 260,
                  child: SelectableText(
                    fileUrl,
                    maxLines: 2,
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: blue),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _rightReviewCard(Color blue, Color surface, Color yellow) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 2.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              color: blue,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _marksCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Marks'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _remarksCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Remarks'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton(onPressed: _prev, child: const Text('Prev')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _next, child: const Text('Next')),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: yellow,
                  foregroundColor: blue,
                ),
                onPressed: _saving ? null : _saveAndNext,
                child: Text(_saving ? 'Saving...' : 'Save & Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}





