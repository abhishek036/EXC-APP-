import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../data/repositories/student_repository.dart';

class QuizResultPage extends StatefulWidget {
  final String quizId;

  const QuizResultPage({super.key, required this.quizId});

  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage> {
  final _repo = sl<StudentRepository>();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _result = <String, dynamic>{};

  Map<String, dynamic> get _summary =>
      Map<String, dynamic>.from(_result['summary'] as Map? ?? const {});

  List<Map<String, dynamic>> get _questions {
    final list = (_result['questions'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((q) => Map<String, dynamic>.from(q))
        .toList();
  }

  Map<String, dynamic> get _quiz => Map<String, dynamic>.from(
    _result['quiz'] as Map? ?? const {},
  );

  bool get _resultReleased => _result['result_released'] == true;
  bool get _canRetry => _result['can_retry'] == true;
  String get _returnTo {
    final value = GoRouterState.of(context).uri.queryParameters['returnTo'];
    if (value == null || value.trim().isEmpty) return '/student/quiz';
    return value;
  }

  num _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _repo.getQuizResult(widget.quizId);
      if (!mounted) return;
      setState(() {
        _result = data;
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
    final title = (_quiz['title'] ?? 'Quiz Result').toString();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(_returnTo);
      },
      child: Scaffold(
        backgroundColor: CT.bg(context),
        appBar: AppBar(
          backgroundColor: CT.bg(context),
          elevation: 0,
          leading: IconButton(
            onPressed: () => context.go(_returnTo),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: CT.textH(context)),
          ),
          title: Text(
            'Quiz Analysis',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: CT.textH(context),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError(context)
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.pagePaddingH,
                        AppDimensions.sm,
                        AppDimensions.pagePaddingH,
                        24,
                      ),
                      children: [
                        if (_resultReleased) ...[
                          _summaryCard(context, title),
                          const SizedBox(height: 16),
                          Text(
                            'Question Review',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: CT.textH(context),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_questions.isEmpty)
                            _emptyQuestions(context)
                          else
                            ..._questions.asMap().entries.map(
                                  (entry) => _questionCard(
                                    context,
                                    entry.key + 1,
                                    entry.value,
                                  ),
                                ),
                        ] else
                          _pendingCard(context, title),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _pendingCard(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1282),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.moltenAmber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'RESULT HELD',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The teacher has not released the score or solution yet.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _canRetry ? 'You can retake after release.' : 'Please wait for the release.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go(_returnTo),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Dashboard'),
                ),
              ),
              if (_canRetry) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _fetch,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Refresh'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 52, color: CT.textM(context)),
            const SizedBox(height: 10),
            Text(
              'Failed to load quiz result',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CT.textH(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: CT.textM(context),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _fetch,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, String title) {
    final totalQuestions = _toNum(_summary['total_questions']).toInt();
    final answered = _toNum(_summary['answered_questions']).toInt();
    final correct = _toNum(_summary['correct_answers']).toInt();
    final wrong = _toNum(_summary['wrong_answers']).toInt();
    final unanswered = _toNum(_summary['unanswered_questions']).toInt();
    final obtained = _toNum(_summary['obtained_marks']).toDouble();
    final total = _toNum(_summary['total_marks']).toDouble();
    final percentage = _toNum(_summary['percentage']).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1282),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.elitePrimary, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Score ${obtained.toStringAsFixed(0)} / ${total.toStringAsFixed(0)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${percentage.toStringAsFixed(1)}% • $correct correct of $totalQuestions questions',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('Answered: $answered', Colors.white),
              _pill('Correct: $correct', AppColors.mintGreen),
              _pill('Wrong: $wrong', AppColors.coralRed),
              _pill('Unanswered: $unanswered', AppColors.moltenAmber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _emptyQuestions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CT.cardDecor(context, radius: 12),
      child: Text(
        'No question analysis available for this attempt.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: CT.textM(context),
        ),
      ),
    );
  }

  Widget _questionCard(
    BuildContext context,
    int index,
    Map<String, dynamic> question,
  ) {
    final selected = (question['selected_option'] ?? '').toString();
    final correct = (question['correct_option'] ?? '').toString();
    final isCorrect = question['is_correct'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: CT.cardDecor(context, radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (question['question_text'] ?? '').toString(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CT.textH(context),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusTag(
                selected.isEmpty ? 'Not Answered' : 'Your answer: $selected',
                selected.isEmpty
                    ? AppColors.moltenAmber
                    : isCorrect
                        ? AppColors.mintGreen
                        : AppColors.coralRed,
              ),
              _statusTag('Correct answer: $correct', AppColors.mintGreen),
            ],
          ),
          const SizedBox(height: 12),
          ...['A', 'B', 'C', 'D'].map((opt) {
            final key = 'option_${opt.toLowerCase()}';
            final text = (question[key] ?? '').toString();
            if (text.isEmpty) return const SizedBox.shrink();

            final isOptCorrect = opt == correct;
            final isOptSelected = opt == selected;

            Color border = CT.textM(context).withValues(alpha: 0.25);
            Color fill = Colors.transparent;

            if (isOptCorrect) {
              border = AppColors.mintGreen;
              fill = AppColors.mintGreen.withValues(alpha: 0.08);
            }
            if (isOptSelected && !isOptCorrect) {
              border = AppColors.coralRed;
              fill = AppColors.coralRed.withValues(alpha: 0.08);
            }

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border, width: 1.2),
              ),
              child: Row(
                children: [
                  Text(
                    '$opt.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CT.textH(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: CT.textH(context),
                      ),
                    ),
                  ),
                  if (isOptCorrect)
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: AppColors.mintGreen),
                  if (isOptSelected && !isOptCorrect)
                    const Icon(Icons.cancel_rounded,
                        size: 16, color: AppColors.coralRed),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statusTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
