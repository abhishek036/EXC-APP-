import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../network/network_info.dart';
import '../services/secure_storage_service.dart';
import '../services/api_auth_service.dart';
import '../services/whatsapp_service.dart';
import '../services/push_notification_service.dart';
import '../services/auto_notification_service.dart';
import '../services/data_export_service.dart';
import '../services/app_update_service.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/admin/data/repositories/admin_repository.dart';
import '../../features/student/data/repositories/student_repository.dart';
import '../../features/teacher/data/repositories/teacher_repository.dart';
import '../../features/parent/data/repositories/parent_repository.dart';
import '../../features/chat/data/repositories/chat_repository.dart';
import '../../features/gamification/data/repositories/gamification_repository.dart';

/// Service Locator instance – importable anywhere.
final sl = GetIt.instance;

/// Call once before runApp().
Future<void> initDependencies() async {
  // ── Auth services ──────────────────────────────────────
  sl.registerLazySingleton<ApiAuthService>(
    () => ApiAuthService(),
  );

  // ── Core services ──────────────────────────────────────
  sl.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(),
  );

  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(),
  );

  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(),
  );

  // ── Feature services ───────────────────────────────────
  sl.registerLazySingleton<WhatsAppService>(
    () => WhatsAppService.instance,
  );

  sl.registerLazySingleton<PushNotificationService>(
    () => PushNotificationService.instance,
  );

  sl.registerLazySingleton<AutoNotificationService>(
    () => AutoNotificationService.instance,
  );

  sl.registerLazySingleton<DataExportService>(
    () => DataExportService.instance,
  );

  sl.registerLazySingleton<AppUpdateService>(
    () => AppUpdateService(),
  );

  sl.registerLazySingleton<AdminRepository>(
    () => AdminRepository(),
  );

  sl.registerLazySingleton<StudentRepository>(
    () => StudentRepository(),
  );

  sl.registerLazySingleton<TeacherRepository>(
    () => TeacherRepository(),
  );

  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepository(),
  );

  sl.registerLazySingleton<ParentRepository>(
    () => ParentRepository(),
  );

  sl.registerLazySingleton<GamificationRepository>(
    () => GamificationRepository(),
  );

  // ── BLoCs ──────────────────────────────────────────────
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      storage: sl<SecureStorageService>(),
      apiAuth: sl<ApiAuthService>(),
    ),
  );
}
