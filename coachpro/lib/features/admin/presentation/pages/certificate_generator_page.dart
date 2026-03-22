import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/utils/certificate_pdf_generator.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/cp_glass_card.dart';

class CertificateGeneratorPage extends StatefulWidget {
  const CertificateGeneratorPage({super.key});

  @override
  State<CertificateGeneratorPage> createState() => _CertificateGeneratorPageState();
}

class _CertificateGeneratorPageState extends State<CertificateGeneratorPage> {
  final _adminRepo = sl<AdminRepository>();
  
  String? _sid;
  String? _sname;
  String _type = 'cp'; // cp = Completion, ex = Excellence
  String _course = 'Foundation Course';
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(top: -100, left: -50, child: _glow(300, AppColors.elitePrimary.withValues(alpha: 0.1))),
            Positioned(bottom: -50, right: -100, child: _glow(250, AppColors.elitePurple.withValues(alpha: 0.05))),
          ],
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(isDark),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPreviewBox(isDark),
                        const SizedBox(height: 32),
                        _stepHeader('1', 'Recipient Details', isDark),
                        const SizedBox(height: 16),
                        _buildStudentSelector(isDark),
                        const SizedBox(height: 32),
                        _stepHeader('2', 'Prestige Level', isDark),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _typeCard('COMPLETION', 'cp', Icons.workspace_premium_rounded, AppColors.elitePrimary, isDark),
                            const SizedBox(width: 16),
                            _typeCard('EXCELLENCE', 'ex', Icons.star_rounded, AppColors.moltenAmber, isDark),
                          ],
                        ),
                        const SizedBox(height: 32),
                        _stepHeader('3', 'Academic Program', isDark),
                        const SizedBox(height: 16),
                        _buildCourseInput(isDark),
                        const SizedBox(height: 48),
                        CustomButton(
                          text: 'Mint Certificate',
                          icon: Icons.auto_fix_high_rounded,
                          isLoading: _generating,
                          onPressed: _handleGenerate,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: size / 2)]));

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          CPPressable(onTap: () => Navigator.pop(context), child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : AppColors.deepNavy)),
          const SizedBox(width: 16),
          Text('Certificate Studio', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _stepHeader(String num, String title, bool isDark) {
    return Row(
      children: [
        Container(width: 24, height: 24, decoration: BoxDecoration(color: AppColors.elitePrimary, borderRadius: BorderRadius.circular(6)), alignment: Alignment.center, child: Text(num, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white))),
        const SizedBox(width: 12),
        Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.2)),
      ],
    );
  }

  Widget _buildPreviewBox(bool isDark) {
    return CPGlassCard(
      isDark: isDark, padding: const EdgeInsets.all(24), borderRadius: 28,
      child: AspectRatio(
        aspectRatio: 1.4,
        child: Container(
          decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05))),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.description_rounded, size: 48, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
              const SizedBox(height: 16),
              Text(_sname ?? '[Recipient Name]', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26))),
              const SizedBox(height: 4),
              Text('For completing $_course', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.12))),
            ],
          ),
        ),
      ),
    ).animate().scale(begin: const Offset(0.9, 0.9), duration: 600.ms, curve: Curves.easeOutBack);
  }

  Widget _buildStudentSelector(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _adminRepo.getStudents(),
      builder: (ctx, snap) {
        final students = snap.data ?? [];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sid, hint: Text('Choose Recipient', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26), fontWeight: FontWeight.w600)),
              isExpanded: true, dropdownColor: isDark ? const Color(0xFF0D1282) : Colors.white, icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white38 : Colors.black38),
              items: students.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name'].toString(), style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : AppColors.deepNavy, fontWeight: FontWeight.w600)))).toList(),
              onChanged: (v) {
                setState(() {
                  _sid = v;
                  final matches = students.where((s) => s['id'].toString() == v).toList();
                  _sname = matches.isEmpty ? null : matches.first['name']?.toString();
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _typeCard(String title, String val, IconData icon, Color color, bool isDark) {
    final active = _type == val;
    return Expanded(
      child: CPPressable(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _type = val);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.1) : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: active ? color : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)), width: active ? 2 : 1),
            boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8))] : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? color : (isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.12)), size: 32),
              const SizedBox(height: 12),
              Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: active ? color : (isDark ? Colors.white38 : Colors.black38), letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))),
      child: TextFormField(
        initialValue: _course,
        onChanged: (v) => setState(() => _course = v),
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.deepNavy),
        decoration: InputDecoration(hintText: 'e.g. Advance Mathematics', hintStyle: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26)), border: InputBorder.none, icon: Icon(Icons.school_outlined, size: 20, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26))),
      ),
    );
  }

  Future<void> _handleGenerate() async {
    if (_sname == null) { CPToast.error(context, 'Select a student'); return; }
    if (_course.isEmpty) { CPToast.error(context, 'Enter course name'); return; }
    
    setState(() => _generating = true);
    try {
      await CertificatePdfGenerator.generateCertificate(_sname!, _course, _type);
      if (mounted) { CPToast.success(context, 'Certificate minted! 🎖️'); }
    } catch (_) { if (mounted) CPToast.error(context, 'Minting failed'); }
    finally { if (mounted) setState(() => _generating = false); }
  }
}


