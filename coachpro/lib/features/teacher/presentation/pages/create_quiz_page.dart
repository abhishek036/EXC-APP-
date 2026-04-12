import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/cloud_storage_service.dart';
 '../../../../core/theme/theme_aware.dart';
CreateQuizPage extends StatefulWidget {
  final String? initialBatchId;
  final String? initialSubject;
  final String? quizId;
  final String? initialAssessmentType;

  const CreateQuizPage({
    super.key,
    this.initialBatchId,
    this.initialSubject,
    this.quizId,
    this.initialAssessmentType,
  });

  @override
  State<CreateQuizPage> createState() => _CreateQuizPageState();
}

class _CreateQuizPageState extends State<CreateQuizPage> with ThemeAware<CreateQuizPage> {
  final _repo = sl<TeacherRepository>();
  final _storage = sl<CloudStorageService>();

  bool _isLoadingBatches = true;
  List<Map<String, dynamic>> _batches = [];
  String? _selectedBatchId;
  String? _selectedSubject;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _durationCtrl = TextEditingController();
  final TextEditingController _negativeMarkingCtrl = TextEditingController();
  final TextEditingController _defaultQuestionMarksCtrl =
      TextEditingController(text: '4');

  final List<Map<String, dynamic>> _questions = [];
  bool _isPublishing = false;
  String _assessmentType = 'QUIZ';
  DateTime? _scheduledAt;
  bool _allowRetry = true;
  bool _showInstantResult = true;

  bool get _isEditMode => widget.quizId != null && widget.quizId!.isNotEmpty;

  String? get _safeSelectedBatchId {
    if (_selectedBatchId == null || _selectedBatchId!.isEmpty) return null;
    final hasSelected = _batches.any(
      (b) => (b['id'] ?? '').toString() == _selectedBatchId,
    );
    return hasSelected ? _selectedBatchId : null;
  }

