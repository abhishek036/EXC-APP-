import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_shimmer.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../data/repositories/admin_repository.dart';

class ExamManagementPage extends StatefulWidget {
  const ExamManagementPage({super.key});

  @override
  State<ExamManagementPage> createState() => _ExamManagementPageState();
}

class _ExamManagementPageState extends State<ExamManagementPage> with SingleTickerProviderStateMixin {
  final _adminRepo = sl<AdminRepository>();
  late TabController _tabController;

  bool _loading = true;
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _completed = [];
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _batches = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final upcoming = await _adminRepo.getExams(status: 'upcoming');
      final completed = await _adminRepo.getExams(status: 'completed');
      final results = await _adminRepo.getExamResults();
      final batches = await _adminRepo.getBatches();
      if (!mounted) return;
      setState(() {
        _upcoming = upcoming;
        _completed = completed;
        _results = results;
        _batches = batches;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _upcoming = [];
        _completed = [];
        _results = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(top: -150, left: -100, child: _glow(400, AppColors.electricBlue.withValues(alpha: 0.15))),
            Positioned(bottom: 50, right: -150, child: _glow(500, AppColors.elitePurple.withValues(alpha: 0.1))),
          ],
          SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  floating: true, pinned: true,
                  backgroundColor: Colors.transparent, elevation: 0,
                  scrolledUnderElevation: 0,
                  title: Text('Assessments', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 24, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -1)),
                  actions: [
                    CPPressable(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        _showCreateExamSheet(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(gradient: AppColors.premiumEliteGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.elitePrimary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                        child: Row(children: [const Icon(Icons.add_rounded, color: Colors.white, size: 18), const SizedBox(width: 6), Text('NEW EXAM', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 11, letterSpacing: 0.5))]),
                      ),
                    ),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(60),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Container(
                        height: 44, padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05))),
                        child: TabBar(
                          controller: _tabController,
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                          unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          labelColor: isDark ? Colors.white : AppColors.deepNavy,
                          unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
                          tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Completed'), Tab(text: 'Results')],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              body: _loading
                  ? ListView.separated(padding: const EdgeInsets.all(20), itemCount: 5, separatorBuilder: (_, _) => const SizedBox(height: 16), itemBuilder: (_, _) => CPShimmer(width: double.infinity, height: 110, borderRadius: 24))
                  : RefreshIndicator(
                      onRefresh: _loadData, color: AppColors.electricBlue,
                      child: TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildExamList(_upcoming, 'upcoming', isDark),
                          _buildExamList(_completed, 'completed', isDark),
                          _buildResultsList(isDark),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: size / 2)]));

  Widget _buildExamList(List<Map<String, dynamic>> exams, String status, bool isDark) {
    if (exams.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03), shape: BoxShape.circle), child: Icon(status == 'upcoming' ? Icons.event_rounded : Icons.fact_check_rounded, size: 48, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1))),
                const SizedBox(height: 24),
                Text(status == 'upcoming' ? 'No upcoming assessments' : 'No evaluations completed', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26))),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: exams.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, i) => _examCard(exams[i], i, status, isDark),
    );
  }

  Widget _examCard(Map<String, dynamic> exam, int i, String status, bool isDark) {
    final name = (exam['name'] ?? 'Exam').toString();
    final batchName = (exam['batchName'] ?? 'Batch').toString();
    final subject = (exam['subject'] ?? '').toString();
    final date = DateTime.tryParse((exam['date'] ?? '').toString());
    final duration = exam['duration']?.toString() ?? '';
    final totalMarks = exam['totalMarks']?.toString() ?? '';
    final id = (exam['id'] ?? '').toString();

    final statusColor = status == 'upcoming' ? AppColors.electricBlue : AppColors.success;

    return CPPressable(
      onTap: () {
        HapticFeedback.lightImpact();
        if (status == 'completed') {
          _showExamResultSheet(context, exam);
        } else {
          _showExamOptions(context, exam, id, isDark);
        }
      },
      child: CPGlassCard(
        isDark: isDark, padding: const EdgeInsets.all(20), borderRadius: 28,
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(width: 50, height: 70, decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(status == 'upcoming' ? Icons.event_rounded : Icons.check_circle_rounded, size: 22, color: statusColor), const SizedBox(height: 4), Text(date != null ? DateFormat('MMM').format(date).toUpperCase() : '', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor)), Text(date != null ? DateFormat('dd').format(date) : '', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: -1))])),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text(name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (status == 'upcoming') Icon(Icons.more_horiz_rounded, size: 20, color: isDark ? Colors.white38 : Colors.black38),
                  ]),
                  const SizedBox(height: 4),
                  Text('${batchName.toUpperCase()} • ${subject.toUpperCase()}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white38 : Colors.black45, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  Row(children: [
                    if (duration.isNotEmpty) _infoChip(Icons.timer_rounded, '$duration MIN', isDark),
                    if (duration.isNotEmpty && totalMarks.isNotEmpty) const SizedBox(width: 12),
                    if (totalMarks.isNotEmpty) _infoChip(Icons.stars_rounded, '$totalMarks PTS', isDark),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 30 * i)).fadeIn(duration: 400.ms).slideX(begin: 0.05);
  }

  void _showExamOptions(BuildContext context, Map<String, dynamic> exam, String id, bool isDark) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => CPGlassCard(
        isDark: isDark, padding: const EdgeInsets.all(28), borderRadius: 40,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 32),
          Text('Assessment Protocol', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -1)),
          Text('Manage "${exam['name']}"', style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600)),
          const SizedBox(height: 32),
          CustomButton(text: 'Finalize & Conclude', icon: Icons.check_circle_rounded, onPressed: () { Navigator.pop(ctx); _markExamComplete(id); }),
          const SizedBox(height: 12),
          CustomButton(text: 'Terminate Record', icon: Icons.delete_forever_rounded, backgroundColor: AppColors.error, onPressed: () { Navigator.pop(ctx); _deleteExam(exam); }),
        ]),
      )
    );
  }

  Widget _infoChip(IconData icon, String text, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isDark ? Colors.white54 : Colors.black54),
            const SizedBox(width: 4),
            Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white54 : Colors.black54, letterSpacing: 0.5)),
          ],
        ),
      );

  Widget _buildResultsList(bool isDark) {
    if (_results.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03), shape: BoxShape.circle), child: Icon(Icons.leaderboard_rounded, size: 48, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1))),
                const SizedBox(height: 24),
                Text('No evaluations recorded', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26))),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final result = _results[i];
        final studentName = (result['studentName'] ?? 'Student').toString();
        final examName = (result['examName'] ?? 'Exam').toString();
        final score = (result['score'] as num?)?.toDouble() ?? 0;
        final total = (result['totalMarks'] as num?)?.toDouble() ?? 100;
        final grade = (result['grade'] ?? '').toString();

        final pct = total > 0 ? ((score / total) * 100) : 0;
        final gradeColor = pct >= 80 ? AppColors.success : pct >= 60 ? AppColors.electricBlue : pct >= 40 ? AppColors.warning : AppColors.error;

        return CPGlassCard(
          isDark: isDark, padding: const EdgeInsets.all(16), borderRadius: 20,
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: gradeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Center(child: Text(studentName.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: gradeColor)))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(studentName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(examName, style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${score.toInt()}/${total.toInt()}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)),
              if (grade.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: gradeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(grade, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: gradeColor, letterSpacing: 0.5))),
              ],
            ]),
          ]),
        ).animate(delay: Duration(milliseconds: 30 * i)).fadeIn(duration: 400.ms).slideX(begin: 0.05);
      },
    );
  }

  Future<void> _markExamComplete(String id) async {
    try {
      await _adminRepo.updateExamStatus(examId: id, status: 'completed');
      if (mounted) { CPToast.success(context, 'Exam flagged as completed'); _loadData(); HapticFeedback.heavyImpact(); }
    } catch (_) { if (mounted) CPToast.error(context, 'Failed to update protocol'); }
  }

  Future<void> _deleteExam(Map<String, dynamic> exam) async {
    final isDark = CT.isDark(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.eliteDarkBg : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Terminate Record?', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)),
        content: Text('Delete "${exam['name']}" permanently from the database.', style: GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('CANCEL', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: isDark ? Colors.white54 : Colors.black54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('TERMINATE', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.error))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminRepo.deleteExam((exam['id'] ?? '').toString());
        if (mounted) { CPToast.success(context, 'Record terminated'); _loadData(); }
      } catch (_) { if (mounted) CPToast.error(context, 'Termination failed'); }
    }
  }

  void _showExamResultSheet(BuildContext context, Map<String, dynamic> exam) {
    final isDark = CT.isDark(context);
    final date = DateTime.tryParse((exam['date'] ?? '').toString());
    final dateStr = date != null ? DateFormat('dd MMM yyyy').format(date) : '—';

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => CPGlassCard(
        isDark: isDark, padding: const EdgeInsets.all(28), borderRadius: 40,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 32),
          Text((exam['name'] ?? 'Exam').toString(), style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -1)),
          const SizedBox(height: 6),
          Text('${(exam['batchName'] ?? '').toString().toUpperCase()} • ${(exam['subject'] ?? '').toString().toUpperCase()}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.white38 : Colors.black45, letterSpacing: 0.5)),
          const SizedBox(height: 40),
          Row(children: [
            _resultStat('SCHEDULED', dateStr, isDark),
            _resultStat('DURATION', '${exam['duration'] ?? '—'} MIN', isDark),
            _resultStat('CAPACITY', '${exam['totalMarks'] ?? '—'} PTS', isDark),
          ]),
          const SizedBox(height: 40),
          CustomButton(text: 'Access Results Engine', icon: Icons.leaderboard_rounded, onPressed: () { Navigator.pop(ctx); _tabController.animateTo(2); }),
          const SizedBox(height: 12),
        ]),
      )
    );
  }

  Widget _resultStat(String label, String value, bool isDark) => Expanded(
        child: Column(
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 0.5)),
          ],
        ),
      );

  void _showCreateExamSheet(BuildContext context) {
    final isDark = CT.isDark(context);
    final nameCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final totalMarksCtrl = TextEditingController(text: '100');
    String? selectedBatchId;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: CPGlassCard(
            isDark: isDark, padding: const EdgeInsets.all(28), borderRadius: 40,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 32),
                  Text('Deployment Protocol', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -1)),
                  const SizedBox(height: 8),
                  Text('Schedule a new assessment for a target batch.', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 40),
                  CustomTextField(label: 'Evaluation Title *', hint: 'e.g. JEE Sprint Mock #5', controller: nameCtrl, prefixIcon: Icons.quiz_rounded, isRequired: true),
                  const SizedBox(height: 20),
                  CustomTextField(label: 'Target Subject', hint: 'e.g. Adv. Physics', controller: subjectCtrl, prefixIcon: Icons.book_rounded),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      final selectedDate = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (selectedDate != null) setSS(() => dateCtrl.text = DateFormat('dd MMM yyyy').format(selectedDate));
                    },
                    child: AbsorbPointer(child: CustomTextField(label: 'Execution Date *', hint: 'Select Date', controller: dateCtrl, prefixIcon: Icons.edit_calendar_rounded, isRequired: true)),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: CustomTextField(label: 'Duration (m)', hint: '120', controller: durationCtrl, prefixIcon: Icons.timer_rounded, keyboardType: TextInputType.number)),
                    const SizedBox(width: 16),
                    Expanded(child: CustomTextField(label: 'Total Capacity', hint: '100', controller: totalMarksCtrl, prefixIcon: Icons.stars_rounded, keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 24),
                  Padding(padding: const EdgeInsets.only(left: 4), child: Text('TARGET BATCH DEPLOYMENT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 0.5))),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    decoration: BoxDecoration(color: (isDark ? Colors.white : AppColors.deepNavy).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedBatchId,
                        hint: Text('Select Academy Batch', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26))),
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                        items: _batches.map((batch) => DropdownMenuItem(value: (batch['id'] ?? '').toString(), child: Text((batch['name'] ?? 'Batch').toString(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.deepNavy)))).toList(),
                        onChanged: (value) => setSS(() => selectedBatchId = value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  CustomButton(
                    text: 'Deploy Assessment',
                    icon: Icons.rocket_launch_rounded,
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty || dateCtrl.text.trim().isEmpty) { CPToast.warning(ctx, 'Mandatory fields missing'); return; }
                      final parsedDate = DateFormat('dd MMM yyyy').parse(dateCtrl.text.trim());
                      try {
                        await _adminRepo.createExam(
                          name: nameCtrl.text.trim(),
                          subject: subjectCtrl.text.trim().isEmpty ? null : subjectCtrl.text.trim(),
                          date: parsedDate,
                          duration: int.tryParse(durationCtrl.text.trim()),
                          totalMarks: int.tryParse(totalMarksCtrl.text.trim()) ?? 100,
                          batchId: selectedBatchId,
                        );
                        if (ctx.mounted) { Navigator.pop(ctx); CPToast.success(context, 'Deployment Initiated 🚀'); }
                        _loadData();
                      } catch (_) { if (ctx.mounted) CPToast.error(ctx, 'Deployment Error'); }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
