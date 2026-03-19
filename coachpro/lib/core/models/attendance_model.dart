

/// Individual attendance record for a student.
class AttendanceRecord {
  final String studentId;
  final String studentName;
  final String status; // P (Present), A (Absent), L (Late), Leave
  final String? note;

  const AttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.status,
    this.note,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      status: map['status'] as String? ?? 'A',
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'studentName': studentName,
        'status': status,
        'note': note,
      };
}

/// Firestore model for daily attendance of a batch.
class AttendanceModel {
  final String id;
  final String batchId;
  final String batchName;
  final DateTime date;
  final String markedBy; // teacher userId
  final String markedByName;
  final List<AttendanceRecord> records;
  final int present;
  final int absent;
  final int late;
  final int leave;
  final DateTime? createdAt;

  const AttendanceModel({
    required this.id,
    required this.batchId,
    required this.batchName,
    required this.date,
    required this.markedBy,
    required this.markedByName,
    required this.records,
    this.present = 0,
    this.absent = 0,
    this.late = 0,
    this.leave = 0,
    this.createdAt,
  });

  factory AttendanceModel.fromFirestore(Map<String, dynamic> data, String docId) {
    final recordsList = (data['records'] as List<dynamic>?)
            ?.map((e) => AttendanceRecord.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    return AttendanceModel(
      id: docId,
      batchId: data['batchId'] as String? ?? '',
      batchName: data['batchName'] as String? ?? '',
      date: DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now(),
      markedBy: data['markedBy'] as String? ?? '',
      markedByName: data['markedByName'] as String? ?? '',
      records: recordsList,
      present: summary['present'] as int? ?? 0,
      absent: summary['absent'] as int? ?? 0,
      late: summary['late'] as int? ?? 0,
      leave: summary['leave'] as int? ?? 0,
      createdAt: DateTime.tryParse((data['createdAt'])?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'batchId': batchId,
      'batchName': batchName,
      'date': date.toIso8601String(),
      'markedBy': markedBy,
      'markedByName': markedByName,
      'records': records.map((r) => r.toMap()).toList(),
      'summary': {
        'present': present,
        'absent': absent,
        'late': late,
        'leave': leave,
      },
    };
  }

  int get total => records.length;
  double get presentPercentage => total > 0 ? (present / total) * 100 : 0;
}
