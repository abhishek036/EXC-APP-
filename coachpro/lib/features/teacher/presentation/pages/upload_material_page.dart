import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';

class UploadMaterialPage extends StatefulWidget {
  const UploadMaterialPage({super.key});
  @override
  State<UploadMaterialPage> createState() => _UploadMaterialPageState();
}

class _UploadMaterialPageState extends State<UploadMaterialPage> {
  int _selectedType = 0; // 0: Notes, 1: Assignment, 2: Video Link
  final _types = ['Notes', 'Assignment', 'Video Link'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(title: Text('Upload Material', style: GoogleFonts.sora(fontWeight: FontWeight.w600))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Segmented Control
          Container(
            height: 44,
            decoration: BoxDecoration(color: CT.textM(context), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: List.generate(_types.length, (i) => Expanded(
                child: CPPressable(
                  onTap: () => setState(() => _selectedType = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _selectedType == i ? CT.bg(context) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _selectedType == i ? [BoxShadow(color: CT.textH(context).withValues(alpha: 0.05), blurRadius: 4)] : [],
                    ),
                    child: Center(child: Text(_types[i], style: GoogleFonts.dmSans(fontSize: 13, fontWeight: _selectedType == i ? FontWeight.w800 : FontWeight.w600, color: _selectedType == i ? CT.textH(context) : CT.textS(context)))),
                  ),
                ),
              )),
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 24),

          // Form fields
          const CustomTextField(
            label: 'Title',
            hint: 'e.g. Laws of Motion - Lecture 2',
            prefixIcon: Icons.title,
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 16),
          
          Row(children: [
            Expanded(child: _dropdownField('Select Batch', 'JEE Batch A')),
            const SizedBox(width: 16),
            Expanded(child: _dropdownField('Subject', 'Physics')),
          ]).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 16),

          if (_selectedType == 1) ...[ // Assignment specific
            const CustomTextField(
              label: 'Due Date',
              hint: 'Select due date & time',
              prefixIcon: Icons.calendar_today_outlined,
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 16),
          ],

          if (_selectedType == 2) ...[ // Video Link
            const CustomTextField(
              label: 'Video Link',
              hint: 'Paste YouTube or Drive link here',
              prefixIcon: Icons.link,
            ).animate().fadeIn(duration: 300.ms),
          ] else ...[ // File upload area for Notes/Assignment
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5, style: BorderStyle.none), // In a real app use a dotted border package
              ),
              child: Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _DashedBorderPainter())),
                Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: CT.card(context), shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 10)]), child: Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 28)),
                    const SizedBox(height: 16),
                    Text('Tap to upload file or drag & drop', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text('PDF, DOC, PPT (Max 20MB)', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textM(context))),
                  ]),
                ),
              ]),
            ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
          ],

          const SizedBox(height: 40),
          CustomButton(text: 'Publish ${_types[_selectedType]}', icon: Icons.send, onPressed: () {}).animate(delay: 400.ms).fadeIn(duration: 400.ms),
        ]),
      ),
    );
  }

  Widget _dropdownField(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(color: CT.card(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: CT.textM(context))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: CT.textM(context), fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: Text(value, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: CT.textH(context)))),
        Icon(Icons.keyboard_arrow_down, size: 20, color: CT.textM(context)),
      ]),
    ]),
  );
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(16));
    
    // Simple dash logic (for a real app, use path_drawing package)
    final dashPaint = Paint()..color = AppColors.primary.withValues(alpha: 0.4)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    canvas.drawRRect(rRect, dashPaint); // Placeholder for actual dashed effect
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
