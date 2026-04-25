import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/theme/theme_aware.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingItem> _items = [
    _OnboardingItem(
      icon: Icons.school_rounded,
      title: 'Welcome to Excellence Academy',
      subtitle: 'The ultimate platform for coaching institutes to manage students, fees, and attendance.',
      gradient: const LinearGradient(colors: [Color(0xFF3D5AF1), Color(0xFF7B68EE)]),
      accent: AppColors.electricBlue,
    ),
    _OnboardingItem(
      icon: Icons.devices_rounded,
      title: 'Learn Anywhere',
      subtitle: 'Access study materials, attend live sessions, and take online quizzes from the comfort of your home.',
      gradient: const LinearGradient(colors: [Color(0xFF00B894), Color(0xFF55E6C1)]),
      accent: AppColors.mintGreen,
    ),
    _OnboardingItem(
      icon: Icons.trending_up_rounded,
      title: 'Track Progress',
      subtitle: 'Parents and students can effortlessly track grades, attendance history, and fee receipts.',
      gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)]),
      accent: AppColors.moltenAmber,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.card(context),
      body: SafeArea(
        child: Stack(
          children: [
            // Soft gradient glow behind active slide
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _items[_currentPage].accent.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4),
                    child: TextButton(
                      onPressed: () => GoRouter.of(context).go('/login'),
                      child: Text('skip', style: GoogleFonts.plusJakartaSans(color: CT.textM(context), fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                ),

                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (value) => setState(() => _currentPage = value),
                    itemCount: _items.length,
                    itemBuilder: (context, index) => _buildSlide(_items[index]),
                  ),
                ),

                // Bottom controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, 0, AppDimensions.pagePaddingH, 16),
                  child: Column(
                    children: [
                      // Pagination dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _items.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 6,
                            width: _currentPage == index ? 28 : 6,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? _items[_currentPage].accent : CT.textM(context),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      CustomButton(
                        text: _currentPage == _items.length - 1 ? 'Get Started' : 'Continue',
                        icon: _currentPage == _items.length - 1 ? Icons.arrow_forward : null,
                        onPressed: () {
                          if (_currentPage == _items.length - 1) {
                            GoRouter.of(context).go('/login');
                          } else {
                            _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_OnboardingItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container with gradient
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: item.gradient,
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: item.accent.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(item.icon, size: 52, color: Colors.white),
          ).animate().scale(delay: 100.ms, duration: 500.ms, curve: Curves.easeOutBack),

          const SizedBox(height: 48),

          // Title
          Text(
            item.title,
            style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w800, color: CT.textH(context), letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.15, end: 0),

          const SizedBox(height: 14),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              item.subtitle,
              style: GoogleFonts.plusJakartaSans(fontSize: 15, color: CT.textS(context), height: 1.6),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.15, end: 0),
          ),
        ],
      ),
    );
  }
}

class _OnboardingItem {
  final IconData icon;
  final String title, subtitle;
  final Gradient gradient;
  final Color accent;
  _OnboardingItem({required this.icon, required this.title, required this.subtitle, required this.gradient, required this.accent});
}

