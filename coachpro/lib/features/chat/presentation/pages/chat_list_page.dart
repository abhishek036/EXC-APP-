import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/theme/theme_aware.dart';

import '../../../../features/chat/data/repositories/chat_repository.dart';
import '../../../../core/di/injection_container.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _chatRepo = sl<ChatRepository>();
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rooms = await _chatRepo.getChatRooms();
      setState(() {
        _rooms = rooms;
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
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        title: Text('Messages', style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: CT.textH(context))),
        actions: [
          CPPressable(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
              child: Icon(Icons.search, size: 24, color: CT.textH(context)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.dmSans(color: CT.textM(context))))
              : _rooms.isEmpty
                ? Center(child: Text('No messages yet', style: GoogleFonts.dmSans(color: CT.textM(context))))
                : ListView.separated(
                  padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
                  itemCount: _rooms.length,
                  separatorBuilder: (context, idx) => const SizedBox(height: AppDimensions.sm),
                  itemBuilder: (context, i) {
                    final room = _rooms[i];
                    final batchId = room['id'] ?? '';
                    final title = room['name'] ?? 'Batch';
                    final lastMsg = (room['last_message'] as Map?)?['text'] ?? 'No messages yet';
                    final lastTime = (room['last_message'] as Map?)?['created_at'] ?? '';

                    return CPPressable(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final loc = GoRouterState.of(context).matchedLocation;
                        context.go('$loc/chat/$batchId');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppDimensions.md),
                        decoration: CT.cardDecor(context),
                        child: Row(
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                color: _getSubjectColor(title).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                              ),
                              child: Icon(Icons.group, color: _getSubjectColor(title), size: 24),
                            ),
                            const SizedBox(width: AppDimensions.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(title, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
                                      if (lastTime.isNotEmpty)
                                        Text(_formatTime(lastTime), style: GoogleFonts.dmSans(fontSize: 11, color: CT.textM(context))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(lastMsg, style: GoogleFonts.dmSans(fontSize: 13, color: CT.textS(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate(delay: Duration(milliseconds: 80 * i)).fadeIn(duration: 400.ms).slideX(begin: 0.04, end: 0);
                  },
                ),
    );
  }

  Color _getSubjectColor(String s) {
    s = s.toLowerCase();
    if (s.contains('physics')) return AppColors.physics;
    if (s.contains('chem')) return AppColors.chemistry;
    if (s.contains('math')) return AppColors.mathematics;
    return CT.accent(context);
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}
