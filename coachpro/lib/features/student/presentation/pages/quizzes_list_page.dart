import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/student_repository.dart';

class QuizzesListPage extends StatefulWidget {
  const QuizzesListPage({super.key});

  @override
  State<QuizzesListPage> createState() => _QuizzesListPageState();
}

class _QuizzesListPageState extends State<QuizzesListPage> {
  final _studentRepo = sl<StudentRepository>();
  List<Map<String, dynamic>> _quizzes = [];
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
      setState(() {
        _quizzes = data;
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
              context.canPop() ? context.pop() : context.go('/student'),
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
            onPressed: () => context.push('/student/results'),
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
            : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    if (_quizzes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 64, color: CT.textM(context)),
            const SizedBox(height: 16),
            Text(
              'No active quizzes',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                color: CT.textH(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new tests!',
              style: GoogleFonts.plusJakartaSans(color: CT.textM(context)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _quizzes.length,
      itemBuilder: (context, index) {
        final quiz = _quizzes[index];
        return _quizCard(quiz, index);
      },
    );
  }

  Widget _quizCard(Map<String, dynamic> quiz, int index) {
    final title = quiz['title'] ?? 'Untitled Quiz';
    final subject = quiz['subject'] ?? 'General';
    final batchName = quiz['batch']?['name'] ?? 'All Batches';
    final timeLimit = quiz['time_limit_min'] ?? 0;
    final questionCount = quiz['_count']?['questions'] ?? 0;
    final marksPerQuestion =
      (quiz['marks_per_question'] ?? quiz['marksPerQuestion'] ?? 1)
        .toString();

    return CPPressable(
          onTap: () => _confirmStart(quiz),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: CT.cardDecor(context, radius: 18),
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
                    const Spacer(),
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: AppColors.moltenAmber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$timeLimit mins',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.moltenAmber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: CT.textH(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Batch: $batchName',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: CT.textM(context),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _infoChip(Icons.help_outline, '$questionCount Qs'),
                    const SizedBox(width: 12),
                    _infoChip(Icons.stars_outlined, '$marksPerQuestion Marks/Q'),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: CT.accent(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Start Test',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: 100 * index))
        .fadeIn()
        .slideX(begin: 0.05, end: 0);
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

  void _confirmStart(Map<String, dynamic> quiz) {
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
                      context.push('/student/quiz/${quiz['id']}');
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
