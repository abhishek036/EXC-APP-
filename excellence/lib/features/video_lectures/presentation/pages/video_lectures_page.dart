import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/di/injection_container.dart';
import '../../../student/data/repositories/student_repository.dart';

class VideoLecturesPage extends StatefulWidget {
  const VideoLecturesPage({super.key});

  @override
  State<VideoLecturesPage> createState() => _VideoLecturesPageState();
}

class _VideoLecturesPageState extends State<VideoLecturesPage> {
  String _selectedSubject = 'All';
  String _sortBy = 'Recent';

  List<Map<String, dynamic>> _lectures = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLectures();
  }

  Future<void> _fetchLectures() async {
    try {
      final repo = sl<StudentRepository>();
      // Fetch lectures and progress in parallel
      final results = await Future.wait([
        repo.getLectures(),
        repo.getLectureProgress().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final data = results[0];
      final progressList = results[1];

      // Build a progress lookup map by lecture_id
      final progressMap = <String, Map<String, dynamic>>{};
      for (final p in progressList) {
        final lid = p['lecture_id']?.toString() ?? '';
        if (lid.isNotEmpty) progressMap[lid] = p;
      }

      if (!mounted) return;

      setState(() {
         _lectures = data.map((e) {
            final lid = e['id']?.toString() ?? '';
            final progress = progressMap[lid];
            final watchedSec = (progress?['watched_sec'] as int?) ?? 0;
            final isCompleted = (progress?['is_completed'] as bool?) ?? false;
            final lastPosition = (progress?['last_position'] as int?) ?? 0;

            return {
               'id': lid,
               'title': e['title'] ?? 'Recordings',
               'subject': e['subject'] ?? 'General',
               'chapter': e['description'] ?? 'Theory Class',
               'teacher': e['teacher_name'] ?? 'Class Teacher',
               'duration': '${e['duration_minutes'] ?? 60}m',
               'durationSec': ((e['duration_minutes'] as int?) ?? 60) * 60,
               'watchedSec': watchedSec,
               'lastPosition': lastPosition,
               'uploadDate': e['created_at'] != null ? DateFormat('d MMM yyyy').format(DateTime.parse(e['created_at'])) : 'Unknown',
               'views': 0,
               'isCompleted': isCompleted,
               'link': e['link']
            };
         }).toList();
         _isLoading = false;
      });
    } catch(e) {
      if (!mounted) return;
      setState(() {
         _error = e.toString();
         _isLoading = false;
      });
    }
  }

  List<String> get _subjects {
     final set = {'All'};
     for (final l in _lectures) {
       final sub = l['subject']?.toString().trim();
       if (sub != null && sub.isNotEmpty) set.add(sub);
     }
     return set.toList();
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _selectedSubject == 'All'
        ? _lectures
        : _lectures.where((l) => l['subject'] == _selectedSubject).toList();

    switch (_sortBy) {
      case 'Recent':
        break; // Already sorted by date
      case 'Most Viewed':
        list = List.from(list)..sort((a, b) => (b['views'] as int).compareTo(a['views'] as int));
        break;
      case 'In Progress':
        list = List.from(list)..sort((a, b) {
          final aProgress = (a['watchedSec'] as int) > 0 && !(a['isCompleted'] as bool) ? 1 : 0;
          final bProgress = (b['watchedSec'] as int) > 0 && !(b['isCompleted'] as bool) ? 1 : 0;
          return bProgress.compareTo(aProgress);
        });
        break;
    }
    return list;
  }

  // Stats
  int get _totalLectures => _lectures.length;
  int get _completedCount => _lectures.where((l) => l['isCompleted'] == true).length;
  int get _inProgressCount => _lectures.where((l) => (l['watchedSec'] as int) > 0 && !(l['isCompleted'] as bool)).length;
  double get _overallProgress {
    final totalSec = _lectures.fold(0, (sum, l) => sum + (l['durationSec'] as int));
    final watchedSec = _lectures.fold(0, (sum, l) => sum + (l['watchedSec'] as int));
    return totalSec > 0 ? watchedSec / totalSec : 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    final accent = CT.accent(context);

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        title: Text('Video Lectures',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: CT.textH(context))),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort_rounded, color: CT.textS(context)),
            color: CT.card(context),
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => ['Recent', 'Most Viewed', 'In Progress'].map((s) {
              return PopupMenuItem(
                value: s,
                child: Row(children: [
                  if (_sortBy == s) Icon(Icons.check_rounded, size: 18, color: accent),
                  if (_sortBy == s) const SizedBox(width: 8),
                  Text(s, style: GoogleFonts.plusJakartaSans(color: CT.textH(context))),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
      body: _isLoading 
         ? const Center(child: CircularProgressIndicator()) 
         : _error != null 
             ? Center(child: Text(_error!, style: GoogleFonts.plusJakartaSans(color: Colors.red)))
             : _lectures.isEmpty
                 ? Center(child: Text('No recorded lectures found.', style: GoogleFonts.plusJakartaSans(color: CT.textS(context))))
                 : CustomScrollView(
        slivers: [
          // Progress overview
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, 0, AppDimensions.pagePaddingH, AppDimensions.md),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.05)]),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                ),
                child: Column(children: [
                  Row(children: [
                    // Progress ring
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: Stack(alignment: Alignment.center, children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: _overallProgress,
                            strokeWidth: 5,
                            backgroundColor: CT.border(context),
                            valueColor: AlwaysStoppedAnimation(accent),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text('${(_overallProgress * 100).toInt()}%',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: accent)),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Your Progress',
                            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: CT.textH(context))),
                        const SizedBox(height: 4),
                        Text('$_completedCount completed · $_inProgressCount in progress · $_totalLectures total',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: CT.textS(context))),
                      ]),
                    ),
                  ]),
                ]),
              ).animate().fadeIn(duration: 400.ms),
            ),
          ),

          // Continue watching section
          if (_inProgressCount > 0) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, 0, AppDimensions.pagePaddingH, AppDimensions.sm),
                child: Text('Continue Watching',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: CT.textH(context))),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
                  children: _lectures
                      .where((l) => (l['watchedSec'] as int) > 0 && !(l['isCompleted'] as bool))
                      .map((l) => _buildContinueCard(l, accent))
                      .toList(),
                ),
              ).animate().fadeIn(delay: 200.ms),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.lg)),
          ],

          // Subject filter chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
                children: _subjects.map((s) {
                  final isActive = _selectedSubject == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CPPressable(
                      onTap: () => setState(() => _selectedSubject = s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? accent : CT.card(context),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          border: Border.all(color: isActive ? accent : CT.border(context)),
                        ),
                        child: Text(s,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: isActive ? Colors.white : CT.textS(context))),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.md)),

          // All lectures list
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
              child: Text('All Lectures (${_filtered.length})',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: CT.textH(context))),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final lecture = _filtered[index];
                  return _buildLectureCard(lecture, accent, isDark)
                      .animate()
                      .fadeIn(delay: (60 * index).ms, duration: 300.ms);
                },
                childCount: _filtered.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String? url) async {
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video link not available.')));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open link: $url')));
    }
  }

  Widget _buildContinueCard(Map<String, dynamic> lecture, Color accent) {
    final progress = (lecture['watchedSec'] as int) / (lecture['durationSec'] as int);
    final watchedMin = ((lecture['watchedSec'] as int) / 60).round();
    final totalMin = ((lecture['durationSec'] as int) / 60).round();

    return CPPressable(
      onTap: () => _launchURL(lecture['link']?.toString()),
      child: Container(
        width: 260,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: CT.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail + play overlay
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: _getSubjectColor(lecture['subject'] as String).withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusMD)),
            ),
            child: Stack(children: [
              Center(
                child: Icon(Icons.play_circle_filled_rounded, size: 44, color: accent.withValues(alpha: 0.8)),
              ),
              // Progress bar at bottom
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.black.withValues(alpha: 0.26),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ),
              // Duration badge
              Positioned(
                right: 8, bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${watchedMin}m / ${totalMin}m',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lecture['title'] as String,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: CT.textH(context))),
              const SizedBox(height: 4),
              Text('${lecture['teacher']} · ${lecture['subject']}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textS(context))),
            ]),
          ),
        ],
      ),
    ));
  }

  Widget _buildLectureCard(Map<String, dynamic> lecture, Color accent, bool isDark) {
    final progress = (lecture['durationSec'] as int) > 0
        ? (lecture['watchedSec'] as int) / (lecture['durationSec'] as int)
        : 0.0;
    final isCompleted = lecture['isCompleted'] as bool;
    final isStarted = (lecture['watchedSec'] as int) > 0;

    return CPPressable(
      onTap: () => _launchURL(lecture['link']?.toString()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        border: Border.all(color: isCompleted ? Colors.green.withValues(alpha: 0.3) : CT.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: _getSubjectColor(lecture['subject'] as String).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(alignment: Alignment.center, children: [
              Icon(
                isCompleted ? Icons.check_circle_rounded : Icons.play_circle_filled_rounded,
                size: 28,
                color: isCompleted ? Colors.green : accent,
              ),
              if (isStarted && !isCompleted)
                Positioned(
                  bottom: 4, left: 4, right: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: Colors.black.withValues(alpha: 0.26),
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getSubjectColor(lecture['subject'] as String).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(lecture['subject'] as String,
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600,
                          color: _getSubjectColor(lecture['subject'] as String))),
                ),
                if (isCompleted) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified_rounded, size: 14, color: Colors.green.shade400),
                  const SizedBox(width: 2),
                  Text('Completed', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.shade400)),
                ],
              ]),
              const SizedBox(height: 4),
              Text(lecture['title'] as String,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
              const SizedBox(height: 4),
              Text('${lecture['teacher']} · ${lecture['chapter']} · ${lecture['duration']}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: CT.textS(context))),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.visibility_rounded, size: 13, color: CT.textM(context)),
                const SizedBox(width: 3),
                Text('${lecture['views']}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textM(context))),
                const SizedBox(width: 10),
                Icon(Icons.calendar_today_rounded, size: 13, color: CT.textM(context)),
                const SizedBox(width: 3),
                Text(lecture['uploadDate'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textM(context))),
                if (isStarted && !isCompleted) ...[
                  const Spacer(),
                  Text('${(progress * 100).toInt()}%',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
                ],
              ]),
            ]),
          ),
        ],
      ),
    ));
  }

  Color _getSubjectColor(String subject) {
    switch (subject) {
      case 'Physics': return Colors.blue;
      case 'Chemistry': return Colors.orange;
      case 'Mathematics': return Colors.purple;
      case 'Biology': return Colors.green;
      default: return Colors.grey;
    }
  }
}
