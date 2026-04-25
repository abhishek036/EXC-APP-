import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/student_repository.dart';

class QuizTakingPage extends StatefulWidget {
  final String quizId;
  const QuizTakingPage({super.key, required this.quizId});

  @override
  State<QuizTakingPage> createState() => _QuizTakingPageState();
}

class _QuizTakingPageState extends State<QuizTakingPage> {
  final _studentRepo = sl<StudentRepository>();

  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _quiz;
  List<dynamic> _questions = [];
  final Map<String, String> _userAnswers = {}; // questionId -> optionLetter ('A','B','C','D')

  int _currentIndex = 0;
  int _secondsRemaining = 0;
  Timer? _timer;
  final _alpha = ['A', 'B', 'C', 'D'];
  bool _showCompletionScreen = false;

  Map<String, dynamic> get _studentState => Map<String, dynamic>.from(
    _quiz?['student_state'] as Map? ?? const {},
  );

  bool get _resultReleased => _studentState['result_released'] == true;
  bool get _canRetry => _studentState['can_retry'] == true;
  String get _returnTo {
    final value = GoRouterState.of(context).uri.queryParameters['returnTo'];
    if (value == null || value.trim().isEmpty) return '/student/quiz';
    return value;
  }

  String get _resultRoute =>
      '/student/quiz/${widget.quizId}/result?returnTo=${Uri.encodeComponent(_returnTo)}';

  @override
  void initState() {
    super.initState();
    _initQuiz();
  }

