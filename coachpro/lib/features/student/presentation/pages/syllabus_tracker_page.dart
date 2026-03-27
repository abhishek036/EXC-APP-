import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';

class SyllabusTrackerPage extends StatefulWidget {
  const SyllabusTrackerPage({super.key});
  @override
  State<SyllabusTrackerPage> createState() => _SyllabusTrackerPageState();
}

class _SyllabusTrackerPageState extends State<SyllabusTrackerPage> {
  int _selectedSub = 0;
  final _subjects = ['Physics', 'Chemistry', 'Mathematics'];

  final _physicsChapters = [
    _Chapter('Kinematics', 1.0, 0),
    _Chapter('Laws of Motion', 0.8, 2),
    _Chapter('Work, Energy, Power', 0.5, 5),
    _Chapter('Rotational Motion', 0.0, 12),
    _Chapter('Gravitation', 0.0, 8),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text(
          'Syllabus Tracker',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        actions: [IconButton(onPressed: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedSub = (_selectedSub + 1) % _subjects.length);
      }, icon: const Icon(Icons.swap_horiz_rounded))],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Progress Card
          Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1282),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: 0.65,
                          color: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                        ),
                        Center(
                          child: Text(
                            '65%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Progress',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You are on track to complete the syllabus by Nov 2026.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 500.ms),

          // Subject filter chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.pagePaddingH,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: _subjects.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => CPPressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedSub = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: _selectedSub == i
                        ? AppColors.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: _selectedSub == i
                          ? AppColors.primary
                          : CT.textM(context),
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Center(
                    child: Text(
                      _subjects[i],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _selectedSub == i
                            ? Colors.white
                            : CT.textS(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Chapter list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.pagePaddingH,
                vertical: 8,
              ),
              itemCount: _physicsChapters.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _buildChapterCard(_physicsChapters[i], i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(_Chapter c, int i) {
    final color = c.progress == 1.0
        ? AppColors.success
        : c.progress > 0
        ? AppColors.primary
        : CT.textM(context);
    return Container(
          padding: const EdgeInsets.all(16),
          decoration: CT.cardDecor(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      c.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (c.progress == 1.0)
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20,
                    )
                  else
                    Text(
                      '${(c.progress * 100).toInt()}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: c.progress == 0 ? null : c.progress,
                  child: c.progress == 0
                      ? const SizedBox()
                      : Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                c.progress == 1.0
                    ? 'Completed'
                    : c.progress == 0.0
                    ? 'Not started'
                    : '${c.topicsLeft} topics left',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: CT.textS(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: 100 * i))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.05, end: 0);
  }
}

class _Chapter {
  final String title;
  final double progress;
  final int topicsLeft;
  _Chapter(this.title, this.progress, this.topicsLeft);
}
