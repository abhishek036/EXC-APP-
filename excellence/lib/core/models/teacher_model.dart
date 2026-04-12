

/// Firestore model for teacher-specific data.
class TeacherModel {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final List<String> subjects;
  final List<String> batchIds;
  final String? email;
  final String? avatarUrl;
  final String? qualification;
  final double? salary;
  final DateTime joiningDate;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TeacherModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.subjects,
    required this.batchIds,
    this.email,
    this.avatarUrl,
    this.qualification,
    this.salary,
    required this.joiningDate,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory TeacherModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return TeacherModel(
      id: docId,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      subjects: List<String>.from(data['subjects'] ?? []),
      batchIds: List<String>.from(data['batchIds'] ?? []),
      email: data['email'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      qualification: data['qualification'] as String?,
      salary: (data['salary'] as num?)?.toDouble(),
      joiningDate: DateTime.tryParse(data['joiningDate']?.toString() ?? '') ?? DateTime.now(),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse((data['updatedAt'])?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      'subjects': subjects,
      'batchIds': batchIds,
      'email': email,
      'avatarUrl': avatarUrl,
      'qualification': qualification,
      'salary': salary,
      'joiningDate': joiningDate.toIso8601String(),
      'isActive': isActive,
    };
  }
}
