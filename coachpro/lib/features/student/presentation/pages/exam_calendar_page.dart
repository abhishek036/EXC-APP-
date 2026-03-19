import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';

class ExamCalendarPage extends StatefulWidget {
  const ExamCalendarPage({super.key});

  @override
  State<ExamCalendarPage> createState() => _ExamCalendarPageState();
}

class _ExamCalendarPageState extends State<ExamCalendarPage> {
  int _selectedMonth = 2; // March (0-indexed in our data)
  final _months = ['January', 'February', 'March', 'April', 'May', 'June'];

  final _exams = [
    _ExamEvent('Physics Weekly Test', 'Ch: Thermodynamics', '5 Mar', '10:00 AM', 30, AppColors.physics),
    _ExamEvent('Chemistry Unit Test', 'Ch: Organic I', '8 Mar', '11:00 AM', 45, AppColors.chemistry),
    _ExamEvent('Mathematics Mid-Term', 'Full Syllabus', '12 Mar', '9:00 AM', 90, AppColors.mathematics),
    _ExamEvent('English Assessment', 'Grammar + Comprehension', '15 Mar', '2:00 PM', 45, AppColors.english),
    _ExamEvent('Biology Chapter Test', 'Ch: Genetics', '20 Mar', '10:00 AM', 30, AppColors.biology),
    _ExamEvent('Physics Practice Test', 'Ch: Waves', '25 Mar', '11:00 AM', 30, AppColors.physics),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text('Exam Calendar', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined)),
        ],
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          _buildExamCount(),
          Expanded(child: _buildExamTimeline()),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _months.length,
      separatorBuilder: (_, i) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final isActive = _selectedMonth == i;
        return CPPressable(
          onTap: () => setState(() => _selectedMonth = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isActive ? AppColors.electricBlue : CT.card(context),
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              border: Border.all(color: isActive ? AppColors.electricBlue : CT.border(context)),
              boxShadow: isActive ? [BoxShadow(color: AppColors.electricBlue.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
            ),
            child: Center(child: Text(
              _months[i],
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.white : CT.textS(context)),
            )),
          ),
        );
      },
    ),
  ).animate().fadeIn();

  Widget _buildExamCount() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      RichText(text: TextSpan(children: [
        TextSpan(text: '${_exams.length} exams ', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
        TextSpan(text: 'in ${_months[_selectedMonth]}', style: GoogleFonts.dmSans(fontSize: 14, color: CT.textS(context))),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppColors.moltenAmber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          const Icon(Icons.timer_outlined, size: 14, color: AppColors.moltenAmber),
          const SizedBox(width: 4),
          Text('Next in 2 days', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.moltenAmber)),
        ]),
      ),
    ]),
  ).animate(delay: 100.ms).fadeIn();

  Widget _buildExamTimeline() => ListView.builder(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    itemCount: _exams.length,
    itemBuilder: (ctx, i) => _buildTimelineCard(_exams[i], i, i == _exams.length - 1),
  );

  Widget _buildTimelineCard(_ExamEvent exam, int index, bool isLast) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline column
        SizedBox(
          width: 52,
          child: Column(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: exam.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: exam.color, width: 2),
              ),
              child: Center(child: Text(
                exam.date.split(' ')[0],
                style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: exam.color),
              )),
            ),
            if (!isLast)
              Expanded(child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: CT.border(context),
              )),
          ]),
        ),
        const SizedBox(width: 12),
        // Card
        Expanded(child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: CT.cardDecor(context, radius: AppDimensions.radiusMD),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exam.name, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
            const SizedBox(height: 4),
            Text(exam.syllabus, style: GoogleFonts.dmSans(fontSize: 12, color: CT.textS(context))),
            const SizedBox(height: 10),
            Row(children: [
              _chipInfo(Icons.access_time_outlined, exam.time),
              const SizedBox(width: 14),
              _chipInfo(Icons.timer_outlined, '${exam.durationMin} min'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: exam.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                child: Text('Set Reminder', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: exam.color)),
              ),
            ]),
          ]),
        )),
      ],
    ),
  ).animate(delay: Duration(milliseconds: 200 + index * 80)).fadeIn().slideX(begin: 0.08, end: 0);

  Widget _chipInfo(IconData icon, String text) => Row(children: [
    Icon(icon, size: 13, color: CT.textM(context)),
    const SizedBox(width: 4),
    Text(text, style: GoogleFonts.dmSans(fontSize: 11, color: CT.textS(context))),
  ]);
}

class _ExamEvent {
  final String name, syllabus, date, time;
  final int durationMin;
  final Color color;
  _ExamEvent(this.name, this.syllabus, this.date, this.time, this.durationMin, this.color);
}
