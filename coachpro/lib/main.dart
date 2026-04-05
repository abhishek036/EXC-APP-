import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/constants/app_colors.dart';
import 'core/di/injection_container.dart';
import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/l10n/app_localizations.dart';
import 'core/l10n/app_locales.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

/// Global notifier for ThemeMode toggling.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  // Initialise dependency injection
  await initDependencies();

  // Initialize Firebase push notifications (best effort)
  try {
    await sl<PushNotificationService>().initialize();
  } catch (_) {}

  // Restore theme preference
  try {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  } catch (_) {}

  // Restore saved language preference
  await AppLocalizations.loadSavedLocale();

  // Save theme on change
  themeNotifier.addListener(() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
    } catch (_) {}
  });

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 60),
                const SizedBox(height: 16),
                Text(
                  'Oops! Something went wrong',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We are working on fixing it. Please restart the app.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  runApp(const ExcellenceAcademyApp());
}

class ExcellenceAcademyApp extends StatefulWidget {
  const ExcellenceAcademyApp({super.key});

  @override
  State<ExcellenceAcademyApp> createState() => _ExcellenceAcademyAppState();
}

class _ExcellenceAcademyAppState extends State<ExcellenceAcademyApp> with WidgetsBindingObserver {
  late final AuthBloc _authBloc;
  late final GoRouter _router;
  Timer? _authSyncTimer;
  StreamSubscription<Map<String, dynamic>>? _notificationTapSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Create the BLoC and Router once.
    // Splash page will fire the first AuthCheckRequested.
    _authBloc = sl<AuthBloc>();
    _router = AppRouter.router(_authBloc);
    _startAuthSyncTimer();
    _notificationTapSub = sl<PushNotificationService>().onNotificationTap.listen((payload) {
      final route = _normalizeNotificationRoute(payload['route']?.toString());
      if (route != null && route.isNotEmpty) {
        _router.go(route);
      }
    });
  }

  String? _normalizeNotificationRoute(String? route) {
    if (route == null || route.isEmpty) return null;

    switch (route) {
      case '/student/quizzes':
        return '/student/quiz';
      case '/teacher/quizzes':
        return '/teacher/batches';
      default:
        return route;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSyncTimer?.cancel();
    _notificationTapSub?.cancel();
    super.dispose();
  }

  void _startAuthSyncTimer() {
    _authSyncTimer?.cancel();
    _authSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _authBloc.add(const AuthRefreshRequested());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );
      // Quietly refresh auth state when app comes back to foreground
      _authBloc.add(const AuthRefreshRequested());
      unawaited(sl<PushNotificationService>().syncTokenRegistration());
      _startAuthSyncTimer();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _authSyncTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, ThemeMode currentMode, child) {
          final isDark = currentMode == ThemeMode.dark;
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: isDark ? const Color(0xFF212529) : Colors.white,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ));
          return ValueListenableBuilder<Locale>(
            valueListenable: localeNotifier,
            builder: (context, Locale currentLocale, child) {
              return MaterialApp.router(
                title: 'Excellence Academy',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: currentMode,
                locale: currentLocale,
                supportedLocales: AppLocales.supported,
                builder: (context, child) {
                  return SafeArea(
                    top: false,
                    left: false,
                    right: false,
                    bottom: true,
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                routerConfig: _router,
              );
            },
          );
        },
      ),
    );
  }
}
