import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/theme/theme_aware.dart';

class AddStudentPage extends StatefulWidget {
  const AddStudentPage({super.key});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _adminRepo = sl<AdminRepository>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _parentNameCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _rollNumberCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _bloodGroupCtrl = TextEditingController();
  final _prevSchoolCtrl = TextEditingController();
  final _emergencyContactCtrl = TextEditingController();
  final _fatherOccupationCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _motherPhoneCtrl = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDob;
  final List<String> _selectedBatchIds = [];
  bool _isSaving = false;

  // Dynamic batch data from backend
  List<Map<String, dynamic>> _batches = [];
  bool _loadingBatches = true;

  final _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _generateRollNumber();
  }

  Future<void> _loadBatches() async {
    try {
      final docs = await _adminRepo.getBatches();
      if (mounted) {
        setState(() {
          _batches = docs.where((b) {
            final isActive = b['is_active'] ?? b['isActive'];
            return isActive == true || isActive == null;
          }).toList();
          _loadingBatches = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingBatches = false);
    }
  }

  Future<void> _generateRollNumber() async {
    final random = math.Random();
    final suffix = 100 + random.nextInt(900);
    _rollNumberCtrl.text = 'STU-$suffix';
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2008, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _selectedDob = date;
        _dobCtrl.text =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBatchIds.isEmpty) {
      CPToast.warning(context, 'Please select at least one batch');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Prepare data for Node.js backend
      final payload = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'dob': _selectedDob?.toUtc().toIso8601String(),
        'gender': _selectedGender,
        'address': _addressCtrl.text.trim(),
        'blood_group': _bloodGroupCtrl.text.trim(),
        'prev_institute': _prevSchoolCtrl.text.trim(),
        'parent_name': _parentNameCtrl.text.trim(),
        'parent_phone': _parentPhoneCtrl.text.trim(),
        'parent_relation': 'father', // Default for now
        'batch_ids': _selectedBatchIds,
      };

      payload.removeWhere(
        (key, value) => value == null || (value is String && value.isEmpty),
      );

      // 2. Call Repo
      final created = await _adminRepo.createStudent(payload);

      if (mounted) {
        CPToast.success(context, 'Student added successfully! 🎉');
        Navigator.pop(context, created); // Return the created record
      }
    } on DioException catch (e) {
      if (mounted) {
        CPToast.error(
          context,
          e.message ?? e.error?.toString() ?? 'Failed to add student',
        );
      }
    } catch (e) {
      if (mounted) {
        CPToast.error(context, 'Failed to add student: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _parentNameCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _rollNumberCtrl.dispose();
    _dobCtrl.dispose();
    _bloodGroupCtrl.dispose();
    _prevSchoolCtrl.dispose();
    _emergencyContactCtrl.dispose();
    _fatherOccupationCtrl.dispose();
    _motherNameCtrl.dispose();
    _motherPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: AppColors.elitePrimary,
        elevation: 0,
        leading: CPPressable(
          onTap: () {
            if (GoRouter.of(context).canPop()) {
              GoRouter.of(context).pop();
            } else {
              GoRouter.of(context).go('/admin/students');
            }
          },
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Student',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
            Text(
              'Quick enrollment with batch assignment',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section: Student Details ──
              _sectionHeader('Student Details', Icons.person_outline),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecor(),
                child: Column(
                  children: [
                    CustomTextField(
                      label: 'Full Name *',
                      hint: 'Enter student name',
                      controller: _nameCtrl,
                      prefixIcon: Icons.person_outline,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Phone Number *',
                      hint: '10-digit mobile number',
                      controller: _phoneCtrl,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      isRequired: true,
                      validator: (v) => v == null || v.trim().length < 10
                          ? 'Enter valid 10-digit number'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Roll Number',
                      hint: 'Auto-generated',
                      controller: _rollNumberCtrl,
                      prefixIcon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Email (Optional)',
                      hint: 'student@example.com',
                      controller: _emailCtrl,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            'Gender',
                            _genders,
                            _selectedGender,
                            (v) => setState(() => _selectedGender = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDate,
                            child: AbsorbPointer(
                              child: CustomTextField(
                                label: 'Date of Birth',
                                hint: 'DD/MM/YYYY',
                                controller: _dobCtrl,
                                prefixIcon: Icons.cake_outlined,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'Blood Group',
                            hint: 'e.g. B+',
                            controller: _bloodGroupCtrl,
                            prefixIcon: Icons.bloodtype_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            label: 'Previous School',
                            hint: 'School name',
                            controller: _prevSchoolCtrl,
                            prefixIcon: Icons.school_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // ── Section: Batch Assignment ──
              _sectionHeader('Assign to Batch(es) *', Icons.class_outlined),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecor(),
                child: _loadingBatches
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _batches.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No batches found. Create a batch first.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: CT.textM(context),
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _batches.map((b) {
                          final batchId = b['id'] as String;
                          final batchName = b['name'] as String? ?? 'Batch';
                          final isSelected = _selectedBatchIds.contains(
                            batchId,
                          );
                          return CPBatchChip(
                            label: batchName,
                            isSelected: isSelected,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if (isSelected) {
                                  _selectedBatchIds.remove(batchId);
                                } else {
                                  _selectedBatchIds.add(batchId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
              ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // ── Section: Parent/Guardian Details ──
              _sectionHeader(
                'Father / Guardian',
                Icons.family_restroom_outlined,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecor(),
                child: Column(
                  children: [
                    CustomTextField(
                      label: 'Father\'s Name *',
                      hint: 'Enter father\'s name',
                      controller: _parentNameCtrl,
                      prefixIcon: Icons.person_outline,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Father\'s Phone *',
                      hint: '10-digit mobile',
                      controller: _parentPhoneCtrl,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Father\'s Occupation',
                      hint: 'e.g. Business, Service',
                      controller: _fatherOccupationCtrl,
                      prefixIcon: Icons.work_outline,
                    ),
                  ],
                ),
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // ── Section: Mother Details ──
              _sectionHeader('Mother Details', Icons.person_outline),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecor(),
                child: Column(
                  children: [
                    CustomTextField(
                      label: 'Mother\'s Name',
                      hint: 'Enter mother\'s name',
                      controller: _motherNameCtrl,
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Mother\'s Phone',
                      hint: '10-digit mobile',
                      controller: _motherPhoneCtrl,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ).animate(delay: 250.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // ── Section: Emergency Contact ──
              _sectionHeader('Emergency Contact', Icons.emergency_outlined),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecor(),
                child: CustomTextField(
                  label: 'Emergency Contact Number',
                  hint: '10-digit number',
                  controller: _emergencyContactCtrl,
                  prefixIcon: Icons.phone_callback_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ).animate(delay: 280.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // ── Section: Address ──
              _sectionHeader('Address', Icons.location_on_outlined),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecor(),
                child: CustomTextField(
                  label: 'Full Address',
                  hint: 'Enter full address',
                  controller: _addressCtrl,
                  prefixIcon: Icons.home_outlined,
                  maxLines: 3,
                ),
              ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 32),

              CustomButton(
                text: 'Send Invite / Add Student',
                icon: Icons.person_add,
                isLoading: _isSaving,
                onPressed: _submit,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecor() => BoxDecoration(
    color: AppColors.eliteLightBg,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.elitePrimary, width: 1.5),
    boxShadow: const [
      BoxShadow(
        color: AppColors.elitePrimary,
        offset: Offset(2, 2),
        blurRadius: 0,
      ),
    ],
  );

  Widget _sectionHeader(String title, IconData icon) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.elitePrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppColors.elitePrimary),
      ),
      const SizedBox(width: 12),
      Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.elitePrimary,
        ),
      ),
    ],
  );

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? value,
    ValueChanged<String?> onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.elitePrimary,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.eliteLightBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.elitePrimary, width: 1.5),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text(
              'Select',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.elitePrimary.withValues(alpha: 0.6),
              ),
            ),
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: AppColors.elitePrimary,
            ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.elitePrimary,
            ),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}

/// Batch selection chip widget
class CPBatchChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CPBatchChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.elitePrimary : AppColors.eliteLightBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.elitePrimary, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.elitePrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

