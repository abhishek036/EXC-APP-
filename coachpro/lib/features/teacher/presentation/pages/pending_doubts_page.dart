import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
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
      if (!mounted) return;
      setState(() {
        _doubts = doubts;
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
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);
    const yellow = Color(0xFFF0DE36);

    return Scaffold(
      backgroundColor: blue,
      appBar: AppBar(
        title: Text('PENDING DOUBTS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1.0)),
        backgroundColor: blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSummaryBar(blue, surface, yellow),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: yellow))
            : _error != null
              ? _buildErrorState(blue, surface, yellow)
              : _doubts.isEmpty
                ? _buildEmptyState(blue, yellow)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _doubts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _buildDoubtCard(_doubts[i], i, blue, surface, yellow),
                  ),
        ),
      ]),
    );
  }

  Widget _buildSummaryBar(Color blue, Color surface, Color yellow) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: yellow, border: Border.all(color: Colors.black, width: 3), borderRadius: BorderRadius.circular(12), boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(4, 4))]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.black, size: 24),
            const SizedBox(width: 12),
            Text('${_doubts.length} DOUBTS AWAITING ACTION', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.5)),
          ],
        ),
      ).animate().fadeIn().slideY(begin: -0.2),
    );
  }

  Widget _buildDoubtCard(Map<String, dynamic> d, int i, Color blue, Color surface, Color yellow) {
    final subject = d['subject']?.toString().toUpperCase() ?? 'GENERAL';
    final studentName = (d['student'] as Map?)?['name']?.toString().toUpperCase() ?? 'STUDENT';
    final batchName = (d['batch'] as Map?)?['name']?.toString().toUpperCase() ?? 'BATCH';
    final question = d['question_text']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: Colors.black, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(5, 5))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: blue, borderRadius: BorderRadius.circular(4)),
            child: Text(subject, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          Text('JUST NOW', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: blue.withValues(alpha: 0.5))),
        ]),
        const SizedBox(height: 16),
        Text(question, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, height: 1.3, color: blue)),
        const SizedBox(height: 20),
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: yellow, border: Border.all(color: Colors.black, width: 2), shape: BoxShape.circle), alignment: Alignment.center, child: Text(studentName[0], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
          const SizedBox(width: 12),
          Expanded(child: Text('$studentName • $batchName', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: blue.withValues(alpha: 0.7)))),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _btn('REPLY', () => _openReplySheet(d), yellow, blue, true)),
          const SizedBox(width: 12),
          Expanded(child: _btn('VIEW IMAGE', () {}, surface, blue, false)),
        ]),
      ]),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _btn(String label, VoidCallback onTap, Color bg, Color fg, bool isPrimary) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: Colors.black, width: 2.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isPrimary ? [const BoxShadow(color: Colors.black, offset: Offset(3, 3))] : null,
        ),
        child: Center(child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: fg))),
      ),
    );
  }

  Future<void> _openReplySheet(Map<String, dynamic> doubt) async {
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);
    final replyCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        decoration: BoxDecoration(color: surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: Colors.black, width: 4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('REPLY TO STUDENT', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: blue, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(doubt['question_text'] ?? '', maxLines: 2, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: blue.withValues(alpha: 0.5))),
            const SizedBox(height: 24),
            TextField(
              controller: replyCtrl,
              minLines: 4,
              maxLines: 6,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: blue),
              decoration: InputDecoration(
                hintText: 'TYPE YOUR ANSWER...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 2.5)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 3)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _isReplying ? null : () async {
                  await _submitReply(doubt, replyCtrl.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: _isReplying ? const CircularProgressIndicator(color: Colors.white) : Text('SEND SOLUTION', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReply(Map<String, dynamic> doubt, String answer) async {
    final doubtId = doubt['id']?.toString() ?? '';
    if (doubtId.isEmpty || answer.isEmpty) return;

    setState(() => _isReplying = true);
    try {
      await _teacherRepo.answerDoubt(doubtId: doubtId, answer: answer);
      if (!mounted) return;
      setState(() => _doubts.removeWhere((d) => d['id']?.toString() == doubtId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doubt Answered!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  Widget _buildEmptyState(Color blue, Color yellow) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: yellow, border: Border.all(color: Colors.black, width: 3), shape: BoxShape.circle), child: const Icon(Icons.celebration_rounded, size: 48, color: Colors.black)),
    const SizedBox(height: 24),
    Text('CLEAN SLATE!', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
    const SizedBox(height: 8),
    Text('ALL DOUBTS HAVE BEEN RESOLVED', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.5))),
  ]));

  Widget _buildErrorState(Color blue, Color surface, Color yellow) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 48),
    const SizedBox(height: 16),
    Text('ERROR LOADING DOUBTS', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900)),
    const SizedBox(height: 24),
    _btn('RETRY', _loadDoubts, yellow, blue, true),
  ]));
}
