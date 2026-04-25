import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/di/injection_container.dart';
import '../../../student/data/repositories/student_repository.dart';

class LiveSessionPage extends StatefulWidget {
  const LiveSessionPage({super.key});

  @override
  State<LiveSessionPage> createState() => _LiveSessionPageState();
}

class _LiveSessionPageState extends State<LiveSessionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final _repo = sl<StudentRepository>();

  bool _isLoading = true;
  List<Map<String, dynamic>> _liveSessions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _fetchLiveSessions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveSessions() async {
    try {
      final data = await _repo.getActiveLiveSessions();
      if (!mounted) return;
      setState(() {
        _liveSessions = data;
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

  void _launchSession(Map<String, dynamic> session) {
    final link = (session['link'] ?? '').toString();
    if (link.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No stream link available yet. The teacher may still be setting up.'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
      return;
    }
    
    // Determine the correct route prefix based on current location
    final location = GoRouterState.of(context).uri.toString();
    String routePrefix = '/student';
    if (location.startsWith('/teacher')) {
      routePrefix = '/teacher';
    } else if (location.startsWith('/admin')) {
      routePrefix = '/admin';
    } else if (location.startsWith('/parent')) {
      routePrefix = '/parent';
    }
    
    GoRouter.of(context).push(
      '$routePrefix/video-player',
      extra: {
        'videoUrl': link,
        'title': session['title']?.toString() ?? 'Live Class',
        'lectureId': session['id']?.toString() ?? '',
        'summary': '',
        'teacherName': session['teacher_name']?.toString() ?? 'Teacher',
        'subject': session['subject']?.toString() ?? '',
        'isLive': true,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        leading: const BackButton(),
        title: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.coralRed.withValues(
                      alpha: 0.5 + _pulseController.value * 0.5,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.coralRed.withValues(
                          alpha: 0.3 * _pulseController.value,
                        ),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            Text(
              'Live Sessions',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: CT.textH(context),
              ),
            ),
          ],
        ),
        actions: [
          CPPressable(
            onTap: () {
              HapticFeedback.mediumImpact();
              setState(() => _isLoading = true);
              _fetchLiveSessions();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: CT.textH(context),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _liveSessions.isEmpty
                  ? _buildEmptyState(isDark)
                  : _buildSessionsList(isDark),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.coralRed),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.coralRed),
            const SizedBox(height: 16),
            Text(
              'Unable to load live sessions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CT.textH(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: CT.textM(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CPPressable(
              onTap: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchLiveSessions();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.elitePrimary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                  ],
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.coralRed.withValues(alpha: 0.1)
                    : AppColors.coralRed.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.coralRed.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.live_tv_rounded,
                size: 48,
                color: AppColors.coralRed.withValues(alpha: 0.6),
              ),
            ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              'No Live Sessions Right Now',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: CT.textH(context),
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 8),
            Text(
              'When your teacher starts a live class, it will appear here. Pull down to refresh.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: CT.textM(context),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 32),
            CPPressable(
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() => _isLoading = true);
                _fetchLiveSessions();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.moltenAmber,
                  border: Border.all(color: AppColors.elitePrimary, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.elitePrimary,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 18, color: AppColors.elitePrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Refresh',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.elitePrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _fetchLiveSessions,
      color: AppColors.coralRed,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        itemCount: _liveSessions.length,
        itemBuilder: (context, index) {
          final session = _liveSessions[index];
          return _buildSessionCard(session, isDark, index)
              .animate(delay: Duration(milliseconds: 100 * index))
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.05);
        },
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session, bool isDark, int index) {
    final title = session['title']?.toString() ?? 'Live Class';
    final subject = session['subject']?.toString() ?? '';
    final teacherName = session['teacher_name']?.toString() ?? 'Teacher';
    final batchName = session['batch_name']?.toString() ?? '';
    final link = session['link']?.toString();
    final scheduledAt = session['scheduled_at'] != null
        ? DateTime.tryParse(session['scheduled_at'].toString())
        : null;
    final timeStr = scheduledAt != null
        ? DateFormat('hh:mm a').format(scheduledAt.toLocal())
        : 'Now';

    final isActive = link != null && link.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.coralRed : CT.border(context),
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.coralRed.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                const BoxShadow(
                  color: AppColors.elitePrimary,
                  offset: Offset(3, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with LIVE badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.coralRed.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                if (isActive) ...[
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.coralRed,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.black, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.coralRed.withValues(
                                alpha: 0.4 * _pulseController.value,
                              ),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'LIVE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.moltenAmber,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Text(
                      'SCHEDULED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                const Spacer(),
                Icon(Icons.access_time_rounded, size: 14, color: CT.textM(context)),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CT.textM(context),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: CT.textH(context),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subject.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subject,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.elitePrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.elitePrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 14,
                        color: AppColors.elitePrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        teacherName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CT.textS(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (batchName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBorder.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          batchName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CT.textM(context),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // Join button
                SizedBox(
                  width: double.infinity,
                  child: CPPressable(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _launchSession(session);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.coralRed : AppColors.elitePrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive ? Colors.black : AppColors.elitePrimary.withValues(alpha: 0.3),
                          width: isActive ? 2 : 1,
                        ),
                        boxShadow: isActive
                            ? const [BoxShadow(color: Colors.black, offset: Offset(2, 2))]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isActive ? Icons.play_circle_filled : Icons.schedule_rounded,
                            size: 20,
                            color: isActive ? Colors.white : AppColors.elitePrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isActive ? 'Join Live Class' : 'Waiting for teacher...',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isActive ? Colors.white : AppColors.elitePrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
