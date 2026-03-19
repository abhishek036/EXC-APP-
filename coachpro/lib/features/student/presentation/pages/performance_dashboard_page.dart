import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';

class PerformanceDashboardPage extends StatefulWidget {
  const PerformanceDashboardPage({super.key});

  @override
  State<PerformanceDashboardPage> createState() => _PerformanceDashboardPageState();
}

class _PerformanceDashboardPageState extends State<PerformanceDashboardPage> {
  int _selectedPeriod = 1; // 0=Week, 1=Month, 2=Year
  final _periods = ['Week', 'Month', 'Year'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildPeriodSelector()),
            SliverToBoxAdapter(child: _buildStatsRow()),
            SliverToBoxAdapter(child: _buildScoreTrendChart()),
            SliverToBoxAdapter(child: _buildSubjectComparison()),
            SliverToBoxAdapter(child: _buildChapterBreakdown()),
            SliverToBoxAdapter(child: _buildStrengthWeakness()),
            SliverToBoxAdapter(child: _buildStudyStreak()),
            SliverToBoxAdapter(child: _buildRecentExams()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, AppDimensions.md, AppDimensions.pagePaddingH, AppDimensions.sm),
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
        const SizedBox(width: 16),
        Expanded(
          child: Text('My Performance', style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: CT.textH(context))),
        ),
      ],
    ),
  ).animate().fadeIn(duration: 400.ms);

  Widget _buildPeriodSelector() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        children: List.generate(_periods.length, (i) {
          final isActive = _selectedPeriod == i;
          return Expanded(
            child: CPPressable(
              onTap: () => setState(() => _selectedPeriod = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.electricBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                alignment: Alignment.center,
                child: Text(
                  _periods[i],
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : CT.textS(context),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    ),
  ).animate(delay: 100.ms).fadeIn();

  Widget _buildStatsRow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Row(
      children: [
        _buildStatDonut('Attendance', 92, AppColors.mintGreen),
        const SizedBox(width: 10),
        _buildStatDonut('Avg Score', 78, AppColors.electricBlue),
        const SizedBox(width: 10),
        _buildStatValue('Rank', '#3', AppColors.moltenAmber),
        const SizedBox(width: 10),
        _buildStatValue('Doubts', '12', AppColors.teacherTeal),
      ],
    ),
  ).animate(delay: 200.ms).fadeIn();

  Widget _buildStatDonut(String label, int value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 50, height: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: value / 100,
                  strokeWidth: 5,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
                Text('$value%', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: CT.textH(context))),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: CT.textS(context)), textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _buildStatValue(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: CT.textS(context)), textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _buildScoreTrendChart() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Score Trend', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
              Row(
                children: [
                  _legendDot(AppColors.physics, 'Physics'),
                  const SizedBox(width: 12),
                  _legendDot(AppColors.chemistry, 'Chemistry'),
                  const SizedBox(width: 12),
                  _legendDot(AppColors.mathematics, 'Maths'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (v) => FlLine(color: CT.textM(context), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 25,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}', style: GoogleFonts.dmSans(fontSize: 10, color: CT.textM(context))),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                        if (v.toInt() < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(labels[v.toInt()], style: GoogleFonts.dmSans(fontSize: 10, color: CT.textM(context))),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  _lineBarData([65, 72, 68, 80, 76, 85], AppColors.physics),
                  _lineBarData([70, 65, 75, 72, 80, 78], AppColors.chemistry),
                  _lineBarData([58, 62, 70, 65, 72, 82], AppColors.mathematics),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) =>
                      LineTooltipItem(
                        '${s.y.toInt()}%',
                        GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: s.bar.color ?? Colors.white),
                      ),
                    ).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ).animate(delay: 300.ms).fadeIn();

  LineChartBarData _lineBarData(List<int> data, Color color) => LineChartBarData(
    spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i].toDouble())),
    isCurved: true,
    color: color,
    barWidth: 2.5,
    dotData: FlDotData(
      show: true,
      getDotPainter: (s, d, bar, i) => FlDotCirclePainter(radius: 3, color: color, strokeWidth: 1.5, strokeColor: CT.card(context)),
    ),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.06)),
  );

  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: CT.textS(context))),
    ],
  );

  Widget _buildSubjectComparison() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subject-wise Performance', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
          const SizedBox(height: 16),
          _subjectBar('Physics', 85, AppColors.physics),
          const SizedBox(height: 10),
          _subjectBar('Chemistry', 78, AppColors.chemistry),
          const SizedBox(height: 10),
          _subjectBar('Mathematics', 72, AppColors.mathematics),
          const SizedBox(height: 10),
          _subjectBar('English', 90, AppColors.english),
          const SizedBox(height: 10),
          _subjectBar('Biology', 65, AppColors.biology),
        ],
      ),
    ),
  ).animate(delay: 400.ms).fadeIn();

  Widget _subjectBar(String name, int percent, Color color) => Row(
    children: [
      SizedBox(width: 80, child: Text(name, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: CT.textH(context)))),
      Expanded(
        child: Stack(
          children: [
            Container(height: 10, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5))),
            FractionallySizedBox(
              widthFactor: percent / 100,
              child: Container(height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5))),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Text('$percent%', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: CT.textH(context))),
    ],
  );

  // ── CHAPTER BREAKDOWN ──
  Widget _buildChapterBreakdown() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Chapter-wise Scores', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.physics.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text('Physics', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.physics)),
          ),
        ]),
        const SizedBox(height: 16),
        ...[
          {'ch': 'Mechanics', 'score': 92, 'trend': '↑'},
          {'ch': 'Thermodynamics', 'score': 78, 'trend': '↑'},
          {'ch': 'Waves & Optics', 'score': 85, 'trend': '→'},
          {'ch': 'Electrodynamics', 'score': 65, 'trend': '↓'},
          {'ch': 'Modern Physics', 'score': 70, 'trend': '↑'},
        ].map((c) {
          final score = c['score'] as int;
          final color = score >= 85 ? AppColors.mintGreen : score >= 70 ? AppColors.moltenAmber : AppColors.coralRed;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              SizedBox(width: 110, child: Text(c['ch'] as String, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: CT.textH(context)))),
              Expanded(child: Stack(children: [
                Container(height: 8, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(widthFactor: score / 100, child: Container(height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)))),
              ])),
              const SizedBox(width: 8),
              Text('$score%', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 4),
              Text(c['trend'] as String, style: GoogleFonts.dmSans(fontSize: 12, color: (c['trend'] == '↑') ? AppColors.mintGreen : (c['trend'] == '↓') ? AppColors.coralRed : CT.textM(context))),
            ]),
          );
        }),
      ]),
    ),
  ).animate(delay: 450.ms).fadeIn();

  // ── STRENGTHS & WEAKNESSES ──
  Widget _buildStrengthWeakness() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(children: [
      Expanded(child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.mintGreen.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: AppColors.mintGreen.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.trending_up, size: 18, color: AppColors.mintGreen),
            const SizedBox(width: 6),
            Text('Strengths', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.mintGreen)),
          ]),
          const SizedBox(height: 10),
          _chipTag('Mechanics', AppColors.mintGreen),
          const SizedBox(height: 6),
          _chipTag('Waves & Optics', AppColors.mintGreen),
          const SizedBox(height: 6),
          _chipTag('English Grammar', AppColors.mintGreen),
        ]),
      )),
      const SizedBox(width: 12),
      Expanded(child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.coralRed.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: AppColors.coralRed.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.trending_down, size: 18, color: AppColors.coralRed),
            const SizedBox(width: 6),
            Text('Improve', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.coralRed)),
          ]),
          const SizedBox(height: 10),
          _chipTag('Electrodynamics', AppColors.coralRed),
          const SizedBox(height: 6),
          _chipTag('Organic Chem', AppColors.coralRed),
          const SizedBox(height: 6),
          _chipTag('Calculus', AppColors.coralRed),
        ]),
      )),
    ]),
  ).animate(delay: 500.ms).fadeIn();

  Widget _chipTag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );

  // ── STUDY STREAK ──
  Widget _buildStudyStreak() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.moltenAmber.withValues(alpha: 0.08), AppColors.moltenAmber.withValues(alpha: 0.02)]),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: AppColors.moltenAmber.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.moltenAmber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.local_fire_department, color: AppColors.moltenAmber, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('12 Day Streak!', style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: CT.textH(context))),
            Text('Keep going! You\'re on fire', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textS(context))),
          ])),
          Text('🔥', style: GoogleFonts.dmSans(fontSize: 28)),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(7, (i) {
          final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
          final active = i < 5;
          return Column(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: active ? AppColors.moltenAmber : CT.textM(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(active ? Icons.check : Icons.remove, size: 16, color: active ? Colors.white : CT.textM(context)),
            ),
            const SizedBox(height: 4),
            Text(days[i], style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: CT.textS(context))),
          ]);
        })),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _streakStat('Best Streak', '18 days'),
          _streakStat('This Month', '22 active days'),
          _streakStat('Consistency', '88%'),
        ]),
      ]),
    ),
  ).animate(delay: 550.ms).fadeIn();

  Widget _streakStat(String label, String value) => Column(children: [
    Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: CT.textH(context))),
    Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: CT.textM(context))),
  ]);

  Widget _buildRecentExams() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Exams', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
            Text('View All', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.electricBlue)),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentExams.asMap().entries.map((e) => _buildExamCard(e.value, e.key)),
      ],
    ),
  ).animate(delay: 500.ms).fadeIn();

  final _recentExams = [
    {'name': 'Physics Weekly Test', 'date': '28 Feb 2026', 'score': '18/20', 'grade': 'A+', 'color': AppColors.physics},
    {'name': 'Chemistry Unit Test', 'date': '25 Feb 2026', 'score': '15/20', 'grade': 'B+', 'color': AppColors.chemistry},
    {'name': 'Maths Mid-Term', 'date': '20 Feb 2026', 'score': '72/100', 'grade': 'A', 'color': AppColors.mathematics},
  ];

  Widget _buildExamCard(Map<String, dynamic> exam, int index) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: CT.card(context),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.04), blurRadius: 8)],
    ),
    child: Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: (exam['color'] as Color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.description_outlined, color: exam['color'] as Color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(exam['name'] as String, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: CT.textH(context))),
              const SizedBox(height: 2),
              Text(exam['date'] as String, style: GoogleFonts.dmSans(fontSize: 11, color: CT.textS(context))),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(exam['score'] as String, style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: CT.textH(context))),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.mintGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(exam['grade'] as String, style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.mintGreen)),
            ),
          ],
        ),
      ],
    ),
  ).animate(delay: Duration(milliseconds: 550 + index * 80)).fadeIn().slideY(begin: 0.2, end: 0);
}
