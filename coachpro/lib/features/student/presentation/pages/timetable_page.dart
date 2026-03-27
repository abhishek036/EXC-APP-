import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/student_repository.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  final _studentRepo = sl<StudentRepository>();
  List<Map<String, dynamic>> _todaySchedule = [];
  bool _isLoading = true;
  String? _error;

  final _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // For now, the backend provides "today" schedule.
      // In a real prod app, you'd pass a date or day index.
      final data = await _studentRepo.getDashboardStats();
      setState(() {
        _todaySchedule = data['batches'] as List<Map<String, dynamic>>? ?? [];
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSchedule,
          child: Column(
            children: [
              _buildHeader(),
              _buildDaySelector(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? _buildErrorState()
                    : _buildScheduleList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppDimensions.pagePaddingH,
      AppDimensions.md,
      AppDimensions.pagePaddingH,
      AppDimensions.sm,
    ),
    child: Row(
      children: [
        CPPressable(
          onTap: () =>
              context.canPop() ? context.pop() : context.go('/student'),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.step),
            decoration: CT.cardDecor(context, radius: AppDimensions.radiusSM),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: CT.textH(context),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Timetable',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: CT.textH(context),
                ),
              ),
              Text(
                'Live Daily Schedule',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: CT.textS(context),
                ),
              ),
            ],
          ),
        ),
        if (!_isLoading && _todaySchedule.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.electricBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
            child: Text(
              '${_todaySchedule.length} classes',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.electricBlue,
              ),
            ),
          ),
      ],
    ),
  ).animate().fadeIn(duration: 400.ms);

  Widget _buildDaySelector() {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: CT.card(context),
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          boxShadow: [
            BoxShadow(
              color: CT.textH(context).withValues(alpha: 0.04),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: List.generate(7, (i) {
            final isSelected =
                i == todayIndex; // For now we only show today's real data
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.electricBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                alignment: Alignment.center,
                child: Text(
                  _days[i],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : CT.textS(context),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ).animate(delay: 100.ms).fadeIn();
  }

  Widget _buildScheduleList() {
    if (_todaySchedule.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.weekend_outlined, size: 60, color: CT.textM(context)),
            const SizedBox(height: 12),
            Text(
              'No classes for today!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CT.textS(context),
              ),
            ),
            Text(
              'Enjoy your day off 🎉',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: CT.textM(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _todaySchedule.length,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final cls = _todaySchedule[index];
        return _buildClassCard(cls, index);
      },
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls, int index) {
    final subject = cls['subject'] ?? 'Subject';
    final startTime = cls['start_time'] ?? '00:00';
    final endTime = cls['end_time'] ?? '00:00';
    final teacher = cls['teacher_name'] ?? 'TBA';
    final batch = cls['name'] ?? 'Batch';
    final room = cls['room'] ?? 'Online';

    Color c = AppColors.elitePrimary;
    if (subject.toLowerCase().contains('physics')) {
      c = AppColors.physics;
    } else if (subject.toLowerCase().contains('chemistry')) {
      c = AppColors.chemistry;
    } else if (subject.toLowerCase().contains('math')) {
      c = AppColors.mathematics;
    }

    return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CPPressable(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 55,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        startTime,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CT.textH(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 2,
                        height: 30,
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        endTime,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: CT.textM(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CT.card(context),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMD,
                      ),
                      border: Border(left: BorderSide(color: c, width: 4)),
                      boxShadow: [
                        BoxShadow(
                          color: CT.textH(context).withValues(alpha: 0.04),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              subject,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: CT.textH(context),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                room,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: c,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          teacher,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: CT.textS(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          batch,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: CT.textM(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: 200 + index * 80))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.1, end: 0);
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load schedule',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              color: CT.textH(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: GoogleFonts.plusJakartaSans(color: CT.textM(context)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadSchedule, child: const Text('Retry')),
        ],
      ),
    );
  }
}
