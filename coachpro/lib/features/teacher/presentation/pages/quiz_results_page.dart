import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';

class QuizResultsPage extends StatelessWidget {
  const QuizResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text('Quiz Results', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuizHeader(context),
            const SizedBox(height: 20),
            _buildOverallStats(context),
            const SizedBox(height: 20),
            _buildScoreDistribution(context),
            const SizedBox(height: 20),
            _buildQuestionAnalysis(context),
            const SizedBox(height: 20),
            _buildDifficultyBreakdown(context),
            const SizedBox(height: 20),
            _buildTimeAnalysis(context),
            const SizedBox(height: 20),
            _buildTopPerformers(context),
            const SizedBox(height: 20),
            _buildImprovementInsights(context),
            const SizedBox(height: 20),
            _buildStudentResults(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizHeader(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: AppColors.heroGradient,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
      boxShadow: [BoxShadow(color: AppColors.electricBlue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
            child: Text('Physics', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
          const Spacer(),
          Text('JEE Batch A', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white70)),
        ]),
        const SizedBox(height: 12),
        Text('Weekly Test — Chapter: Thermodynamics', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 6),
        Text('28 Feb 2026 • 20 Questions • 30 min', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 16),
        Row(children: [
          _headerStat(context, 'Attempted', '28/32'),
          _headerStat(context, 'Avg Score', '14.5/20'),
          _headerStat(context, 'Highest', '19/20'),
          _headerStat(context, 'Lowest', '8/20'),
        ]),
      ],
    ),
  ).animate().fadeIn(duration: 600.ms);

