import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/di/injection_container.dart';
import '../../../student/data/repositories/student_repository.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _repo = sl<StudentRepository>();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      _notifications = await _repo.getNotifications();
      // Assume newly fetched ones are unread if 'isRead' doesn't exist.
      for (var n in _notifications) {
        if (!n.containsKey('isRead')) {
          n['isRead'] = false;
        }
      }
    } catch (e) {
      _notifications = [];
    }
    setState(() => _isLoading = false);
  }

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) { n['isRead'] = true; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    final unreadCount = _notifications.where((n) => n['isRead'] == false).length;

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Notifications', style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: CT.textH(context))),
          if (unreadCount > 0)
            Text('$unreadCount unread', style: GoogleFonts.dmSans(fontSize: 12, color: CT.accent(context), fontWeight: FontWeight.w600)),
        ]),
        actions: [
          if (unreadCount > 0)
            CPPressable(
              onTap: _markAllRead,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                child: Text('Mark all read', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: CT.accent(context))),
              ),
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _notifications.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_rounded, size: 60, color: CT.textS(context).withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text("No new notifications", style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
                  const SizedBox(height: 8),
                  Text("You're all caught up!", style: GoogleFonts.dmSans(fontSize: 14, color: CT.textS(context))),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.step, horizontal: AppDimensions.pagePaddingH),
              itemCount: _notifications.length,
              separatorBuilder: (context, idx) => const SizedBox(height: AppDimensions.sm),
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                final isRead = notif['isRead'] as bool;

                IconData icon;
                Color color;
                switch (notif['type']) {
                  case 'material': icon = Icons.menu_book_outlined; color = AppColors.success; break;
                  case 'live': icon = Icons.videocam_outlined; color = AppColors.error; break;
                  case 'fee': icon = Icons.account_balance_wallet_outlined; color = AppColors.warning; break;
                  case 'exam': icon = Icons.analytics_outlined; color = AppColors.primary; break;
                  default: icon = Icons.notifications_none; color = CT.textS(context);
                }

                return CPPressable(
                  onTap: () => setState(() => _notifications[index]['isRead'] = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(AppDimensions.md),
                    decoration: BoxDecoration(
                      color: isRead ? CT.card(context) : CT.accent(context).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                      border: isRead
                        ? (isDark ? Border.all(color: Colors.white.withValues(alpha: 0.06)) : Border.all(color: CT.border(context)))
                        : Border.all(color: CT.accent(context).withValues(alpha: 0.2)),
                      boxShadow: AppDimensions.shadowSm(isDark),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isRead ? 0.08 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: AppDimensions.step),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text(notif['title'] ?? 'Notification',
                                style: GoogleFonts.sora(fontSize: 14, fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, color: CT.textH(context))),
                            ),
                            if (!isRead)
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: CT.accent(context), shape: BoxShape.circle)),
                          ]),
                          const SizedBox(height: 4),
                          Text(notif['body'] ?? notif['desc'] ?? '',
                            style: GoogleFonts.dmSans(fontSize: 13, color: isRead ? CT.textM(context) : CT.textS(context), height: 1.4),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Text(notif['time'] ?? 'Just now',
                            style: GoogleFonts.dmSans(fontSize: 11, color: CT.accent(context), fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ),
                ).animate(delay: Duration(milliseconds: 40 * index)).fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0);
              },
            ),
    );
  }
}