  Future<void> _initQuiz({bool forceRetake = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _showCompletionScreen = false;
    });
    try {
      if (forceRetake) {
        await _studentRepo.startQuizAttempt(widget.quizId);
      }

      final quizData = await _studentRepo.getQuizById(widget.quizId);
      final studentState = Map<String, dynamic>.from(
        quizData['student_state'] as Map? ?? const {},
      );
      final isCompleted = studentState['is_finished'] == true ||
          studentState['submitted_at'] != null;

      if (isCompleted && !forceRetake) {
        if (!mounted) return;
        setState(() {
          _quiz = quizData;
          _questions = quizData['questions'] as List? ?? [];
          _secondsRemaining = 0;
          _showCompletionScreen = true;
          _isLoading = false;
        });
        _timer?.cancel();
        return;
      }

      if (!forceRetake && !isCompleted) {
        await _studentRepo.startQuizAttempt(widget.quizId);
      }

      final activeQuizData = forceRetake || !isCompleted
          ? await _studentRepo.getQuizById(widget.quizId)
          : quizData;

      setState(() {
        _quiz = activeQuizData;
        _questions = activeQuizData['questions'] as List? ?? [];
        _secondsRemaining = (activeQuizData['time_limit_min'] ?? 30) * 60;
        _isLoading = false;
        _showCompletionScreen = false;
      });

      _startTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        _autoSubmit();
      }
    });
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _autoSubmit() async {
    // Auto submit when time up
    await _submitQuiz();
  }

  Future<void> _submitQuiz() async {
    _timer?.cancel();
    setState(() => _isLoading = true);

    try {
      await _studentRepo.submitQuizAttempt(
        quizId: widget.quizId,
        answers: _userAnswers,
      );

      if (mounted) {
        await _initQuiz();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
      }
    }
  }

  Future<void> _startRetake() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: CT.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Retake quiz?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CT.textH(ctx),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will reset your submitted attempt and start a fresh run.',
              style: GoogleFonts.plusJakartaSans(color: CT.textS(ctx)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CT.accent(ctx),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retake Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    await _initQuiz(forceRetake: true);
  }

  Widget _buildCompletionScreen() {
    final quizTitle = (_quiz?['title'] ?? 'Quiz').toString();
    final scoreText = (_studentState['obtained_marks'] != null &&
            _studentState['total_marks'] != null)
        ? '${_studentState['obtained_marks']}/${_studentState['total_marks']}'
        : 'Submitted';

    return Scaffold(
      backgroundColor: CT.card(context),
      appBar: AppBar(
        backgroundColor: CT.card(context),
        leading: IconButton(
          onPressed: () => GoRouter.of(context).go(_returnTo),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          quizTitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CT.bg(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  offset: const Offset(0, 8),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _resultReleased
                        ? AppColors.mintGreen.withValues(alpha: 0.18)
                        : AppColors.moltenAmber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _resultReleased ? 'RESULT READY' : 'SUBMITTED',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Quiz Finished',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _resultReleased
                      ? 'Your score is ready and the solution is visible below.'
                      : 'Your answers have been recorded. The teacher will release the score and solution later.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CT.textS(context),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  scoreText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => GoRouter.of(context).go(_returnTo),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.primary, width: 1.4),
                        ),
                        child: const Text('Dashboard'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _resultReleased
                            ? () => GoRouter.of(context).go(_resultRoute)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CT.accent(context),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _resultReleased ? 'Result' : 'Locked',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_canRetry) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _startRetake,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primary, width: 1.4),
                      ),
                      child: const Text('Retake Quiz'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _quiz == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_quiz != null && _showCompletionScreen) {
      return _buildCompletionScreen();
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Failed to start quiz',
                style: GoogleFonts.plusJakartaSans(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _initQuiz, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentIndex];
    final qId = currentQuestion['id'].toString();
    final selectedOption = _userAnswers[qId];

    return Scaffold(
      backgroundColor: CT.card(context),
      appBar: AppBar(
        backgroundColor: CT.card(context),
        leading: IconButton(
          onPressed: () => _confirmExit(),
          icon: const Icon(Icons.close),
        ),
        title: Text(
          _quiz?['title'] ?? 'Quiz',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          CPPressable(
            onTap: _confirmSubmit,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  'FINISH',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: CT.accent(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Timer + question number
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.pagePaddingH,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TIME REMAINING',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: CT.textM(context),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Question',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: CT.textM(context),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.timer,
                                size: 16,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatTime(_secondsRemaining),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${_currentIndex + 1}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              TextSpan(
                                text: ' / ${_questions.length}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  color: CT.textM(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (_currentIndex + 1) / _questions.length,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Question navigator
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _questions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final isCurrent = i == _currentIndex;
                          final isAnswered = _userAnswers.containsKey(
                            _questions[i]['id'].toString(),
                          );
                          return CPPressable(
                            onTap: () => setState(() => _currentIndex = i),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? AppColors.primary
                                    : isAnswered
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCurrent
                                      ? AppColors.primary
                                      : isAnswered
                                      ? AppColors.primary.withValues(alpha: 0.3)
                                      : CT.textM(context),
                                  width: isCurrent ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isCurrent
                                        ? Colors.white
                                        : isAnswered
                                        ? AppColors.primary
                                        : CT.textM(context),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Question card
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.physics.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _quiz?['subject'] ?? 'Subject',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.physics,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (currentQuestion['image_url'] != null &&
                          currentQuestion['image_url'].toString().isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            image: DecorationImage(
                              image: NetworkImage(
                                currentQuestion['image_url'].toString(),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Q${_currentIndex + 1}. ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: CT.textM(context),
                              ),
                            ),
                            TextSpan(
                              text: currentQuestion['question_text'] ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: CT.textH(context),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Options
                      ...List.generate(4, (i) {
                        final key = 'option_${_alpha[i].toLowerCase()}';
                        final optionText = currentQuestion[key] as String?;
                        final optImageUrl = currentQuestion['${key}_image'] as String?;

                        if (optionText == null || optionText.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final selected = selectedOption == _alpha[i];
                        return CPPressable(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _userAnswers[qId] = _alpha[i]);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : CT.card(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : CT.textM(context),
                                width: selected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  offset: const Offset(0, 4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? Colors.white.withValues(
                                              alpha: 0.2,
                                            )
                                            : CT.textM(context),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: selected
                                            ? const Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                            : Text(
                                              _alpha[i],
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: CT.textS(context),
                                              ),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        optionText,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? Colors.white
                                              : CT.textH(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (optImageUrl != null &&
                                    optImageUrl.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 44,
                                      top: 12,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        optImageUrl,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (ctx, err, stack) =>
                                                const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Bottom nav
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: CT.card(context),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _currentIndex > 0
                              ? () => setState(() => _currentIndex--)
                              : null,
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: Text(
                            'Previous',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentIndex < _questions.length - 1) {
                              setState(() {
                                _currentIndex++;
                              });
                            } else {
                              _confirmSubmit();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentIndex < _questions.length - 1
                                    ? 'Next'
                                    : 'Submit',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _currentIndex < _questions.length - 1
                                    ? Icons.arrow_forward
                                    : Icons.check_circle,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  void _confirmSubmit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Quiz?'),
        content: Text(
          'You have answered ${_userAnswers.length} out of ${_questions.length} questions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Review'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitQuiz();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit Quiz?'),
        content: const Text(
          'Your progress will be lost and this will count as an attempt. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              GoRouter.of(context).go(_returnTo);
            },
            child: Text('Quit', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

