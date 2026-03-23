import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/teacher_repository.dart';

class CreateQuizPage extends StatefulWidget {
  const CreateQuizPage({super.key});

  @override
  State<CreateQuizPage> createState() => _CreateQuizPageState();
}

class _CreateQuizPageState extends State<CreateQuizPage> {
  final _repo = sl<TeacherRepository>();

  bool _isLoadingBatches = true;
  List<Map<String, dynamic>> _batches = [];
  String? _selectedBatchId;
  String? _selectedSubject;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _durationCtrl = TextEditingController();

  final List<Map<String, dynamic>> _questions = [];
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _addEmptyQuestion();
  }

  Future<void> _loadBatches() async {
    try {
      final b = await _repo.getMyBatches();
      if (!mounted) return;
      setState(() {
        _batches = b;
        _isLoadingBatches = false;
        if (b.isNotEmpty) {
          _selectedBatchId = b.first['id']?.toString();
          _selectedSubject = b.first['subject']?.toString() ?? 'General';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingBatches = false);
    }
  }

  void _addEmptyQuestion() {
    setState(() {
      _questions.add({
        'question': TextEditingController(),
        'options': [TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController()],
        'correct_index': 0,
        'marks': '4'
      });
    });
  }

  Future<void> _publishQuiz() async {
    final title = _titleCtrl.text.trim();
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 0;

    if (title.isEmpty || duration <= 0 || _selectedBatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all main fields.')));
      return;
    }

    final parsedQuestions = <Map<String, dynamic>>[];
    for (int i = 0; i < _questions.length; i++) {
      final qMap = _questions[i];
      final qText = (qMap['question'] as TextEditingController).text.trim();
      final optCtrls = qMap['options'] as List<TextEditingController>;
      final opts = optCtrls.map((c) => c.text.trim()).toList();
      final correctIdx = qMap['correct_index'] as int;

      if (qText.isEmpty || opts.any((o) => o.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all fields in Question ${i + 1}.')));
        return;
      }
      parsedQuestions.add({
        'question_text': qText,
        'options': opts,
        'correct_option_index': correctIdx,
        'marks': int.tryParse(qMap['marks'].toString()) ?? 4,
        'type': 'multiple_choice'
      });
    }

    if (parsedQuestions.isEmpty) return;

    setState(() => _isPublishing = true);
    try {
      await _repo.createQuiz(
        title: title,
        subject: _selectedSubject ?? 'General',
        batchId: _selectedBatchId!,
        timeLimit: duration,
        questions: parsedQuestions,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz Published Successfully!')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
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
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('CREATE QUIZ', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1.0)),
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildSettingsCard(blue, surface, yellow),
              const SizedBox(height: 32),
              Text('QUESTIONS (${_questions.length})', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: yellow, letterSpacing: 2)),
              const SizedBox(height: 16),
              ...List.generate(_questions.length, (idx) => _buildQuestionCard(idx, blue, surface, yellow)),
              const SizedBox(height: 16),
              _buildAddQuestionBtn(blue, surface, yellow),
              const SizedBox(height: 40),
            ]),
          ),
        ),
        _buildBottomBar(blue, surface, yellow),
      ]),
    );
  }

  Widget _buildSettingsCard(Color blue, Color surface, Color yellow) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: Colors.black, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(5, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _inputLabel('QUIZ TITLE', blue),
          _textField(_titleCtrl, 'e.g. WEEKLY TEST #4', blue),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_inputLabel('MINS', blue), _textField(_durationCtrl, '60', blue, isNum: true)])),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_inputLabel('BATCH', blue), _buildBatchDropdown(blue)])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inputLabel(String label, Color blue) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900, color: blue.withValues(alpha: 0.5), letterSpacing: 1)));

  Widget _textField(TextEditingController ctrl, String hint, Color blue, {bool isNum = false, int maxLines = 1}) => TextField(
    controller: ctrl,
    keyboardType: isNum ? TextInputType.number : TextInputType.text,
    maxLines: maxLines,
    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: blue),
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black, width: 2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black, width: 2.5)),
    ),
  );

  Widget _buildBatchDropdown(Color blue) {
    if (_isLoadingBatches) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 2), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBatchId,
          isExpanded: true,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: blue),
          onChanged: (val) => setState(() {
            _selectedBatchId = val;
            _selectedSubject = _batches.firstWhere((b) => b['id']?.toString() == val, orElse: () => {})['subject']?.toString();
          }),
          items: _batches.map((b) => DropdownMenuItem(value: b['id']?.toString(), child: Text(b['name']?.toString() ?? 'BATCH', overflow: TextOverflow.ellipsis))).toList(),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, Color blue, Color surface, Color yellow) {
    final qMap = _questions[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: Colors.black, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: yellow, offset: const Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: blue, borderRadius: BorderRadius.circular(4)), child: Text('Q${index + 1}', style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.w900))),
              if (_questions.length > 1) IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.coralRed), onPressed: () => setState(() => _questions.removeAt(index))),
            ],
          ),
          const SizedBox(height: 16),
          _textField(qMap['question'], 'ENTER QUESTION...', blue, maxLines: 2),
          const SizedBox(height: 20),
          _inputLabel('OPTIONS', blue),
          ...List.generate(4, (i) => _optionRow(index, i, blue, yellow)),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _optionRow(int qIdx, int oIdx, Color blue, Color yellow) {
    final qMap = _questions[qIdx];
    final isCorrect = qMap['correct_index'] == oIdx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => qMap['correct_index'] = oIdx),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: isCorrect ? yellow : Colors.white, border: Border.all(color: Colors.black, width: 2), shape: BoxShape.circle),
              child: isCorrect ? const Icon(Icons.check_rounded, size: 18, color: Colors.black) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _textField(qMap['options'][oIdx], 'OPTION ${String.fromCharCode(65 + oIdx)}', blue)),
        ],
      ),
    );
  }

  Widget _buildAddQuestionBtn(Color blue, Color surface, Color yellow) => InkWell(
    onTap: _addEmptyQuestion,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: blue.withValues(alpha: 0.3), border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2, strokeAlign: BorderSide.strokeAlignOutside), borderRadius: BorderRadius.circular(16)),
      child: Center(child: Text('+ ADD ANOTHER QUESTION', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: Colors.white))),
    ),
  );

  Widget _buildBottomBar(Color blue, Color surface, Color yellow) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    decoration: BoxDecoration(color: surface, border: const Border(top: BorderSide(color: Colors.black, width: 4))),
    child: SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: blue,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black, width: 3)),
        ),
        onPressed: _isPublishing ? null : _publishQuiz,
        child: _isPublishing ? const CircularProgressIndicator() : Text('PUBLISH QUIZ', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    ),
  );
}
