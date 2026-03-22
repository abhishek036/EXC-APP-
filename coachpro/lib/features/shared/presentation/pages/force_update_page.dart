import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/widgets/custom_button.dart';
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
    return Scaffold(
      backgroundColor: CT.bg(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Update illustration (Abstract Shapes)
              SizedBox(
                height: 200,
                width: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Positioned(
                      child: Icon(
                        Icons.system_update_rounded,
                        size: 80,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
              
              const SizedBox(height: 40),
              
              Text(
                'Time to Update!',
                style: GoogleFonts.sora(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: CT.textH(context),
                ),
              ).animate(delay: 200.ms).fadeIn(),
              
              const SizedBox(height: 16),
              
              Text(
                'We have added new features and fixed bugs to make your experience smoother.\nPlease update Excellence Academy to continue using the app.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: CT.textS(context),
                  height: 1.5,
                ),
              ).animate(delay: 300.ms).fadeIn(),

              if (latestVersion.isNotEmpty || minSupportedVersion.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  [
                    if (latestVersion.isNotEmpty) 'Latest: v$latestVersion',
                    if (minSupportedVersion.isNotEmpty) 'Minimum supported: v$minSupportedVersion',
                  ].join(' • '),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: CT.textS(context),
                  ),
                ),
              ],
              
              const Spacer(),
              
              CustomButton(
                text: 'Update Now',
                icon: Icons.update,
                onPressed: () async {
                  final launched = await sl<AppUpdateService>().openStore(storeUrl);
                  if (!context.mounted || launched) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Store link is not configured yet. Please contact support.')),
                  );
                },
              ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.5, end: 0),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
