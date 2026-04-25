import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/teacher_repository.dart';
import '../../../../core/theme/theme_aware.dart';
class QuizResultsPage extends StatefulWidget {
  final String quizId;
  final String? fallbackTitle;

  const QuizResultsPage({super.key, required this.quizId, this.fallbackTitle});

  @override
  State<QuizResultsPage> createState() => _QuizResultsPageState();
}

class _QuizResultsPageState extends State<QuizResultsPage> with ThemeAware<QuizResultsPage> {
  final _repo = sl<TeacherRepository>();

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _report = {};
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _repo.getQuizReport(widget.quizId),
        _repo.getQuizResults(widget.quizId),
      ]);

      final report = Map<String, dynamic>.from(results[0] as Map);
      final leaderboard = List<Map<String, dynamic>>.from(results[1] as List);

      if (!mounted) return;
      setState(() {
        _report = report;
        _leaderboard = leaderboard;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _questions {
    final quiz = (_report['quiz'] as Map?) ?? const {};
    final questions = (quiz['questions'] as List?) ?? const [];
    return questions
        .whereType<Map>()
        .map((q) => Map<String, dynamic>.from(q))
        .toList();
  }

  List<Map<String, dynamic>> get _attempts {
    final attempts = (_report['attempts'] as List?) ?? const [];
    return attempts
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .where((a) => a['submitted_at'] != null)
        .toList();
  }

  List<Map<String, dynamic>> get _classResults {
    final items = (_report['class_results'] as List?) ?? const [];
    if (items.isEmpty) {
      return _attempts
          .map(
            (a) => {
              'student_name': ((a['student'] as Map?)?['name'] ?? 'Student')
                  .toString(),
              'status': a['submitted_at'] != null ? 'submitted' : 'pending',
              'obtained_marks': a['obtained_marks'],
              'total_marks': a['total_marks'],
            },
          )
          .toList();
    }
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  num _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  int get _totalMarks => _questions.fold<int>(
    0,
    (sum, q) =>
        sum +
        (_toNum(q['marks']).toInt() == 0 ? 1 : _toNum(q['marks']).toInt()),
  );

  double get _avgScore {
    if (_attempts.isEmpty) return 0;
    final total = _attempts.fold<num>(
      0,
      (sum, a) => sum + _toNum(a['obtained_marks']),
    );
    return total / _attempts.length;
  }

  int get _topScore {
    if (_attempts.isEmpty) return 0;
    return _attempts
        .map((a) => _toNum(a['obtained_marks']).toInt())
        .reduce((a, b) => a > b ? a : b);
  }

  int get _lowScore {
    if (_attempts.isEmpty) return 0;
    return _attempts
        .map((a) => _toNum(a['obtained_marks']).toInt())
        .reduce((a, b) => a < b ? a : b);
  }

  List<int> get _gradeBuckets {
    int ap = 0, a = 0, b = 0, c = 0;
    final maxMarks = _totalMarks == 0 ? 1 : _totalMarks;

    for (final attempt in _attempts) {
      final pct = (_toNum(attempt['obtained_marks']) / maxMarks) * 100;
      if (pct >= 85) {
        ap++;
      } else if (pct >= 70) {
        a++;
      } else if (pct >= 50) {
        b++;
      } else {
        c++;
      }
    }

    return [ap, a, b, c];
  }

  List<int> get _scoreDistribution {
    if (_attempts.isEmpty) return [0, 0, 0, 0, 0];
    final maxMarks = _totalMarks == 0 ? 1 : _totalMarks;
    final buckets = [0, 0, 0, 0, 0];

    for (final attempt in _attempts) {
      final score = _toNum(attempt['obtained_marks']);
      final ratio = (score / maxMarks).clamp(0, 1);
      final idx = (ratio * 5).floor().clamp(0, 4);
      buckets[idx] += 1;
    }

    return buckets;
  }

  List<Map<String, dynamic>> get _questionStats {
    final attempts = _attempts;
    if (attempts.isEmpty || _questions.isEmpty) return [];

    return _questions.asMap().entries.map((entry) {
      final idx = entry.key;
      final q = entry.value;
      final qId = (q['id'] ?? '').toString();
      final correctOption = (q['correct_option'] ?? '').toString();
      final text = (q['question_text'] ?? 'Question ${idx + 1}').toString();

      int correct = 0;
      int totalAnswered = 0;

      for (final attempt in attempts) {
        final answers = attempt['answers'];
        if (answers is! Map) continue;
        final selected = answers[qId]?.toString();
        if (selected == null || selected.isEmpty) continue;
        totalAnswered += 1;
        if (selected == correctOption) correct += 1;
      }

      final pct = totalAnswered == 0
          ? 0
          : ((correct / totalAnswered) * 100).round();
      return {'q': 'Q${idx + 1}', 'topic': text, 'pct': pct};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.elitePrimary;
    const surface = AppColors.offWhite;
    const yellow = AppColors.moltenAmber;

    final quiz = (_report['quiz'] as Map?) ?? const {};
    final title = (quiz['title'] ?? widget.fallbackTitle ?? 'QUIZ ANALYTICS')
        .toString()
        .toUpperCase();
    final subject = (quiz['subject'] ?? 'GENERAL').toString().toUpperCase();
    final totalQuestions = _questions.length;
    final totalAttempts = _attempts.length;

    return Scaffold(
      backgroundColor: blue,
      appBar: AppBar(
        backgroundColor: blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              GoRouter.of(context).pop();
            } else {
              GoRouter.of(context).go('/teacher');
            }
          },
        ),
        title: Text(
          'QUIZ ANALYTICS',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: yellow))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load analytics: $_error',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildQuizOverview(
                    blue,
                    surface,
                    yellow,
                    title,
                    subject,
                    totalQuestions,
                    totalAttempts,
                  ),
                  const SizedBox(height: 24),
                  _buildPerformanceGrid(blue, surface, yellow),
                  const SizedBox(height: 24),
                  _buildChartSection(
                    'SCORE DISTRIBUTION',
                    _buildBarChart(blue),
                    blue,
                    surface,
                  ),
                  const SizedBox(height: 24),
                  _buildChartSection(
                    'QUESTION ANALYSIS',
                    _buildQuestionStack(blue, yellow),
                    blue,
                    surface,
                  ),
                  const SizedBox(height: 24),
                  _buildClassResults(blue, surface),
                  const SizedBox(height: 24),
                  _buildLeaderboard(blue, surface),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildQuizOverview(
    Color blue,
    Color surface,
    Color yellow,
    String title,
    String subject,
    int totalQuestions,
    int totalAttempts,
  ) {
    final avg = _avgScore.toStringAsFixed(1);
    final top = _topScore;
    final low = _lowScore;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  subject,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'ATTEMPTS: $totalAttempts',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: blue.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: blue,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalQuestions QUESTIONS • TOTAL MARKS $_totalMarks',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: blue.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _headerStat('AVG', '$avg/$_totalMarks', blue),
              _headerStat('TOP', '$top/$_totalMarks', blue),
              _headerStat('LOW', '$low/$_totalMarks', blue),
              _headerStat('ATT', '$totalAttempts', blue),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06);
  }

  Widget _headerStat(String label, String val, Color blue) => Column(
    children: [
      Text(
        val,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: blue,
        ),
      ),
      Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: blue.withValues(alpha: 0.4),
        ),
      ),
    ],
  );

  Widget _buildPerformanceGrid(Color blue, Color surface, Color yellow) {
    final buckets = _gradeBuckets;
    return Row(
      children: [
        _statBox('A+', '${buckets[0]}', AppColors.mintGreen, blue, surface),
        const SizedBox(width: 12),
        _statBox('A', '${buckets[1]}', blue, blue, surface),
        const SizedBox(width: 12),
        _statBox('B', '${buckets[2]}', const Color(0xFFC0A000), blue, surface),
        const SizedBox(width: 12),
        _statBox('C', '${buckets[3]}', AppColors.coralRed, blue, surface),
      ],
    ).animate(delay: 100.ms).fadeIn();
  }

  Widget _statBox(
    String grade,
    String count,
    Color color,
    Color blue,
    Color surface,
  ) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
      ),
      child: Column(
        children: [
          Text(
            count,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            grade,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: blue.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildChartSection(
    String title,
    Widget chart,
    Color blue,
    Color surface,
  ) {
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
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: blue,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),
          chart,
        ],
      ),
    );
  }

  Widget _buildBarChart(Color blue) {
    final distribution = _scoreDistribution;
    final maxY =
        (distribution.isEmpty
            ? 1
            : distribution.reduce((a, b) => a > b ? a : b)) +
        1;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY.toDouble(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 25,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: blue.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  const labels = [
                    '0-20%',
                    '21-40%',
                    '41-60%',
                    '61-80%',
                    '81-100%',
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      v.toInt() < labels.length ? labels[v.toInt()] : '',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: blue,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: blue.withValues(alpha: 0.1), strokeWidth: 2),
          ),
          barGroups: distribution.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.toDouble(),
                  width: 24,
                  borderRadius: BorderRadius.circular(2),
                  color: blue,
                  borderSide: BorderSide(color: blue, width: 1.5),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildQuestionStack(Color blue, Color yellow) {
    final items = _questionStats;
    if (items.isEmpty) {
      return Text(
        'No submitted attempts yet.',
        style: GoogleFonts.plusJakartaSans(
          color: blue.withValues(alpha: 0.6),
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Column(
      children: items.take(8).map((q) {
        final pct = q['pct'] as int;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  q['q'] as String,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: blue,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: blue, width: 1),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct / 100,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: pct < 40 ? AppColors.coralRed : yellow,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: blue, width: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                child: Text(
                  '$pct%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: blue,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaderboard(Color blue, Color surface) {
    final top = _leaderboard.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOP PERFORMERS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        if (top.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'No submissions yet.',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: blue.withValues(alpha: 0.7),
              ),
            ),
          )
        else
          ...top.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final item = entry.value;
            final student = (item['student'] as Map?) ?? const {};
            final name = (student['name'] ?? 'STUDENT')
                .toString()
                .toUpperCase();
            final obtained = _toNum(item['obtained_marks']).toInt();

            return Container(
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
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rank == 1 ? const Color(0xFFFFD54F) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: blue, width: 2),
                    ),
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        color: blue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        color: blue,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '$obtained/$_totalMarks',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.w900,
                      color: blue,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildClassResults(Color blue, Color surface) {
    final rows = _classResults;

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
          Text(
            'CLASS RESULTS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: blue,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            Text(
              'No students found for this batch yet.',
              style: GoogleFonts.plusJakartaSans(
                color: blue.withValues(alpha: 0.65),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...rows.asMap().entries.map((entry) {
              final idx = entry.key;
              final row = entry.value;
              final name = (row['student_name'] ?? row['name'] ?? 'Student')
                  .toString()
                  .toUpperCase();
              final status = (row['status'] ?? '').toString().toLowerCase();
              final submitted = status == 'submitted' || row['submitted_at'] != null;
              final obtained = _toNum(row['obtained_marks']).toInt();
              final total = _toNum(row['total_marks']).toInt();
              final marksText = submitted
                  ? '$obtained/${total > 0 ? total : _totalMarks}'
                  : 'PENDING';

              return Container(
                margin: EdgeInsets.only(bottom: idx == rows.length - 1 ? 0 : 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: submitted
                        ? blue.withValues(alpha: 0.25)
                        : AppColors.moltenAmber.withValues(alpha: 0.7),
                    width: 1.3,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: blue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      marksText,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: submitted ? blue : AppColors.moltenAmber,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}





