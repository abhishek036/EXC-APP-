import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../student/data/repositories/student_repository.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _repo = sl<StudentRepository>();

  final List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _perPage = 20;
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    _fetchNotifications(reset: true);
  }

  Future<void> _fetchNotifications({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _page = 1;
        _hasMore = true;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final data = await _repo.getNotifications(
        page: _page,
        perPage: _perPage,
        type: _selectedType == 'all' ? null : _selectedType,
        readStatus: 'all',
      );

      setState(() {
        if (reset) {
          _notifications
            ..clear()
            ..addAll(data.map(_normalizeNotification));
        } else {
          _notifications.addAll(data.map(_normalizeNotification));
        }

        _hasMore = data.length >= _perPage;
        if (_hasMore) _page += 1;
      });
    } catch (_) {
      if (reset) {
        setState(() {
          _notifications.clear();
          _hasMore = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Map<String, dynamic> _normalizeNotification(Map<String, dynamic> input) {
    return {
      ...input,
      'isRead': input['read_status'] == true || input['isRead'] == true,
      'title': input['title'] ?? 'Notification',
      'body': input['body'] ?? input['message'] ?? '',
      'type': (input['type'] ?? 'system').toString(),
      'time': (input['created_at'] ?? input['date'] ?? '').toString(),
    };
  }

  Future<void> _markRead(int index, {bool read = true}) async {
    final id = (_notifications[index]['id'] ?? '').toString();
    if (id.isEmpty) return;

    setState(() => _notifications[index]['isRead'] = read);
    try {
      await _repo.markNotificationRead(id, read: read);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notifications[index]['isRead'] = !read);
    }
  }

  Future<void> _markAllRead() async {
    final backup = _notifications.map((n) => Map<String, dynamic>.from(n)).toList();
    setState(() {
      for (final item in _notifications) {
        item['isRead'] = true;
      }
    });

    try {
      await _repo.markAllNotificationsRead();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifications
          ..clear()
          ..addAll(backup);
      });
    }
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notifications', style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: CT.textH(context))),
            if (unreadCount > 0)
              Text('$unreadCount unread', style: GoogleFonts.dmSans(fontSize: 12, color: CT.accent(context), fontWeight: FontWeight.w600)),
          ],
        ),
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
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
              children: [
                _typeChip('all', 'All'),
                _typeChip('fee', 'Fees'),
                _typeChip('class', 'Class'),
                _typeChip('exam', 'Exam'),
                _typeChip('attendance', 'Attendance'),
                _typeChip('system', 'System'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? _emptyState(context)
                    : RefreshIndicator(
                        onRefresh: () => _fetchNotifications(reset: true),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: AppDimensions.step, horizontal: AppDimensions.pagePaddingH),
                          itemCount: _notifications.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (context, idx) => const SizedBox(height: AppDimensions.sm),
                          itemBuilder: (context, index) {
                            if (index >= _notifications.length) {
                              _fetchNotifications(reset: false);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: _isLoadingMore
                                      ? const CircularProgressIndicator(strokeWidth: 2)
                                      : Text('Load more', style: GoogleFonts.dmSans(color: CT.textS(context))),
                                ),
                              );
                            }

                            final notif = _notifications[index];
                            final isRead = notif['isRead'] as bool;

                            final iconData = _iconForType(notif['type']?.toString() ?? 'system');
                            final iconColor = _colorForType(notif['type']?.toString() ?? 'system', context);

                            return CPPressable(
                              onTap: () => _markRead(index, read: true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.all(AppDimensions.md),
                                decoration: BoxDecoration(
                                  color: isRead ? CT.card(context) : CT.accent(context).withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                                  border: isRead
                                      ? (isDark ? Border.all(color: Colors.white.withValues(alpha: 0.06)) : Border.all(color: CT.border(context)))
                                      : Border.all(color: CT.accent(context).withValues(alpha: 0.2)),
                                  boxShadow: AppDimensions.shadowSm(isDark),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: iconColor.withValues(alpha: isRead ? 0.08 : 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(iconData, color: iconColor, size: 20),
                                    ),
                                    const SizedBox(width: AppDimensions.step),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notif['title'].toString(),
                                                  style: GoogleFonts.sora(fontSize: 14, fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, color: CT.textH(context)),
                                                ),
                                              ),
                                              if (!isRead)
                                                Container(width: 8, height: 8, decoration: BoxDecoration(color: CT.accent(context), shape: BoxShape.circle)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            notif['body'].toString(),
                                            style: GoogleFonts.dmSans(fontSize: 13, color: isRead ? CT.textM(context) : CT.textS(context), height: 1.4),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            notif['time'].toString(),
                                            style: GoogleFonts.dmSans(fontSize: 11, color: CT.accent(context), fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate(delay: Duration(milliseconds: 35 * index)).fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final selected = _selectedType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: ChoiceChip(
        selected: selected,
        label: Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        onSelected: (_) {
          setState(() => _selectedType = value);
          _fetchNotifications(reset: true);
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_rounded, size: 60, color: CT.textS(context).withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No notifications found', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
          const SizedBox(height: 8),
          Text('You are all caught up!', style: GoogleFonts.dmSans(fontSize: 14, color: CT.textS(context))),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'fee':
        return Icons.account_balance_wallet_outlined;
      case 'class':
        return Icons.calendar_month_rounded;
      case 'exam':
      case 'result':
        return Icons.analytics_outlined;
      case 'attendance':
        return Icons.fact_check_rounded;
      default:
        return Icons.notifications_none;
    }
  }

  Color _colorForType(String type, BuildContext context) {
    switch (type) {
      case 'fee':
        return AppColors.warning;
      case 'class':
        return AppColors.primary;
      case 'exam':
      case 'result':
        return AppColors.success;
      case 'attendance':
        return AppColors.error;
      default:
        return CT.textS(context);
    }
  }
}
