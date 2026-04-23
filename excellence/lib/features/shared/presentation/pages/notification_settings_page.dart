import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/app_permission_service.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/services/push_notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  Map<NotificationCategory, bool> _prefs = {};
  bool _globalEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  final String _quietHoursStart = '10:00 PM';
  final String _quietHoursEnd = '7:00 AM';
  bool _quietHoursEnabled = false;
  Future<PushRegistrationStatus>? _statusFuture;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _statusFuture = PushNotificationService.instance.getStatus();
  }

  Future<void> _loadPreferences() async {
    final prefs = await PushNotificationService.instance.getPreferences();
    final globalEnabled = await PushNotificationService.instance.isPushEnabled();
    setState(() {
      _prefs = prefs;
      _globalEnabled = globalEnabled;
    });
  }

  void _refreshStatus() {
    setState(() {
      _statusFuture = PushNotificationService.instance.getStatus();
    });
  }

  Future<void> _toggleCategory(NotificationCategory category, bool value) async {
    setState(() => _prefs[category] = value);
    await PushNotificationService.instance.setPreference(category, value);
  }

  Future<void> _toggleGlobal(bool value) async {
    setState(() => _globalEnabled = value);
    try {
      await PushNotificationService.instance.setPushEnabled(value);
      _refreshStatus();
    } catch (_) {
      if (!mounted) return;
      setState(() => _globalEnabled = !value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = CT.accent(context);

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        title: Text('Notification Settings',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: CT.textH(context))),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        children: [
          // Global toggle
          _buildToggleCard(
            icon: Icons.notifications_rounded,
            title: 'Push Notifications',
            subtitle: 'Enable or disable all push notifications',
            value: _globalEnabled,
            onChanged: _toggleGlobal,
            accent: accent,
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: AppDimensions.lg),

          _buildStatusCard(accent),

          const SizedBox(height: AppDimensions.lg),

          if (_globalEnabled) ...[
            // Sound & Vibration
            Text('General', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textS(context))),
            const SizedBox(height: AppDimensions.sm),
            _buildToggleCard(
              icon: Icons.volume_up_rounded,
              title: 'Sound',
              subtitle: 'Play notification sounds',
              value: _soundEnabled,
              onChanged: (v) => setState(() => _soundEnabled = v),
              accent: accent,
            ),
            _buildToggleCard(
              icon: Icons.vibration_rounded,
              title: 'Vibration',
              subtitle: 'Vibrate on notification',
              value: _vibrationEnabled,
              onChanged: (v) => setState(() => _vibrationEnabled = v),
              accent: accent,
            ),

            const SizedBox(height: AppDimensions.lg),

            // Quiet hours
            _buildToggleCard(
              icon: Icons.do_not_disturb_on_rounded,
              title: 'Quiet Hours',
              subtitle: 'Mute notifications from $_quietHoursStart to $_quietHoursEnd',
              value: _quietHoursEnabled,
              onChanged: (v) => setState(() => _quietHoursEnabled = v),
              accent: accent,
            ),

            const SizedBox(height: AppDimensions.lg),

            // Category toggles
            Text('Categories', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textS(context))),
            const SizedBox(height: AppDimensions.sm),
            ..._buildCategoryToggles(accent),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(Color accent) {
    return FutureBuilder<PushRegistrationStatus>(
      future: _statusFuture ?? PushNotificationService.instance.getStatus(),
      builder: (context, snapshot) {
        final status = snapshot.data;
        final ready = status?.registeredWithBackend == true;
        final tokenText = status?.hasToken == true
          ? '${status!.token!.substring(0, status.token!.length > 8 ? 8 : status.token!.length)}...'
            : 'No token';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CT.card(context),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            border: Border.all(color: CT.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(ready ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: ready ? Colors.green : Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Push Registration',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: CT.textH(context)),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await PushNotificationService.instance.syncTokenRegistration();
                      _refreshStatus();
                    },
                    child: Text('Refresh', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                status == null
                    ? 'Checking push token state...'
                    : '${status.message}\nToken: $tokenText\nBackend sync: ${ready ? 'OK' : 'Not registered'}',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: CT.textS(context), height: 1.4),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final granted = await AppPermissionService.requestNotificationAccess(context);
                    if (!mounted) return;
                    _refreshStatus();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          granted
                              ? 'Notification permission granted'
                              : 'Notification permission not changed',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 16),
                  label: Text(
                    'Grant Permission',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildCategoryToggles(Color accent) {
    final categories = [
      (NotificationCategory.feeReminder, Icons.currency_rupee_rounded, 'Fee Reminders', 'Due date alerts & payment confirmations'),
      (NotificationCategory.attendance, Icons.fact_check_rounded, 'Attendance', 'Daily attendance status updates'),
      (NotificationCategory.examResult, Icons.assessment_rounded, 'Exam Results', 'Score & rank published alerts'),
      (NotificationCategory.announcement, Icons.campaign_rounded, 'Announcements', 'Institute announcements & updates'),
      (NotificationCategory.liveSession, Icons.videocam_rounded, 'Live Sessions', 'Class starting & schedule reminders'),
      (NotificationCategory.studyMaterial, Icons.menu_book_rounded, 'Study Material', 'New notes & assignments uploaded'),
      (NotificationCategory.doubtAnswer, Icons.help_rounded, 'Doubt Answers', 'Teacher replied to your doubt'),
      (NotificationCategory.chatMessage, Icons.chat_rounded, 'Chat Messages', 'New messages in batch chats'),
      (NotificationCategory.system, Icons.settings_rounded, 'System', 'App updates & maintenance'),
    ];

    return categories.asMap().entries.map((entry) {
      final (cat, icon, title, subtitle) = entry.value;
      return _buildToggleCard(
        icon: icon,
        title: title,
        subtitle: subtitle,
        value: _prefs[cat] ?? true,
        onChanged: (v) => _toggleCategory(cat, v),
        accent: accent,
      ).animate().fadeIn(delay: (50 * entry.key).ms);
    }).toList();
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color accent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        border: Border.all(color: CT.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
              Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: CT.textS(context))),
            ]),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: accent,
          ),
        ],
      ),
    );
  }
}
