import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/app_update_service.dart';
import '../bloc/auth_bloc.dart';
import '../../../../core/theme/theme_aware.dart';
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with ThemeAware<SplashPage> {
  String _appVersion = 'v1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _initAuth();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = 'v${info.version}');
      }
    } catch (_) {}
  }

  /// Play animations for 2.8 s then tell AuthBloc to check stored session.
  /// GoRouter redirect handles the navigation based on the resulting state.
  Future<void> _initAuth() async {
    await Future.delayed(const Duration(milliseconds: 800));

    final updateDecision = await sl<AppUpdateService>().checkPolicy();
    if (!mounted) return;

    if (updateDecision.forceUpdate) {
      final params = <String, String>{
        'latest': updateDecision.latestVersion,
        'min': updateDecision.minSupportedVersion,
        if (updateDecision.storeUrl.isNotEmpty) 'storeUrl': updateDecision.storeUrl,
      };
      context.go(Uri(path: '/update', queryParameters: params).toString());
      return;
    }

    if (updateDecision.recommendUpdate &&
        await sl<AppUpdateService>().shouldShowOptionalPrompt(updateDecision.latestVersion) &&
        mounted) {
      final updateNow = await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (ctx) => AlertDialog(
              title: const Text('Update available'),
              content: Text(
                'A newer version (${updateDecision.latestVersion}) is available. Update now for the latest fixes and improvements.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Later'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Update now'),
                ),
              ],
            ),
          ) ??
          false;

      if (!mounted) return;

      if (updateNow) {
        await sl<AppUpdateService>().openStore(updateDecision.storeUrl);
      } else {
        await sl<AppUpdateService>().markOptionalPromptSkipped(updateDecision.latestVersion);
      }
    }

    if (mounted) {
      context.read<AuthBloc>().add(AuthCheckRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen background image
          Image.asset(
            'assets/images/splash_bg.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ).animate().fadeIn(duration: 800.ms),


          // Bottom version text
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _appVersion,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: Colors.white30,
                ),
              ).animate(delay: 1000.ms).fadeIn(duration: 500.ms),
            ),
          ),
        ],
      ),
    );
  }
}