  Widget _headerStat(BuildContext context, String label, String value) => Expanded(
    child: Column(children: [
      Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: Colors.white60)),
    ]),
  );

  Widget _buildOverallStats(BuildContext context) => Row(
    children: [
      _resultCard(context, 'A+ (90%+)', '5', AppColors.mintGreen),
      const SizedBox(width: 10),
      _resultCard(context, 'A (75-90%)', '12', AppColors.electricBlue),
      const SizedBox(width: 10),
      _resultCard(context, 'B (50-75%)', '8', AppColors.moltenAmber),
      const SizedBox(width: 10),
      _resultCard(context, 'C (<50%)', '3', AppColors.coralRed),
    ],
  ).animate(delay: 200.ms).fadeIn();

  Widget _resultCard(BuildContext context, String grade, String count, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: CT.cardDecor(context),
      child: Column(children: [
        Text(count, style: GoogleFonts.jetBrainsMono(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(grade, style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w600, color: CT.textS(context)), textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _buildScoreDistribution(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: CT.cardDecor(context, radius: AppDimensions.radiusLG),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Score Distribution', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 10,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, reservedSize: 25, interval: 2,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}', style: GoogleFonts.dmSans(fontSize: 10, color: CT.textM(context))),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      const labels = ['0-4', '5-8', '9-12', '13-16', '17-20'];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(v.toInt() < labels.length ? labels[v.toInt()] : '', style: GoogleFonts.dmSans(fontSize: 10, color: CT.textM(context))),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 2, getDrawingHorizontalLine: (v) => FlLine(color: CT.textM(context), strokeWidth: 1)),
              barGroups: [1, 3, 8, 10, 6].asMap().entries.map((e) =>
                BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(
                    toY: e.value.toDouble(), width: 24,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    color: [AppColors.coralRed, AppColors.moltenAmber, AppColors.electricBlue, AppColors.royalIndigo, AppColors.mintGreen][e.key],
                  ),
                ]),
              ).toList(),
            ),
          ),
        ),
      ],
    ),
  ).animate(delay: 300.ms).fadeIn();

  // ── QUESTION-WISE ANALYSIS ──
  Widget _buildQuestionAnalysis(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: CT.cardDecor(context, radius: AppDimensions.radiusLG),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Question-wise Analysis', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
      const SizedBox(height: 4),
      Text('Correct answers out of 28 students', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textS(context))),
      const SizedBox(height: 16),
      ...[
        {'q': 'Q1', 'correct': 26, 'topic': 'First Law'},
        {'q': 'Q2', 'correct': 24, 'topic': 'Heat Transfer'},
        {'q': 'Q3', 'correct': 20, 'topic': 'Entropy'},
        {'q': 'Q4', 'correct': 22, 'topic': 'Carnot Cycle'},
        {'q': 'Q5', 'correct': 14, 'topic': 'Second Law'},
        {'q': 'Q6', 'correct': 18, 'topic': 'Work Done'},
        {'q': 'Q7', 'correct': 8, 'topic': 'Adiabatic Process'},
        {'q': 'Q8', 'correct': 16, 'topic': 'Isothermal'},
        {'q': 'Q9', 'correct': 21, 'topic': 'PV Diagrams'},
        {'q': 'Q10', 'correct': 12, 'topic': 'KTG Applications'},
      ].map((q) {
        final correct = q['correct'] as int;
        final pct = (correct / 28 * 100).round();
        final color = pct >= 75 ? AppColors.mintGreen : pct >= 50 ? AppColors.moltenAmber : AppColors.coralRed;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 28, child: Text(q['q'] as String, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: CT.textM(context)))),
            Expanded(child: Stack(children: [
              Container(height: 8, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4))),
              FractionallySizedBox(widthFactor: pct / 100, child: Container(height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)))),
            ])),
            const SizedBox(width: 8),
            SizedBox(width: 34, child: Text('$pct%', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: color))),
            SizedBox(width: 80, child: Text(q['topic'] as String, style: GoogleFonts.dmSans(fontSize: 9, color: CT.textM(context)), overflow: TextOverflow.ellipsis)),
          ]),
        );
      }),
    ]),
  ).animate(delay: 350.ms).fadeIn();

  // ── DIFFICULTY BREAKDOWN ──
  Widget _buildDifficultyBreakdown(BuildContext context) => Row(children: [
    _difficultyCard(context, 'Easy', '8 Qs', '89%', AppColors.mintGreen, Icons.sentiment_satisfied_alt),
    const SizedBox(width: 10),
    _difficultyCard(context, 'Medium', '8 Qs', '68%', AppColors.moltenAmber, Icons.sentiment_neutral),
    const SizedBox(width: 10),
    _difficultyCard(context, 'Hard', '4 Qs', '42%', AppColors.coralRed, Icons.sentiment_dissatisfied),
  ]).animate(delay: 400.ms).fadeIn();

  Widget _difficultyCard(BuildContext context, String level, String count, String accuracy, Color color, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: CT.cardDecor(context),
      child: Column(children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(level, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: CT.textH(context))),
        Text(count, style: GoogleFonts.dmSans(fontSize: 10, color: CT.textM(context))),
        const SizedBox(height: 6),
        Text(accuracy, style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text('accuracy', style: GoogleFonts.dmSans(fontSize: 9, color: CT.textS(context))),
      ]),
    ),
  );

  // ── TIME ANALYSIS ──
  Widget _buildTimeAnalysis(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: CT.cardDecor(context, radius: AppDimensions.radiusLG),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Time Analysis', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
      const SizedBox(height: 16),
      Row(children: [
        _timeStatCard(context, 'Avg Time', '22 min', AppColors.electricBlue),
        const SizedBox(width: 10),
        _timeStatCard(context, 'Fastest', '14 min', AppColors.mintGreen),
        const SizedBox(width: 10),
        _timeStatCard(context, 'Slowest', '29 min', AppColors.coralRed),
      ]),
      const SizedBox(height: 16),
      Text('Time per Question (avg)', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600, color: CT.textM(context))),
      const SizedBox(height: 10),
      SizedBox(
        height: 140,
        child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround, maxY: 4,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 25, interval: 1,
              getTitlesWidget: (v, _) => Text('${v.toInt()}m', style: GoogleFonts.dmSans(fontSize: 9, color: CT.textM(context))))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
              getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 4),
                child: Text('Q${v.toInt() + 1}', style: GoogleFonts.dmSans(fontSize: 8, color: CT.textM(context)))))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1,
            getDrawingHorizontalLine: (v) => FlLine(color: CT.textM(context), strokeWidth: 1)),
          barGroups: [0.8, 1.2, 1.5, 1.0, 2.5, 1.8, 3.2, 1.4, 1.1, 2.8].asMap().entries.map((e) =>
            BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(toY: e.value, width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                color: e.value > 2 ? AppColors.coralRed : e.value > 1.5 ? AppColors.moltenAmber : AppColors.electricBlue),
            ]),
          ).toList(),
        )),
      ),
    ]),
  ).animate(delay: 450.ms).fadeIn();

  Widget _timeStatCard(BuildContext context, String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: CT.textS(context))),
      ]),
    ),
  );

  // ── IMPROVEMENT INSIGHTS ──
  Widget _buildImprovementInsights(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [AppColors.electricBlue.withValues(alpha: 0.06), AppColors.neonIndigo.withValues(alpha: 0.03)]),
      borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
      border: Border.all(color: AppColors.electricBlue.withValues(alpha: 0.15)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.lightbulb_outline, size: 20, color: AppColors.electricBlue),
        const SizedBox(width: 8),
        Text('Key Insights', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
      ]),
      const SizedBox(height: 14),
      ...[
        {'icon': Icons.warning_amber, 'text': 'Q7 (Adiabatic Process) had the lowest accuracy at 29%. Consider revisiting this topic.', 'color': AppColors.coralRed},
        {'icon': Icons.timer_outlined, 'text': 'Students spent 3.2 min avg on Q7 — indicating conceptual difficulty, not just carelessness.', 'color': AppColors.moltenAmber},
        {'icon': Icons.trending_up, 'text': 'Hard questions improved 15% compared to last test. Good progress!', 'color': AppColors.mintGreen},
        {'icon': Icons.school_outlined, 'text': '5 students scored below 50%. Recommend doubt-clearing session for them.', 'color': AppColors.electricBlue},
      ].map((insight) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: (insight['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(insight['icon'] as IconData, size: 14, color: insight['color'] as Color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(insight['text'] as String, style: GoogleFonts.dmSans(fontSize: 12, height: 1.5, color: CT.textH(context)))),
        ]),
      )),
    ]),
  ).animate(delay: 550.ms).fadeIn();

  Widget _buildTopPerformers(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Top Performers', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
      const SizedBox(height: 12),
      Row(children: [
        _topCard(context, 1, 'Vikash Kumar', '19/20', AppColors.moltenAmber),
        const SizedBox(width: 10),
        _topCard(context, 2, 'Meera Das', '18/20', AppColors.ash),
        const SizedBox(width: 10),
        _topCard(context, 3, 'Rohan Sharma', '17/20', AppColors.english),
      ]),
    ],
  ).animate(delay: 400.ms).fadeIn();

  Widget _topCard(BuildContext context, int rank, String name, String score, Color medalColor) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: CT.cardDecor(context),
      child: Column(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: medalColor.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Center(child: Text('#$rank', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w800, color: medalColor))),
        ),
        const SizedBox(height: 8),
        Text(name, style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: CT.textH(context)), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(score, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.mintGreen)),
      ]),
    ),
  );

  Widget _buildStudentResults(BuildContext context) {
    final students = [
      {'name': 'Vikash Kumar', 'score': '19/20', 'pct': 95, 'grade': 'A+'},
      {'name': 'Meera Das', 'score': '18/20', 'pct': 90, 'grade': 'A+'},
      {'name': 'Rohan Sharma', 'score': '17/20', 'pct': 85, 'grade': 'A'},
      {'name': 'Priya Singh', 'score': '16/20', 'pct': 80, 'grade': 'A'},
      {'name': 'Arjun Reddy', 'score': '14/20', 'pct': 70, 'grade': 'B+'},
      {'name': 'Ananya Verma', 'score': '12/20', 'pct': 60, 'grade': 'B'},
      {'name': 'Kavya Nair', 'score': '10/20', 'pct': 50, 'grade': 'C+'},
      {'name': 'Sneha Patel', 'score': '8/20', 'pct': 40, 'grade': 'C'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('All Results', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
          Text('${students.length} students', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textM(context))),
        ]),
        const SizedBox(height: 12),
        ...students.asMap().entries.map((e) {
          final s = e.value;
          final pct = s['pct'] as int;
          final gradeColor = pct >= 90 ? AppColors.mintGreen : pct >= 75 ? AppColors.electricBlue : pct >= 50 ? AppColors.moltenAmber : AppColors.coralRed;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: CT.cardDecor(context, radius: AppDimensions.radiusSM),
            child: Row(children: [
              SizedBox(width: 24, child: Text('${e.key + 1}', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: CT.textM(context)))),
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.electricBlue.withValues(alpha: 0.1),
                child: Text((s['name'] as String).split(' ').map((w) => w[0]).take(2).join(), style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.electricBlue)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(s['name'] as String, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: CT.textH(context)))),
              Text(s['score'] as String, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: CT.textH(context))),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: gradeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(s['grade'] as String, style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700, color: gradeColor)),
              ),
            ]),
          ).animate(delay: Duration(milliseconds: 500 + e.key * 60)).fadeIn().slideX(begin: 0.05, end: 0);
        }),
      ],
    ).animate(delay: 500.ms).fadeIn();
  }
}
