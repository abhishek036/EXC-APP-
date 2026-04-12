import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:excellence/core/di/injection_container.dart';
import 'package:excellence/core/services/whatsapp_service.dart';
import 'package:excellence/core/services/push_notification_service.dart';
import 'package:excellence/core/services/auto_notification_service.dart';
import 'package:excellence/core/services/data_export_service.dart';
import 'package:excellence/core/services/secure_storage_service.dart';
import 'package:excellence/core/network/api_client.dart';
import 'package:excellence/core/network/network_info.dart';
import 'package:excellence/features/auth/presentation/bloc/auth_bloc.dart';

void main() {
  group('Dependency Injection', () {
    setUp(() async {
      // Reset GetIt between tests
      await GetIt.instance.reset();
      await initDependencies();
    });

    tearDown(() async {
      await GetIt.instance.reset();
    });

    test('all core services are registered', () {
      expect(sl.isRegistered<SecureStorageService>(), isTrue);
      expect(sl.isRegistered<NetworkInfo>(), isTrue);
      expect(sl.isRegistered<ApiClient>(), isTrue);
    });

    test('all feature services are registered', () {
      expect(sl.isRegistered<WhatsAppService>(), isTrue);
      expect(sl.isRegistered<PushNotificationService>(), isTrue);
      expect(sl.isRegistered<AutoNotificationService>(), isTrue);
      expect(sl.isRegistered<DataExportService>(), isTrue);
    });

    test('AuthBloc is registered as factory', () {
      expect(sl.isRegistered<AuthBloc>(), isTrue);
      // Factory returns new instance each time
      final bloc1 = sl<AuthBloc>();
      final bloc2 = sl<AuthBloc>();
      expect(identical(bloc1, bloc2), isFalse);
      bloc1.close();
      bloc2.close();
    });

    test('WhatsAppService resolves to singleton instance', () {
      final service1 = sl<WhatsAppService>();
      final service2 = sl<WhatsAppService>();
      expect(identical(service1, service2), isTrue);
    });

    test('PushNotificationService resolves to singleton instance', () {
      final service1 = sl<PushNotificationService>();
      final service2 = sl<PushNotificationService>();
      expect(identical(service1, service2), isTrue);
    });

    test('DataExportService resolves to singleton instance', () {
      final service1 = sl<DataExportService>();
      final service2 = sl<DataExportService>();
      expect(identical(service1, service2), isTrue);
    });

    test('AutoNotificationService resolves to singleton instance', () {
      final service1 = sl<AutoNotificationService>();
      final service2 = sl<AutoNotificationService>();
      expect(identical(service1, service2), isTrue);
    });
  });
}

