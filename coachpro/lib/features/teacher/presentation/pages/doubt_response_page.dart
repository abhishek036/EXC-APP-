import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../features/teacher/data/repositories/teacher_repository.dart';
import '../../../../core/di/injection_container.dart';

class DoubtResponsePage extends StatefulWidget {
  final Map<String, dynamic> doubt;
  const DoubtResponsePage({super.key, required this.doubt});

  @override
  State<DoubtResponsePage> createState() => _DoubtResponsePageState();
}

class _DoubtResponsePageState extends State<DoubtResponsePage> {
  final _teacherRepo = sl<TeacherRepository>();
  final _answerController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;

    final doubtId = widget.doubt['id']?.toString() ?? '';
    if (doubtId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid doubt payload. Please open this from Pending Doubts page.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _teacherRepo.answerDoubt(doubtId: doubtId, answer: answer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doubt marked as resolved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);
    const yellow = Color(0xFFF0DE36);

    final d = widget.doubt;
    final subject = d['subject']?.toString().toUpperCase() ?? 'GENERAL';
    final studentName =
        (d['student'] as Map?)?['name']?.toString().toUpperCase() ?? 'STUDENT';
    final batchName =
        (d['batch'] as Map?)?['name']?.toString().toUpperCase() ?? 'BATCH';
    final question = d['question_text']?.toString() ?? '';

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
          'RESOLVE DOUBT',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuestionCard(
              subject,
              question,
              studentName,
              batchName,
              blue,
              surface,
              yellow,
            ),
            const SizedBox(height: 40),
            _inputLabel(
              'YOUR SOLUTION/EXPLANATION',
              Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _answerController,
              'TYPE YOUR ANSWER HERE...',
              blue,
            ),
            const SizedBox(height: 32),
            _buildMediaActions(blue, surface, yellow),
            const SizedBox(height: 48),
            _buildSubmitBtn(blue, surface, yellow),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    String subject,
    String question,
    String student,
    String batch,
    Color blue,
    Color surface,
    Color yellow,
  ) {
    final studentInitial = student.isNotEmpty ? student[0] : 'S';
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: blue,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              subject,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            question,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: blue,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: yellow,
                  border: Border.all(color: blue, width: 2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  studentInitial,
                  style: TextStyle(fontWeight: FontWeight.w900, color: blue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$student • $batch',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: blue.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _inputLabel(String label, Color color) => Text(
    label,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w900,
      color: color,
      letterSpacing: 1,
    ),
  );

  Widget _buildTextField(TextEditingController ctrl, String hint, Color blue) =>
      TextField(
        controller: ctrl,
        maxLines: 8,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          color: blue,
        ),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(20),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: blue, width: 2.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: blue, width: 3),
          ),
        ),
      );

  Widget _buildMediaActions(Color blue, Color surface, Color yellow) {
    return Row(
      children: [
        Expanded(
          child: _mediaBtn(Icons.camera_alt_rounded, 'CAMERA', blue, surface),
        ),
        const SizedBox(width: 16),
        Expanded(child: _mediaBtn(Icons.mic_rounded, 'VOICE', blue, surface)),
      ],
    );
  }

  Widget _mediaBtn(IconData icon, String label, Color blue, Color surface) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label support will be enabled soon')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: blue, width: 2.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: blue, offset: const Offset(2, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: blue, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: blue,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitBtn(Color blue, Color surface, Color yellow) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: blue,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: blue, width: 3),
          ),
        ),
        onPressed: _isSubmitting ? null : _submitAnswer,
        child: _isSubmitting
            ? const CircularProgressIndicator()
            : Text(
                'MARK AS RESOLVED',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
