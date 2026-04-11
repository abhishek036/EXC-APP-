import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/utils/role_prefix.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../student/data/repositories/student_repository.dart';
import '../../../teacher/data/repositories/teacher_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:async';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final TeacherRepository _teacherRepo;
  late final StudentRepository _studentRepo;
  final _realtime = sl<RealtimeSyncService>();
  StreamSubscription? _syncSub;

  // Getter to choose repo based on current role prefix - must be called after build
  dynamic get _repo {
    final prefix = context.rolePrefix;
    if (prefix == '/teacher' || prefix == '/admin') {
      return _teacherRepo;
    }
    return _studentRepo;
  }

  final List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _perPage = 20;
  String _selectedType = 'all';

  bool get _canComposeOrGlobalDelete {
    final prefix = context.rolePrefix;
    return prefix == '/teacher' || prefix == '/admin';
  }

  @override
  void initState() {
    super.initState();
    _fetchNotifications(reset: true);
    _initRealtime();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _initRealtime() async {
    await _realtime.connect();
    _syncSub?.cancel();
    _syncSub = _realtime.updates.listen((event) {
      if (!mounted) return;
      final type = (event['type'] ?? '').toString();
      final reason = (event['reason'] ?? '').toString().toLowerCase();

      if (type == 'notification' ||
          type == 'broadcast' ||
          type == 'notification_deleted' ||
          type == 'unread_count_update' ||
          reason.contains('notification') ||
          reason.contains('announcement')) {
        _fetchNotifications(reset: true);
      }
    });
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

      if (reset) {
        try {
          final unreadCount = await _repo.getUnreadCount();
          _realtime.updateUnreadCount(unreadCount);
        } catch (_) {}
      }

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

  bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value == null) return false;

    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y';
  }

  Map<String, dynamic> _normalizeNotification(Map<String, dynamic> input) {
    final rawDate = input['created_at'] ?? input['date'];
    DateTime? dt;
    if (rawDate != null) {
      dt = DateTime.tryParse(rawDate.toString())?.toLocal();
    }
    return {
      ...input,
      'isRead':
          _isTruthy(input['read_status']) ||
          _isTruthy(input['isRead']) ||
          _isTruthy(input['readStatus']) ||
          _isTruthy(input['is_read']),
      'title': input['title'] ?? 'Notification',
      'body': input['body'] ?? input['message'] ?? '',
      'type': (input['type'] ?? 'system').toString(),
      'time': (input['created_at'] ?? input['date'] ?? '').toString(),
      'dateTime': dt,
      'batchName':
          input['batch_name'] ??
          input['batchName'] ??
          (input['meta'] is Map ? input['meta']['batchName'] : null),
    };
  }

  Future<void> _markRead(int index, {bool read = true}) async {
    final id = (_notifications[index]['id'] ?? '').toString();
    if (id.isEmpty) return;
    if (_notifications[index]['isRead'] == read) return;

    HapticFeedback.lightImpact();
    setState(() => _notifications[index]['isRead'] = read);
    try {
      await _repo.markNotificationRead(id, read: read);
      final count = await _repo.getUnreadCount();
      _realtime.updateUnreadCount(count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notifications[index]['isRead'] = !read);
    }
  }

  Future<void> _markAllRead() async {
    HapticFeedback.mediumImpact();
    final backup = _notifications
        .map((n) => Map<String, dynamic>.from(n))
        .toList();
    setState(() {
      for (final item in _notifications) {
        item['isRead'] = true;
      }
    });

    try {
      await _repo.markAllNotificationsRead();
      final count = await _repo.getUnreadCount();
      _realtime.updateUnreadCount(count);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifications
          ..clear()
          ..addAll(backup);
      });
    }
  }

  Future<void> _deleteNotification(int index, {required bool global}) async {
    final id = (_notifications[index]['id'] ?? '').toString();
    if (id.isEmpty) return;

    final removed = _notifications.removeAt(index);
    if (mounted) setState(() {});

    try {
      if (global) {
        await _repo.deleteNotificationGlobally(id);
      } else {
        await _repo.deleteNotification(id);
      }
      final count = await _repo.getUnreadCount();
      _realtime.updateUnreadCount(count);
      _fetchNotifications(reset: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            global ? 'Deleted for all recipients' : 'Notification deleted',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _notifications.insert(index, removed);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed. Please try again.')),
      );
    }
  }

  Future<void> _showComposeSheet() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String selectedType = 'system';
    String selectedRole = context.rolePrefix == '/teacher' ? 'student' : 'all';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CT.bg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final roleOptions = context.rolePrefix == '/teacher'
                ? const ['student', 'parent']
                : const ['all', 'teacher', 'student', 'parent', 'admin'];
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NEW BROADCAST',
                        style: GoogleFonts.sora(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      CPPressable(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: titleCtrl,
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'HEADER TITLE',
                      labelStyle: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: CT.textS(context),
                      ),
                      filled: true,
                      fillColor: CT.card(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: CT.border(context)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bodyCtrl,
                    minLines: 3,
                    maxLines: 5,
                    style: GoogleFonts.dmSans(),
                    decoration: InputDecoration(
                      labelText: 'MESSAGE BODY',
                      labelStyle: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: CT.textS(context),
                      ),
                      filled: true,
                      fillColor: CT.card(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: CT.border(context)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: InputDecoration(
                            labelText: 'TYPE',
                            labelStyle: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                            filled: true,
                            fillColor: CT.card(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items:
                              const [
                                    'system',
                                    'class',
                                    'attendance',
                                    'exam',
                                    'fee',
                                    'content',
                                    'result',
                                  ]
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        value.toUpperCase(),
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setSheetState(() => selectedType = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          decoration: InputDecoration(
                            labelText: 'TARGET',
                            labelStyle: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                            filled: true,
                            fillColor: CT.card(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: roleOptions
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    value.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setSheetState(() => selectedRole = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  CPPressable(
                    onTap: () async {
                      final title = titleCtrl.text.trim();
                      final body = bodyCtrl.text.trim();
                      if (title.isEmpty || body.isEmpty) return;

                      HapticFeedback.mediumImpact();
                      try {
                        await _repo.sendManualNotification(
                          title: title,
                          body: body,
                          type: selectedType,
                          roleTarget: selectedRole,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _fetchNotifications(reset: true);
                      } catch (_) {}
                    },
                    child: Container(
                      height: 56,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: CT.textH(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CT.border(context), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: CT.border(context),
                            offset: const Offset(3, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'EMIT BROADCAST',
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: CT.elevated(context),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications
        .where((n) => n['isRead'] == false)
        .length;
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACTIVITY',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
            if (unreadCount > 0)
              Text(
                '$unreadCount pending nodes',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: CT.accent(context),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
          ],
        ),
        actions: [
          if (_canComposeOrGlobalDelete)
            IconButton(
              icon: const Icon(Icons.add_box_outlined, size: 28),
              onPressed: _showComposeSheet,
            ),
          if (unreadCount > 0)
            CPPressable(
              onTap: _markAllRead,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    'CLEAR ALL',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: CT.accent(context),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _typeChip('all', 'ALL'),
                  _typeChip('attendance', 'ATTENDANCE'),
                  _typeChip('exam', 'QUIZ/EXAM'),
                  _typeChip('material', 'MATERIAL'),
                  _typeChip('fee', 'FEES'),
                  _typeChip('class', 'CLASSES'),
                  _typeChip('system', 'CORE'),
                ],
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _notifications.isEmpty
                ? _emptyState(context)
                : RefreshIndicator(
                    onRefresh: () => _fetchNotifications(reset: true),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _notifications.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (context, idx) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index >= _notifications.length) {
                          _fetchNotifications(reset: false);
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        final notif = _notifications[index];
                        final isRead = notif['isRead'] as bool;
                        final iconColor = _colorForType(
                          notif['type']?.toString() ?? 'system',
                          context,
                        );

                        return CPPressable(
                          onTap: () {
                            _markRead(index, read: true);
                            final meta = notif['meta'] as Map<String, dynamic>?;
                            final rawRoute =
                                meta?['route']?.toString() ??
                                notif['route']?.toString();
                            final route = rawRoute == '/student/quizzes'
                                ? '/student/quiz'
                                : rawRoute == '/teacher/quizzes'
                                ? '/teacher/batches'
                                : rawRoute;

                            if (route != null && route.isNotEmpty) {
                              context.push(route);
                            } else {
                              final type = notif['type']?.toString();
                              final prefix = context.rolePrefix;

                              if (type == 'doubt') {
                                context.push('$prefix/doubts/history');
                              } else if (type == 'class') {
                                context.push('$prefix/timetable');
                              } else if (type == 'exam' || type == 'quiz') {
                                if (prefix == '/student') {
                                  context.push('/student/quiz');
                                } else if (prefix == '/teacher') {
                                  context.push('/teacher/batches');
                                } else {
                                  context.push(prefix);
                                }
                              } else if (type == 'material' ||
                                  type == 'content') {
                                context.push('$prefix/materials');
                              } else if (type == 'attendance') {
                                context.push('$prefix/attendance');
                              } else if (type == 'result') {
                                context.push('$prefix/results');
                              }
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? CT.card(context)
                                  : iconColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isRead
                                    ? CT.border(context)
                                    : iconColor.withValues(alpha: 0.5),
                                width: isRead ? 1 : 2,
                              ),
                              boxShadow: isRead
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: iconColor.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                      ),
                                    ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isRead
                                        ? CT.bg(context)
                                        : iconColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _iconForType(
                                      notif['type']?.toString() ?? 'system',
                                    ),
                                    color: iconColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                if (!isRead)
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    margin:
                                                        const EdgeInsets.only(
                                                          right: 8,
                                                        ),
                                                    decoration:
                                                        const BoxDecoration(
                                                          color:
                                                              AppColors.primary,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                  ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        notif['title']
                                                            .toString()
                                                            .toUpperCase(),
                                                        style: GoogleFonts.sora(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: CT.textH(
                                                            context,
                                                          ),
                                                          letterSpacing: -0.2,
                                                        ),
                                                      ),
                                                      if (notif['batchName'] !=
                                                          null)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                top: 2,
                                                              ),
                                                          child: Text(
                                                            'BATCH: ${notif['batchName'].toString().toUpperCase()}',
                                                            style: GoogleFonts.jetBrainsMono(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                              fontSize: 9,
                                                              color: AppColors
                                                                  .electricBlue,
                                                              letterSpacing:
                                                                  0.5,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _buildMiniMenu(index),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notif['body'].toString(),
                                        style: GoogleFonts.dmSans(
                                          fontSize: 14,
                                          color: CT.textM(context),
                                          height: 1.4,
                                          fontWeight: isRead
                                              ? FontWeight.w400
                                              : FontWeight.w500,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            notif['dateTime'] != null
                                                ? timeago.format(
                                                    notif['dateTime'],
                                                  )
                                                : notif['time'].toString(),
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 9,
                                              color: CT.textS(context),
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          if (notif['dateTime'] != null)
                                            Text(
                                              DateFormat(
                                                'dd MMM, hh:mm a',
                                              ).format(notif['dateTime']),
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 8,
                                                color: CT
                                                    .textS(context)
                                                    .withValues(alpha: 0.5),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.02);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMenu(int index) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded, color: CT.textS(context), size: 18),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'delete') _deleteNotification(index, global: false);
        if (value == 'delete_global') _deleteNotification(index, global: true);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'delete',
          child: Text('Remove', style: GoogleFonts.dmSans(fontSize: 13)),
        ),
        if (_canComposeOrGlobalDelete)
          PopupMenuItem(
            value: 'delete_global',
            child: Text(
              'Recall Broadcast',
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error),
            ),
          ),
      ],
    );
  }

  Widget _typeChip(String value, String label) {
    final selected = _selectedType == value;
    final accent = CT.accent(context);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: CPPressable(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedType = value);
          _fetchNotifications(reset: true);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? accent : CT.card(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? CT.border(context) : CT.border(context),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: CT.border(context),
                      offset: const Offset(2, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: selected ? CT.elevated(context) : CT.textS(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CT.card(context),
              shape: BoxShape.circle,
              border: Border.all(color: CT.border(context), width: 2),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: CT.textS(context).withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ZERO ACTIVITY NODES',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: CT.textH(context),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are fully synchronized with the hub.',
            style: GoogleFonts.dmSans(fontSize: 14, color: CT.textS(context)),
          ),
        ],
      ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'fee':
        return Icons.account_balance_wallet_outlined;
      case 'class':
        return Icons.calendar_today_rounded;
      case 'exam':
      case 'quiz':
        return Icons.analytics_outlined;
      case 'attendance':
        return Icons.fact_check_rounded;
      case 'material':
      case 'content':
        return Icons.description_outlined;
      case 'result':
        return Icons.emoji_events_outlined;
      default:
        return Icons.radar_rounded;
    }
  }

  Color _colorForType(String type, BuildContext context) {
    switch (type) {
      case 'fee':
        return AppColors.warning;
      case 'class':
        return AppColors.primary;
      case 'exam':
      case 'quiz':
        return AppColors.success;
      case 'attendance':
        return AppColors.error;
      case 'material':
      case 'content':
        return Colors.purple;
      case 'result':
        return AppColors.moltenAmber;
      default:
        return CT.accent(context);
    }
  }
}
