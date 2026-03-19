import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_dimensions.dart';
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
    _selectedCode = localeNotifier.value.languageCode;
  }

  Future<void> _saveSelection() async {
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

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        title: Text('Choose Language',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
        actions: [
          CPPressable(
            onTap: _saveSelection,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
              child: Center(
                child: Text('Save',
                    style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: accent)),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            ),
            child: Row(children: [
              Icon(Icons.translate_rounded, color: accent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Choose your preferred language. The app interface will update accordingly.',
                  style: GoogleFonts.dmSans(fontSize: 13, color: CT.textH(context)),
                ),
              ),
            ]),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: AppDimensions.lg),

          // Language list
          ...AppLocales.languageNames.entries.toList().asMap().entries.map((entry) {
            final langCode = entry.value.key;
            final langName = entry.value.value;
            final isSelected = _selectedCode == langCode;

            return CPPressable(
              onTap: () => setState(() => _selectedCode = langCode),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? accent.withValues(alpha: 0.12) : CT.card(context),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                  border: Border.all(
                    color: isSelected ? accent : CT.border(context),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Language icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          langCode.toUpperCase(),
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        langName,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: CT.textH(context),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: accent, size: 24)
                    else
                      Icon(Icons.radio_button_unchecked_rounded, color: CT.border(context), size: 24),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: (50 * entry.key).ms);
          }),
        ],
      ),
    );
  }
}
