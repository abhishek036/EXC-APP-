import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';

import '../../../../features/teacher/data/repositories/teacher_repository.dart';
import '../../../../core/di/injection_container.dart';
import 'package:go_router/go_router.dart';

class PendingDoubtsPage extends StatefulWidget {
  const PendingDoubtsPage({super.key});

  @override
  State<PendingDoubtsPage> createState() => _PendingDoubtsPageState();
}

class _PendingDoubtsPageState extends State<PendingDoubtsPage> {
  final _teacherRepo = sl<TeacherRepository>();
  List<Map<String, dynamic>> _doubts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDoubts();
  }

  Future<void> _loadDoubts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final doubts = await _teacherRepo.getPendingDoubts();
      setState(() {
        _doubts = doubts;
        _isLoading = false;
      });
    } catch (e) {
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
        title: Text('Pending Doubts', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list))],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary block
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
          child: Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
                child: Center(child: Text('${_doubts.length} Pending', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.warning))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
                child: Center(child: Text('0 Resolved Today', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success))),
              ),
            ),
          ]).animate().fadeIn(duration: 400.ms),
        ),
        const SizedBox(height: 16),
        
        // List of doubts
        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.dmSans(color: CT.textM(context))))
              : _doubts.isEmpty
                ? Center(child: Text('No pending doubts!', style: GoogleFonts.dmSans(color: CT.textM(context))))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH, vertical: 8),
                    itemCount: _doubts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _buildDoubtCard(context, _doubts[i], i),
                  ),
        ),
      ]),
    );
  }

  Widget _buildDoubtCard(BuildContext context, Map<String, dynamic> d, int i) {
    final subject = d['subject'] ?? 'Subject';
    final studentName = (d['student'] as Map?)?['name'] ?? 'Student';
    final batchName = (d['batch'] as Map?)?['name'] ?? 'Batch';
    final question = d['question_text'] ?? '';
    final time = d['created_at'] ?? '';
    final hasImg = d['question_img'] != null;
    final color = _getSubjectColor(subject);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CT.cardDecor(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(subject, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
          ),
          if (time.isNotEmpty)
            Text(_formatTime(time), style: GoogleFonts.dmSans(fontSize: 11, color: CT.textM(context))),
        ]),
        const SizedBox(height: 12),
        Text(question, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4)),
        const SizedBox(height: 14),
        Row(children: [
          CircleAvatar(radius: 14, backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: Text(studentName[0], style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
          const SizedBox(width: 8),
          Expanded(child: Text('$studentName • $batchName', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textM(context), fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => context.go('/teacher/doubts/response', extra: d),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text('Resolve', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: CT.card(context))),
            ),
          ),
          if (hasImg) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.image_outlined, size: 16),
                label: Text('View Image', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), side: BorderSide(color: CT.textM(context))),
              ),
            ),
          ]
        ]),
      ]),
    ).animate(delay: Duration(milliseconds: 100 * i)).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Color _getSubjectColor(String s) {
    s = s.toLowerCase();
    if (s.contains('physics')) return AppColors.physics;
    if (s.contains('chem')) return AppColors.chemistry;
    if (s.contains('math')) return AppColors.mathematics;
    return CT.accent(context);
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}';
    } catch (_) { return ''; }
  }
}
