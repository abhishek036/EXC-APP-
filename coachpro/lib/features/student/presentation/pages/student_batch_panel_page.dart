import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';

class StudentBatchPanelPage extends StatelessWidget {
  final String batchId;
  final Map<String, dynamic> batchInfo;

  const StudentBatchPanelPage({
    super.key,
    required this.batchId,
    this.batchInfo = const {},
  });

  Widget _neoContainer({
    required Widget child,
    bool isDark = true,
    EdgeInsetsGeometry? padding,
    Color? bgColor,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor ?? (isDark ? AppColors.eliteDarkBg : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elitePrimary, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.elitePrimary, offset: Offset(3, 3)),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    final subject = batchInfo['subject'] ?? 'Subject';
    final name = batchInfo['name'] ?? 'Batch';
    final teacher = batchInfo['teacher_name'] ?? 'TBA';
    final time = '${batchInfo['start_time'] ?? ''} - ${batchInfo['end_time'] ?? ''}';

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.deepNavy),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Batch Overview',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.deepNavy,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            _neoContainer(
              isDark: isDark,
              bgColor: AppColors.moltenAmber,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.elitePrimary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      subject.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.elitePrimary,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.elitePrimary),
                      const SizedBox(width: 8),
                      Text(
                        teacher,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.elitePrimary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.schedule_rounded, size: 20, color: AppColors.elitePrimary),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.elitePrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'Batch Resources',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.deepNavy,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.95,
              children: [
                _actionCard(
                  context: context,
                  isDark: isDark,
                  title: 'Timetable',
                  subtitle: 'View schedule',
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFF5C7CFA),
                  route: '/student/timetable',
                ),
                _actionCard(
                  context: context,
                  isDark: isDark,
                  title: 'Study Material',
                  subtitle: 'Notes & PDFs',
                  icon: Icons.menu_book_rounded,
                  color: AppColors.moltenAmber,
                  route: '/student/materials', // Add extra routing args inside the page later if needed
                ),
                _actionCard(
                  context: context,
                  isDark: isDark,
                  title: 'Ask a Doubt',
                  subtitle: 'Get instant help',
                  icon: Icons.help_outline_rounded,
                  color: AppColors.coralRed,
                  route: '/student/doubts/ask', 
                  extra: {'batchId': batchId, 'subject': subject},
                ),
                _actionCard(
                  context: context,
                  isDark: isDark,
                  title: 'Quizzes',
                  subtitle: 'Test preparation',
                  icon: Icons.quiz_rounded,
                  color: AppColors.mintGreen,
                  route: '/student/quiz',
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Call to action or info
            _neoContainer(
              isDark: isDark,
              bgColor: AppColors.elitePrimary,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Keep up the good work!',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stay consistent with your daily classes.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
    Object? extra,
  }) {
    return CPPressable(
      onTap: () {
        context.push(route, extra: extra);
      },
      child: _neoContainer(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha((0.15 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.elitePrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
