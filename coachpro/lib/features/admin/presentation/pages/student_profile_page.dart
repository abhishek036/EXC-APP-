import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_glass_card.dart';

class StudentProfilePage extends StatefulWidget {
  final String studentId;
  const StudentProfilePage({super.key, required this.studentId});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  final _adminRepo = sl<AdminRepository>();

  Map<String, dynamic>? _student;
  List<Map<String, dynamic>> _feeHistory = [];
  List<Map<String, dynamic>> _examResults = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _adminRepo.getStudentById(widget.studentId),
        _adminRepo.getFeeRecords(studentId: widget.studentId),
        _adminRepo.getExamResults(),
        _adminRepo.getStudentAttendance(studentId: widget.studentId),
      ]);

      if (mounted) {
        final attendanceData = results[3] as Map<String, dynamic>;
        final attendancePercent =
            (attendanceData['attendancePercent'] as num?)?.toInt() ??
            (attendanceData['percentage'] as num?)?.toInt() ??
            (attendanceData['avgPercentage'] as num?)?.toInt() ??
            0;
        final studentMap = Map<String, dynamic>.from(results[0] as Map<String, dynamic>);
        studentMap['attendancePercent'] = attendancePercent;

        final allExamResults = (results[2] as List<Map<String, dynamic>>?) ?? [];

        setState(() {
          _student = studentMap;
          _feeHistory = (results[1] as List<Map<String, dynamic>>?) ?? [];
          _examResults = allExamResults
              .where((exam) => (exam['studentId'] ?? exam['student_id'] ?? '').toString() == widget.studentId)
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
        body: const Center(child: CircularProgressIndicator(color: AppColors.elitePrimary)),
      );
    }

    if (_student == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Scholar Missing', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: isDark ? Colors.white : AppColors.deepNavy)),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined, size: 64, color: isDark ? Colors.white10 : Colors.black12),
              const SizedBox(height: 16),
              Text('Incomplete identity record', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    final s = _student!;
    final parents = (s['parents'] as List<dynamic>? ?? [])
      .whereType<Map>()
      .map((parent) => Map<String, dynamic>.from(parent))
      .toList();
    final primaryParent = parents.isNotEmpty ? parents.first : <String, dynamic>{};
    final studentBatches = (s['student_batches'] as List<dynamic>? ?? [])
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList();
    
    final name = (s['name'] as String?) ?? 'Student';
    final rollNumber = (s['student_code'] ?? s['rollNumber'] ?? s['studentId'] ?? '').toString();
    final phone = (s['phone'] as String?) ?? '';
    final parentName = (s['parentName'] as String?) ?? (primaryParent['name'] as String?) ?? '';
    final parentPhone = (s['parentPhone'] as String?) ?? (primaryParent['phone'] as String?) ?? '';
    final email = (s['email'] as String?) ?? '';
    final address = (s['address'] as String?) ?? '';
    final gender = (s['gender'] as String?) ?? '';
    final status = (s['status'] as String?) ?? 'active';
    final feeStatus = (s['feeStatus'] as String?) ?? 'PENDING';
    final attendance = (s['attendancePercent'] as num?)?.toInt() ?? 0;
    
    final batchIds = (s['batchIds'] as List<dynamic>? ?? [])
      .isNotEmpty
      ? (s['batchIds'] as List<dynamic>)
      : studentBatches
        .map((entry) => ((entry['batch'] as Map?)?['name'] ?? entry['batch_id'] ?? '').toString())
        .where((value) => value.isNotEmpty)
        .toList();

    final initials = name.split(' ').where((e) => e.isNotEmpty)
        .map((e) => e[0]).take(2).join().toUpperCase();

    final statusColor = status == 'active' ? AppColors.mintGreen : AppColors.coralRed;

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(top: -150, right: -100, child: _glow(400, AppColors.elitePrimary.withValues(alpha: 0.12))),
            Positioned(bottom: 50, left: -150, child: _glow(500, AppColors.elitePurple.withValues(alpha: 0.08))),
          ],
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(context, isDark, initials, name, rollNumber, statusColor, status),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickMetrics(attendance, feeStatus, isDark),
                        const SizedBox(height: 32),
                        _buildSectionHeader("Identification & Reach", Icons.contact_emergency_rounded, isDark),
                        const SizedBox(height: 16),
                        _buildContactInfo(phone, email, gender, parentName, parentPhone, address, isDark),
                        const SizedBox(height: 32),
                        if (batchIds.isNotEmpty) ...[
                          _buildSectionHeader("Academic Enclaves", Icons.hub_rounded, isDark),
                          const SizedBox(height: 16),
                          _buildBatchChips(batchIds, isDark),
                          const SizedBox(height: 32),
                        ],
                        if (_examResults.isNotEmpty) ...[
                          _buildSectionHeader("Performance Ledger", Icons.insights_rounded, isDark),
                          const SizedBox(height: 16),
                          _buildExamList(isDark),
                          const SizedBox(height: 32),
                        ],
                        _buildSectionHeader("Revenue Participation", Icons.currency_rupee_rounded, isDark),
                        const SizedBox(height: 16),
                        _buildFeeHistory(isDark),
                        const SizedBox(height: 48),
                        _buildActionRow(phone, parentPhone, isDark),
                        const SizedBox(height: 80),
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

  Widget _buildSliverAppBar(BuildContext context, bool isDark, String initials, String name, String roll, Color sColor, String status) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: CPPressable(onTap: () => Navigator.pop(context), child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : AppColors.deepNavy)),
      actions: [
        CPPressable(
          onTap: () => CPToast.info(context, 'Edit coming soon'),
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(child: Text('EDIT', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.elitePrimary, letterSpacing: 1))),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Hero(
                  tag: 'stu_${widget.studentId}',
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(gradient: AppColors.premiumEliteGradient, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: AppColors.elitePrimary.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5)]),
                    child: Center(child: Text(initials, style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1))),
                  ),
                ),
                const SizedBox(height: 16),
                Text(name, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.8)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(roll, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 0.5)),
                    const SizedBox(width: 8),
                    Container(width: 4, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: sColor, letterSpacing: 0.5)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMetrics(int attendance, String feeStatus, bool isDark) {
    final attColor = attendance >= 80 ? AppColors.mintGreen : attendance >= 70 ? AppColors.warning : AppColors.error;
    final feeColor = feeStatus == 'PAID' ? AppColors.mintGreen : AppColors.moltenAmber;

    return Row(
      children: [
        _metricCard('SCHOLASTIC PRESENCE', '$attendance%', attColor, isDark, ring: true, pct: attendance / 100),
        const SizedBox(width: 16),
        _metricCard('FINANCIAL STATUS', feeStatus, feeColor, isDark),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _metricCard(String label, String val, Color color, bool isDark, {bool ring = false, double pct = 0}) {
    return Expanded(
      child: CPGlassCard(
        isDark: isDark, padding: const EdgeInsets.all(20), borderRadius: 28,
        child: Column(
          children: [
            if (ring) 
              SizedBox(width: 60, height: 60, child: CustomPaint(painter: _EliteRingPainter(pct, color, isDark), child: Center(child: Text(val, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: color)))))
            else
              Text(val, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
            const SizedBox(height: 12),
            Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.elitePrimary.withValues(alpha: 0.5)),
        const SizedBox(width: 10),
        Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.2)),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildContactInfo(String phone, String email, String gender, String pName, String pPhone, String address, bool isDark) {
    return CPGlassCard(
      isDark: isDark, padding: const EdgeInsets.all(24), borderRadius: 28,
      child: Column(
        children: [
          _contactItem(Icons.phone_iphone_rounded, "Personal", phone, isDark),
          _divider(isDark),
          _contactItem(Icons.alternate_email_rounded, "Neural Link", email.isNotEmpty ? email : "Unlinked", isDark),
          _divider(isDark),
          _contactItem(Icons.family_restroom_rounded, "Parental Proxy", pName.isNotEmpty ? '$pName • $pPhone' : "Not recorded", isDark),
          _divider(isDark),
          _contactItem(Icons.location_on_rounded, "Coordinates", address.isNotEmpty ? address : "Mobile Scholar", isDark),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _contactItem(IconData icon, String label, String val, bool isDark) {
    return Row(
      children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 18, color: isDark ? Colors.white38 : Colors.black38)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(val, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.deepNavy)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider(bool isDark) => Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Divider(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), height: 1));

  Widget _buildBatchChips(List<dynamic> batches, bool isDark) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: batches.map((b) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.elitePrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.elitePrimary.withValues(alpha: 0.1))), child: Text(b.toString().toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.elitePrimary, letterSpacing: 0.5)))).toList(),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildExamList(bool isDark) {
    return Column(
      children: _examResults.map((exam) {
        final name = (exam['examName'] ?? 'Performance Check').toString();
        final subject = (exam['subject'] ?? 'Discipline').toString();
        final score = exam['score']?.toString() ?? '0';
        final total = exam['totalMarks']?.toString() ?? '100';
        final grade = exam['grade']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CPGlassCard(
            isDark: isDark, padding: const EdgeInsets.all(18), borderRadius: 24,
            child: Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy)),
                  Text(subject.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 0.5)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$score / $total', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.elitePrimary, letterSpacing: -0.5)),
                  if (grade.isNotEmpty) Text('Grade $grade', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.mintGreen, letterSpacing: 0.5)),
                ]),
              ],
            ),
          ),
        );
      }).toList(),
    ).animate().fadeIn(delay: 700.ms);
  }

  Widget _buildFeeHistory(bool isDark) {
    if (_feeHistory.isEmpty) return _emptyCard("No revenue history found", isDark);
    return Column(
      children: _feeHistory.map((fee) {
        final month = (fee['month'] ?? 'Cycle').toString();
        final amount = _toAmount(fee['amount']).toInt();
        final status = ((fee['status'] as String?) ?? 'pending').toUpperCase();
        final feeColor = status == 'PAID' ? AppColors.mintGreen : status == 'OVERDUE' ? AppColors.error : AppColors.moltenAmber;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CPGlassCard(
            isDark: isDark, padding: const EdgeInsets.all(18), borderRadius: 24,
            child: Row(
              children: [
                Expanded(child: Text(month.toUpperCase(), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: 0.5))),
                Text('₹$amount', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)),
                const SizedBox(width: 14),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: feeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: feeColor.withValues(alpha: 0.2))), child: Text(status, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: feeColor, letterSpacing: 0.5))),
              ],
            ),
          ),
        );
      }).toList(),
    ).animate().fadeIn(delay: 800.ms);
  }

  Widget _buildActionRow(String phone, String pPhone, bool isDark) {
    return Row(
      children: [
        Expanded(child: _actionBtn(Icons.phone_rounded, 'CALL PARENT', () => _callPhone(pPhone.isEmpty ? phone : pPhone), AppColors.elitePrimary, isDark)),
        const SizedBox(width: 16),
        Expanded(child: _actionBtn(Icons.chat_bubble_rounded, 'WHATSAPP', () => _openWhatsApp(pPhone.isEmpty ? phone : pPhone), AppColors.mintGreen, isDark)),
      ],
    ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.2);
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, Color color, bool isDark) {
    return CPPressable(
      onTap: () { HapticFeedback.mediumImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.15))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18, color: color), const SizedBox(width: 10), Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5))]),
      ),
    );
  }

  Widget _emptyCard(String msg, bool isDark) => CPGlassCard(isDark: isDark, padding: const EdgeInsets.all(32), borderRadius: 28, child: Center(child: Text(msg, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white24 : Colors.black26))));

  double _toAmount(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  void _callPhone(String number) { if (number.isNotEmpty) launchUrl(Uri.parse('tel:$number')); }
  void _openWhatsApp(String number) {
    final cleanNum = number.replaceAll(RegExp(r'[^0-9]'), '');
    final whatsappNum = cleanNum.length == 10 ? '91$cleanNum' : cleanNum;
    launchUrl(Uri.parse('https://wa.me/$whatsappNum'));
  }
}

class _EliteRingPainter extends CustomPainter {
  final double p;
  final Color c;
  final bool isDark;
  _EliteRingPainter(this.p, this.c, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final ctr = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    
    // Background track
    canvas.drawCircle(ctr, r, Paint()..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)..style = PaintingStyle.stroke..strokeWidth = 6);
    
    // Progress glow
    canvas.drawArc(Rect.fromCircle(center: ctr, radius: r), -math.pi / 2, 2 * math.pi * p, false, Paint()..color = c.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 10..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    
    // Progress stroke
    canvas.drawArc(Rect.fromCircle(center: ctr, radius: r), -math.pi / 2, 2 * math.pi * p, false, Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

