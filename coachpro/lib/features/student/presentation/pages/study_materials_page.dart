import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../data/repositories/student_repository.dart';

class StudyMaterialsPage extends StatefulWidget {
  const StudyMaterialsPage({super.key});

  @override
  State<StudyMaterialsPage> createState() => _StudyMaterialsPageState();
}

class _StudyMaterialsPageState extends State<StudyMaterialsPage> {
  int _selectedType = 0;
  int _selectedSubject = 0;
  final _studentRepo = sl<StudentRepository>();
  late Future<List<_Material>> _materialsFuture;

  final _types = ['Notes', 'Videos'];
  final _subjects = ['Recent', 'Physics', 'Chemistry', 'Mathematics'];

  List<Map<String, dynamic>> _batches = [];
  String? _selectedBatchId;
  String _selectedBatchName = 'All Batches';

  @override
  void initState() {
    super.initState();
    _materialsFuture = Future.value([]); // init eagerly
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final batches = await _studentRepo.getMyBatches();
      if (mounted) {
        setState(() {
          _batches = batches;
        });
      }
    } catch (_) {}
    
    if (mounted) {
      setState(() {
        _materialsFuture = _loadMaterials();
      });
    }
  }

  Future<List<_Material>> _loadMaterials() async {
    final notes = await _studentRepo.getStudyMaterials(batchId: _selectedBatchId);

    final noteMaterials = notes
        .map(
          (note) => _Material.fromMap({
            'title': note['title'],
            'subject': note['subject'],
            'teacherName': 'Teacher',
            'meta': note['file_size_kb'] != null
                ? '${note['file_size_kb']} KB'
                : '',
            'type': (note['type'] ?? note['file_type'] ?? 'pdf').toString().toLowerCase(),
            'url': note['file_url'],
          }),
        )
        .toList();

    return noteMaterials;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text(
          'Study Materials',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedBatchName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
              ],
            ),
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              HapticFeedback.selectionClick();
              setState(() {
                if (val == 'all') {
                  _selectedBatchId = null;
                  _selectedBatchName = 'All Batches';
                } else {
                  _selectedBatchId = val;
                  final b = _batches.firstWhere((e) => (e['id'] ?? '').toString() == val, orElse: () => {});
                  _selectedBatchName = (b['name'] ?? 'Batch').toString();
                }
                _materialsFuture = _loadMaterials();
              });
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem(
                  value: 'all',
                  child: Text('All Batches', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                ),
                ..._batches.map((b) {
                  final name = (b['name'] ?? 'Batch').toString();
                  return PopupMenuItem(
                    value: (b['id'] ?? '').toString(),
                    child: Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  );
                }),
              ];
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: CT.textM(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: List.generate(
                  _types.length,
                  (i) => Expanded(
                    child: CPPressable(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedType = i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _selectedType == i
                              ? CT.bg(context)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedType == i
                              ? [
                                  BoxShadow(
                                    color: CT
                                        .textH(context)
                                        .withValues(alpha: 0.05),
                                    blurRadius: 0,
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            _types[i],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: _selectedType == i
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: _selectedType == i
                                  ? CT.textH(context)
                                  : CT.textS(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),
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
                  setState(() => _selectedSubject = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: _selectedSubject == i
                        ? AppColors.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: _selectedSubject == i
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
                        color: _selectedSubject == i
                            ? Colors.white
                            : CT.textS(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<_Material>>(
              future: _materialsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load materials',
                      style: GoogleFonts.plusJakartaSans(
                        color: CT.textS(context),
                      ),
                    ),
                  );
                }

                final materials = snapshot.data ?? const [];

                final selectedType = _types[_selectedType].toLowerCase();
                final selectedSubject = _selectedSubject == 0
                    ? null
                    : _subjects[_selectedSubject].toLowerCase();

                final filtered = materials.where((item) {
                    final typeMatch = selectedType == 'notes'
                      ? item.type != 'assignment' && item.type != 'video' && item.type != 'link'
                      : item.type == 'video' || item.type == 'link';

                  final subjectMatch =
                      selectedSubject == null ||
                      item.subject.toLowerCase() == selectedSubject;
                  return typeMatch && subjectMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No materials available',
                      style: GoogleFonts.plusJakartaSans(
                        color: CT.textS(context),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                    vertical: 8,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _buildMaterialCard(filtered[i], i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(_Material material, int index) {
    return CPPressable(
          onTap: () {
            if (material.type == 'video' || material.type == 'link') {
              context.push('/student/youtube-player', extra: {
                'videoId': material.url,
                'title': material.title,
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: CT.cardDecor(context),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: material.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    material.type == 'video'
                        ? Icons.play_circle_fill
                        : material.type == 'assignment'
                        ? Icons.assignment
                        : Icons.picture_as_pdf,
                    color: material.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: CT.textH(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${material.subject} • ${material.teacher}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: CT.textM(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        material.meta,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: CT.textM(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final url = material.url;
                    if (url.isNotEmpty) {
                      final uri = Uri.tryParse(url);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                        return;
                      }
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('No valid URL for ${material.title}'),
                        backgroundColor: AppColors.error,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.file_download_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  style: IconButton.styleFrom(backgroundColor: CT.bg(context)),
                ),
              ],
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: 100 * index))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.05, end: 0);
  }
}

class _Material {
  final String title;
  final String subject;
  final String teacher;
  final String meta;
  final String type;
  final String url;
  final Color color;

  const _Material({
    required this.title,
    required this.subject,
    required this.teacher,
    required this.meta,
    required this.type,
    required this.url,
    required this.color,
  });

  factory _Material.fromMap(Map<String, dynamic> map) {
    final subject = (map['subject'] ?? 'General').toString();
    Color color;
    switch (subject.toLowerCase()) {
      case 'physics':
        color = AppColors.physics;
        break;
      case 'chemistry':
        color = AppColors.chemistry;
        break;
      case 'mathematics':
        color = AppColors.mathematics;
        break;
      default:
        color = AppColors.accent;
    }

    return _Material(
      title: (map['title'] ?? 'Untitled Material').toString(),
      subject: subject,
      teacher: (map['teacherName'] ?? 'Teacher').toString(),
      meta: (map['meta'] ?? map['size'] ?? '').toString(),
      type: (map['type'] ?? 'pdf').toString().toLowerCase(),
      url: (map['url'] ?? '').toString(),
      color: color,
    );
  }
}
