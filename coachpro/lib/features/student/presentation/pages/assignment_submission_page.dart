import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';

class AssignmentSubmissionPage extends StatefulWidget {
  const AssignmentSubmissionPage({super.key});

  @override
  State<AssignmentSubmissionPage> createState() => _AssignmentSubmissionPageState();
}

class _AssignmentSubmissionPageState extends State<AssignmentSubmissionPage> {
  bool _isFileUploaded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text('Submit Assignment', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Basic Info
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.physics.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('Physics', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.physics)),
            ),
            Text('Due In 2 Days', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          Text('Mechanics Problem Set #4', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            'Complete all 20 problems from the worksheet. Ensure you show all steps for the free-body diagrams in questions 12 to 15.',
            style: GoogleFonts.dmSans(fontSize: 14, color: CT.textS(context), height: 1.5),
          ),
          const SizedBox(height: 32),

          // Upload Box
          Text('Your Submission', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          
          if (!_isFileUploaded)
            CPPressable(
              onTap: () {
                // Simulate upload
                setState(() => _isFileUploaded = true);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: CT.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5), // Simulate dashed border
                ),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text('Tap to browse files', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(height: 6),
                  Text('PDF, DOCX, JPG (Max 20MB)', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textM(context))),
                ]),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0)
          else
            // Uploaded File Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CT.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.05), blurRadius: 10)],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.red),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rohan_Sharma_PS4.pdf', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('2.4 MB • Uploaded just now', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textS(context))),
                ])),
                IconButton(
                  onPressed: () => setState(() => _isFileUploaded = false),
                  icon: Icon(Icons.close, color: CT.textM(context)),
                ),
              ]),
            ).animate().fadeIn(duration: 400.ms).scaleXY(begin: 0.95, end: 1.0, curve: Curves.easeOutBack),
          
          const SizedBox(height: 40),
          
          // Action Buttons
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: CT.textM(context)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cancel', style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: CT.textS(context))),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: CustomButton(
                text: 'Turn In Assignment',
                onPressed: _isFileUploaded ? () {} : null, // Disable if no file
              ),
            ),
          ]).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
        ]),
      ),
    );
  }
}
