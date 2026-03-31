import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../di/injection_container.dart';
import '../network/api_client.dart';

/// Types of automated notifications.
enum AutoNotificationType {
  feeReminder,
  feeDueToday,
  feeOverdue,
  attendanceAbsent,
  examReminder,
  resultPublished,
  batchScheduleChange,
}

/// A scheduled automated notification rule.
class AutoNotificationRule {
  final String id;
  final AutoNotificationType type;
  final String title;
  final String description;
  final bool isEnabled;
  final int daysBefore; // For reminders, how many days before
  final String channel; // 'push', 'sms', 'whatsapp', 'all'
  final String? cronExpression; // For recurring (e.g., daily check)

  const AutoNotificationRule({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.isEnabled = true,
    this.daysBefore = 3,
    this.channel = 'push',
    this.cronExpression,
  });

  AutoNotificationRule copyWith({
    bool? isEnabled,
    int? daysBefore,
    String? channel,
  }) => AutoNotificationRule(
    id: id,
    type: type,
    title: title,
    description: description,
    isEnabled: isEnabled ?? this.isEnabled,
    daysBefore: daysBefore ?? this.daysBefore,
    channel: channel ?? this.channel,
    cronExpression: cronExpression,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'description': description,
    'isEnabled': isEnabled,
    'daysBefore': daysBefore,
    'channel': channel,
    'cronExpression': cronExpression,
  };

  factory AutoNotificationRule.fromJson(Map<String, dynamic> json) =>
      AutoNotificationRule(
        id: json['id'] as String,
        type: AutoNotificationType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => AutoNotificationType.feeReminder,
        ),
        title: json['title'] as String,
        description: json['description'] as String,
        isEnabled: json['isEnabled'] as bool? ?? true,
        daysBefore: json['daysBefore'] as int? ?? 3,
        channel: json['channel'] as String? ?? 'push',
        cronExpression: json['cronExpression'] as String?,
      );
}

/// Service to manage automated fee due date reminders and other scheduled notifications.
///
/// In production, this coordinates with the backend (Bull Queue / cron jobs)
/// to schedule and send notifications. The client manages rules and preferences.
class AutoNotificationService {
  AutoNotificationService._();
  static final instance = AutoNotificationService._();

  /// Default rules that ship with the app.
  static final List<AutoNotificationRule> defaultRules = [
    const AutoNotificationRule(
      id: 'fee_3day',
      type: AutoNotificationType.feeReminder,
      title: 'Fee Due in 3 Days',
      description: 'Remind parents 3 days before fee due date',
      daysBefore: 3,
      channel: 'all',
      cronExpression: '0 9 * * *', // Daily at 9 AM
    ),
    const AutoNotificationRule(
      id: 'fee_1day',
      type: AutoNotificationType.feeReminder,
      title: 'Fee Due Tomorrow',
      description: 'Remind parents 1 day before fee due date',
      daysBefore: 1,
      channel: 'all',
      cronExpression: '0 9 * * *',
    ),
    const AutoNotificationRule(
      id: 'fee_today',
      type: AutoNotificationType.feeDueToday,
      title: 'Fee Due Today',
      description: 'Notify parents on the fee due date',
      daysBefore: 0,
      channel: 'all',
      cronExpression: '0 10 * * *',
    ),
    const AutoNotificationRule(
      id: 'fee_overdue',
      type: AutoNotificationType.feeOverdue,
      title: 'Fee Overdue Alert',
      description: 'Alert parents when fee is overdue (daily)',
      daysBefore: -1,
      channel: 'push',
      cronExpression: '0 11 * * *',
    ),
    const AutoNotificationRule(
      id: 'attendance_absent',
      type: AutoNotificationType.attendanceAbsent,
      title: 'Absence Notification',
      description: 'Notify parents when student is marked absent',
      channel: 'all',
      cronExpression: '0 14 * * 1-6', // Weekdays at 2 PM
    ),
    const AutoNotificationRule(
      id: 'exam_reminder',
      type: AutoNotificationType.examReminder,
      title: 'Exam Reminder',
      description: 'Remind students 2 days before exam',
      daysBefore: 2,
      channel: 'push',
      cronExpression: '0 18 * * *',
    ),
    const AutoNotificationRule(
      id: 'result_published',
      type: AutoNotificationType.resultPublished,
      title: 'Result Published',
      description: 'Notify students & parents when results are published',
      channel: 'all',
    ),
  ];

  /// Load saved rules (or return defaults).
  Future<List<AutoNotificationRule>> loadRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('auto_notification_rules');
      if (stored != null && stored.isNotEmpty) {
        return stored
            .map(
              (s) => AutoNotificationRule.fromJson(
                jsonDecode(s) as Map<String, dynamic>,
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading auto notification rules: $e');
    }
    return List.from(defaultRules);
  }

  /// Save rules to preferences.
  Future<void> saveRules(List<AutoNotificationRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'auto_notification_rules',
      rules.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  /// Toggle a specific rule.
  Future<List<AutoNotificationRule>> toggleRule(
    String ruleId,
    bool enabled,
  ) async {
    final rules = await loadRules();
    final updated = rules
        .map((r) => r.id == ruleId ? r.copyWith(isEnabled: enabled) : r)
        .toList();
    await saveRules(updated);

    // TODO: Sync with backend
    // await apiClient.put('/notifications/rules/$ruleId', data: {'enabled': enabled});

    return updated;
  }

  /// Update delivery channel for a rule.
  Future<List<AutoNotificationRule>> updateChannel(
    String ruleId,
    String channel,
  ) async {
    final rules = await loadRules();
    final updated = rules
        .map((r) => r.id == ruleId ? r.copyWith(channel: channel) : r)
        .toList();
    await saveRules(updated);
    return updated;
  }

  /// Trigger a manual fee reminder check (admin action).
  Future<void> triggerFeeReminders() async {
    try {
      await sl<ApiClient>().dio.post('notifications/trigger/fee-reminders');
    } catch (error) {
      debugPrint('Fee reminder trigger failed: $error');
      rethrow;
    }
  }

  /// Trigger manual attendance notifications.
  Future<void> triggerAttendanceNotifications() async {
    try {
      await sl<ApiClient>().dio.post('notifications/trigger/class-reminders');
    } catch (error) {
      debugPrint('Attendance notification trigger failed: $error');
      rethrow;
    }
  }
}
