import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'batch_detail_common_widgets.dart';
import '../../../../core/theme/theme_aware.dart';

class BatchAnnouncementsTab extends StatelessWidget {
  final List<Map<String, dynamic>> announcements;
  final String Function(dynamic) dateLabel;
  final VoidCallback onAddAnnouncement;
  final Function(Map<String, dynamic>) onDeleteAnnouncement;

  const BatchAnnouncementsTab({
    super.key,
    required this.announcements,
    required this.dateLabel,
    required this.onAddAnnouncement,
    required this.onDeleteAnnouncement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('announcements-tab'),
      children: [
        sectionCard(
          context,
          title: 'Batch Announcements',
          trailing: TextButton.icon(
            onPressed: onAddAnnouncement,
            icon: const Icon(Icons.campaign_rounded, size: 16),
            label: const Text('New Post'),
          ),
          child: announcements.isEmpty
              ? Text(
                  'No announcements yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: CT.textS(context),
                  ),
                )
              : Column(
                  children: announcements.take(10).map((ann) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFF354388), width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF354388),
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (ann['title'] ?? 'Announcement').toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                dateLabel(ann['createdAt'] ?? ann['created_at']),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => onDeleteAnnouncement(ann),
                                child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFB6231B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (ann['body'] ?? ann['content'] ?? ann['message'] ?? '').toString(),
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
