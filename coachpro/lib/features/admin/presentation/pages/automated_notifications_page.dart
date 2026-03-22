import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/services/auto_notification_service.dart';

class AutomatedNotificationsPage extends StatefulWidget {
  const AutomatedNotificationsPage({super.key});

  @override
  State<AutomatedNotificationsPage> createState() => _AutomatedNotificationsPageState();
}

class _AutomatedNotificationsPageState extends State<AutomatedNotificationsPage> {
  List<AutoNotificationRule> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final rules = await AutoNotificationService.instance.loadRules();
    setState(() {
      _rules = rules;
      _isLoading = false;
    });
  }

  Future<void> _toggleRule(String id, bool enabled) async {
    final updated = await AutoNotificationService.instance.toggleRule(id, enabled);
    setState(() => _rules = updated);
  }

  Future<void> _updateChannel(String id, String channel) async {
    final updated = await AutoNotificationService.instance.updateChannel(id, channel);
    setState(() => _rules = updated);
  }

  Future<void> _triggerManualCheck(String type) async {
    if (type == 'fee') {
      await AutoNotificationService.instance.triggerFeeReminders();
    } else {
      await AutoNotificationService.instance.triggerAttendanceNotifications();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${type == 'fee' ? 'Fee' : 'Attendance'} notifications triggered'),
          backgroundColor: Colors.green.shade600,
        ),
      );
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
        title: Text('Automated Notifications',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                  ),
                  child: Row(children: [
                    Icon(Icons.auto_awesome_rounded, color: accent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Smart Automation',
                            style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
                        const SizedBox(height: 2),
                        Text(
                          'Configure automatic notifications for fee reminders, attendance alerts, and more. '
                          'Messages are sent via Push, SMS, or WhatsApp based on your settings.',
                          style: GoogleFonts.dmSans(fontSize: 12, color: CT.textS(context)),
                        ),
                      ]),
                    ),
                  ]),
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: AppDimensions.lg),

                // Quick actions
                Text('Quick Actions', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textS(context))),
                const SizedBox(height: AppDimensions.sm),
                Row(children: [
                  _buildQuickAction(
                    Icons.currency_rupee_rounded,
                    'Send Fee\nReminders Now',
                    () => _triggerManualCheck('fee'),
                    accent,
                  ),
                  const SizedBox(width: 12),
                  _buildQuickAction(
                    Icons.fact_check_rounded,
                    'Send Attendance\nAlerts Now',
                    () => _triggerManualCheck('attendance'),
                    accent,
                  ),
                ]).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: AppDimensions.lg),

                // Fee reminder rules
                _buildSectionHeader('Fee Reminders', Icons.currency_rupee_rounded),
                const SizedBox(height: AppDimensions.sm),
                ..._rules
                    .where((r) => r.type == AutoNotificationType.feeReminder ||
                        r.type == AutoNotificationType.feeDueToday ||
                        r.type == AutoNotificationType.feeOverdue)
                    .toList()
                    .asMap()
                    .entries
                    .map((e) => _buildRuleCard(e.value, accent).animate().fadeIn(delay: (60 * e.key).ms)),

                const SizedBox(height: AppDimensions.lg),

                // Attendance rules
                _buildSectionHeader('Attendance Alerts', Icons.fact_check_rounded),
                const SizedBox(height: AppDimensions.sm),
                ..._rules
                    .where((r) => r.type == AutoNotificationType.attendanceAbsent)
                    .toList()
                    .asMap()
                    .entries
                    .map((e) => _buildRuleCard(e.value, accent).animate().fadeIn(delay: (60 * e.key).ms)),

                const SizedBox(height: AppDimensions.lg),

                // Exam & results rules
                _buildSectionHeader('Exams & Results', Icons.assessment_rounded),
                const SizedBox(height: AppDimensions.sm),
                ..._rules
                    .where((r) => r.type == AutoNotificationType.examReminder ||
                        r.type == AutoNotificationType.resultPublished)
                    .toList()
                    .asMap()
                    .entries
                    .map((e) => _buildRuleCard(e.value, accent).animate().fadeIn(delay: (60 * e.key).ms)),
              ],
            ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap, Color accent) {
    return Expanded(
      child: CPPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: CT.card(context),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            border: Border.all(color: CT.border(context)),
          ),
          child: Column(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: CT.textH(context))),
          ]),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: CT.textS(context)),
      const SizedBox(width: 6),
      Text(title, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textS(context))),
    ]);
  }

  Widget _buildRuleCard(AutoNotificationRule rule, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        border: Border.all(color: rule.isEnabled ? accent.withValues(alpha: 0.3) : CT.border(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rule.title,
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
              const SizedBox(height: 2),
              Text(rule.description,
                  style: GoogleFonts.dmSans(fontSize: 12, color: CT.textS(context))),
            ]),
          ),
          Switch.adaptive(
            value: rule.isEnabled,
            onChanged: (v) => _toggleRule(rule.id, v),
            activeThumbColor: accent,
          ),
        ]),
        if (rule.isEnabled) ...[
          const SizedBox(height: 10),
          // Channel selector
          Row(children: [
            Text('Send via: ', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textM(context))),
            ...['push', 'sms', 'whatsapp', 'all'].map((ch) {
              final isActive = rule.channel == ch;
              final label = ch == 'push' ? 'Push' : ch == 'sms' ? 'SMS' : ch == 'whatsapp' ? 'WhatsApp' : 'All';
              final icon = ch == 'push'
                  ? Icons.notifications_rounded
                  : ch == 'sms'
                      ? Icons.sms_rounded
                      : ch == 'whatsapp'
                          ? Icons.chat_rounded
                          : Icons.all_inclusive_rounded;
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: CPPressable(
                  onTap: () => _updateChannel(rule.id, ch),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? accent.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      border: Border.all(color: isActive ? accent : CT.border(context)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 12, color: isActive ? accent : CT.textM(context)),
                      const SizedBox(width: 3),
                      Text(label,
                          style: GoogleFonts.dmSans(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: isActive ? accent : CT.textM(context))),
                    ]),
                  ),
                ),
              );
            }),
          ]),
          if (rule.cronExpression != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 13, color: CT.textM(context)),
              const SizedBox(width: 4),
              Text(_cronToHuman(rule.cronExpression!),
                  style: GoogleFonts.dmSans(fontSize: 11, color: CT.textM(context))),
            ]),
          ],
        ],
      ]),
    );
  }

  String _cronToHuman(String cron) {
    // Simple CRON to human-readable for display
    if (cron.contains('9 * * *')) return 'Daily at 9:00 AM';
    if (cron.contains('10 * * *')) return 'Daily at 10:00 AM';
    if (cron.contains('11 * * *')) return 'Daily at 11:00 AM';
    if (cron.contains('14 * * 1-6')) return 'Weekdays at 2:00 PM';
    if (cron.contains('18 * * *')) return 'Daily at 6:00 PM';
    return 'Scheduled';
  }
}


