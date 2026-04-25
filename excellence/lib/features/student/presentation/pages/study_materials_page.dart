import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/download_registry.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/utils/file_opener.dart';
import '../../../../core/utils/stable_token.dart';
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
  bool _bookmarksOnly = false;
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
    DownloadRegistry.instance.ensureLoaded();
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
    final notes = _bookmarksOnly
        ? await _studentRepo.getBookmarkedStudyMaterials(
            batchId: _selectedBatchId,
          )
        : await _studentRepo.getStudyMaterials(
            batchId: _selectedBatchId,
          );

    final noteMaterials = notes
        .map((note) {
          final noteFilesRaw = note['note_files'];
          final noteFiles = noteFilesRaw is List
              ? noteFilesRaw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[];

          final primaryRaw = note['primary_file'];
          final primary = primaryRaw is Map
              ? Map<String, dynamic>.from(primaryRaw)
              : (noteFiles.isNotEmpty ? noteFiles.first : <String, dynamic>{});

          final fileType =
              (primary['file_type'] ?? note['file_type'] ?? 'pdf').toString().toLowerCase();
          final sizeKb = primary['file_size_kb'] ?? note['file_size_kb'];
          final chapterTitle = (note['chapter_title'] ?? 'General').toString();
          final downloadCount = note['downloads_count'] ?? note['download_count'] ?? 0;
          final metaParts = <String>[
            if (chapterTitle.trim().isNotEmpty) 'Chapter: $chapterTitle',
            if (sizeKb != null) '${sizeKb.toString()} KB',
            '${downloadCount.toString()} downloads',
          ];

          return _Material.fromMap({
            'noteId': note['id'],
            'fileId': primary['id'],
            'title': note['title'],
            'subject': note['subject'],
            'chapterTitle': chapterTitle,
            'teacherName': 'Teacher',
            'meta': metaParts.join('  •  '),
            'type': fileType,
            'url': primary['file_url'] ?? note['file_url'],
            'isBookmarked': note['is_bookmarked'] == true,
            'downloadCount': downloadCount,
          });
        })
        .toList();

    return noteMaterials;
  }

  Future<void> _refreshMaterials() async {
    if (!mounted) return;
    setState(() {
      _materialsFuture = _loadMaterials();
    });
  }

  Future<void> _toggleBookmark(_Material material) async {
    if (material.noteId.isEmpty) return;
    try {
      if (material.isBookmarked) {
        await _studentRepo.unbookmarkStudyMaterial(material.noteId);
      } else {
        await _studentRepo.bookmarkStudyMaterial(material.noteId);
      }

      await _refreshMaterials();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(material.isBookmarked ? 'Bookmark removed' : 'Bookmarked'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update bookmark right now'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openMaterial(_Material material, {String action = 'download'}) async {
    HapticFeedback.mediumImpact();
    try {
      String targetUrl = material.url;
      String? resolvedFileName;
      String? resolvedMimeType;
      if (material.noteId.isNotEmpty && material.fileId.isNotEmpty) {
        final requestedAction = action.toLowerCase() == 'view' ? 'download' : action;
        final access = await _studentRepo.getStudyMaterialAccess(
          noteId: material.noteId,
          fileId: material.fileId,
          action: requestedAction,
        );
        targetUrl = (access['access_url'] ?? '').toString();
        resolvedFileName = (access['file_name'] ?? '').toString();
        resolvedMimeType = (access['mime_type'] ?? '').toString();
      }

      if (targetUrl.isEmpty) {
        throw Exception('Missing file url');
      }

      await downloadAndOpenFromUrl(
        url: targetUrl,
        fileName: resolvedFileName?.trim().isEmpty ?? true ? material.title : resolvedFileName,
        mimeType: resolvedMimeType?.trim().isEmpty ?? true ? null : resolvedMimeType,
        downloadKey: _downloadKeyFor(material),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open ${material.title}'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
          IconButton(
            tooltip: _bookmarksOnly ? 'Show all materials' : 'Show bookmarked only',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _bookmarksOnly = !_bookmarksOnly;
                _materialsFuture = _loadMaterials();
              });
            },
            icon: Icon(
              _bookmarksOnly ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: Colors.white,
            ),
          ),
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
    final downloadKey = _downloadKeyFor(material);
    return CPPressable(
          onTap: () {
            if (material.type == 'video' || material.type == 'link') {
              final summary = material.chapterTitle.toLowerCase() == 'general'
                  ? ''
                  : material.chapterTitle;
              GoRouter.of(context).push('/student/video-player', extra: {
                'videoUrl': material.url,
                'title': material.title,
                'summary': summary,
                'teacherName': material.teacher,
                'subject': material.subject,
              });
              return;
            }

            _openMaterial(material, action: 'view');
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
                      if (material.chapterTitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          material.chapterTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
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
                Column(
                  children: [
                    IconButton(
                      onPressed: material.noteId.isEmpty
                          ? null
                          : () => _toggleBookmark(material),
                      icon: Icon(
                        material.isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: material.isBookmarked ? AppColors.primary : CT.textS(context),
                        size: 24,
                      ),
                      style: IconButton.styleFrom(backgroundColor: CT.bg(context)),
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: DownloadRegistry.instance,
                      builder: (context, _) {
                        final registry = DownloadRegistry.instance;
                        final isDownloading = registry.isDownloading(downloadKey);
                        final isDownloaded = registry.isDownloaded(downloadKey);

                        return IconButton(
                          tooltip: isDownloaded
                              ? 'Downloaded'
                              : isDownloading
                                  ? 'Downloading'
                                  : 'Download note',
                          onPressed: isDownloading
                              ? null
                              : () => _openMaterial(material, action: 'download'),
                          icon: isDownloading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : Icon(
                                  isDownloaded
                                      ? Icons.check_circle_rounded
                                      : Icons.file_download_outlined,
                                  color: isDownloaded
                                      ? AppColors.mintGreen
                                      : AppColors.primary,
                                  size: 26,
                                ),
                          style: IconButton.styleFrom(backgroundColor: CT.bg(context)),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: 100 * index))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.05, end: 0);
  }

  String _downloadKeyFor(_Material material) {
    if (material.noteId.isNotEmpty && material.fileId.isNotEmpty) {
      return 'note:${material.noteId}:${material.fileId}';
    }
    if (material.url.trim().isNotEmpty) {
      return 'note-url:${stableToken(material.url.trim())}';
    }
    return 'note:${stableToken(material.title)}';
  }
}

class _Material {
  final String noteId;
  final String fileId;
  final String title;
  final String subject;
  final String chapterTitle;
  final String teacher;
  final String meta;
  final String type;
  final String url;
  final bool isBookmarked;
  final int downloadCount;
  final Color color;

  const _Material({
    required this.noteId,
    required this.fileId,
    required this.title,
    required this.subject,
    required this.chapterTitle,
    required this.teacher,
    required this.meta,
    required this.type,
    required this.url,
    required this.isBookmarked,
    required this.downloadCount,
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

    final rawDownload = map['downloadCount'];
    final downloadCount = rawDownload is num
        ? rawDownload.toInt()
        : int.tryParse(rawDownload?.toString() ?? '0') ?? 0;

    return _Material(
      noteId: (map['noteId'] ?? '').toString(),
      fileId: (map['fileId'] ?? '').toString(),
      title: (map['title'] ?? 'Untitled Material').toString(),
      subject: subject,
      chapterTitle: (map['chapterTitle'] ?? '').toString(),
      teacher: (map['teacherName'] ?? 'Teacher').toString(),
      meta: (map['meta'] ?? map['size'] ?? '').toString(),
      type: (map['type'] ?? 'pdf').toString().toLowerCase(),
      url: (map['url'] ?? '').toString(),
      isBookmarked: map['isBookmarked'] == true,
      downloadCount: downloadCount,
      color: color,
    );
  }
}

