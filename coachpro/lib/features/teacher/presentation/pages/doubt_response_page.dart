import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/theme/theme_aware.dart';

import '../../../../features/teacher/data/repositories/teacher_repository.dart';
import '../../../../core/di/injection_container.dart';
import 'package:go_router/go_router.dart';

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

    setState(() => _isSubmitting = true);
    try {
      await _teacherRepo.answerDoubt(
        doubtId: widget.doubt['id'],
        answer: answer,
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doubt;
    final subject = d['subject'] ?? 'Subject';
    final studentName = (d['student'] as Map?)?['name'] ?? 'Student';
    final batchName = (d['batch'] as Map?)?['name'] ?? 'Batch';
    final question = d['question_text'] ?? '';
    final color = _getSubjectColor(subject);

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text('Resolve Doubt', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // The Question
          Container(
            padding: const EdgeInsets.all(16),
            decoration: CT.cardDecor(context),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(subject, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
                ),
              ]),
              const SizedBox(height: 12),
              Text(question, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4, color: CT.textH(context))),
              const SizedBox(height: 14),
              Row(children: [
                CircleAvatar(radius: 14, backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: Text(studentName[0], style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
                const SizedBox(width: 8),
                Expanded(child: Text('$studentName • $batchName', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textM(context), fontWeight: FontWeight.w600))),
              ]),
            ]),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 32),

          // The Response Input
          Text('Your Response', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: CT.textH(context))),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _answerController,
            hint: 'Type your explanation here...',
            maxLines: 8,
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 20),

          // Media attachments
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text('Camera', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3))),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.mic_none_outlined),
                label: Text('Voice Note', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3))),
              ),
            ),
          ]).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 40),
          CustomButton(
            text: _isSubmitting ? 'Submitting...' : 'Mark as Resolved', 
            onPressed: _isSubmitting ? null : _submitAnswer
          ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
        ]),
      ),
    );
  }

  Color _getSubjectColor(String s) {
    s = s.toLowerCase();
    if (s.contains('physics')) return AppColors.physics;
    if (s.contains('chem')) return AppColors.chemistry;
    if (s.contains('math')) return AppColors.mathematics;
    return CT.accent(context);
  }
}
