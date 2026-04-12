

/// Firestore model for notifications/announcements.
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // announcement, fee_reminder, attendance, result, general
  final String targetType; // all, role, batch, student
  final String? targetId;
  final String? targetRole;
  final String sentBy;
  final String sentByName;
  final List<String> readBy;
  final List<String> channels; // push, whatsapp, sms
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'general',
    this.targetType = 'all',
    this.targetId,
    this.targetRole,
    required this.sentBy,
    required this.sentByName,
    this.readBy = const [],
    this.channels = const ['push'],
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return NotificationModel(
      id: docId,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'general',
      targetType: data['targetType'] as String? ?? 'all',
      targetId: data['targetId'] as String?,
      targetRole: data['targetRole'] as String?,
      sentBy: data['sentBy'] as String? ?? '',
      sentByName: data['sentByName'] as String? ?? '',
      readBy: List<String>.from(data['readBy'] ?? []),
      channels: List<String>.from(data['channels'] ?? ['push']),
      createdAt: DateTime.tryParse((data['createdAt'])?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'targetType': targetType,
      'targetId': targetId,
      'targetRole': targetRole,
      'sentBy': sentBy,
      'sentByName': sentByName,
      'readBy': readBy,
      'channels': channels,
    };
  }

  bool isReadBy(String userId) => readBy.contains(userId);
}
