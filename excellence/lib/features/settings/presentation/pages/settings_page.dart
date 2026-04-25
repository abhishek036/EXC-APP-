import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/download_registry.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/utils/role_prefix.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _offlineMode = true;
  bool _autoDownload = false;
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _offlineMode = prefs.getBool('offlineMode') ?? true;
        _autoDownload = prefs.getBool('autoDownload') ?? false;
        _language = 'English';
      });
    } catch (_) {}
  }

  Future<void> _saveBool(String key, bool value) async {
    try { (await SharedPreferences.getInstance()).setBool(key, value); } catch (_) {}
  }
  Future<void> _saveString(String key, String value) async {
    try { (await SharedPreferences.getInstance()).setString(key, value); } catch (_) {}
  }

  Future<void> _clearCache() async {
    final cleared = await DownloadRegistry.instance.clearAll();
    if (!mounted) return;
    _showSnack(
      cleared > 0 ? 'Cleared $cleared cached file(s).' : 'Cache is already empty.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        leading: CPPressable(
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(context.rolePrefix);
            }
          },
          child: Icon(Icons.arrow_back_ios, size: 18, color: CT.textH(context)),
        ),
        title: Text('Settings', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: CT.textH(context))),
        backgroundColor: CT.bg(context),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('Account'),
          _settingsTile(Icons.person_outline, 'Edit Profile', subtitle: 'Name, phone, email', onTap: () => context.go('${context.rolePrefix}/profile?edit=true'), isDark: isDark),
          const SizedBox(height: AppDimensions.lg),

          _sectionTitle('Content & Downloads'),
          _settingsToggle(Icons.cloud_off_outlined, 'Offline Mode', _offlineMode, (v) { setState(() => _offlineMode = v); _saveBool('offlineMode', v); }, isDark: isDark),
          _settingsToggle(Icons.download_outlined, 'Auto-Download on WiFi', _autoDownload, (v) { setState(() => _autoDownload = v); _saveBool('autoDownload', v); }, isDark: isDark),
          _settingsTile(Icons.language, 'Language', subtitle: _language,
            trailing: Icon(Icons.chevron_right, color: CT.textM(context)),
            onTap: () => _showLanguagePicker(), isDark: isDark),
          const SizedBox(height: AppDimensions.lg),

          _sectionTitle('Data & Privacy'),
          _settingsTile(Icons.delete_outline, 'Clear Cache', subtitle: 'Free up storage space', onTap: _clearCache, isDark: isDark),
          const SizedBox(height: AppDimensions.lg),

          _sectionTitle('Support'),
          _settingsTile(Icons.help_outline, 'Help & FAQ', onTap: () => _showHelpFAQSheet(), isDark: isDark),
          _settingsTile(Icons.chat_bubble_outline, 'Contact Support', onTap: () => _showContactSupportSheet(), isDark: isDark),
          _settingsTile(Icons.bug_report_outlined, 'Report a Bug', onTap: () => _showBugReportSheet(), isDark: isDark),
          _settingsTile(Icons.star_outline, 'Rate App', onTap: () => _showRateAppDialog(), isDark: isDark),
          const SizedBox(height: AppDimensions.lg),

          _sectionTitle('About'),
          _settingsTile(Icons.info_outline, 'App Version', subtitle: 'v1.0.0 (Build 42)', isDark: isDark),
          _settingsTile(Icons.description_outlined, 'Terms of Service', onTap: () => _showTermsSheet(), isDark: isDark),
          _settingsTile(Icons.privacy_tip_outlined, 'Privacy Policy', onTap: () => _showPrivacySheet(), isDark: isDark),
          _settingsTile(Icons.shield_outlined, 'Open Source Licenses',
            onTap: () => showLicensePage(context: context, applicationName: 'Excellence Academy', applicationVersion: 'v1.0.0'), isDark: isDark),
          const SizedBox(height: AppDimensions.lg),

          // Logout
          CPPressable(
            onTap: () => _showLogoutDialog(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.logout, color: AppColors.error, size: 20),
                const SizedBox(width: AppDimensions.sm),
                Text('Log Out', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.error)),
              ]),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: CT.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMD)),
      title: Text('Log out?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: CT.textH(context))),
      content: Text('You\'ll need to sign in again to access your account.', style: GoogleFonts.plusJakartaSans(color: CT.textS(context))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: CT.textM(context)))),
        ElevatedButton(
          onPressed: () { Navigator.pop(ctx); context.read<AuthBloc>().add(const AuthLogoutRequested()); },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXS))),
          child: Text('Log Out', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        ),
      ],
    ));
  }

  void _showLanguagePicker() {
    showModalBottomSheet(context: context, backgroundColor: CT.bg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Language', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: CT.textH(context))),
          const SizedBox(height: AppDimensions.md),
          ...['English'].map((l) => CPPressable(
            onTap: () { setState(() => _language = l); _saveString('language', l); Navigator.pop(ctx); },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.step),
              child: Row(children: [
                Icon(_language == l ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _language == l ? CT.accent(context) : CT.textM(context)),
                const SizedBox(width: AppDimensions.step),
                Text(l, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: CT.textH(context))),
              ]),
            ),
          )),
          const SizedBox(height: AppDimensions.md),
        ]),
      ));
  }

  void _showHelpFAQSheet() {
    final faqs = [
      {'q': 'How do I reset my password?', 'a': 'Please contact support to reset your password.'},
      {'q': 'How do I change my profile picture?', 'a': 'Navigate to your Profile page and tap on the avatar to upload a new photo.'},
      {'q': 'Can I access content offline?', 'a': 'Yes! Enable Offline Mode in Settings → Content & Downloads to save materials for offline use.'},
      {'q': 'How do I contact my teacher?', 'a': 'Use the Chat feature from your dashboard to send direct messages to your assigned teachers.'},
      {'q': 'How do I view my test results?', 'a': 'Go to your Performance Dashboard from the home screen to see all test scores and analytics.'},
      {'q': 'How do I pay fees?', 'a': 'Navigate to the Fees section and select the pending fee to make payment through multiple payment options.'},
      {'q': 'Is my data secure?', 'a': 'Yes, all data is encrypted and stored securely. We follow industry-standard security practices.'},
    ];
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: CT.bg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75, maxChildSize: 0.9, minChildSize: 0.4, expand: false,
        builder: (ctx, scrollCtrl) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: CT.textM(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Help & FAQ', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context))),
              const SizedBox(height: 4),
              Text('Find answers to frequently asked questions', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: CT.textS(context))),
              const SizedBox(height: 12),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl, padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: faqs.length,
              itemBuilder: (ctx, i) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: CT.card(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: CT.border(context).withValues(alpha: 0.5))),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: const Border(),
                  title: Text(faqs[i]['q']!, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: CT.textH(context))),
                  iconColor: CT.accent(context), collapsedIconColor: CT.textM(context),
                  children: [Text(faqs[i]['a']!, style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.5, color: CT.textS(context)))],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showContactSupportSheet() {
    final msgCtrl = TextEditingController();
    String selectedTopic = 'General Query';
    final topics = ['General Query', 'Fee Related', 'Technical Issue', 'Content Feedback', 'Other'];
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: CT.bg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: CT.textM(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Contact Support', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context))),
          const SizedBox(height: 4),
          Text('We usually respond within 24 hours', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: CT.textS(context))),
          const SizedBox(height: 20),
          Text('Topic', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: CT.textM(context))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: topics.map((t) => CPPressable(
            onTap: () => setS(() => selectedTopic = t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selectedTopic == t ? CT.accent(context).withValues(alpha: 0.1) : CT.card(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selectedTopic == t ? CT.accent(context) : CT.border(context)),
              ),
              child: Text(t, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: selectedTopic == t ? CT.accent(context) : CT.textS(context))),
            ),
          )).toList()),
          const SizedBox(height: 16),
          TextField(
            controller: msgCtrl, maxLines: 4,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: CT.textH(context)),
            decoration: InputDecoration(
              hintText: 'Describe your issue or question...', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: CT.textM(context)),
              filled: true, fillColor: CT.card(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: CT.border(context))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: CT.border(context))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: CT.accent(context), width: 1.5)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                if (msgCtrl.text.trim().isEmpty) { _showSnack('Please describe your issue'); return; }
                Navigator.pop(ctx);
                _showSnack('Support request sent! We\'ll get back to you soon.');
              },
              icon: const Icon(Icons.send, size: 18),
              label: Text('Send Message', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(backgroundColor: CT.accent(context), foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ]),
      )),
    );
  }

  void _showBugReportSheet() {
    final descCtrl = TextEditingController();
    String severity = 'Medium';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: CT.bg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: CT.textM(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Report a Bug', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context))),
          const SizedBox(height: 4),
          Text('Help us improve by reporting issues', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: CT.textS(context))),
          const SizedBox(height: 20),
          Text('Severity', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: CT.textM(context))),
          const SizedBox(height: 8),
          Row(children: ['Low', 'Medium', 'High', 'Critical'].map((s) {
            final colors = {'Low': AppColors.mintGreen, 'Medium': AppColors.moltenAmber, 'High': AppColors.coralRed, 'Critical': const Color(0xFFB71C1C)};
            final c = colors[s]!;
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: CPPressable(
                onTap: () => setS(() => severity = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: severity == s ? c.withValues(alpha: 0.15) : CT.card(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: severity == s ? c : CT.border(context)),
                  ),
                  alignment: Alignment.center,
                  child: Text(s, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: severity == s ? c : CT.textS(context))),
                ),
              ),
            ));
          }).toList()),
          const SizedBox(height: 16),
          TextField(
            controller: descCtrl, maxLines: 4,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: CT.textH(context)),
            decoration: InputDecoration(
              hintText: 'Describe the bug in detail...\nWhat happened? What did you expect?', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: CT.textM(context)),
              filled: true, fillColor: CT.card(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: CT.border(context))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: CT.border(context))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: CT.accent(context), width: 1.5)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                if (descCtrl.text.trim().isEmpty) { _showSnack('Please describe the bug'); return; }
                Navigator.pop(ctx);
                _showSnack('Bug report submitted! Thank you for helping us improve.');
              },
              icon: const Icon(Icons.bug_report_outlined, size: 18),
              label: Text('Submit Report', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(backgroundColor: CT.accent(context), foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ]),
      )),
    );
  }

  void _showRateAppDialog() {
    int rating = 0;
    final reviewCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      backgroundColor: CT.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.star_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 16),
        Text('Rate Excellence Academy', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: CT.textH(context))),
        const SizedBox(height: 6),
        Text('Your feedback helps us improve!', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: CT.textS(context))),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => CPPressable(
          onTap: () => setS(() => rating = i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 36,
              color: i < rating ? AppColors.moltenAmber : CT.textM(context)),
          ),
        ))),
        const SizedBox(height: 16),
        if (rating > 0) TextField(
          controller: reviewCtrl, maxLines: 3,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: CT.textH(context)),
          decoration: InputDecoration(
            hintText: rating >= 4 ? 'Tell us what you love!' : 'How can we improve?',
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: CT.textM(context)),
            filled: true, fillColor: CT.bg(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CT.border(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CT.border(context))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CT.accent(context), width: 1.5)),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: rating > 0 ? () { Navigator.pop(ctx); _showSnack('Thank you for your $rating-star rating! ⭐'); } : null,
            style: ElevatedButton.styleFrom(backgroundColor: CT.accent(context), foregroundColor: Colors.white, elevation: 0, disabledBackgroundColor: CT.textM(context).withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text('Submit Rating', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
        CPPressable(
          onTap: () => Navigator.pop(ctx),
          child: Text('Maybe Later', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: CT.textM(context))),
        ),
      ]),
    )));
  }

  void _showTermsSheet() {
    context.push('/terms-of-service');
  }

  void _showPrivacySheet() {
    context.push('/privacy-policy');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.plusJakartaSans(color: Colors.white)),
      backgroundColor: CT.accent(context),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimensions.step),
    child: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: CT.textM(context), letterSpacing: 0.8)),
  );

  Widget _settingsTile(IconData icon, String title, {String? subtitle, Widget? trailing, VoidCallback? onTap, required bool isDark}) => CPPressable(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: CT.cardDecor(context),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.sm),
          decoration: BoxDecoration(color: CT.accent(context).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppDimensions.radiusXS)),
          child: Icon(icon, size: 20, color: CT.accent(context)),
        ),
        const SizedBox(width: AppDimensions.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: CT.textH(context))),
          if (subtitle != null) Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: CT.textM(context))),
        ])),
        trailing ?? Icon(Icons.chevron_right, color: CT.textM(context), size: 20),
      ]),
    ),
  );

  Widget _settingsToggle(IconData icon, String title, bool value, ValueChanged<bool> onChanged, {required bool isDark}) => Container(
    margin: const EdgeInsets.only(bottom: AppDimensions.sm),
    padding: const EdgeInsets.all(AppDimensions.md),
    decoration: CT.cardDecor(context),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(AppDimensions.sm),
        decoration: BoxDecoration(color: CT.accent(context).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppDimensions.radiusXS)),
        child: Icon(icon, size: 20, color: CT.accent(context)),
      ),
      const SizedBox(width: AppDimensions.md),
      Expanded(child: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: CT.textH(context)))),
      Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: CT.accent(context)),
    ]),
  );
}

