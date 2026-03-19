import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_section_header.dart';
import '../../../../core/widgets/cp_animated_list_item.dart';

import '../../../../core/di/injection_container.dart';
import '../../data/repositories/student_repository.dart';

class ExamResultsPage extends StatefulWidget {
  const ExamResultsPage({super.key});

  @override
  State<ExamResultsPage> createState() => _ExamResultsPageState();
}

class _ExamResultsPageState extends State<ExamResultsPage> {
  final _repo = sl<StudentRepository>();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    setState(() => _isLoading = true);
    try {
      _results = await _repo.getMyResults();
    } catch (e) {
      _results = [];
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: CT.bg(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: CT.bg(context),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildOverallCard(context)),
            SliverToBoxAdapter(child: const SizedBox(height: AppDimensions.lg)),
            SliverToBoxAdapter(child: _buildSubjectBreakdown(context)),
            SliverToBoxAdapter(child: const SizedBox(height: AppDimensions.lg)),
            SliverToBoxAdapter(child: _buildRecentTests(context)),
            SliverToBoxAdapter(child: const SizedBox(height: AppDimensions.lg)),
            SliverToBoxAdapter(child: _buildDownloadButton(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppDimensions.pagePaddingH, AppDimensions.md,
      AppDimensions.pagePaddingH, AppDimensions.sm,
    ),
    child: Row(
      children: [
        CPPressable(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.step),
            decoration: CT.cardDecor(context, radius: AppDimensions.radiusSM),
            child: Icon(Icons.arrow_back_ios_new, size: 18, color: CT.textH(context)),
          ),
        ),
        const SizedBox(width: AppDimensions.md),
        Expanded(
          child: Text('My Results', style: GoogleFonts.sora(
            fontSize: 22, fontWeight: FontWeight.w700, color: CT.textH(context),
          )),
        ),
        CPPressable(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.step),
            decoration: CT.cardDecor(context, radius: AppDimensions.radiusSM),
            child: Icon(Icons.share_outlined, size: 18, color: CT.textS(context)),
          ),
        ),
      ],
    ),
  ).animate().fadeIn(duration: 400.ms);

  Widget _buildOverallCard(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3D5AF1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        boxShadow: AppDimensions.shadowGlow(const Color(0xFF3D5AF1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text('Overall Score', style: GoogleFonts.dmSans(
          fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 0.5,
        )),
        const SizedBox(height: AppDimensions.sm),
        Text('78.4%', style: GoogleFonts.sora(
          fontSize: 48, fontWeight: FontWeight.w700, color: Colors.white, height: 1,
        )),
        const SizedBox(height: AppDimensions.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.step, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          ),
          child: Text('Rank: #5 out of 32', style: GoogleFonts.dmSans(
            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
          )),
        ),
        const SizedBox(height: AppDimensions.lg),
        SizedBox(
          height: 50,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _miniBar(0.55, 'T1'),
            const SizedBox(width: 14),
            _miniBar(0.72, 'T2'),
            const SizedBox(width: 14),
            _miniBar(0.65, 'T3'),
            const SizedBox(width: 14),
            _miniBar(0.82, 'T4'),
            const SizedBox(width: 14),
            _miniBar(0.78, 'T5'),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
  );

  Widget _miniBar(double h, String label) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Expanded(
        child: FractionallySizedBox(
          heightFactor: h,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 20,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.dmSans(
        fontSize: 9, color: Colors.white60, fontWeight: FontWeight.w700,
      )),
    ],
  );

  Widget _buildSubjectBreakdown(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CPSectionHeader(title: 'Subject Breakdown', icon: Icons.pie_chart_outline_rounded),
      const SizedBox(height: AppDimensions.step),
      _subjectRow(context, 'Physics', 82, AppColors.physics, 'Strong', 0),
      const SizedBox(height: AppDimensions.step),
      _subjectRow(context, 'Chemistry', 75, AppColors.chemistry, 'Average', 1),
      const SizedBox(height: AppDimensions.step),
      _subjectRow(context, 'Mathematics', 88, AppColors.mathematics, 'Excellent', 2),
    ]).animate(delay: 200.ms).fadeIn(duration: 500.ms),
  );

  Widget _subjectRow(BuildContext context, String name, int pct, Color color, String level, int index) {
    final levelColor = level == 'Excellent' ? AppColors.success : level == 'Strong' ? AppColors.success : AppColors.warning;
    return CPAnimatedListItem(
      index: index,
      child: CPPressable(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: CT.cardDecor(context, radius: AppDimensions.radiusMD),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(name, style: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w700, color: CT.textH(context),
              )),
              Row(children: [
                Text('$pct%', style: GoogleFonts.sora(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color,
                )),
                const SizedBox(width: AppDimensions.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  child: Text(level, style: GoogleFonts.dmSans(
                    fontSize: 10, fontWeight: FontWeight.w700, color: levelColor,
                  )),
                ),
              ]),
            ]),
            const SizedBox(height: AppDimensions.sm),
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildRecentTests(BuildContext context) {
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CPSectionHeader(title: 'Recent Tests', actionLabel: 'View All', icon: Icons.history_rounded),
            const SizedBox(height: AppDimensions.step),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.lg),
              decoration: CT.cardDecor(context, radius: AppDimensions.radiusMD),
              child: Column(
                children: [
                  Icon(Icons.analytics_outlined, size: 48, color: CT.textS(context).withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text("No results yet", style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
                  const SizedBox(height: 4),
                  Text("Take a quiz to see your scores here.", style: GoogleFonts.dmSans(fontSize: 13, color: CT.textS(context))),
                ],
              ),
            )
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          const CPSectionHeader(title: 'Recent Tests', actionLabel: 'View All', icon: Icons.history_rounded),
          const SizedBox(height: AppDimensions.step),
          ..._results.asMap().entries.map((e) {
            final test = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.step),
              child: _testCard(context, test['title'] ?? 'Quiz', 'General', '${test['score'] ?? 0}/${test['totalScore'] ?? 10}', 'Recent', 'B', AppColors.primary, e.key),
            );
          }),
        ]
      ).animate(delay: 400.ms).fadeIn(duration: 500.ms),
    );
  }

  Widget _testCard(BuildContext context, String name, String sub, String score, String date, String grade, Color color, int index) {
    final gradeColor = grade.startsWith('A') ? AppColors.success : grade.startsWith('B') ? AppColors.info : AppColors.warning;
    return CPAnimatedListItem(
      index: index,
      child: CPPressable(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: CT.card(context),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            border: Border(left: BorderSide(color: color, width: 3)),
            boxShadow: AppDimensions.shadowSm(CT.isDark(context)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: GoogleFonts.sora(
                fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context),
              )),
              const SizedBox(height: AppDimensions.xxs),
              Text('$sub · $date', style: GoogleFonts.dmSans(
                fontSize: 12, color: CT.textM(context),
              )),
            ])),
            Text(score, style: GoogleFonts.sora(
              fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context),
            )),
            const SizedBox(width: AppDimensions.step),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: 3),
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
              ),
              child: Text(grade, style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w800, color: gradeColor,
              )),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
    child: CPPressable(
      onTap: () {},
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: CT.accent(context), width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.download_outlined, size: 18, color: CT.accent(context)),
          const SizedBox(width: AppDimensions.sm),
          Text('Download Report Card', style: GoogleFonts.sora(
            fontSize: 14, fontWeight: FontWeight.w600, color: CT.accent(context),
          )),
        ]),
      ),
    ).animate(delay: 600.ms).fadeIn(duration: 500.ms),
  );
}
