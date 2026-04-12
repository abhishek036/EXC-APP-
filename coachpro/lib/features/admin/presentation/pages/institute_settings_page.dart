import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/custom_text_field.dart';

class InstituteSettingsPage extends StatefulWidget {
  const InstituteSettingsPage({super.key});

  @override
  State<InstituteSettingsPage> createState() => _InstituteSettingsPageState();
}

class _InstituteSettingsPageState extends State<InstituteSettingsPage> {
  final _adminRepo = sl<AdminRepository>();

  bool _isLoading = true;
  bool _isSaving = false;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  final _currencyCtrl = TextEditingController(text: '₹');
  final _lateFeeCtrl = TextEditingController(text: '50');
  final _dueDayCtrl = TextEditingController(text: '10');

  bool _notifyOnAbsent = true;
  bool _notifyOnFeeDue = true;
  bool _notifyOnExam = true;
  bool _allowPublicYoutubeUploads = false;
  String _defaultYoutubeVisibility = 'unlisted';
  Map<String, dynamic> _loadedSettings = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _adminRepo.getInstituteConfig();
      _nameCtrl.text =
          doc['name'] ?? doc['instituteName'] ?? 'Excellence Academy';
      _emailCtrl.text =
          doc['email'] ?? doc['contactEmail'] ?? 'info@excellence.academy';
      _phoneCtrl.text = doc['phone'] ?? doc['contactPhone'] ?? '+91 9876543210';
      _addressCtrl.text = doc['address'] ?? '123 Education Hub, Knowledge City';

      _currencyCtrl.text = doc['currency'] ?? '₹';
      _lateFeeCtrl.text = (doc['late_fee_amount'] ?? doc['lateFeeAmount'] ?? 50)
          .toString();
      _dueDayCtrl.text = (doc['default_due_day'] ?? doc['defaultDueDay'] ?? 10)
          .toString();

      _notifyOnAbsent = doc['notify_absent'] ?? doc['notifyAbsent'] ?? true;
      _notifyOnFeeDue = doc['notify_fee_due'] ?? doc['notifyFeeDue'] ?? true;
      _notifyOnExam = doc['notify_exam'] ?? doc['notifyExam'] ?? true;

        final rawSettings = doc['settings'];
        _loadedSettings = rawSettings is Map
          ? Map<String, dynamic>.from(rawSettings)
          : <String, dynamic>{};
        final videoPolicyRaw = _loadedSettings['video_policy'];
        final videoPolicy = videoPolicyRaw is Map
          ? Map<String, dynamic>.from(videoPolicyRaw)
          : <String, dynamic>{};

