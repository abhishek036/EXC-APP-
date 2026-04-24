import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/l10n/app_locales.dart';
import '../../../../core/l10n/app_localizations.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  late String _selectedCode;

  @override
  void initState() {
    super.initState();
    _selectedCode = AppLocales.supported.any((l) => l.languageCode == localeNotifier.value.languageCode)
        ? localeNotifier.value.languageCode
        : AppLocales.english.languageCode;
  }

  Future<void> _saveSelection() async {
    HapticFeedback.heavyImpact();
    final locale = AppLocales.supported.firstWhere(
      (l) => l.languageCode == _selectedCode,
      orElse: () => AppLocales.english,
    );
    await AppLocalizations.changeLocale(locale);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accent = CT.accent(context);
    final isDark = CT.isDark(context);

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        title: Text('Languages',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: CT.textH(context))),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
              children: [
                // Minimal Header
                Text(
                  'SYSTEM LOCALES',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: CT.textS(context),
                    letterSpacing: 2,
                  ),
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 16),

                // Language list
                ...AppLocales.languageNames.entries.toList().asMap().entries.map((entry) {
                  final langCode = entry.value.key;
                  final langName = entry.value.value;
                  final isSelected = _selectedCode == langCode;

                  return CPPressable(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      setState(() => _selectedCode = langCode);
                    },
                    child: AnimatedContainer(
                      duration: 200.ms,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? accent.withValues(alpha: isDark ? 0.15 : 0.08) 
                            : CT.card(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? accent : CT.border(context),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected 
                            ? [BoxShadow(color: accent.withValues(alpha: 0.1), blurRadius: 10)] 
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Mono Language Indicator
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.paleSlate1.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                langCode.toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? accent : CT.textS(context),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              langName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: CT.textH(context),
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded, color: accent, size: 22)
                          else
                            Icon(Icons.radio_button_off_rounded, color: CT.textS(context).withValues(alpha: 0.3), size: 22),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: (40 * entry.key).ms).slideY(begin: 0.05, end: 0);
                }),
              ],
            ),
          ),
          
          // Action Block
          Container(
            padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
            decoration: BoxDecoration(
              color: CT.bg(context),
              border: Border(top: BorderSide(color: CT.border(context))),
            ),
            child: SafeArea(
              child: CPPressable(
                onTap: _saveSelection,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'APPLY SELECTION',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ).animate().slideY(begin: 0.5, end: 0, delay: 200.ms),
          ),
        ],
      ),
    );
  }
}
