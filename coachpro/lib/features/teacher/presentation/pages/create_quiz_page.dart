import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/theme/theme_aware.dart';

class CreateQuizPage extends StatefulWidget {
  const CreateQuizPage({super.key});

  @override
  State<CreateQuizPage> createState() => _CreateQuizPageState();
}

class _CreateQuizPageState extends State<CreateQuizPage> {
  int _correctAnswerIndex = 0; // 0: A, 1: B, 2: C, 3: D

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        leading: IconButton(onPressed: () {}, icon: const Icon(Icons.close)),
        title: Text('Create Quiz', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('Save Draft', style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Settings
              const CustomTextField(label: 'Quiz Title', hint: 'e.g. Weekly Test #4'),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: CustomTextField(label: 'Duration (mins)', hint: '60', keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: CustomTextField(label: 'Total Marks', hint: '100', keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 32),
              
              Text('Questions (1 added)', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              
              // Collapsed Question Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: CT.card(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: CT.textM(context))),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('1. What is the value of G?', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Multiple Choice • 4 marks', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textM(context))),
                  ])),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20)),
                ]),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 16),

              // Expanded Add Question Form
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: CT.card(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.05), blurRadius: 10)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Question 2', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    Text('4 marks', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: CT.textS(context))),
                  ]),
                  const SizedBox(height: 16),
                  const CustomTextField(label: 'Question Text', hint: 'Enter your question here...', maxLines: 3),
                  const SizedBox(height: 20),
                  Text('Options (Select correct answer)', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: CT.textM(context))),
                  const SizedBox(height: 12),
                  
                  ...List.generate(4, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => setState(() => _correctAnswerIndex = i),
                        child: Padding(
                           padding: const EdgeInsets.all(8.0),
                           child: Icon(
                             i == _correctAnswerIndex ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                             color: i == _correctAnswerIndex ? AppColors.success : Colors.grey,
                           ),
                        ),
                      ),
                      Expanded(child: CustomTextField(hint: 'Option ${String.fromCharCode(65 + i)}')), // A, B, C, D
                    ]),
                  )),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 18), label: Text('Add Option', style: GoogleFonts.sora(fontWeight: FontWeight.w600))),
                  ),
                ]),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
              
              const SizedBox(height: 16),
              // Add Question dashed button
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary, width: 1.5)), // Placeholder for dotted border
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Add New Question', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ])),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),
            ]),
          ),
        ),
        // Bottom Fixed Button
        Container(
          padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
          decoration: BoxDecoration(color: CT.card(context), boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.05), blurRadius: 10, offset: Offset(0, -4))]),
          child: CustomButton(text: 'Publish Quiz', onPressed: () {}),
        ),
      ]),
    );
  }
}
