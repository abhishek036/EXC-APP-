import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/teacher_repository.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_glass_card.dart';

class TeacherBatchesPage extends StatefulWidget {
  const TeacherBatchesPage({super.key});

  @override
  State<TeacherBatchesPage> createState() => _TeacherBatchesPageState();
}

class _TeacherBatchesPageState extends State<TeacherBatchesPage> {
  final _teacherRepo = sl<TeacherRepository>();
  List<Map<String, dynamic>> _batches = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final data = await _teacherRepo.getMyBatches();
      if (!mounted) return;
      setState(() {
        _batches = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text('My Batches', style: GoogleFonts.sora(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(_error!, style: GoogleFonts.dmSans(color: CT.textM(context))),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadBatches, child: const Text('Retry')),
                  ]),
                )
              : _batches.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.class_outlined, size: 64, color: CT.textM(context)),
                        const SizedBox(height: 16),
                        Text('No Batches Assigned', style: GoogleFonts.sora(color: CT.textM(context))),
                        const SizedBox(height: 8),
                        Text('You have no active batches right now.', style: GoogleFonts.dmSans(color: CT.textS(context))),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBatches,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
                        itemCount: _batches.length,
                        itemBuilder: (ctx, i) {
                          final b = _batches[i];
                          return _BatchCard(
                            batch: b,
                            index: i,
                            onTap: () {
                              // If there's a specific teacher batch detail view, go there
                              // For now, we can route to common batch details
                              context.push('/teacher/batches/${b['id']}');
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  final Map<String, dynamic> batch;
  final int index;
  final VoidCallback onTap;

  const _BatchCard({required this.batch, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = batch['name'] ?? 'Batch';
    final subject = batch['subject'] ?? 'General';
    final schedule = '${batch['start_time'] ?? '--'} - ${batch['end_time'] ?? '--'}';
    final capacity = batch['capacity'] ?? 0;
    // Assuming 'students' array or 'enrolled_count' is returned
    final enrolledList = batch['students'] as List?;
    final enrolled = enrolledList?.length ?? batch['enrolled_count'] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: GestureDetector(
        onTap: onTap,
        child: CPGlassCard(
          isDark: CT.isDark(context),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLG)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.class_, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(name, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: CT.textH(context))),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: CT.textM(context)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(icon: Icons.book_outlined, text: subject),
                          const SizedBox(height: 8),
                          _InfoRow(icon: Icons.schedule_outlined, text: schedule),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CT.bg(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CT.border(context)),
                      ),
                      child: Column(
                        children: [
                          Text('$enrolled${capacity > 0 ? '/$capacity' : ''}', 
                            style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primary)),
                          Text('Students', style: GoogleFonts.dmSans(fontSize: 10, color: CT.textS(context))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate(delay: Duration(milliseconds: 50 * index)).fadeIn().slideX(begin: 0.05),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: CT.textM(context)),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.dmSans(fontSize: 13, color: CT.textH(context))),
      ],
    );
  }
}
