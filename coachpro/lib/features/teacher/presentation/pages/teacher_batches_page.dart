import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/teacher_repository.dart';
import 'teacher_batch_panel_page.dart';

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
    if (!mounted) return;
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

  void _handleBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    context.go('/teacher');
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0D1282);
    const surfaceWhite = Color(0xFFEEEDED);
    const accentYellow = Color(0xFFF0DE36);

    return Scaffold(
      backgroundColor: primaryBlue,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: _handleBack,
        ),
        title: Text(
          'MY BATCHES',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentYellow))
          : _error != null
              ? Center(
                  child: _PremiumCard(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.coralRed),
                      const SizedBox(height: 16),
                      Text(_error!, style: GoogleFonts.plusJakartaSans(color: primaryBlue, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _ActionBtn(label: 'RETRY', icon: Icons.refresh, blue: primaryBlue, yellow: accentYellow, onPressed: _loadBatches),
                    ]),
                  ),
                )
              : _batches.isEmpty
                  ? Center(
                      child: _PremiumCard(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.class_outlined, size: 64, color: primaryBlue.withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          Text('NO BATCHES ASSIGNED', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: primaryBlue)),
                        ]),
                      ),
                    )
                  : RefreshIndicator(
                      color: accentYellow,
                      backgroundColor: primaryBlue,
                      onRefresh: _loadBatches,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _batches.length,
                        itemBuilder: (ctx, i) {
                          final b = _batches[i];
                          return _BatchCard(
                            batch: b,
                            index: i,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherBatchPanelPage(batchId: (b['id'] ?? '').toString()))),
                            blue: primaryBlue,
                            yellow: accentYellow,
                            white: surfaceWhite,
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
  final Color blue;
  final Color yellow;
  final Color white;

  const _BatchCard({required this.batch, required this.index, required this.onTap, required this.blue, required this.yellow, required this.white});

  @override
  Widget build(BuildContext context) {
    final name = (batch['name'] ?? 'Batch').toString().toUpperCase();
    final subject = (batch['subject'] ?? 'General').toString().toUpperCase();
    final schedule = '${batch['start_time'] ?? '--'} - ${batch['end_time'] ?? '--'}';
    final studentCount = (batch['student_count'] ?? batch['enrolled_count'] ?? 0).toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: white,
            border: Border.all(color: blue, width: 2.5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: blue, offset: const Offset(5, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: blue,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(child: Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5))),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: yellow),
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
                          Text(subject, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 18, color: blue)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.timer_rounded, size: 14, color: blue.withValues(alpha: 0.5)),
                              const SizedBox(width: 6),
                              Text(schedule, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: blue.withValues(alpha: 0.6))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: yellow,
                        border: Border.all(color: blue, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(studentCount, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 16, color: blue)),
                          Text('STUDENTS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 8, color: blue)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate(delay: Duration(milliseconds: 50 * index)).fadeIn().slideX(begin: 0.1),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final Widget child;
  const _PremiumCard({required this.child});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: blue, offset: Offset(4, 4))],
      ),
      child: child,
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color blue;
  final Color yellow;
  final VoidCallback onPressed;

  const _ActionBtn({required this.label, required this.icon, required this.blue, required this.yellow, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: yellow,
          border: Border.all(color: blue, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: blue),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 12, color: blue)),
          ],
        ),
      ),
    );
  }
}
