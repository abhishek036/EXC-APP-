import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_shimmer.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../data/repositories/parent_repository.dart';

class _DoubtThreadMessage {
  final String label;
  final String text;
  final String? imageUrl;
  final DateTime? timestamp;
  final bool isStudent;

  String get senderName => label;
  String get senderRole => isStudent ? 'student' : 'teacher';

  const _DoubtThreadMessage({
    required this.label,
    required this.text,
    required this.timestamp,
    required this.isStudent,
    this.imageUrl,
  });
}

class ParentDoubtsPage extends StatefulWidget {
  const ParentDoubtsPage({super.key});

  @override
  State<ParentDoubtsPage> createState() => _ParentDoubtsPageState();
}

class _ParentDoubtsPageState extends State<ParentDoubtsPage> {
  final _parentRepo = sl<ParentRepository>();
  final _realtime = sl<RealtimeSyncService>();
  StreamSubscription<Map<String, dynamic>>? _syncSub;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _doubts = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadDoubts();
    _initRealtime();
  }

  Future<void> _initRealtime() async {
    await _realtime.connect();
    _syncSub?.cancel();
    _syncSub = _realtime.updates.listen((event) {
      if (!mounted) return;
      final type = (event['type'] ?? '').toString();
      final reason = (event['reason'] ?? '').toString().toLowerCase();
      if (type == 'dashboard_sync' || reason.contains('doubt') || type == 'batch_sync') {
        _loadDoubts(isSilent: true);
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDoubts({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }
    try {
      final doubts = await _parentRepo.getChildrenDoubts();
      if (!mounted) return;
      setState(() {
        _doubts = doubts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load doubts. Network Error';
        _isLoading = false;
      });
    }
  }

  bool _labelRepresentsStudent(String label, bool defaultIsStudent) {
    final l = label.toLowerCase();
    if (l.contains('teacher') || l.contains('instructor')) return false;
    if (l.contains('student')) return true;
    return defaultIsStudent;
  }

  List<_DoubtThreadMessage> _parseThreadText({
    required String rawText,
    required bool defaultIsStudent,
    required String fallbackLabel,
    DateTime? fallbackTimestamp,
  }) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return const [];

    final blocks = trimmed.split(RegExp(r'\n\s*\n+'));
    final headerPattern = RegExp(r'^\[(.+?)\s*\|\s*(.+?)\]$');
    final messages = <_DoubtThreadMessage>[];

    for (final block in blocks) {
      final rawLines = block
          .split('\n')
          .map((line) => line.trimRight())
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (rawLines.isEmpty) continue;

      var label = fallbackLabel;
      var ts = fallbackTimestamp;
      var contentStart = 0;

      final headerMatch = headerPattern.firstMatch(rawLines.first.trim());
      if (headerMatch != null) {
        label = headerMatch.group(1)?.trim() ?? fallbackLabel;
        ts = DateTime.tryParse((headerMatch.group(2) ?? '').trim()) ?? ts;
        contentStart = 1;
      }

      String? imageUrl;
      final textLines = <String>[];
      for (var i = contentStart; i < rawLines.length; i++) {
        final line = rawLines[i].trim();
        if (line.toLowerCase().startsWith('image:')) {
          final maybeUrl = line.substring(6).trim();
          if (maybeUrl.isNotEmpty) imageUrl = maybeUrl;
          continue;
        }
        textLines.add(rawLines[i]);
      }

      final text = textLines.join('\n').trim();
      if (text.isEmpty && (imageUrl == null || imageUrl.isEmpty)) continue;

      messages.add(
        _DoubtThreadMessage(
          label: label,
          text: text,
          imageUrl: imageUrl,
          timestamp: ts,
          isStudent: _labelRepresentsStudent(label, defaultIsStudent),
        ),
      );
    }

    return messages;
  }

  List<_DoubtThreadMessage> _extractThreadMessages(Map<String, dynamic> doubt) {
    final createdAt = DateTime.tryParse(
      (doubt['createdAt'] ?? doubt['created_at'] ?? '').toString(),
    );
    final resolvedAt = DateTime.tryParse(
      (doubt['resolvedAt'] ?? doubt['resolved_at'] ?? '').toString(),
    );

    final questionText =
        (doubt['questionText'] ?? doubt['question_text'] ?? '').toString();
    final answerText =
        (doubt['answerText'] ?? doubt['answer_text'] ?? '').toString();

    final fromStudent = _parseThreadText(
      rawText: questionText,
      defaultIsStudent: true,
      fallbackLabel: 'Student Question',
      fallbackTimestamp: createdAt,
    );
    final fromTeacher = _parseThreadText(
      rawText: answerText,
      defaultIsStudent: false,
      fallbackLabel: 'Teacher Reply',
      fallbackTimestamp: resolvedAt ?? createdAt,
    );

    final all = <_DoubtThreadMessage>[
      ...fromStudent,
      ...fromTeacher,
    ];

    all.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return -1;
      if (b.timestamp == null) return 1;
      return a.timestamp!.compareTo(b.timestamp!);
    });

    return all;
  }

  Widget _buildThreadBubble(_DoubtThreadMessage msg, bool isDark) {
    final bubbleColor = msg.isStudent
        ? AppColors.electricBlue.withValues(alpha: isDark ? 0.25 : 0.10)
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04));
    final textColor = isDark ? AppColors.paleSlate1 : AppColors.deepNavy;
    final metaColor = isDark ? AppColors.paleSlate2 : Colors.black54;
    final ts = msg.timestamp == null
        ? ''
        : DateFormat('MMM d, h:mm a').format(msg.timestamp!.toLocal());

    return Align(
      alignment: msg.isStudent ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: msg.isStudent
                  ? AppColors.electricBlue.withValues(alpha: 0.35)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.08)),
            ),
          ),
          child: Column(
            crossAxisAlignment: msg.isStudent
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                msg.label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: metaColor,
                  letterSpacing: 0.4,
                ),
              ),
              if (ts.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  ts,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: metaColor,
                  ),
                ),
              ],
              if (msg.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    msg.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (msg.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  msg.text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          if (isDark) ...[
            const Positioned(top: -100, left: -50, child: SizedBox.shrink()),
            const Positioned(
              bottom: 200,
              right: -150,
              child: SizedBox.shrink(),
            ),
          ],
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppBar(context, isDark),
                Expanded(
                  child: _isLoading
                      ? _buildShimmer()
                      : _error.isNotEmpty && _doubts.isEmpty
                      ? Center(
                          child: Text(
                            _error,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: isDark ? AppColors.paleSlate2 : Colors.black45,
                            ),
                          ),
                        )
                      : _buildDoubtsList(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Child Monitoring',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Doubt Chat History',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.paleSlate2 : Colors.black54,
                ),
              ),
            ],
          ),
          CPPressable(
            onTap: _loadDoubts,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.paleSlate1 : Colors.black).withValues(
                  alpha: 0.05,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => const CPShimmer(
        width: double.infinity,
        height: 120,
        borderRadius: 20,
      ),
    );
  }

  Widget _buildDoubtsList(bool isDark) {
    if (_doubts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.paleSlate1 : Colors.black).withValues(
                  alpha: 0.02,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 64,
                color: isDark ? AppColors.darkBorder : Colors.black26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No doubt history available.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.paleSlate2 : Colors.black45,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDoubts,
      color: AppColors.electricBlue,
      child: ListView.separated(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: 100,
        ),
        itemCount: _doubts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, i) {
          final doubt = _doubts[i];
          final threadMessages = _extractThreadMessages(doubt);
          final status = (doubt['status'] ?? 'pending')
              .toString()
              .toLowerCase();
          final dt = DateTime.tryParse(
            (doubt['createdAt'] ?? doubt['created_at'] ?? '').toString(),
          );
          final dateStr = dt != null
              ? DateFormat('MMM d, h:mm a').format(dt)
              : '—';

          final isResolved = status == 'resolved';
          final sColor = isResolved ? AppColors.success : AppColors.warning;

          final studentName = doubt['student']?['name'] ?? 'Child';
          final subject = doubt['subject'] ?? 'General';

          return CPGlassCard(
                isDark: isDark,
                padding: const EdgeInsets.all(20),
                borderRadius: 24,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.electricBlue.withValues(alpha: 0.1),
                          child: Icon(Icons.person_rounded, size: 18, color: AppColors.electricBlue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                studentName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                                ),
                              ),
                              Text(
                                subject,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.paleSlate2 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: sColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isResolved ? 'RESOLVED' : 'ACTIVE',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: sColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.paleSlate2 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (threadMessages.isEmpty)
                      Text(
                        'No conversation text available',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.paleSlate2 : Colors.black54,
                        ),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.forum_rounded, size: 14, color: AppColors.electricBlue),
                                const SizedBox(width: 8),
                                Text(
                                  'LATEST UPDATE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.electricBlue,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              threadMessages.last.text.isNotEmpty 
                                ? threadMessages.last.text 
                                : (threadMessages.last.imageUrl != null ? '[Image Attachment]' : 'No text'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CPPressable(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => _DoubtChatSheet(
                                doubt: doubt,
                                threadMessages: threadMessages,
                                isDark: isDark,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.electricBlue,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.electricBlue.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.remove_red_eye_rounded, size: 16, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'View Full Conversation',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
              .animate(delay: (40 * i).ms)
              .fadeIn(duration: 400.ms)
              .slideX(begin: 0.05);
        },
      ),
    );
  }
}

class _DoubtChatSheet extends StatelessWidget {
  final Map<String, dynamic> doubt;
  final List<_DoubtThreadMessage> threadMessages;
  final bool isDark;

  const _DoubtChatSheet({
    required this.doubt,
    required this.threadMessages,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final studentName = ((doubt['student'] as Map?)?['name'] ?? 'Student').toString();
    final subject = (doubt['subject'] ?? 'Academic').toString();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.deepNavy : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.electricBlue.withValues(alpha: 0.1),
                  child: Icon(Icons.forum_rounded, color: AppColors.electricBlue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doubt Conversation',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.deepNavy,
                        ),
                      ),
                      Text(
                        '$studentName • $subject',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.paleSlate2 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                CPPressable(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded, color: isDark ? Colors.white : AppColors.deepNavy),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: threadMessages.length,
              itemBuilder: (context, index) {
                final msg = threadMessages[index];
                final isTeacher = msg.senderRole == 'teacher';
                final hasImage = msg.imageUrl != null && msg.imageUrl!.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: isTeacher ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                        child: Text(
                          msg.senderName.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppColors.paleSlate2 : Colors.black38,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isTeacher
                              ? (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF5F7FA))
                              : AppColors.electricBlue,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isTeacher ? 0 : 20),
                            bottomRight: Radius.circular(isTeacher ? 20 : 0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasImage) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  msg.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                                ),
                              ),
                              if (msg.text.isNotEmpty) const SizedBox(height: 12),
                            ],
                            if (msg.text.isNotEmpty)
                              Text(
                                msg.text,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isTeacher
                                      ? (isDark ? Colors.white : AppColors.deepNavy)
                                      : Colors.white,
                                  height: 1.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
