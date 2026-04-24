import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import 'batch_detail_common_widgets.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/constants/app_dimensions.dart';

class BatchContentTab extends StatefulWidget {
  final List<Map<String, dynamic>> lectures;
  final List<Map<String, dynamic>> materials;
  final List<Map<String, dynamic>> assignments;
  final String Function(dynamic) dateLabel;
  final String Function(dynamic) timeLabel;
  final double Function(dynamic) toDouble;
  final int Function(dynamic) toInt;
  final String Function(dynamic) normalizeNoteType;
  final VoidCallback onAddLecture;
  final Function(Map<String, dynamic>) onEditLecture;
  final Function(String) onDeleteLecture;
  final VoidCallback onAddNote;
  final Function(Map<String, dynamic>) onEditNote;
  final Function(Map<String, dynamic>) onReplaceNote;
  final Function(Map<String, dynamic>) onDeleteNote;
  final VoidCallback onAddAssignment;
  final Function(Map<String, dynamic>) onEditAssignment;
  final Function(Map<String, dynamic>) onDeleteAssignment;
  final Function(Map<String, dynamic>) onViewSubmissions;

  const BatchContentTab({
    super.key,
    required this.lectures,
    required this.materials,
    required this.assignments,
    required this.dateLabel,
    required this.timeLabel,
    required this.toDouble,
    required this.toInt,
    required this.normalizeNoteType,
    required this.onAddLecture,
    required this.onEditLecture,
    required this.onDeleteLecture,
    required this.onAddNote,
    required this.onEditNote,
    required this.onReplaceNote,
    required this.onDeleteNote,
    required this.onAddAssignment,
    required this.onEditAssignment,
    required this.onDeleteAssignment,
    required this.onViewSubmissions,
  });

  @override
  State<BatchContentTab> createState() => _BatchContentTabState();
}

class _BatchContentTabState extends State<BatchContentTab> {
  int _activeContentTab = 0;
  final List<String> _contentTabs = [
    'Lectures',
    'Notes',
    'Assignments',
    'DPP',
    'Materials',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('content-tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 2),
          decoration: const BoxDecoration(
            color: AppColors.elitePrimary,
            border: Border(
              top: BorderSide(color: AppColors.elitePrimary, width: 2),
              bottom: BorderSide(color: AppColors.elitePrimary, width: 2),
            ),
          ),
          child: SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.pagePaddingH,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: _contentTabs.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                final selected = _activeContentTab == index;
                return InkWell(
                  onTap: () => setState(() => _activeContentTab = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selected
                              ? AppColors.moltenAmber
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      _contentTabs[index].toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                        color: selected
                            ? AppColors.moltenAmber
                            : Colors.white.withValues(alpha: 0.68),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_activeContentTab == 0) _buildLecturesBlock(context),
        if (_activeContentTab == 1) _buildNotesBlock(context),
        if (_activeContentTab == 2 || _activeContentTab == 3)
          _buildAssignmentsBlock(context, isDpp: _activeContentTab == 3),
        if (_activeContentTab == 4) _buildMaterialsBlock(context),
      ],
    );
  }

