

/// Firestore model for study notes/materials.
class NoteModel {
  final String id;
  final String title;
  final String? description;
  final String batchId;
  final String batchName;
  final String subject;
  final String teacherId;
  final String teacherName;
  final String fileUrl;
  final String fileType; // pdf, doc, image
  final int fileSize; // in bytes
  final int downloadCount;
  final DateTime uploadedAt;

  const NoteModel({
    required this.id,
    required this.title,
    this.description,
    required this.batchId,
    required this.batchName,
    required this.subject,
    required this.teacherId,
    required this.teacherName,
    required this.fileUrl,
    this.fileType = 'pdf',
    this.fileSize = 0,
    this.downloadCount = 0,
    required this.uploadedAt,
  });

  factory NoteModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return NoteModel(
      id: docId,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      batchId: data['batchId'] as String? ?? '',
      batchName: data['batchName'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      teacherName: data['teacherName'] as String? ?? '',
      fileUrl: data['fileUrl'] as String? ?? '',
      fileType: data['fileType'] as String? ?? 'pdf',
      fileSize: data['fileSize'] as int? ?? 0,
      downloadCount: data['downloadCount'] as int? ?? 0,
      uploadedAt: DateTime.tryParse((data['uploadedAt'])?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'batchId': batchId,
      'batchName': batchName,
      'subject': subject,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSize': fileSize,
      'downloadCount': downloadCount,
    };
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
