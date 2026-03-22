import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/theme/theme_aware.dart';
import 'add_student_page.dart' show CPBatchChip;

class EditStudentPage extends StatefulWidget {
  final String studentId;
  const EditStudentPage({super.key, required this.studentId});

  @override
  State<EditStudentPage> createState() => _EditStudentPageState();
}

class _EditStudentPageState extends State<EditStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _adminRepo = sl<AdminRepository>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _parentNameCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _bloodGroupCtrl = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDob;
  final List<String> _selectedBatchIds = [];
  bool _isSaving = false;
  bool _isLoading = true;
  Map<String, dynamic>? _student;

  List<Map<String, dynamic>> _batches = [];
  final _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _adminRepo.getStudentById(widget.studentId),
        _adminRepo.getBatches(),
      ]);

      final studentData = results[0] as Map<String, dynamic>;
      final batches = results[1] as List<Map<String, dynamic>>;

      if (!mounted) return;
      setState(() {
        _student = studentData;
        _batches = batches.where((b) => b['is_active'] != false).toList();

        // Pre-fill fields
        _nameCtrl.text = studentData['name'] ?? '';
        _phoneCtrl.text = studentData['phone'] ?? '';
        _emailCtrl.text = studentData['email'] ?? '';
        _selectedGender = studentData['gender'];

        final dobStr = studentData['dob'] as String?;
        if (dobStr != null) {
          final dob = DateTime.tryParse(dobStr);
          if (dob != null) {
            _selectedDob = dob;
            _dobCtrl.text =
                '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}';
          }
        }

        _bloodGroupCtrl.text = studentData['blood_group'] ?? '';
        _addressCtrl.text = studentData['address'] ?? '';

        // Pre-select batches
        final enrolledBatches = studentData['batches'] as List? ?? [];
        for (final b in enrolledBatches) {
          final id = b['id'] as String?;
          if (id != null) _selectedBatchIds.add(id);
        }

        // Parent info
        final parents = studentData['parents'] as List?;
        if (parents != null && parents.isNotEmpty) {
          _parentNameCtrl.text = parents[0]['name'] ?? '';
          _parentPhoneCtrl.text = parents[0]['phone'] ?? '';
        }

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CPToast.error(context, 'Failed to load student: $e');
      }
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2008, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
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
      final payload = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'dob': _selectedDob?.toUtc().toIso8601String(),
        'gender': _selectedGender,
        'address': _addressCtrl.text.trim(),
        'blood_group': _bloodGroupCtrl.text.trim(),
        'parent_name': _parentNameCtrl.text.trim(),
        'parent_phone': _parentPhoneCtrl.text.trim(),
        'batch_ids': _selectedBatchIds,
      };

      payload.removeWhere((key, value) => value == null || (value is String && value.isEmpty));

      await _adminRepo.updateStudent(widget.studentId, payload);

      if (mounted) {
        CPToast.success(context, 'Student updated successfully! ✅');
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      if (mounted) {
        CPToast.error(context, e.message ?? e.error?.toString() ?? 'Failed to update student');
      }
    } catch (e) {
      if (mounted) {
        CPToast.error(context, 'Failed to update student: $e');
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
    _dobCtrl.dispose();
    _bloodGroupCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Student', style: GoogleFonts.sora(fontWeight: FontWeight.w600, fontSize: 16)),
            if (_student != null)
              Text(_student!['name'] ?? '', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textM(context))),
          ],
        ),
        actions: [
          if (_student != null)
            IconButton(
              icon: Icon(
                (_student!['is_active'] ?? true) ? Icons.person_off_outlined : Icons.person_outlined,
                color: (_student!['is_active'] ?? true) ? AppColors.error : AppColors.success,
              ),
              tooltip: (_student!['is_active'] ?? true) ? 'Deactivate Student' : 'Activate Student',
              onPressed: _toggleStatus,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Student Details', Icons.person_outline),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: _cardDecor(),
                      child: Column(children: [
                        CustomTextField(
                          label: 'Full Name *',
                          hint: 'Student full name',
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
                          label: 'Email (Optional)',
                          hint: 'student@example.com',
                          controller: _emailCtrl,
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: _buildGenderDropdown()),
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
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'Blood Group',
                              hint: 'e.g. B+',
                              controller: _bloodGroupCtrl,
                              prefixIcon: Icons.bloodtype_outlined,
                            ),
                          ),
                        ]),
                      ]),
                    ).animate().fadeIn(duration: 400.ms),

                    const SizedBox(height: 24),

                    _sectionHeader('Assign to Batch(es) *', Icons.class_outlined),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: _cardDecor(),
                      child: _batches.isEmpty
                          ? Text('No batches available', style: GoogleFonts.dmSans(color: CT.textM(context)))
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _batches.map((b) {
                                final batchId = b['id'] as String;
                                final batchName = b['name'] as String? ?? 'Batch';
                                final isSelected = _selectedBatchIds.contains(batchId);
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

                    _sectionHeader('Parent / Guardian', Icons.family_restroom_outlined),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: _cardDecor(),
                      child: Column(children: [
                        CustomTextField(
                          label: "Father's Name *",
                          hint: "Enter father's name",
                          controller: _parentNameCtrl,
                          prefixIcon: Icons.person_outline,
                          isRequired: true,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: "Father's Phone *",
                          hint: '10-digit mobile',
                          controller: _parentPhoneCtrl,
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          isRequired: true,
                        ),
                      ]),
                    ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

                    const SizedBox(height: 24),

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
                      text: 'Save Changes',
                      icon: Icons.save_outlined,
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

  Future<void> _toggleStatus() async {
    final current = _student!['is_active'] ?? true;
    final action = current ? 'deactivate' : 'activate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action.capitalize()} Student?', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to $action "${_student!['name']}"?',
          style: GoogleFonts.dmSans(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: current ? AppColors.error : AppColors.success),
            child: Text(action.capitalize()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _adminRepo.toggleStudentStatus(widget.studentId, !current);
      if (!mounted) return;
      setState(() => _student!['is_active'] = !current);
      CPToast.success(context, 'Student ${!current ? 'activated' : 'deactivated'}');
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Failed: $e');
    }
  }

  BoxDecoration _cardDecor() => BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.04), blurRadius: 10)],
      );

  Widget _sectionHeader(String title, IconData icon) => Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: AppColors.electricBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: AppColors.electricBlue),
        ),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
      ]);

  Widget _buildGenderDropdown() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gender', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: CT.textS(context))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: CT.bg(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CT.border(context)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedGender,
                hint: Text('Select', style: GoogleFonts.dmSans(fontSize: 13, color: CT.textM(context))),
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                style: GoogleFonts.dmSans(fontSize: 13, color: CT.textH(context)),
                items: _genders.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _selectedGender = v),
              ),
            ),
          ),
        ],
      );
}

extension StringExt on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}


