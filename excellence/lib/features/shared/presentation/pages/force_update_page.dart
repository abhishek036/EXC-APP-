import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/theme/theme_aware.dart';

class ForceUpdatePage extends StatelessWidget {
  final String latestVersion;
  final String minSupportedVersion;
  final String storeUrl;

  const ForceUpdatePage({
    super.key,
    this.latestVersion = '',
    this.minSupportedVersion = '',
    this.storeUrl = '',
  });

  @override
  Widget build(BuildContext context) {
    final accent = CT.accent(context);
    final isDark = CT.isDark(context);

    return Scaffold(
      backgroundColor: CT.bg(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
          child: Column(
            children: [
              const Spacer(),
              
              // NEO-BRUTALIST ILLUSTRATION
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.moltenAmber,
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(6, 6)),
                  ],
                ),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.rocket_launch_rounded,
                      size: 100,
                      color: Colors.black,
                    ),
                  ],
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
              
              const SizedBox(height: 60),
              
              Text(
                'SYSTEM UPGRADE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: CT.textH(context),
                  letterSpacing: -1,
                ),
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1),
              
              const SizedBox(height: 20),
              
              Text(
                'We have deployed critical updates to Excellence Academy. Your current version is no longer supported.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: CT.textM(context),
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ).animate(delay: 300.ms).fadeIn(),

              const SizedBox(height: 32),

              if (latestVersion.isNotEmpty || minSupportedVersion.isNotEmpty) 
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CT.border(context)),
                  ),
                  child: Text(
                    [
                      if (latestVersion.isNotEmpty) 'LATEST: v$latestVersion',
                      if (minSupportedVersion.isNotEmpty) 'MINIMUM: v$minSupportedVersion',
                    ].join('  /  '),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ).animate(delay: 400.ms).fadeIn(),
              
              const Spacer(),
              
              CPPressable(
                onTap: () async {
                  final launched = await sl<AppUpdateService>().openStore(storeUrl);
                  if (!context.mounted || launched) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Store link is not configured. Contact Admin.')),
                  );
                },
                child: Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 2.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.download_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'INSTALL UPDATE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.5, end: 0),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
