import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';

class QuizResultsPage extends StatelessWidget {
  const QuizResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);
    const yellow = Color(0xFFF0DE36);

    return Scaffold(
      backgroundColor: blue,
      appBar: AppBar(
        backgroundColor: blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'QUIZ ANALYTICS',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildQuizOverview(blue, surface, yellow),
            const SizedBox(height: 24),
            _buildPerformanceGrid(blue, surface, yellow),
            const SizedBox(height: 24),
            _buildChartSection('SCORE DISTRIBUTION', _buildBarChart(blue, surface, yellow), blue, surface, yellow),
            const SizedBox(height: 24),
            _buildChartSection('QUESTION ANALYSIS', _buildQuestionStack(blue, surface, yellow), blue, surface, yellow),
            const SizedBox(height: 24),
            _buildLeaderboard(blue, surface, yellow),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizOverview(Color blue, Color surface, Color yellow) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: yellow, offset: const Offset(6, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: blue, borderRadius: BorderRadius.circular(4)), child: Text('PHYSICS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white))),
              const Spacer(),
              Text('JEE BATCH A', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: blue.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 16),
          Text('THERMODYNAMICS - WK 4', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: blue, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('28 FEB 2026 • 20 QUESTIONS • 30 MIN', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: blue.withValues(alpha: 0.6))),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _headerStat('AVG', '14.5/20', blue),
              _headerStat('TOP', '19/20', blue),
              _headerStat('LOW', '8/20', blue),
              _headerStat('ATT', '28/32', blue),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _headerStat(String label, String val, Color blue) => Column(
    children: [
      Text(val, style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w900, color: blue)),
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: blue.withValues(alpha: 0.4))),
    ],
  );

  Widget _buildPerformanceGrid(Color blue, Color surface, Color yellow) {
    return Row(
      children: [
        _statBox('A+', '5', AppColors.mintGreen, blue, surface),
        const SizedBox(width: 12),
        _statBox('A', '12', blue, blue, surface),
        const SizedBox(width: 12),
        _statBox('B', '8', const Color(0xFFC0A000), blue, surface),
        const SizedBox(width: 12),
        _statBox('C', '3', AppColors.coralRed, blue, surface),
      ],
    ).animate(delay: 200.ms).fadeIn();
  }

  Widget _statBox(String grade, String count, Color color, Color blue, Color surface) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
      ),
      child: Column(children: [
        Text(count, style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(grade, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: blue.withValues(alpha: 0.6))),
      ]),
    ),
  );

  Widget _buildChartSection(String title, Widget chart, Color blue, Color surface, Color yellow) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 2.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(5, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: blue, letterSpacing: 0.5)),
          const SizedBox(height: 24),
          chart,
        ],
      ),
    );
  }

  Widget _buildBarChart(Color blue, Color surface, Color yellow) {
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 12,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 25, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w900, color: blue.withValues(alpha: 0.5))))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
              const labels = ['0-4', '5-8', '9-12', '13-16', '17-20'];
              return Padding(padding: const EdgeInsets.only(top: 8), child: Text(v.toInt() < labels.length ? labels[v.toInt()] : '', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: blue)));
            })),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 3, getDrawingHorizontalLine: (v) => FlLine(color: blue.withValues(alpha: 0.1), strokeWidth: 2)),
          barGroups: [1, 3, 8, 11, 6].asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(toY: e.value.toDouble(), width: 24, borderRadius: BorderRadius.circular(2), color: blue, borderSide: const BorderSide(color: Colors.black, width: 1.5)),
          ])).toList(),
        ),
      ),
    );
  }

  Widget _buildQuestionStack(Color blue, Color surface, Color yellow) {
    final questions = [
      {'q': 'Q1', 'topic': 'FIRST LAW', 'pct': 92},
      {'q': 'Q2', 'topic': 'HEAT TRANS', 'pct': 85},
      {'q': 'Q3', 'topic': 'ENTROPY', 'pct': 71},
      {'q': 'Q4', 'topic': 'CARNOT', 'pct': 32},
      {'q': 'Q5', 'topic': 'PROCESSES', 'pct': 64},
    ];

    return Column(
      children: questions.map((q) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SizedBox(width: 32, child: Text(q['q'] as String, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w900, color: blue))),
            Expanded(child: Stack(children: [
              Container(height: 12, decoration: BoxDecoration(color: blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2), border: Border.all(color: blue, width: 1))),
              FractionallySizedBox(widthFactor: (q['pct'] as int) / 100, child: Container(height: 12, decoration: BoxDecoration(color: (q['pct'] as int) < 40 ? AppColors.coralRed : yellow, borderRadius: BorderRadius.circular(2), border: Border.all(color: blue, width: 1)))),
            ])),
            const SizedBox(width: 12),
            SizedBox(width: 40, child: Text('${q['pct']}%', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w900, color: blue))),
            SizedBox(width: 80, child: Text(q['topic'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w900, color: blue.withValues(alpha: 0.5)), overflow: TextOverflow.ellipsis)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildLeaderboard(Color blue, Color surface, Color yellow) {
    final tops = [
      {'name': 'VIKASH KUMAR', 'score': '19/20', 'rank': 1},
      {'name': 'MEERA DAS', 'score': '18/20', 'rank': 2},
      {'name': 'ROHAN SHARMA', 'score': '17/20', 'rank': 3},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TOP PERFORMERS', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0)),
        const SizedBox(height: 16),
        ...tops.map((t) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: blue, width: 2.5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
          ),
          child: Row(
            children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: t['rank'] == 1 ? yellow : blue, border: Border.all(color: blue, width: 2), borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: Text('#${t['rank']}', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, color: t['rank'] == 1 ? blue : Colors.white))),
              const SizedBox(width: 16),
              Expanded(child: Text(t['name'] as String, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: blue, fontSize: 13))),
              Text(t['score'] as String, style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, color: AppColors.mintGreen, fontSize: 16)),
            ],
          ),
        )),
      ],
    );
  }
}
