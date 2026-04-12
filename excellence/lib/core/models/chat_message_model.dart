

/// Firestore model for chat messages (subcollection under batches).
class ChatMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole; // admin, teacher, student
  final String? text;
  final String? imageUrl;
  final String? fileUrl;
  final String type; // text, image, file
  final DateTime sentAt;

  const ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.text,
    this.imageUrl,
    this.fileUrl,
    this.type = 'text',
    required this.sentAt,
  });

  factory ChatMessageModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return ChatMessageModel(
      id: docId,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      senderRole: data['senderRole'] as String? ?? 'student',
      text: data['text'] as String?,
      imageUrl: data['imageUrl'] as String?,
      fileUrl: data['fileUrl'] as String?,
      type: data['type'] as String? ?? 'text',
      sentAt: DateTime.tryParse((data['sentAt'])?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'text': text,
      'imageUrl': imageUrl,
      'fileUrl': fileUrl,
      'type': type,
      'sentAt': sentAt.toIso8601String(),
    };
  }

  bool get isTextMessage => type == 'text';
  bool get isImageMessage => type == 'image';
  bool get isFileMessage => type == 'file';
}
