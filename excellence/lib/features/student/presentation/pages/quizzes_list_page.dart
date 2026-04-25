import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/student_repository.dart';

enum _QuizBucket { newQuiz, resultReady, oldQuiz }

class _QuizStateView {
  final _QuizBucket bucket;
  final bool hasAttempt;
  final bool isInProgress;
  final bool isSubmitted;
  final bool resultReleased;
  final bool canRetry;
  final String statusLabel;
  final String resultLabel;
  final String actionLabel;
  final String? scoreLabel;
  final Map<String, dynamic>? attempt;

  const _QuizStateView({
  required this.bucket,
  required this.hasAttempt,
  required this.isInProgress,
  required this.isSubmitted,
  required this.resultReleased,
  required this.canRetry,
  required this.statusLabel,
  required this.resultLabel,
  required this.actionLabel,
  required this.scoreLabel,
  required this.attempt,
  });

  static _QuizStateView fromQuiz(Map<String, dynamic> quiz) {
  final attempts = ((quiz['attempts'] as List?) ?? const [])
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .toList();
  final attempt = attempts.isNotEmpty ? attempts.first : null;

  final assessmentType = (quiz['assessment_type'] ?? 'QUIZ')
    .toString()
    .toUpperCase();
  final allowRetry = quiz['allow_retry'] == null
    ? assessmentType == 'QUIZ'
    : quiz['allow_retry'] == true;
  final showInstantResult = quiz['show_instant_result'] == null
    ? assessmentType == 'QUIZ'
    : quiz['show_instant_result'] == true;

  final submittedAt = attempt?['submitted_at'];
  final hasAttempt = attempt != null;
  final isSubmitted = submittedAt != null;
  final isInProgress = hasAttempt && !isSubmitted;
  final resultReleased = isSubmitted && showInstantResult;
  final canRetry = isSubmitted && allowRetry;

  final bucket = !hasAttempt
    ? _QuizBucket.newQuiz
    : resultReleased
      ? _QuizBucket.resultReady
      : _QuizBucket.oldQuiz;

  final resultLabel = !hasAttempt
    ? 'Not started'
    : isInProgress
      ? 'In progress'
      : resultReleased
        ? 'Score ready'
        : 'Held by teacher';

  final scoreLabel = resultReleased
    ? '${attempt?['obtained_marks'] ?? 0}/${attempt?['total_marks'] ?? 0}'
    : isInProgress
      ? 'Resume anytime'
      : isSubmitted
        ? 'Awaiting release'
        : 'Tap to start';

  final actionLabel = !hasAttempt
    ? 'START'
    : isInProgress
      ? 'CONTINUE'
      : resultReleased
        ? 'VIEW RESULT'
        : 'LOCKED';

  final statusLabel = !hasAttempt
    ? 'NEW'
    : isInProgress
      ? 'IN PROGRESS'
      : resultReleased
        ? 'RESULT READY'
        : 'OLD';

  return _QuizStateView(
    bucket: bucket,
    hasAttempt: hasAttempt,
    isInProgress: isInProgress,
    isSubmitted: isSubmitted,
    resultReleased: resultReleased,
    canRetry: canRetry,
    statusLabel: statusLabel,
    resultLabel: resultLabel,
    actionLabel: actionLabel,
    scoreLabel: scoreLabel,
    attempt: attempt,
  );
  }
}

class QuizzesListPage extends StatefulWidget {
  const QuizzesListPage({super.key});

  @override
  State<QuizzesListPage> createState() => _QuizzesListPageState();
}

class _QuizzesListPageState extends State<QuizzesListPage> {
  final _studentRepo = sl<StudentRepository>();
  List<Map<String, dynamic>> _newQuizzes = [];
  List<Map<String, dynamic>> _resultQuizzes = [];
  List<Map<String, dynamic>> _oldQuizzes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _studentRepo.getAvailableQuizzes();
      final newQuizzes = <Map<String, dynamic>>[];
      final resultQuizzes = <Map<String, dynamic>>[];
      final oldQuizzes = <Map<String, dynamic>>[];

