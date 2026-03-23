import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/injection_container.dart';
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
    if (!mounted) return;
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
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);
    const yellow = Color(0xFFF0DE36);

    return Scaffold(
      backgroundColor: blue,
      appBar: AppBar(
        backgroundColor: blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('DAILY SCHEDULE', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1.2)),
      ),
      body: RefreshIndicator(
        color: yellow,
        backgroundColor: blue,
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: yellow))
            : _error != null
                ? _buildErrorState(blue, yellow)
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildWeekStrip(blue, surface, yellow),
                      const SizedBox(height: 32),
                      _buildSectionTitle('TODAY\'S CLASSES', yellow),
                      const SizedBox(height: 16),
                      if (_today.isEmpty)
                        _buildEmptyState(blue, surface)
                      else
                        ..._today.asMap().entries.map((entry) => _buildClassCard(entry.value, entry.key, blue, surface, yellow)),
                      const SizedBox(height: 40),
                      _buildAlertsCard(blue, surface, yellow),
                    ],
                  ),
      ),
    );
  }

  Widget _buildWeekStrip(Color blue, Color surface, Color yellow) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.add(Duration(days: i - now.weekday + 1)));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: Colors.black, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((d) {
          final isToday = d.day == now.day && d.month == now.month;
          return Column(
            children: [
              Text(_dayShort(d.weekday), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: blue.withValues(alpha: 0.5))),
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isToday ? yellow : Colors.transparent,
                  border: isToday ? Border.all(color: Colors.black, width: 2) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('${d.day}', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: blue)),
              ),
            ],
          );
        }).toList(),
      ),
    ).animate().fadeIn();
  }

  Widget _buildSectionTitle(String title, Color yellow) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: yellow),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildClassCard(Map<String, dynamic> item, int index, Color blue, Color surface, Color yellow) {
    final name = (item['name'] ?? item['batch_name'] ?? 'BATCH').toString().toUpperCase();
    final subject = (item['subject'] ?? 'SUBJECT').toString().toUpperCase();
    final start = (item['start_time'] ?? '--').toString();
    final end = (item['end_time'] ?? '--').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: Colors.black, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: yellow, border: Border.all(color: Colors.black, width: 2), borderRadius: BorderRadius.circular(8)),
            child: Text(start, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: blue)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: blue)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(subject, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w900, color: blue.withValues(alpha: 0.5))),
                    const SizedBox(width: 12),
                    Text('$start - $end', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: blue.withValues(alpha: 0.5))),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: blue, size: 20),
        ],
      ),
    ).animate(delay: (50 * index).ms).fadeIn().slideX(begin: 0.1);
  }

  Widget _buildAlertsCard(Color blue, Color surface, Color yellow) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), border: Border.all(color: Colors.white24, width: 2), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.notifications_active_rounded, color: yellow, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'REMAINDERS: ALL CLASSES FOR TODAY ARE ON TRACK. NO SUBSTITUTIONS ASSIGNED.',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.7), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color blue, Color surface) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: surface.withValues(alpha: 0.1), border: Border.all(color: Colors.white24, width: 2, style: BorderStyle.solid), borderRadius: BorderRadius.circular(16)),
      child: Center(child: Text('NO CLASSES SCHEDULED FOR TODAY', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1))),
    );
  }

  Widget _buildErrorState(Color blue, Color yellow) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline_rounded, color: Colors.white, size: 48),
      const SizedBox(height: 16),
      Text('FAILED TO LOAD SCHEDULE', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900)),
      const SizedBox(height: 24),
      _btn('RETRY', _load, yellow, blue),
    ]));
  }

  Widget _btn(String label, VoidCallback onTap, Color bg, Color fg) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(color: bg, border: Border.all(color: Colors.black, width: 2.5), borderRadius: BorderRadius.circular(8), boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(3, 3))]),
        child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: fg)),
      ),
    );
  }

  String _dayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'MON';
      case DateTime.tuesday: return 'TUE';
      case DateTime.wednesday: return 'WED';
      case DateTime.thursday: return 'THU';
      case DateTime.friday: return 'FRI';
      case DateTime.saturday: return 'SAT';
      default: return 'SUN';
    }
  }
}
