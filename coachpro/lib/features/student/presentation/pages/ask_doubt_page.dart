import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/firebase_storage_service.dart';
import '../../../student/data/repositories/student_repository.dart';

class AskDoubtPage extends StatefulWidget {
  const AskDoubtPage({super.key});

  @override
  State<AskDoubtPage> createState() => _AskDoubtPageState();
}

class _AskDoubtPageState extends State<AskDoubtPage> {
  List<Map<String, dynamic>> _batches = [];
  Map<String, dynamic>? _selectedBatch;
  final _questionController = TextEditingController();
  String? _questionError;
  XFile? _selectedImage;
  bool _isSubmitting = false;
  final _studentRepo = sl<StudentRepository>();
  final _storage = sl<FirebaseStorageService>();

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final batches = await _studentRepo.getMyBatches();
      if (mounted) {
        setState(() {
          _batches = batches;
          if (batches.isNotEmpty) _selectedBatch = batches[0];
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked != null) {
        setState(() {
          _selectedImage = picked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _submitDoubt() async {
    setState(() {
      _questionError = _questionController.text.trim().isEmpty
          ? 'Please describe your doubt'
          : _questionController.text.trim().length < 10
          ? 'Please provide more details (min 10 chars)'
          : null;
    });
    if (_questionError != null) return;
    if (_selectedBatch == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No batch selected')));
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String? imageUrl;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        imageUrl = await _storage.uploadBytes(bytes, 'doubts', _selectedImage!.name);
      }

      await _studentRepo.submitDoubt(
        batchId: _selectedBatch!['id'] as String,
        question: _questionController.text.trim(),
        imageUrl: imageUrl,
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Doubt submitted successfully!',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to submit: ${e.toString().replaceFirst('Exception: ', '')}',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 18, color: CT.textH(context)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Ask a Doubt',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: CT.textH(context),
          ),
        ),
        backgroundColor: CT.bg(context),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1282),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stuck on a problem?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Our teachers are here to help you out.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.help_outline, color: Colors.white, size: 40),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 24),

            // Batch Selection
            Text(
              'Select Batch/Subject',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CT.textH(context),
              ),
            ),
            const SizedBox(height: 12),
            if (_batches.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Loading batches or none found...', style: GoogleFonts.plusJakartaSans(color: CT.textS(context))),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _batches
                    .map(
                      (batch) => CPPressable(
                        onTap: () => setState(() => _selectedBatch = batch),
                        child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedBatch == batch
                              ? AppColors.primary
                              : CT.card(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedBatch == batch
                                ? AppColors.primary
                                : CT.border(context),
                          ),
                          boxShadow: _selectedBatch == batch
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 0,
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          batch['subject'] ?? batch['name'] ?? 'Batch',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _selectedBatch == batch
                                ? Colors.white
                                : CT.textS(context),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 24),

            // Question input with validation
            Text(
              'Your Question',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CT.textH(context),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: CT.card(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _questionError != null
                      ? AppColors.error
                      : CT.border(context),
                ),
              ),
              child: TextField(
                controller: _questionController,
                maxLines: 5,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: CT.textH(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Describe your doubt in detail...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: CT.textM(context),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            if (_questionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  _questionError!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.error,
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // File upload
            Text(
              'Attach an Image (Optional)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CT.textH(context),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: CT.card(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedImage != null 
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _selectedImage != null ? Icons.check_circle : Icons.camera_alt_outlined,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedImage != null ? 'Image Attached' : 'Tap to select image',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.05, end: 0),
            ),

            const SizedBox(height: 40),
            CustomButton(
              text: 'Submit Doubt',
              icon: Icons.send,
              isLoading: _isSubmitting,
              onPressed: _submitDoubt,
            ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
