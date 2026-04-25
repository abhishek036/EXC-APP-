String? resolveNotificationRoute(
  Map<String, dynamic> payload, {
  String? currentRolePrefix,
}) {
  final rawRoute = payload['route']?.toString().trim();
  final meta = payload['meta'] is Map
      ? Map<String, dynamic>.from(payload['meta'] as Map)
      : <String, dynamic>{};
  final roleTarget = (payload['role_target'] ?? meta['role_target'])
      ?.toString()
      .trim();
  final type = (payload['type'] ?? meta['type'])?.toString().trim();
  final studentId = (meta['student_id'] ?? payload['student_id'])
      ?.toString()
      .trim();

  String parentRoute() {
    if (studentId != null && studentId.isNotEmpty) {
      return '/parent/weekly-report/$studentId';
    }
    return '/parent';
  }

  String? normalizeLegacyRoute(String? route) {
    if (route == null || route.isEmpty) return null;

    switch (route) {
      case '/student/quizzes':
        return '/student/quiz';
      case '/teacher/quizzes':
        return '/teacher/batches';
      case '/student/attendance':
        return '/student/performance';
      case '/parent/attendance':
      case '/parent/results':
        return parentRoute();
      default:
        return route;
    }
  }

  final normalizedRoute = normalizeLegacyRoute(rawRoute);
  if (normalizedRoute != null) {
    return normalizedRoute;
  }

  final role = (roleTarget != null && roleTarget.isNotEmpty)
      ? roleTarget
      : ((currentRolePrefix ?? '').startsWith('/')
          ? currentRolePrefix!.substring(1)
          : currentRolePrefix ?? '');

  switch (role) {
    case 'student':
      switch (type) {
        case 'attendance':
          return '/student/performance';
        case 'result':
          return '/student/results';
        case 'doubt':
          return '/student/doubts/history';
        case 'material':
        case 'content':
          return '/student/materials';
        case 'class':
          return '/student/timetable';
        case 'exam':
        case 'quiz':
          return '/student/quiz';
      }
      return '/student';
    case 'teacher':
      switch (type) {
        case 'attendance':
          return '/teacher/attendance';
        case 'result':
        case 'exam':
        case 'quiz':
          return '/teacher/batches';
        case 'doubt':
          return '/teacher/doubts';
        case 'material':
        case 'content':
          return '/teacher/upload-material';
        case 'class':
          return '/teacher/schedule';
      }
      return '/teacher';
    case 'parent':
      switch (type) {
        case 'attendance':
        case 'result':
        case 'exam':
        case 'quiz':
        case 'material':
        case 'content':
        case 'class':
          return parentRoute();
      }
      return '/parent';
    case 'admin':
      switch (type) {
        case 'attendance':
          return '/admin/attendance';
        case 'result':
          return '/admin/reports';
        case 'doubt':
          return '/admin/all-functions';
        case 'material':
        case 'content':
        case 'exam':
        case 'quiz':
          return '/admin/exams';
        case 'class':
          return '/admin/timetable';
      }
      return '/admin';
    default:
      return null;
  }
}