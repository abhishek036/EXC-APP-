import '../../domain/entities/user_entity.dart';

/// Lightweight data‑layer model.
/// When the real backend is wired, add `fromJson` / `toJson`.
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.phone,
    super.email,
    required super.role,
    super.avatarUrl,
    super.createdAt,
  });

  /// Factory from backend response.
  /// Handles both Firestore (camelCase) and local storage (snake_case) keys.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle createdAt from either Firestore Timestamp or ISO string
    DateTime? createdAt;
    final rawCreated = json['createdAt'] ?? json['created_at'];
    if (rawCreated != null) {
      if (rawCreated is String) {
        createdAt = DateTime.tryParse(rawCreated);
      } else if (rawCreated is DateTime) {
        createdAt = rawCreated;
      } else {
        // Firestore Timestamp → .toDate()
        try {
          createdAt = (rawCreated as dynamic).toDate() as DateTime;
        } catch (_) {}
      }
    }

    return UserModel(
      id: (json['id'] ?? json['uid'] ?? '') as String,
      name: (json['name'] ?? 'User') as String,
      phone: (json['phone'] ?? '') as String,
      email: json['email'] as String?,
      role: AppRole.values.firstWhere(
        (r) {
          final rawRole = (json['role'] ?? '').toString().toLowerCase();
          final normalizedRole =
              rawRole == 'super_admin' || rawRole == 'sub_admin' ? 'admin' : rawRole;
          return r.name == normalizedRole;
        },
        orElse: () => AppRole.student,
      ),
      avatarUrl: (json['avatarUrl'] ?? json['avatar_url']) as String?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'role': role.name,
        'avatar_url': avatarUrl,
        'created_at': createdAt?.toIso8601String(),
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    AppRole? role,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Quickly create a mock user (frontend‑only until backend is ready).
  factory UserModel.mock(AppRole role) {
    final label = role.name[0].toUpperCase() + role.name.substring(1);
    return UserModel(
      id: 'mock_${role.name}_001',
      name: 'Demo $label',
      phone: '9876543210',
      email: '${role.name}@excellenceacademy.app',
      role: role,
      createdAt: DateTime.now(),
    );
  }
}
