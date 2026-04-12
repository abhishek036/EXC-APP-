/// All API endpoint paths.
/// Update these when backend is ready.
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login           = 'auth/login';
  static const String logout          = 'auth/logout';
  static const String refreshToken    = 'auth/refresh';
  static const String sendOtp         = 'auth/otp/send';
  static const String verifyOtp       = 'auth/otp/verify';
  static const String forgotPassword  = 'auth/forgot-password';
  // Backend exposes password reset at /api/auth/password/reset
  static const String resetPassword   = 'auth/password/reset';
  static const String authMe          = 'auth/me';

  // Users
  static const String profile         = 'auth/me';
  static const String updateProfile   = 'auth/me';
  // Some deployments expose name update at a dedicated route
  static const String updateProfileName = 'auth/me/name';
  static const String uploadAvatar     = 'auth/me/avatar';
  static const String changePassword  = 'auth/password/change';

  // Students
  static const String students        = 'students';
  static String studentById(String id) => 'students/$id';

  // Teachers
  static const String teachers        = 'teachers';
  static String teacherById(String id) => 'teachers/$id';

  // Batches
  static const String batches         = 'batches';
  static String batchById(String id)  => 'batches/$id';

  // Attendance
  static const String attendance      = 'attendance';
  static const String markAttendance  = 'attendance/mark';

  // Fees
  static const String fees            = 'fees';
  static const String feePayment      = 'fees/pay';

  // Exams & Quizzes
  static const String exams           = 'exams';
  static const String quizzes         = 'quizzes';
  static String quizById(String id)   => 'quizzes/$id';

  // Study Materials
  static const String materials       = 'materials';
  static const String uploadMaterial  = 'materials/upload';

  // Doubts
  static const String doubts          = 'doubts';
  static String resolveDoubtById(String id) => 'doubts/$id/resolve';

  // Announcements
  static const String announcements   = 'announcements';

  // Notifications
  static const String notifications   = 'notifications';

  // Chat
  static const String chatRooms       = 'chat/rooms';
  // Backend uses batch-scoped chat endpoints
  static String chatBatchHistory(String batchId) => 'chat/batch/$batchId/history';
  static String chatBatchMessages(String batchId) => 'chat/batch/$batchId/messages';

  // Student-specific notifications (backend: /api/students/me/notifications)
  static const String studentNotificationsMe = 'students/me/notifications';

  // App Update
  static const String appUpdatePolicy = 'app-update/policy';
}