  Widget _buildLecturesBlock(BuildContext context) {
    return sectionCard(
      context,
      title: 'Lectures',
      trailing: TextButton.icon(
        onPressed: widget.onAddLecture,
        icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
        label: const Text('Add Lecture'),
      ),
      child: widget.lectures.isEmpty
          ? Text(
              'No lectures uploaded yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: CT.textS(context),
              ),
            )
          : Column(
              children: widget.lectures.take(12).map((lecture) {
                final rawStatus = (lecture['status'] ?? '').toString().trim();
                final status = rawStatus.isNotEmpty
                    ? rawStatus
                    : (lecture['is_live'] == true ? 'Live' : 'Recorded');
                final completion = widget.toDouble(lecture['completion_percent']);
                final views = widget.toInt(
                  lecture['views_count'] ?? lecture['view_count'],
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFF354388),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (lecture['title'] ?? 'Lecture').toString(),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          statusTag(
                            status,
                            status.toLowerCase() == 'live'
                                ? const Color(0xFFE5A100)
                                : const Color(0xFF354388),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.dateLabel(lecture['scheduled_at'])} ${widget.timeLabel(lecture['scheduled_at'])} • ${widget.toInt(lecture['duration_minutes'])} min',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Views: $views',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Completion: ${completion.toStringAsFixed(0)}%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => widget.onEditLecture(lecture),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            onPressed: () => widget.onDeleteLecture(
                                (lecture['id'] ?? '').toString()),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildNotesBlock(BuildContext context) {
    return sectionCard(
      context,
      title: 'Notes',
      trailing: TextButton.icon(
        onPressed: widget.onAddNote,
        icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
        label: const Text('Add Note'),
      ),
      child: widget.materials.isEmpty
          ? Text(
              'No notes uploaded yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: CT.textS(context),
              ),
            )
          : Column(
              children: widget.materials.take(12).map((note) {
                final downloads = widget.toInt(
                  note['downloads_count'] ?? note['download_count'],
                );
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF354388),
                  ),
                  title: Text(
                    (note['title'] ?? note['file_name'] ?? 'Note').toString(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${(note['subject'] ?? 'General').toString()} • ${widget.dateLabel(note['created_at'])} • $downloads downloads',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        widget.onEditNote(note);
                      } else if (value == 'replace') {
                        widget.onReplaceNote(note);
                      } else if (value == 'delete') {
                        widget.onDeleteNote(note);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'replace', child: Text('Replace File')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildAssignmentsBlock(BuildContext context, {required bool isDpp}) {
    final title = isDpp ? 'DPP' : 'Assignments';
    final list = widget.assignments.where((item) {
      final type = (item['type'] ?? '').toString().toLowerCase();
      if (isDpp) return type == 'dpp' || type.contains('practice');
      return type.isEmpty || type == 'assignment';
    }).toList();

    return sectionCard(
      context,
      title: title,
      trailing: isDpp
          ? null
          : TextButton.icon(
              onPressed: widget.onAddAssignment,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text('Add Assignment'),
            ),
      child: list.isEmpty
          ? Text(
              'No $title found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: CT.textS(context),
              ),
            )
          : Column(
              children: list.take(12).map((item) {
                final submissions = widget.toInt(
                  item['submission_count'] ??
                      item['submissions_count'] ??
                      item['submitted_count'],
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFF354388),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['title'] ?? title).toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Due: ${widget.dateLabel(item['due_date'])} • Submissions: $submissions',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => widget.onViewSubmissions(item),
                            icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                            label: const Text('View Submissions'),
                          ),
                          OutlinedButton(
                            onPressed: () => widget.onEditAssignment(item),
                            child: const Text('Edit'),
                          ),
                          OutlinedButton(
                            onPressed: () => widget.onDeleteAssignment(item),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildMaterialsBlock(BuildContext context) {
    return sectionCard(
      context,
      title: 'Materials Library',
      trailing: TextButton.icon(
        onPressed: widget.onAddNote,
        icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
        label: const Text('Add Material'),
      ),
      child: widget.materials.isEmpty
          ? Text(
              'No materials available',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: CT.textS(context),
              ),
            )
          : Column(
              children: widget.materials.take(10).map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFF354388),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.folder_open_rounded,
                        color: Color(0xFF354388),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (item['title'] ?? item['file_name'] ?? 'Material')
                              .toString(),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.normalizeNoteType(item['file_type'] ?? item['type'])
                                .toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF354388),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz_rounded, size: 18),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                widget.onEditNote(item);
                              } else if (value == 'replace') {
                                widget.onReplaceNote(item);
                              } else if (value == 'delete') {
                                widget.onDeleteNote(item);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'replace', child: Text('Replace File')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}
