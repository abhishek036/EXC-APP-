import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_shimmer.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../data/repositories/student_repository.dart';

class MyDoubtsHistoryPage extends StatefulWidget {
  const MyDoubtsHistoryPage({super.key});

  @override
  State<MyDoubtsHistoryPage> createState() => _MyDoubtsHistoryPageState();
}

class _MyDoubtsHistoryPageState extends State<MyDoubtsHistoryPage> {
  final _studentRepo = sl<StudentRepository>();
  bool _isLoading = true;
  List<Map<String, dynamic>> _doubts = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadDoubts();
  }

  Future<void> _loadDoubts() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final doubts = await _studentRepo.getMyDoubts();
      if (!mounted) return;
      setState(() {
        _doubts = doubts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Fallback for demo purposes if backend method not fully implemented in student repo
        _doubts = [];
        _error = 'Failed to load doubts network Error';
        _isLoading = false;
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
            const Positioned(top: -100, left: -50, child: SizedBox.shrink()),
            const Positioned(
              bottom: 200,
              right: -150,
              child: SizedBox.shrink(),
            ),
          ],
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppBar(context, isDark),
                Expanded(
                  child: _isLoading
                      ? _buildShimmer()
                      : _error.isNotEmpty && _doubts.isEmpty
                      ? Center(
                          child: Text(
                            _error,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                          ),
                        )
                      : _buildDoubtsList(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          context.push('/student/doubts/ask').then((_) => _loadDoubts());
        },
        backgroundColor: AppColors.electricBlue,
        icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
        label: Text(
          'Ask Doubt',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'My Doubts',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.deepNavy,
              letterSpacing: -1,
            ),
          ),
          CPPressable(
            onTap: _loadDoubts,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.05,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: isDark ? Colors.white : AppColors.deepNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => const CPShimmer(
        width: double.infinity,
        height: 120,
        borderRadius: 20,
      ),
    );
  }

  Widget _buildDoubtsList(bool isDark) {
    if (_doubts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.02,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 64,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No questions asked yet.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to ask a new doubt.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDoubts,
      color: AppColors.electricBlue,
      child: ListView.separated(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: 100,
        ),
        itemCount: _doubts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, i) {
          final doubt = _doubts[i];
          final question =
              (doubt['questionText'] ?? doubt['question_text'] ?? '')
                  .toString();
          final status = (doubt['status'] ?? 'pending')
              .toString()
              .toLowerCase();
          final dt = DateTime.tryParse(
            (doubt['createdAt'] ?? doubt['created_at'] ?? '').toString(),
          );
          final dateStr = dt != null
              ? DateFormat('MMM d, h:mm a').format(dt)
              : '—';

          final isResolved = status == 'resolved';
          final sColor = isResolved ? AppColors.success : AppColors.warning;
          final answer = doubt['answer_text'] ?? doubt['answerText'];

          return CPGlassCard(
                isDark: isDark,
                padding: const EdgeInsets.all(20),
                borderRadius: 24,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
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
                            color: sColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isResolved ? 'RESOLVED' : 'PENDING',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: sColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          dateStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      question,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.deepNavy,
                        height: 1.4,
                      ),
                    ),
                    if (isResolved && answer != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.reply_rounded,
                                  size: 14,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Instructor Reply',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.success,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              answer.toString(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              )
              .animate(delay: (40 * i).ms)
              .fadeIn(duration: 400.ms)
              .slideX(begin: 0.05);
        },
      ),
    );
  }
}
