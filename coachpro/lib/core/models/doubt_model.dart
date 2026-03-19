

/// Firestore model for student doubts.
class DoubtModel {
  final String id;
  final String studentId;
  final String studentName;
  final String batchId;
  final String subject;
  final String question;
  final String? imageUrl;
  final String status; // pending, answered, resolved
  final String? answer;
  final String? answeredBy; // teacher userId
  final String? answeredByName;
  final DateTime? answeredAt;
  final DateTime createdAt;

  const DoubtModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.batchId,
    required this.subject,
    required this.question,
    this.imageUrl,
    this.status = 'pending',
    this.answer,
    this.answeredBy,
    this.answeredByName,
    this.answeredAt,
    required this.createdAt,
  });

  factory DoubtModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return DoubtModel(
      id: docId,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      batchId: data['batchId'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      question: data['question'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      status: data['status'] as String? ?? 'pending',
      answer: data['answer'] as String?,
      answeredBy: data['answeredBy'] as String?,
      answeredByName: data['answeredByName'] as String?,
      answeredAt: DateTime.tryParse(data['answeredAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'batchId': batchId,
      'subject': subject,
      'question': question,
      'imageUrl': imageUrl,
      'status': status,
      'answer': answer,
      'answeredBy': answeredBy,
      'answeredByName': answeredByName,
      'answeredAt': answeredAt?.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isAnswered => status == 'answered' || status == 'resolved';
}