      for (final rawQuiz in data.whereType<Map>()) {
        final quiz = Map<String, dynamic>.from(rawQuiz);
        final state = _quizState(quiz);

        switch (state.bucket) {
          case _QuizBucket.newQuiz:
            newQuizzes.add(quiz);
            break;
          case _QuizBucket.resultReady:
            resultQuizzes.add(quiz);
            break;
          case _QuizBucket.oldQuiz:
            oldQuizzes.add(quiz);
            break;
        }
      }

      setState(() {
        _newQuizzes = newQuizzes;
        _resultQuizzes = resultQuizzes;
        _oldQuizzes = oldQuizzes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 18, color: CT.textH(context)),
          onPressed: () =>
              GoRouter.of(context).canPop() ? GoRouter.of(context).pop() : GoRouter.of(context).go('/student'),
        ),
        title: Text(
          'Available Quizzes',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: CT.textH(context),
          ),
        ),
        backgroundColor: CT.bg(context),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => GoRouter.of(context).push('/student/results'),
            icon: Icon(Icons.history_rounded, size: 22, color: CT.textH(context)),
            tooltip: 'View Results',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadQuizzes,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: TabBar(
                            isScrollable: true,
                            indicatorColor: AppColors.primary,
                            indicatorWeight: 3,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: CT.textM(context),
                            labelStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            tabs: [
                              Tab(text: 'NEW (${_newQuizzes.length})'),
                              Tab(text: 'RESULT (${_resultQuizzes.length})'),
                              Tab(text: 'OLD (${_oldQuizzes.length})'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildCategoryList(
                                context,
                                _newQuizzes,
                                emptyTitle: 'No new quizzes',
                                emptySubtitle: 'Fresh quizzes will appear here.',
                              ),
                              _buildCategoryList(
                                context,
                                _resultQuizzes,
                                emptyTitle: 'No released results yet',
                                emptySubtitle: 'Finished quizzes will appear here.',
                              ),
                              _buildCategoryList(
                                context,
                                _oldQuizzes,
                                emptyTitle: 'No old quizzes',
                                emptySubtitle: 'Held or locked quizzes will appear here.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    List<Map<String, dynamic>> quizzes, {
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (quizzes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz_outlined, size: 64, color: CT.textM(context)),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  color: CT.textH(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: CT.textM(context)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: quizzes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _quizCard(quizzes[index], index),
    );
  }

  Widget _quizCard(Map<String, dynamic> quiz, int index) {
    final state = _quizState(quiz);
    final title = (quiz['title'] ?? 'Untitled Quiz').toString();
    final subject = (quiz['subject'] ?? 'General').toString();
    final batchName = (quiz['batch']?['name'] ?? 'All Batches').toString();
    final timeLimit = (quiz['time_limit_min'] ?? 0).toString();
    final questionCount = (quiz['_count']?['questions'] ?? 0).toString();
    final marksPerQuestion =
        (quiz['marks_per_question'] ?? quiz['marksPerQuestion'] ?? 1)
            .toString();
    final quizId = (quiz['id'] ?? '').toString();

    return Container(
      decoration: CT.cardDecor(context, radius: 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _handleQuizTap(quiz, state),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 1.4,
                  ),
                ),
                child: const Icon(
                  Icons.quiz_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            subject.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: state.resultReleased
                                ? AppColors.mintGreen.withValues(alpha: 0.15)
                                : state.isSubmitted
                                    ? AppColors.moltenAmber.withValues(alpha: 0.16)
                                    : AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            state.statusLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: CT.textH(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Batch: $batchName',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: CT.textM(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _infoChip(Icons.help_outline, '$questionCount Qs'),
                        _infoChip(Icons.timer_outlined, '$timeLimit mins'),
                        _infoChip(Icons.stars_outlined, '$marksPerQuestion Marks/Q'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RESULT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: CT.textM(context),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.scoreLabel ?? state.resultLabel,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: CT.textH(context),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: quizId.isEmpty
                            ? null
                            : () => _handleQuizTap(quiz, state),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _buttonColorFor(state),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          state.actionLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (state.resultReleased && state.canRetry) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: quizId.isEmpty ? null : () => _confirmRetake(quiz),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.primary,
                              width: 1.4,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'RETAKE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 80 * index))
        .fadeIn()
        .slideX(begin: 0.04, end: 0);
  }

  Widget _infoChip(IconData icon, String label) => Row(
    children: [
      Icon(icon, size: 14, color: CT.textS(context)),
      const SizedBox(width: 4),
      Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: CT.textS(context),
        ),
      ),
    ],
  );

  Color _buttonColorFor(_QuizStateView state) {
    if (state.resultReleased && state.canRetry) return AppColors.moltenAmber;
    if (state.isSubmitted && !state.resultReleased) return AppColors.coralRed;
    return CT.accent(context);
  }

  _QuizStateView _quizState(Map<String, dynamic> quiz) => _QuizStateView.fromQuiz(quiz);

  String get _returnTo => '/student/quiz';
  String _quizTakingRoute(String quizId) =>
      '/student/quiz/$quizId?returnTo=${Uri.encodeComponent(_returnTo)}';
  String _quizResultRoute(String quizId) =>
      '/student/quiz/$quizId/result?returnTo=${Uri.encodeComponent(_returnTo)}';

  Future<void> _handleQuizTap(Map<String, dynamic> quiz, _QuizStateView state) async {
    final quizId = (quiz['id'] ?? '').toString();
    if (quizId.isEmpty) return;

    if (!state.hasAttempt || state.isInProgress) {
      _confirmStart(quiz);
      return;
    }

    if (state.resultReleased) {
      GoRouter.of(context).push(_quizResultRoute(quizId));
      return;
    }

    await _showHeldResultSheet(quiz, state);
  }

  Future<void> _confirmStart(Map<String, dynamic> quiz) async {
    final quizId = (quiz['id'] ?? '').toString();
    if (quizId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: CT.bg(context),
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
              'Ready to start?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CT.textH(ctx),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Once you start, the timer will begin. Make sure you have a stable internet connection.',
              style: GoogleFonts.plusJakartaSans(color: CT.textS(ctx)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      GoRouter.of(context).push(_quizTakingRoute(quizId));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CT.accent(ctx),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Start Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRetake(Map<String, dynamic> quiz) async {
    final quizId = (quiz['id'] ?? '').toString();
    if (quizId.isEmpty) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: CT.bg(context),
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
              'This will reset your current submitted attempt and start a fresh run.',
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

    try {
      await _studentRepo.startQuizAttempt(quizId);
      if (!mounted) return;
      GoRouter.of(context).push(_quizTakingRoute(quizId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _showHeldResultSheet(
    Map<String, dynamic> quiz,
    _QuizStateView state,
  ) async {
    final quizTitle = (quiz['title'] ?? 'Quiz').toString();
    final quizId = (quiz['id'] ?? '').toString();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CT.bg(context),
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
              'Result is held',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CT.textH(ctx),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$quizTitle is submitted, but the teacher has not released the score and solution yet.',
              style: GoogleFonts.plusJakartaSans(color: CT.textS(ctx)),
            ),
            const SizedBox(height: 16),
            Text(
              state.scoreLabel ?? 'Awaiting release',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Dashboard'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: state.resultReleased && quizId.isNotEmpty
                        ? () {
                            Navigator.pop(ctx);
                            GoRouter.of(context).push(_quizResultRoute(quizId));
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CT.accent(ctx),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Result Locked'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to sync quizzes',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: CT.textH(context),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadQuizzes, child: const Text('Retry')),
        ],
      ),
    );
  }
}

