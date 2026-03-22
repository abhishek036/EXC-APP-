import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../data/repositories/teacher_repository.dart';

class TeacherSchedulePage extends StatefulWidget {
  const TeacherSchedulePage({super.key});

  @override
  State<TeacherSchedulePage> createState() => _TeacherSchedulePageState();
}

class _TeacherSchedulePageState extends State<TeacherSchedulePage> {
  final _repo = sl<TeacherRepository>();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _today = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final today = await _repo.getTodaySchedule();
      if (!mounted) return;
      setState(() {
        _today = today;
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
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text('Schedule', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(child: Text('Failed to load schedule', style: GoogleFonts.sora(color: CT.textH(context)))),
                      const SizedBox(height: 8),
                      Center(child: Text(_error!, style: GoogleFonts.dmSans(color: CT.textM(context)))),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
                    children: [
                      _weekStrip(),
                      const SizedBox(height: 16),
                      _alertsCard(),
                      const SizedBox(height: 16),
                      Text('Today\'s Classes', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
                      const SizedBox(height: 10),
                      if (_today.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: CT.cardDecor(context),
                          child: Text('No classes scheduled today', style: GoogleFonts.dmSans(color: CT.textM(context))),
                        )
                      else
                        ..._today.asMap().entries.map((entry) {
                          return _classCard(entry.value, entry.key);
                        }),
                    ],
                  ),
      ),
    );
  }

  Widget _weekStrip() {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.add(Duration(days: i - now.weekday + 1)));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: CT.cardDecor(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((d) {
          final selected = d.day == now.day && d.month == now.month;
          return Container(
            width: 36,
            height: 50,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF0D1282) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF0D1282).withValues(alpha: selected ? 0 : 0.15)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_dayShort(d.weekday), style: GoogleFonts.dmSans(fontSize: 10, color: selected ? const Color(0xFFEEEDED) : CT.textM(context))),
                const SizedBox(height: 2),
                Text('${d.day}', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? const Color(0xFFEEEDED) : CT.textH(context))),
              ],
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _alertsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0DE36).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0DE36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Substitution & Reminder Alerts', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
          const SizedBox(height: 6),
          Text('• No substitutions for today\n• Next class reminder will trigger 15 minutes before start', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textH(context))),
        ],
      ),
    ).animate(delay: 80.ms).fadeIn(duration: 300.ms);
  }

  Widget _classCard(Map<String, dynamic> item, int index) {
    final name = (item['name'] ?? item['batch_name'] ?? 'Batch').toString();
    final subject = (item['subject'] ?? 'Subject').toString();
    final start = (item['start_time'] ?? '--').toString();
    final end = (item['end_time'] ?? '--').toString();
    final room = (item['room'] ?? 'Online').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: CT.cardDecor(context),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1282).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(start, textAlign: TextAlign.center, style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282)))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
                const SizedBox(height: 2),
                Text(subject, style: GoogleFonts.dmSans(color: CT.textM(context))),
                const SizedBox(height: 2),
                Text('$start - $end • $room', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textS(context))),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: 60 * index)).fadeIn(duration: 240.ms).slideY(begin: 0.04);
  }

  String _dayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      default:
        return 'Sun';
    }
  }
}