  Map<String, dynamic>? _findBatchById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final batch in _batches) {
      if ((batch['id'] ?? '').toString() == id) return batch;
    }
    return null;
  }

  TextEditingController _ensureMarksController(Map<String, dynamic> question) {
    final existing = question['marks'];
    if (existing is TextEditingController) return existing;

    final controller = TextEditingController(
      text: (existing ?? _defaultQuestionMarksCtrl.text).toString(),
    );
    question['marks'] = controller;
    return controller;
  }

  void _applyDefaultMarksToAllQuestions() {
    final value = int.tryParse(_defaultQuestionMarksCtrl.text.trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default marks must be a positive number.')),
      );
      return;
    }

    setState(() {
      for (final question in _questions) {
        _ensureMarksController(question).text = '$value';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _assessmentType =
        (widget.initialAssessmentType ?? 'QUIZ').toUpperCase() == 'TEST'
            ? 'TEST'
            : 'QUIZ';
    _allowRetry = _assessmentType == 'QUIZ';
    _showInstantResult = _assessmentType == 'QUIZ';
    if (widget.initialSubject != null &&
        widget.initialSubject!.trim().isNotEmpty) {
      _selectedSubject = widget.initialSubject!.trim();
    }
    _loadBatches();
    if (!_isEditMode) {
      _addEmptyQuestion();
    }
  }

  Future<void> _loadBatches() async {
    try {
      final b = await _repo.getMyBatches();
      if (!mounted) return;
      setState(() {
        _batches = b;
        _isLoadingBatches = false;
        if (b.isNotEmpty) {
          final pre = widget.initialBatchId;
          final matched = (pre != null && pre.isNotEmpty)
              ? b.where((item) => (item['id'] ?? '').toString() == pre).toList()
              : const <Map<String, dynamic>>[];
          final selected = matched.isNotEmpty ? matched.first : b.first;
          _selectedBatchId = (selected['id'] ?? '').toString();
          _selectedSubject =
              widget.initialSubject ??
              selected['subject']?.toString() ??
              'General';
        }
      });

      if (_isEditMode) {
        await _loadQuizForEdit();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingBatches = false);
    }
  }

  void _clearQuestions() {
    for (final item in _questions) {
      if (item['question'] is TextEditingController) {
        (item['question'] as TextEditingController).dispose();
      }
      final options = item['options'] as List;
      for (final opt in options) {
        if (opt is Map && opt['text'] is TextEditingController) {
          (opt['text'] as TextEditingController).dispose();
        } else if (opt is TextEditingController) {
          opt.dispose();
        }
      }
      if (item['marks'] is TextEditingController) {
        (item['marks'] as TextEditingController).dispose();
      }
    }
    _questions.clear();
  }

  Future<void> _loadQuizForEdit() async {
    try {
      final quiz = await _repo.getQuizById(widget.quizId!);
      if (!mounted) return;

      final questions = ((quiz['questions'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      const optionToIndex = {'A': 0, 'B': 1, 'C': 2, 'D': 3};

      _clearQuestions();
      for (final question in questions) {
        _questions.add({
          'question': TextEditingController(
            text: (question['question_text'] ?? '').toString(),
          ),
          'image_url': (question['image_url'] ?? '').toString(),
          'options': [
            {
              'text': TextEditingController(
                text: (question['option_a'] ?? '').toString(),
              ),
              'image_url': (question['option_a_image'] ?? '').toString(),
            },
            {
              'text': TextEditingController(
                text: (question['option_b'] ?? '').toString(),
              ),
              'image_url': (question['option_b_image'] ?? '').toString(),
            },
            {
              'text': TextEditingController(
                text: (question['option_c'] ?? '').toString(),
              ),
              'image_url': (question['option_c_image'] ?? '').toString(),
            },
            {
              'text': TextEditingController(
                text: (question['option_d'] ?? '').toString(),
              ),
              'image_url': (question['option_d_image'] ?? '').toString(),
            },
          ],
          'correct_index':
              optionToIndex[(question['correct_option'] ?? 'A')
                  .toString()
                  .toUpperCase()] ??
              0,
          'marks': TextEditingController(
            text: (question['marks'] ?? 1).toString(),
          ),
        });
      }

      if (_questions.isEmpty) {
        _addEmptyQuestion();
      }

      final firstQuestion = _questions.isNotEmpty ? _questions.first : null;
      if (firstQuestion != null) {
        final firstMarks = _ensureMarksController(firstQuestion).text.trim();
        if (firstMarks.isNotEmpty) {
          _defaultQuestionMarksCtrl.text = firstMarks;
        }
      }

      setState(() {
        _titleCtrl.text = (quiz['title'] ?? '').toString();
        _assessmentType =
            ((quiz['assessment_type'] ?? _assessmentType)
                    .toString()
                    .toUpperCase() ==
                'TEST')
            ? 'TEST'
            : 'QUIZ';
        _durationCtrl.text =
            (quiz['time_limit_min'] ?? (_assessmentType == 'TEST' ? 60 : ''))
                .toString();
        _selectedBatchId = (quiz['batch_id'] ?? _selectedBatchId ?? '')
            .toString();
        _selectedSubject = (quiz['subject'] ?? _selectedSubject ?? 'General')
            .toString();
        _scheduledAt = quiz['scheduled_at'] != null
            ? DateTime.tryParse(quiz['scheduled_at'].toString())?.toLocal()
            : null;
        _negativeMarkingCtrl.text = (quiz['negative_marking'] ?? '').toString();
        _allowRetry = quiz['allow_retry'] == null
            ? _assessmentType == 'QUIZ'
            : quiz['allow_retry'] == true;
        _showInstantResult = quiz['show_instant_result'] == null
            ? _assessmentType == 'QUIZ'
            : quiz['show_instant_result'] == true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load quiz for edit: $e')),
      );
      if (_questions.isEmpty) {
        _addEmptyQuestion();
      }
    }
  }

  void _addEmptyQuestion() {
    final defaultMarks = int.tryParse(_defaultQuestionMarksCtrl.text.trim());
    final resolvedMarks =
        (defaultMarks != null && defaultMarks > 0)
            ? defaultMarks
            : (_assessmentType == 'TEST' ? 1 : 4);

    setState(() {
      _questions.add({
        'question': TextEditingController(),
        'image_url': '',
        'options': List.generate(
          4,
          (index) => {
            'text': TextEditingController(),
            'image_url': '',
          },
        ),
        'correct_index': 0,
        'marks': TextEditingController(text: '$resolvedMarks'),
      });
    });
  }

  Future<void> _pickQuestionImage(int qIndex, {int? oIndex}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() => _isPublishing = true);

        String url;
        if (kIsWeb) {
          url = await _storage.uploadBytes(file.bytes!, 'quizzes', file.name);
        } else {
          url = await _storage.uploadFile(File(file.path!), 'quizzes');
        }

        setState(() {
          if (oIndex == null) {
            _questions[qIndex]['image_url'] = url;
          } else {
            (_questions[qIndex]['options'] as List)[oIndex]['image_url'] = url;
          }
          _isPublishing = false;
        });
      }
    } catch (e) {
      setState(() => _isPublishing = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _publishQuiz() async {
    final title = _titleCtrl.text.trim();
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    final negativeMarking = double.tryParse(_negativeMarkingCtrl.text.trim());

    if (title.isEmpty || _selectedBatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all main fields.')),
      );
      return;
    }

    if (_assessmentType == 'TEST' && duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test mode needs a strict timer.')),
      );
      return;
    }

    final parsedQuestions = <Map<String, dynamic>>[];
    for (int i = 0; i < _questions.length; i++) {
      final qMap = _questions[i];
      final qText = (qMap['question'] as TextEditingController).text.trim();
      final options = qMap['options'] as List;
      final correctIdx = qMap['correct_index'] as int;
      final imageUrl = qMap['image_url'] as String?;

      final optTexts = <String>[];
      final optImages = <String>[];

      for (final opt in options) {
        final text = (opt['text'] as TextEditingController).text.trim();
        optTexts.add(text);
        optImages.add((opt['image_url'] as String?) ?? '');
      }

      if (qText.isEmpty || optTexts.any((o) => o.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fill all text fields in Question ${i + 1}.'),
          ),
        );
        return;
      }

      final marksText = _ensureMarksController(qMap).text.trim();
      final parsedMarks = int.tryParse(marksText) ?? 0;
      if (parsedMarks <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please set a positive marks weightage for Question ${i + 1}.',
            ),
          ),
        );
        return;
      }

      parsedQuestions.add({
        'question_text': qText,
        'image_url': imageUrl,
        'options': optTexts,
        'option_a_image': optImages[0],
        'option_b_image': optImages[1],
        'option_c_image': optImages[2],
        'option_d_image': optImages[3],
        'correct_option_index': correctIdx,
        'marks': parsedMarks,
        'type': 'multiple_choice',
      });
    }

    if (parsedQuestions.isEmpty) return;

    setState(() => _isPublishing = true);
    try {
      if (_isEditMode) {
        await _repo.updateQuiz(
          quizId: widget.quizId!,
          title: title,
          subject: _selectedSubject ?? 'General',
          batchId: _selectedBatchId!,
          timeLimit: duration,
          questions: parsedQuestions,
          assessmentType: _assessmentType,
          scheduledAt: _scheduledAt,
          negativeMarking: negativeMarking,
          allowRetry: _allowRetry,
          showInstantResult: _showInstantResult,
        );
      } else {
        await _repo.createQuiz(
          title: title,
          subject: _selectedSubject ?? 'General',
          batchId: _selectedBatchId!,
          timeLimit: duration,
          questions: parsedQuestions,
          assessmentType: _assessmentType,
          scheduledAt: _scheduledAt,
          negativeMarking: negativeMarking,
          allowRetry: _allowRetry,
          showInstantResult: _showInstantResult,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Quiz Updated Successfully!'
                : 'Quiz Published Successfully!',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _durationCtrl.dispose();
    _negativeMarkingCtrl.dispose();
    _defaultQuestionMarksCtrl.dispose();
    _clearQuestions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);
    const yellow = Color(0xFFF0DE36);

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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'EDIT QUIZ' : 'CREATE QUIZ',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingsCard(blue, surface, yellow),
                  const SizedBox(height: 32),
                  Text(
                    'QUESTIONS (${_questions.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: yellow,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                    _questions.length,
                    (idx) => _buildQuestionCard(idx, blue, surface, yellow),
                  ),
                  const SizedBox(height: 16),
                  _buildAddQuestionBtn(blue, surface, yellow),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          _buildBottomBar(blue, surface, yellow),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(Color blue, Color surface, Color yellow) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _inputLabel('QUIZ TITLE', blue),
          _textField(_titleCtrl, 'e.g. WEEKLY TEST #4', blue),
          const SizedBox(height: 24),
          _inputLabel('MODE', blue),
          Row(
            children: [
              Expanded(
                child: _modeChip(
                  label: 'QUIZ (PRACTICE)',
                  value: 'QUIZ',
                  selected: _assessmentType == 'QUIZ',
                  blue: blue,
                  yellow: yellow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _modeChip(
                  label: 'TEST (EXAM)',
                  value: 'TEST',
                  selected: _assessmentType == 'TEST',
                  blue: blue,
                  yellow: yellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _inputLabel(
                      _assessmentType == 'TEST'
                          ? 'STRICT TIMER (MINS)'
                          : 'OPTIONAL TIMER (MINS)',
                      blue,
                    ),
                    _textField(
                      _durationCtrl,
                      _assessmentType == 'TEST' ? '60' : '0',
                      blue,
                      isNum: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _inputLabel('BATCH', blue),
                    _buildBatchDropdown(blue),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _inputLabel('DEFAULT MARKS / QUESTION', blue),
                    _textField(
                      _defaultQuestionMarksCtrl,
                      _assessmentType == 'TEST' ? '1' : '4',
                      blue,
                      isNum: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _inputLabel('APPLY DEFAULT', blue),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _applyDefaultMarksToAllQuestions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: yellow,
                          foregroundColor: blue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: blue, width: 2),
                          ),
                        ),
                        child: Text(
                          'APPLY TO ALL',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_assessmentType == 'TEST') ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _inputLabel('NEGATIVE MARKING (OPTIONAL)', blue),
                      _textField(
                        _negativeMarkingCtrl,
                        '0.25',
                        blue,
                        isNum: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _inputLabel('SCHEDULE (OPTIONAL)', blue),
                      OutlinedButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _scheduledAt ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (date == null || !mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              _scheduledAt ?? DateTime.now(),
                            ),
                          );
                          if (time == null || !mounted) return;
                          setState(() {
                            _scheduledAt = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          side: BorderSide(color: blue, width: 2),
                          backgroundColor: Colors.white,
                        ),
                        child: Text(
                          _scheduledAt == null
                              ? 'SET DATE & TIME'
                              : '${_scheduledAt!.day.toString().padLeft(2, '0')}/${_scheduledAt!.month.toString().padLeft(2, '0')} ${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (_assessmentType == 'QUIZ')
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    value: _allowRetry,
                    onChanged: (v) => setState(() => _allowRetry = v),
                    title: Text(
                      'ALLOW RETRY',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: blue,
                      ),
                    ),
                    dense: true,
                    activeThumbColor: yellow,
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    value: _showInstantResult,
                    onChanged: (v) => setState(() => _showInstantResult = v),
                    title: Text(
                      'INSTANT RESULT',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: blue,
                      ),
                    ),
                    dense: true,
                    activeThumbColor: yellow,
                  ),
                ),
              ],
            )
          else
            Text(
              'TEST MODE: ONE ATTEMPT, STRICT TIMER, LEADERBOARD ENABLED',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: blue.withValues(alpha: 0.7),
                letterSpacing: 0.6,
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeChip({
    required String label,
    required String value,
    required bool selected,
    required Color blue,
    required Color yellow,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _assessmentType = value;
          if (_assessmentType == 'QUIZ') {
            _allowRetry = true;
            _showInstantResult = true;
          } else {
            _allowRetry = false;
            _showInstantResult = false;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? yellow : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: blue, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 11,
              color: blue,
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputLabel(String label, Color blue) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: blue.withValues(alpha: 0.5),
        letterSpacing: 1,
      ),
    ),
  );

  Widget _textField(
    TextEditingController ctrl,
    String hint,
    Color blue, {
    bool isNum = false,
    int maxLines = 1,
  }) => TextField(
    controller: ctrl,
    keyboardType: isNum ? TextInputType.number : TextInputType.text,
    maxLines: maxLines,
    style: GoogleFonts.plusJakartaSans(
      fontWeight: FontWeight.w800,
      color: blue,
    ),
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: blue, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: blue, width: 2.5),
      ),
    ),
  );

  Widget _buildBatchDropdown(Color blue) {
    if (_isLoadingBatches) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: blue, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _safeSelectedBatchId,
          isExpanded: true,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: blue,
          ),
          onChanged: (val) {
            final selectedBatch = _findBatchById(val);
            setState(() {
              _selectedBatchId = val;
              _selectedSubject =
                  selectedBatch?['subject']?.toString() ?? 'General';
            });
          },
          items: _batches
              .map(
                (b) => DropdownMenuItem(
                  value: b['id']?.toString(),
                  child: Text(
                    b['name']?.toString() ?? 'BATCH',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    int index,
    Color blue,
    Color surface,
    Color yellow,
  ) {
    final qMap = _questions[index];
    final imageUrl = qMap['image_url'] as String?;
    final marksCtrl = _ensureMarksController(qMap);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
                  'Q${index + 1}',
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      imageUrl != null && imageUrl.isNotEmpty
                          ? Icons.image_rounded
                          : Icons.add_photo_alternate_rounded,
                      color: imageUrl != null && imageUrl.isNotEmpty
                          ? blue
                          : blue.withValues(alpha: 0.5),
                    ),
                    onPressed: () => _pickQuestionImage(index),
                    tooltip: 'Add Question Image',
                  ),
                  if (_questions.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.coralRed,
                      ),
                      onPressed: () {
                        final removed = _questions.removeAt(index);
                        if (removed['question'] is TextEditingController) {
                          (removed['question'] as TextEditingController).dispose();
                        }

                        final removedOptions =
                            (removed['options'] as List?) ?? const [];
                        for (final opt in removedOptions) {
                          if (opt is Map && opt['text'] is TextEditingController) {
                            (opt['text'] as TextEditingController).dispose();
                          } else if (opt is TextEditingController) {
                            opt.dispose();
                          }
                        }

                        if (removed['marks'] is TextEditingController) {
                          (removed['marks'] as TextEditingController).dispose();
                        }

                        setState(() {});
                      },
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (imageUrl != null && imageUrl.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: blue, width: 2),
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => qMap['image_url'] = ''),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _textField(qMap['question'], 'ENTER QUESTION...', blue, maxLines: 2),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _inputLabel('MARKS WEIGHTAGE', blue),
                    _textField(marksCtrl, '4', blue, isNum: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _inputLabel('OPTIONS', blue),
          ...List.generate(4, (i) => _optionRow(index, i, blue, yellow)),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _optionRow(int qIdx, int oIdx, Color blue, Color yellow) {
    final qMap = _questions[qIdx];
    final option = (qMap['options'] as List)[oIdx];
    final isCorrect = qMap['correct_index'] == oIdx;
    final optImageUrl = option['image_url'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => qMap['correct_index'] = oIdx),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCorrect ? yellow : Colors.white,
                    border: Border.all(color: blue, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: isCorrect
                      ? Icon(Icons.check_rounded, size: 18, color: blue)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(
                  option['text'] as TextEditingController,
                  'OPTION ${String.fromCharCode(65 + oIdx)}',
                  blue,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  optImageUrl != null && optImageUrl.isNotEmpty
                      ? Icons.image_rounded
                      : Icons.add_photo_alternate_rounded,
                  color: optImageUrl != null && optImageUrl.isNotEmpty
                      ? blue
                      : blue.withValues(alpha: 0.5),
                ),
                onPressed: () => _pickQuestionImage(qIdx, oIndex: oIdx),
                tooltip: 'Add Option Image',
              ),
            ],
          ),
          if (optImageUrl != null && optImageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 4, bottom: 8),
              child: Stack(
                children: [
                  Container(
                    height: 100,
                    width: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: blue, width: 2),
                      image: DecorationImage(
                        image: NetworkImage(optImageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => option['image_url'] = ''),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddQuestionBtn(Color blue, Color surface, Color yellow) =>
      InkWell(
        onTap: _addEmptyQuestion,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: blue.withValues(alpha: 0.3),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              '+ ADD ANOTHER QUESTION',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );

  Widget _buildBottomBar(Color blue, Color surface, Color yellow) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    decoration: BoxDecoration(
      color: surface,
      border: Border(top: BorderSide(color: blue, width: 4)),
    ),
    child: SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: blue,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: blue, width: 3),
          ),
        ),
        onPressed: _isPublishing ? null : _publishQuiz,
        child: _isPublishing
            ? const CircularProgressIndicator()
            : Text(
                _isEditMode ? 'UPDATE QUIZ' : 'PUBLISH QUIZ',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
      ),
    ),
  );
}

