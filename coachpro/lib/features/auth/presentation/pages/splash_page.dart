import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/auth_bloc.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  /// Play animations for 2.8 s then tell AuthBloc to check stored session.
  /// GoRouter redirect handles the navigation based on the resulting state.
  Future<void> _initAuth() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (mounted) {
      context.read<AuthBloc>().add(const AuthCheckRequested());
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

          // Loading dots at bottom center
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) =>
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white54,
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(
                      delay: Duration(milliseconds: 800 + i * 200),
                      onPlay: (c) => c.repeat(reverse: true),
                    )
                    .scaleXY(begin: 0.6, end: 1.2, duration: 600.ms)
                    .fadeIn(duration: 400.ms),
              ),
            ),
          ),

          // Bottom version text
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'v1.0.0',
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
