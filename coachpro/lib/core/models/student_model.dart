

/// Firestore model for student-specific data.
class StudentModel {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String rollNumber;
  final List<String> batchIds;
  final String? parentId;
  final String? parentPhone;
  final String? parentName;
  final DateTime? dateOfBirth;
  final String? address;
  final String? email;
  final String? avatarUrl;
  final DateTime enrollmentDate;
  final String status; // active, inactive, passed_out
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StudentModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.rollNumber,
    required this.batchIds,
    this.parentId,
    this.parentPhone,
    this.parentName,
    this.dateOfBirth,
    this.address,
    this.email,
    this.avatarUrl,
    required this.enrollmentDate,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  factory StudentModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return StudentModel(
      id: docId,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      rollNumber: data['rollNumber'] as String? ?? '',
      batchIds: List<String>.from(data['batchIds'] ?? []),
      parentId: data['parentId'] as String?,
      parentPhone: data['parentPhone'] as String?,
      parentName: data['parentName'] as String?,
      dateOfBirth: DateTime.tryParse(data['dateOfBirth']?.toString() ?? ''),
      address: data['address'] as String?,
      email: data['email'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      enrollmentDate: DateTime.tryParse(data['enrollmentDate']?.toString() ?? '') ?? DateTime.now(),
      status: data['status'] as String? ?? 'active',
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      'rollNumber': rollNumber,
      'batchIds': batchIds,
      'parentId': parentId,
      'parentPhone': parentPhone,
      'parentName': parentName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'address': address,
      'email': email,
      'avatarUrl': avatarUrl,
      'enrollmentDate': enrollmentDate.toIso8601String(),
      'status': status,
    };
  }

  StudentModel copyWith({
    String? name,
    String? phone,
    String? rollNumber,
    List<String>? batchIds,
    String? parentId,
    String? parentPhone,
    String? parentName,
    DateTime? dateOfBirth,
    String? address,
    String? email,
    String? avatarUrl,
    String? status,
  }) {
    return StudentModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      rollNumber: rollNumber ?? this.rollNumber,
      batchIds: batchIds ?? this.batchIds,
      parentId: parentId ?? this.parentId,
      parentPhone: parentPhone ?? this.parentPhone,
      parentName: parentName ?? this.parentName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      enrollmentDate: enrollmentDate,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
