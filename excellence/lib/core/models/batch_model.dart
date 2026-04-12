

/// Schedule entry for a batch.
class ScheduleEntry {
  final String day; // Monday, Tuesday, etc.
  final String startTime; // "10:00 AM"
  final String endTime; // "11:30 AM"
  final String? room;

  const ScheduleEntry({
    required this.day,
    required this.startTime,
    required this.endTime,
    this.room,
  });

  factory ScheduleEntry.fromMap(Map<String, dynamic> map) {
    return ScheduleEntry(
      day: map['day'] as String? ?? '',
      startTime: map['startTime'] as String? ?? '',
      endTime: map['endTime'] as String? ?? '',
      room: map['room'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
        'room': room,
      };
}

/// Firestore model for batches/classes.
class BatchModel {
  final String id;
  final String name;
  final String? description;
  final String subject;
  final String teacherId;
  final String? teacherName;
  final List<String> studentIds;
  final List<ScheduleEntry> schedule;
  final double fee; // monthly fee
  final DateTime startDate;
  final DateTime? endDate;
  final int maxStudents;
  final bool isActive;
  final DateTime? createdAt;

  const BatchModel({
    required this.id,
    required this.name,
    this.description,
    required this.subject,
    required this.teacherId,
    this.teacherName,
    required this.studentIds,
    required this.schedule,
    required this.fee,
    required this.startDate,
    this.endDate,
    this.maxStudents = 60,
    this.isActive = true,
    this.createdAt,
  });

  factory BatchModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return BatchModel(
      id: docId,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      subject: data['subject'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      teacherName: data['teacherName'] as String?,
      studentIds: List<String>.from(data['studentIds'] ?? []),
      schedule: (data['schedule'] as List<dynamic>?)
              ?.map((e) => ScheduleEntry.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      fee: (data['fee'] as num?)?.toDouble() ?? 0,
      startDate: DateTime.tryParse(data['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(data['endDate']?.toString() ?? ''),
      maxStudents: data['maxStudents'] as int? ?? 60,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse((data['createdAt'])?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'subject': subject,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'studentIds': studentIds,
      'schedule': schedule.map((e) => e.toMap()).toList(),
      'fee': fee,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'maxStudents': maxStudents,
      'isActive': isActive,
    };
  }

  int get studentCount => studentIds.length;
  bool get isFull => studentIds.length >= maxStudents;
}
