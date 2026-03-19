import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service to handle WhatsApp integration for coaching centers.
/// Supports sending attendance, fee reminders, results, and announcements
/// to parents via WhatsApp / WhatsApp Business API.
class WhatsAppService {
  WhatsAppService._();
  static final instance = WhatsAppService._();

  /// Country code prefix (default India).
  static const _countryCode = '91';

  /// Format phone number for WhatsApp (strip leading 0, add country code).
  @visibleForTesting
  String formatPhone(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('0')) cleaned = cleaned.substring(1);
    if (!cleaned.startsWith(_countryCode) && cleaned.length == 10) {
      cleaned = '$_countryCode$cleaned';
    }
    return cleaned;
  }

  /// Open WhatsApp chat with a pre-filled message.
  Future<bool> sendMessage({required String phone, required String message}) async {
    final formattedPhone = formatPhone(phone);
    if (formattedPhone.isEmpty) return false;
    final encodedMessage = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$formattedPhone?text=$encodedMessage');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Build attendance notification message.
  String buildAttendanceMessage({
    required String studentName,
    required String status,
    required String batchName,
    required String date,
  }) {
    return '📋 *Attendance Update*\n\n'
        'Dear Parent,\n\n'
        'Student: *$studentName*\n'
        'Batch: $batchName\n'
        'Date: $date\n'
        'Status: *$status*\n\n'
        '${status == 'Absent' ? '⚠️ Please ensure regular attendance for better results.\n\n' : ''}'
        '— Excellence Academy';
  }

  /// Build fee reminder message.
  String buildFeeReminderMessage({
    required String studentName,
    required double amount,
    required String dueDate,
    required String batchName,
  }) {
    return '💰 *Fee Reminder*\n\n'
        'Dear Parent,\n\n'
        'Student: *$studentName*\n'
        'Batch: $batchName\n'
        'Amount Due: *₹${amount.toStringAsFixed(0)}*\n'
        'Due Date: *$dueDate*\n\n'
        'Please clear the pending fee to avoid late charges.\n\n'
        '— Excellence Academy';
  }

  /// Build exam result message.
  String buildResultMessage({
    required String studentName,
    required String examName,
    required int scored,
    required int total,
    required int rank,
    required String batchName,
  }) {
    final percentage = ((scored / total) * 100).toStringAsFixed(1);
    return '📊 *Exam Results*\n\n'
        'Dear Parent,\n\n'
        'Student: *$studentName*\n'
        'Exam: $examName\n'
        'Score: *$scored/$total ($percentage%)*\n'
        'Rank: *#$rank* in $batchName\n\n'
        '${double.parse(percentage) >= 80 ? '🌟 Great performance! Keep it up!' : 'Focus on weak areas for improvement.'}\n\n'
        '— Excellence Academy';
  }

  /// Build general announcement message.
  String buildAnnouncementMessage({
    required String title,
    required String body,
    required String instituteName,
  }) {
    return '📢 *$title*\n\n'
        '$body\n\n'
        '— $instituteName via Excellence Academy';
  }
}