        _allowPublicYoutubeUploads =
          videoPolicy['allow_public_uploads'] == true;
        final configuredVisibility =
          (videoPolicy['default_visibility'] ?? 'unlisted')
            .toString()
            .toLowerCase();
        _defaultYoutubeVisibility =
          configuredVisibility == 'public' ? 'public' : 'unlisted';
    } catch (_) {
      // Ignored, fallback defaults
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_nameCtrl.text.isEmpty) {
      CPToast.error(context, 'Institute Name cannot be empty');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final nextSettings = Map<String, dynamic>.from(_loadedSettings);
      nextSettings['video_policy'] = {
        'allow_public_uploads': _allowPublicYoutubeUploads,
        'default_visibility': _allowPublicYoutubeUploads
            ? _defaultYoutubeVisibility
            : 'unlisted',
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _adminRepo.updateInstituteConfig({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'currency': _currencyCtrl.text.trim(),
        'late_fee_amount': int.tryParse(_lateFeeCtrl.text.trim()) ?? 0,
        'default_due_day': int.tryParse(_dueDayCtrl.text.trim()) ?? 10,
        'notify_absent': _notifyOnAbsent,
        'notify_fee_due': _notifyOnFeeDue,
        'notify_exam': _notifyOnExam,
        'settings': nextSettings,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      if (mounted) CPToast.success(context, 'Settings saved successfully');
    } catch (e) {
      if (mounted) CPToast.error(context, 'Failed to save settings');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Removed _glow method
  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ── HEADER ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      CPPressable(
                        onTap: () { if (context.canPop()) { context.pop(); } else { context.go('/admin'); } },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFF354388),
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFF354388),
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                            color: Color(0xFF354388),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Institute Configuration',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF354388),
                              letterSpacing: -1.0,
                            ),
                          ),
                          Text(
                            'Core system parameters',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF354388),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle(
                                'GENERAL INFORMATION',
                                Icons.business_rounded,
                                isDark,
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                label: 'Institute Name *',
                                hint: 'Excellence Academy',
                                controller: _nameCtrl,
                                prefixIcon: Icons.account_balance_rounded,
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                label: 'Contact Email',
                                hint: 'info@excellence.academy',
                                controller: _emailCtrl,
                                prefixIcon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                label: 'Contact Phone',
                                hint: '+91 ...',
                                controller: _phoneCtrl,
                                prefixIcon: Icons.phone_rounded,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                label: 'Physical Address',
                                hint: 'Street, City, Code...',
                                controller: _addressCtrl,
                                prefixIcon: Icons.place_rounded,
                                maxLines: 2,
                              ),

                              const SizedBox(height: 48),

                              _sectionTitle(
                                'FINANCIAL ENGINE',
                                Icons.account_balance_wallet_rounded,
                                isDark,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      label: 'Currency',
                                      hint: '₹',
                                      controller: _currencyCtrl,
                                      prefixIcon: Icons.currency_rupee_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextField(
                                      label: 'Late Penalty',
                                      hint: '50',
                                      controller: _lateFeeCtrl,
                                      prefixIcon: Icons.warning_rounded,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                label: 'Standard Installment Day (1-28)',
                                hint: '10',
                                controller: _dueDayCtrl,
                                prefixIcon: Icons.calendar_today_rounded,
                                keyboardType: TextInputType.number,
                              ),

                              const SizedBox(height: 48),

                              _sectionTitle(
                                'AUTOMATED COMMUNICATIONS',
                                Icons.campaign_rounded,
                                isDark,
                              ),
                              const SizedBox(height: 16),
                              _settingsToggle(
                                Icons.person_off_rounded,
                                'Attendance Alerts',
                                'Trigger SMS/Push when student is marked absent',
                                _notifyOnAbsent,
                                (val) => setState(() => _notifyOnAbsent = val),
                                AppColors.error,
                                isDark,
                              ),
                              _settingsToggle(
                                Icons.receipt_long_rounded,
                                'Invoice Reminders',
                                'Auto-dispatch notices 3 days prior to due date',
                                _notifyOnFeeDue,
                                (val) => setState(() => _notifyOnFeeDue = val),
                                AppColors.warning,
                                isDark,
                              ),
                              _settingsToggle(
                                Icons.task_rounded,
                                'Assessment Grades',
                                'Instant broadcast of grades upon upload',
                                _notifyOnExam,
                                (val) => setState(() => _notifyOnExam = val),
                                AppColors.primary,
                                isDark,
                              ),

                              const SizedBox(height: 48),

                              _sectionTitle(
                                'YOUTUBE VIDEO POLICY',
                                Icons.ondemand_video_rounded,
                                isDark,
                              ),
                              const SizedBox(height: 16),
                              _settingsToggle(
                                Icons.public_rounded,
                                'Allow Public YouTube Videos',
                                'When off, teachers can only tag uploads as Unlisted.',
                                _allowPublicYoutubeUploads,
                                (val) {
                                  setState(() {
                                    _allowPublicYoutubeUploads = val;
                                    if (!val) {
                                      _defaultYoutubeVisibility = 'unlisted';
                                    }
                                  });
                                },
                                AppColors.info,
                                isDark,
                              ),
                              const SizedBox(height: 12),
                              _buildYoutubeDefaultVisibilityDropdown(
                                isDark,
                                const Color(0xFF354388),
                              ),

                              const SizedBox(
                                height: 120,
                              ), // Padding for bottom nav
                            ],
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
                        ),
                ),
              ],
            ),
          ),

          // Custom Bottom Navigation Action
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
                    (isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg)
                        .withValues(alpha: 0),
                  ],
                ),
              ),
              child: CPPressable(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  _saveSettings();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBDAE18),
                    border: Border.all(
                      color: const Color(0xFF354388),
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF354388), offset: Offset(3, 3)),
                    ],
                  ),
                  child: _isSaving
                      ? const Center(
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shield_rounded,
                              color: Color(0xFF354388),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Commit System Configuration',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF354388),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, bool isDark) => Row(
    children: [
      Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.black54),
      const SizedBox(width: 8),
      Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white54 : Colors.black54,
          letterSpacing: 1.0,
        ),
      ),
    ],
  );

  Widget _settingsToggle(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    Color accentColor,
    bool isDark,
  ) {
    return CPGlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 20,
      border: Border.all(
        color: value
            ? accentColor.withValues(alpha: 0.3)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: accentColor, width: 2),
              boxShadow: [
                BoxShadow(color: accentColor, offset: const Offset(2, 2)),
              ],
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF354388),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF354388),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch.adaptive(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeThumbColor: Colors.white,
            activeTrackColor: accentColor,
            inactiveThumbColor: isDark ? Colors.white38 : Colors.black38,
            inactiveTrackColor: isDark
                ? Colors.white12
                : Colors.black.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }

  Widget _buildYoutubeDefaultVisibilityDropdown(bool isDark, Color primary) {
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white;
    final options = _allowPublicYoutubeUploads
        ? const <String>['unlisted', 'public']
        : const <String>['unlisted'];

    return CPGlassCard(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: 16,
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08),
      ),
      child: Row(
        children: [
          Icon(Icons.video_settings_rounded, color: primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Default Lecture Visibility',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primary, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: options.contains(_defaultYoutubeVisibility)
                    ? _defaultYoutubeVisibility
                    : 'unlisted',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _defaultYoutubeVisibility = val);
                },
                items: options
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option.toUpperCase()),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

