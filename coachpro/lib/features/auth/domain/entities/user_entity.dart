import 'package:equatable/equatable.dart';

/// Roles available in Excellence Academy.
/// Kept separate from the UI‑only [UserRole] in login_page.dart
/// so domain logic never imports presentation code.
enum AppRole { admin, teacher, student, parent }

/// Pure domain entity – no JSON / serialisation here (that belongs in data layer).
class UserEntity extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final AppRole role;
  final String? avatarUrl;
  final DateTime? createdAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.avatarUrl,
    this.createdAt,
  });

  /// Convenience: role‑based route prefix used by GoRouter.
  String get dashboardPath {
    switch (role) {
      case AppRole.admin:
        return '/admin';
      case AppRole.teacher:
        return '/teacher';
      case AppRole.student:
        return '/student';
      case AppRole.parent:
        return '/parent';
    }
  }

  @override
  List<Object?> get props => [id, name, phone, email, role, avatarUrl, createdAt];
}
