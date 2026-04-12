

/// Firestore model for exams.
class ExamModel {
  final String id;
  final String title;
  final String batchId;
  final String batchName;
  final String subject;
  final DateTime date;
  final int totalMarks;
  final int duration; // in minutes
  final String type; // unit_test, mid_term, final, quiz
  final String? syllabus;
  final String createdBy;
  final DateTime? createdAt;

  const ExamModel({
    required this.id,
    required this.title,
    required this.batchId,
    required this.batchName,
    required this.subject,
    required this.date,
    required this.totalMarks,
    required this.duration,
    this.type = 'unit_test',
    this.syllabus,
    required this.createdBy,
    this.createdAt,
  });

  factory ExamModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return ExamModel(
      id: docId,
      title: data['title'] as String? ?? '',
      batchId: data['batchId'] as String? ?? '',
      batchName: data['batchName'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      date: DateTime.tryParse((data['date'])?.toString() ?? '') ?? DateTime.now(),
      totalMarks: data['totalMarks'] as int? ?? 0,
      duration: data['duration'] as int? ?? 60,
      type: data['type'] as String? ?? 'unit_test',
      syllabus: data['syllabus'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'batchId': batchId,
      'batchName': batchName,
      'subject': subject,
      'date': date.toIso8601String(),
      'totalMarks': totalMarks,
      'duration': duration,
      'type': type,
      'syllabus': syllabus,
      'createdBy': createdBy,
    };
  }

  bool get isUpcoming => date.isAfter(DateTime.now());
}

/// Firestore model for exam results.
class ResultModel {
  final String id;
  final String examId;
  final String examTitle;
  final String studentId;
  final String studentName;
  final String batchId;
  final String subject;
  final int marksObtained;
  final int totalMarks;
  final double percentage;
  final String? grade;
  final int? rank;
  final String? remarks;
  final DateTime? createdAt;

  const ResultModel({
    required this.id,
    required this.examId,
    required this.examTitle,
    required this.studentId,
    required this.studentName,
    required this.batchId,
    required this.subject,
    required this.marksObtained,
    required this.totalMarks,
    required this.percentage,
    this.grade,
    this.rank,
    this.remarks,
    this.createdAt,
  });

  factory ResultModel.fromFirestore(Map<String, dynamic> data, String docId) {
    final marks = data['marksObtained'] as int? ?? 0;
    final total = data['totalMarks'] as int? ?? 1;
    return ResultModel(
      id: docId,
      examId: data['examId'] as String? ?? '',
      examTitle: data['examTitle'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      batchId: data['batchId'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      marksObtained: marks,
      totalMarks: total,
      percentage: data['percentage'] as double? ?? (marks / total * 100),
      grade: data['grade'] as String?,
      rank: data['rank'] as int?,
      remarks: data['remarks'] as String?,
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'examId': examId,
      'examTitle': examTitle,
      'studentId': studentId,
      'studentName': studentName,
      'batchId': batchId,
      'subject': subject,
      'marksObtained': marksObtained,
      'totalMarks': totalMarks,
      'percentage': percentage,
      'grade': grade,
      'rank': rank,
      'remarks': remarks,
    };
  }
}
