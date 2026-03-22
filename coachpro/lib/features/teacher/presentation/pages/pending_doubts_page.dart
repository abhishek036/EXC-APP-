import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';

import '../../../../features/teacher/data/repositories/teacher_repository.dart';
import '../../../../core/di/injection_container.dart';

class PendingDoubtsPage extends StatefulWidget {
  const PendingDoubtsPage({super.key});

  @override
  State<PendingDoubtsPage> createState() => _PendingDoubtsPageState();
}

class _PendingDoubtsPageState extends State<PendingDoubtsPage> {
  final _teacherRepo = sl<TeacherRepository>();
  List<Map<String, dynamic>> _doubts = [];
  bool _isLoading = true;
  bool _isReplying = false;
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
              onPressed: () => _openReplySheet(d),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text('Reply', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: CT.card(context))),
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

  Future<void> _openReplySheet(Map<String, dynamic> doubt) async {
    final replyCtrl = TextEditingController();
    String status = 'resolved';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CT.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Widget statusChip(String label, String value) {
              final active = status == value;
              return GestureDetector(
                onTap: () => setSheetState(() => status = value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFF0DE36) : CT.bg(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: active ? const Color(0xFFF0DE36) : CT.textM(context).withValues(alpha: 0.25)),
                  ),
                  child: Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Reply', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
                  const SizedBox(height: 6),
                  Text((doubt['question_text'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(color: CT.textM(context))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      statusChip('Resolved', 'resolved'),
                      statusChip('Pending', 'pending'),
                      statusChip('Discuss in class', 'discuss_in_class'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: replyCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Write text/voice/image reply summary...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isReplying ? null : () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isReplying
                              ? null
                              : () async {
                                  final answer = replyCtrl.text.trim();
                                  if (answer.isEmpty) return;
                                  await _submitReply(doubt, answer, status);
                                  if (!mounted || !ctx.mounted) return;
                                  Navigator.of(ctx).pop();
                                },
                          child: _isReplying
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Send Reply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitReply(Map<String, dynamic> doubt, String answer, String status) async {
    final doubtId = (doubt['id'] ?? '').toString();
    if (doubtId.isEmpty) return;

    setState(() => _isReplying = true);
    try {
      await _teacherRepo.answerDoubt(doubtId: doubtId, answer: answer);
      if (!mounted) return;

      if (status == 'resolved') {
        setState(() {
          _doubts.removeWhere((d) => (d['id'] ?? '').toString() == doubtId);
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'resolved' ? 'Doubt resolved' : 'Reply sent ($status)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reply: $e')));
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
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