class _DataExportDialog extends StatefulWidget {
  final Color accent, card, textH, textS;
  const _DataExportDialog({required this.accent, required this.card, required this.textH, required this.textS});
  @override
  State<_DataExportDialog> createState() => _DataExportDialogState();
}

class _DataExportDialogState extends State<_DataExportDialog> with SingleTickerProviderStateMixin {
  bool _exporting = false;
  bool _done = false;

  void _startExport() {
    setState(() => _exporting = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() { _exporting = false; _done = true; });
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: widget.card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      if (!_exporting && !_done) ...[
        Icon(Icons.download_for_offline_outlined, size: 48, color: widget.accent),
        const SizedBox(height: 16),
        Text('Export Your Data', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: widget.textH)),
        const SizedBox(height: 8),
        Text('This will prepare a download of your profile, attendance, scores, and activity data.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: widget.textS, height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
          onPressed: _startExport,
          style: ElevatedButton.styleFrom(backgroundColor: widget.accent, foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text('Export Data', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
        )),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: widget.textS))),
      ],
      if (_exporting) ...[
        const SizedBox(height: 12),
        SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3, color: widget.accent)),
        const SizedBox(height: 20),
        Text('Preparing your data...', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: widget.textH)),
        const SizedBox(height: 8),
        Text('This may take a moment', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: widget.textS)),
        const SizedBox(height: 12),
      ],
      if (_done) ...[
        const SizedBox(height: 12),
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: AppColors.mintGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, color: AppColors.mintGreen, size: 36),
        ),
        const SizedBox(height: 16),
        Text('Export Ready!', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: widget.textH)),
        const SizedBox(height: 8),
        Text('Your data has been exported successfully.', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: widget.textS), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.mintGreen, foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text('Done', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
        )),
        const SizedBox(height: 12),
      ],
    ]),
  );
}
