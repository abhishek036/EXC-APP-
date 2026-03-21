import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_shimmer.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../data/repositories/admin_repository.dart';

class BulkResultEntryPage extends StatefulWidget {
  final Map<String, dynamic> exam;
  
  const BulkResultEntryPage({super.key, required this.exam});

  @override
  State<BulkResultEntryPage> createState() => _BulkResultEntryPageState();
}

class _BulkResultEntryPageState extends State<BulkResultEntryPage> {
  final _adminRepo = sl<AdminRepository>();
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _students = [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final batchId = widget.exam['batchId']?.toString();
      if (batchId == null || batchId.isEmpty) throw Exception('No associated batch');

      final students = await _adminRepo.getStudents();
      // Only keep students in the exam's batch
      final batchStudents = students.where((s) {
        final assignedBatches = s['batches'] as List? ?? [];
        return assignedBatches.any((b) => b['id'] == batchId);
      }).toList();

      if (!mounted) return;
      
      setState(() {
        _students = batchStudents;
        for (var student in _students) {
          final sid = student['id'].toString();
          _controllers[sid] = TextEditingController();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      CPToast.error(context, 'Failed to load batch scholars');
    }
  }

  Future<void> _saveResults() async {
    final maxMarks = widget.exam['totalMarks'] as int? ?? 100;
    
    final results = <Map<String, dynamic>>[];
    for (var entry in _controllers.entries) {
      final text = entry.value.text.trim();
      if (text.isNotEmpty) {
        final score = double.tryParse(text);
        if (score != null) {
          if (score < 0 || score > maxMarks) {
            CPToast.error(context, 'Invalid score for some entries (Max: $maxMarks)');
            return;
          }
          results.add({
            'studentId': entry.key,
            'score': score,
          });
        }
      }
    }

    if (results.isEmpty) {
      CPToast.warning(context, 'No results entered');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final examId = widget.exam['id'].toString();
      for (var result in results) {
        await _adminRepo.saveExamResult(
          examId: examId,
          studentId: result['studentId'],
          score: result['score'],
          maxMarks: maxMarks,
        );
      }
      
      if (!mounted) return;
      CPToast.success(context, 'Batch results deployed successfully');
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      CPToast.error(context, 'System failure during bulk persistence');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    final examName = widget.exam['name']?.toString() ?? 'Exam';
    final totalMarks = widget.exam['totalMarks']?.toString() ?? '100';

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(top: -100, left: -50, child: _glow(300, AppColors.electricBlue.withValues(alpha: 0.1))),
            Positioned(bottom: 100, right: -100, child: _glow(350, AppColors.elitePrimary.withValues(alpha: 0.05))),
          ],
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppBar(context, isDark),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: CPGlassCard(
                    isDark: isDark, padding: const EdgeInsets.all(16), borderRadius: 20,
                    border: Border.all(color: AppColors.electricBlue.withValues(alpha: 0.3)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Evaluation Parameters', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white54 : Colors.black54, letterSpacing: 0.5)),
                              const SizedBox(height: 6),
                              Text(examName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: AppColors.electricBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded, size: 14, color: AppColors.electricBlue),
                              const SizedBox(width: 4),
                              Text('MAX $totalMarks', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.electricBlue, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? _buildShimmer()
                      : _buildStudentList(isDark),
                ),
                if (!_isLoading && _students.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: CustomButton(
                      text: _isSaving ? 'Processing Protocol...' : 'Deploy Bulk Results',
                      icon: _isSaving ? Icons.hourglass_empty_rounded : Icons.check_circle_rounded,
                      onPressed: _isSaving ? () {} : _saveResults,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: size / 2)]));

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          CPPressable(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : AppColors.deepNavy),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text('Bulk Grading', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.8))),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => CPShimmer(width: double.infinity, height: 80, borderRadius: 16),
    );
  }

  Widget _buildStudentList(bool isDark) {
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_off_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text('No scholars found in batch', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final student = _students[i];
        final name = student['name'] ?? 'Student';
        final roll = student['rollNumber'] ?? 'Unknown Roll';
        final sid = student['id'].toString();
        
        return CPGlassCard(
          isDark: isDark, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), borderRadius: 20,
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          child: Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)), child: const Center(child: Icon(Icons.person_rounded, size: 20, color: AppColors.electricBlue))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Text(roll, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.black45)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                child: CustomTextField(
                  hint: 'Score',
                  controller: _controllers[sid],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ).animate(delay: (30 * i).ms).fadeIn(duration: 400.ms).slideY(begin: 0.1);
      },
    );
  }
}
