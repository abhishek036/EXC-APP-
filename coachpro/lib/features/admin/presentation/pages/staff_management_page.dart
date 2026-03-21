import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_shimmer.dart';
import '../../data/repositories/admin_repository.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  final _adminRepo = sl<AdminRepository>();
  int _tabIndex = 0; // 0: Staff, 1: History

  bool _loading = true;
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _payroll = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _adminRepo.getStaff(),
        _adminRepo.getStaffPayrollRecords(),
      ]);
      if (!mounted) return;
      setState(() {
        _staff = results[0];
        _payroll = results[1];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

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
                _buildAppBar(isDark),
                const SizedBox(height: 12),
                _buildSummary(isDark),
                const SizedBox(height: 24),
                _buildTabs(isDark),
                const SizedBox(height: 20),
                Expanded(
                  child: _loading
                      ? ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: 5,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, __) => const CPShimmer(width: double.infinity, height: 80, borderRadius: 16),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppColors.elitePrimary,
                          child: _tabIndex == 0 ? _buildStaffList(isDark) : _buildPayrollList(isDark),
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30, right: 20,
            child: CPPressable(
              onTap: () {
                HapticFeedback.heavyImpact();
                _tabIndex == 0 ? _showAddStaffSheet() : _showAddPayrollSheet();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(color: const Color(0xFF0D1282), border: Border.all(color: const Color(0xFF0D1282), width: 3), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(4, 4), blurRadius: 0)]),
                child: Row(children: [const Icon(Icons.add_rounded, color: Color(0xFFEEEDED), size: 24), const SizedBox(width: 8), Text(_tabIndex == 0 ? 'ONBOARD STAFF' : 'RECORD PAYOUT', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFFEEEDED), fontSize: 13, letterSpacing: 0.5))]),
              ),
            ),
          ).animate().slideY(begin: 1, duration: 600.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }

  // Removed _glow method

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          CPPressable(onTap: () => Navigator.pop(context), child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : AppColors.deepNavy)),
          const SizedBox(width: 16),
          Text('Human Capital', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.8)),
          const Spacer(),
          _appBarAction(Icons.refresh_rounded, _loadData, isDark),
        ],
      ),
    );
  }

  Widget _appBarAction(IconData icon, VoidCallback onTap, bool isDark) {
    return CPPressable(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: const Color(0xFFEEEDED), border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3), blurRadius: 0)]),
        child: Icon(icon, size: 20, color: const Color(0xFF0D1282)),
      ),
    );
  }

  Widget _buildSummary(bool isDark) {
    final totalSalary = _staff.fold<double>(0, (sum, s) => sum + _toAmount(s['salary']));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _statCard('STAFF COUNT', '${_staff.length}', AppColors.elitePrimary, isDark),
          const SizedBox(width: 12),
          _statCard('EST. LIABILITY', '₹${(totalSalary/1000).toStringAsFixed(1)}K', AppColors.mintGreen, isDark),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _statCard(String label, String val, Color color, bool isDark) {
    return Expanded(
      child: CPGlassCard(
        isDark: isDark, padding: const EdgeInsets.all(20), borderRadius: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26), letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(val, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))),
      child: Row(
        children: [
          _tabItem('Employees', 0, isDark),
          _tabItem('Disbursements', 1, isDark),
        ],
      ),
    );
  }

  Widget _tabItem(String title, int idx, bool isDark) {
    final active = _tabIndex == idx;
    return Expanded(
      child: CPPressable(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _tabIndex = idx);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: active ? const Color(0xFFF0DE36) : const Color(0xFFEEEDED), border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: active ? const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3))] : null),
          alignment: Alignment.center,
          child: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
        ),
      ),
    );
  }

  Widget _buildStaffList(bool isDark) {
    if (_staff.isEmpty) return _emptyState('The roster is empty.', Icons.people_outline_rounded, isDark);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: _staff.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, i) {
        final staff = _staff[i];
        final salary = _toAmount(staff['salary']).toInt();
        return CPGlassCard(
          isDark: isDark, padding: const EdgeInsets.all(20), borderRadius: 28,
          child: Row(
            children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.elitePrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.elitePrimary.withValues(alpha: 0.1))), child: const Icon(Icons.badge_rounded, color: AppColors.elitePrimary, size: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((staff['name'] ?? '').toString(), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.4)),
                    const SizedBox(height: 4),
                    Text('${(staff['role'] ?? '').toString().toUpperCase()} • ${(staff['phone'] ?? '').toString()}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white38 : Colors.black45, letterSpacing: 0.2)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${NumberFormat('#,##,###').format(salary)}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.mintGreen, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFEEEDED), border: Border.all(color: AppColors.elitePrimary, width: 2), boxShadow: const [BoxShadow(color: AppColors.elitePrimary, offset: Offset(2, 2))]), child: Text('ACTIVE', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282), letterSpacing: 0.5))),
                ],
              ),
            ],
          ),
        ).animate(delay: (i * 30).ms).fadeIn(duration: 500.ms).slideX(begin: 0.05);
      },
    );
  }

  Widget _buildPayrollList(bool isDark) {
    if (_payroll.isEmpty) return _emptyState('No disbursement records found.', Icons.account_balance_rounded, isDark);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: _payroll.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final pay = _payroll[i];
        final amount = _toAmount(pay['amount']).toInt();
        return CPGlassCard(
          isDark: isDark, padding: const EdgeInsets.all(16), borderRadius: 24,
          child: Row(
            children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFEEEDED), border: Border.all(color: AppColors.mintGreen, width: 2), boxShadow: const [BoxShadow(color: AppColors.mintGreen, offset: Offset(2, 2))]), child: const Icon(Icons.payments_rounded, color: AppColors.mintGreen, size: 20)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((pay['staffName'] ?? '').toString(), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.3)),
                    const SizedBox(height: 2),
                    Text('${(pay['month'] ?? '').toString()} • ${(pay['type'] ?? '').toString().toUpperCase()}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.black45)),
                  ],
                ),
              ),
              Text('₹${NumberFormat('#,##,###').format(amount)}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)),
            ],
          ),
        ).animate(delay: (i * 30).ms).fadeIn(duration: 500.ms).slideX(begin: 0.05);
      },
    );
  }

  Widget _emptyState(String msg, IconData icon, bool isDark) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03), shape: BoxShape.circle), child: Icon(icon, size: 48, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1))), const SizedBox(height: 24), Padding(padding: const EdgeInsets.symmetric(horizontal: 50), child: Text(msg, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26)), textAlign: TextAlign.center))]));

  double _toAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  void _showAddStaffSheet() {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    final isDark = CT.isDark(context);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => CPGlassCard(
        isDark: isDark, padding: EdgeInsets.fromLTRB(28, 16, 28, MediaQuery.of(ctx).viewInsets.bottom + 40), borderRadius: 40,
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 32),
            Text('Hire Talent', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -1)),
            const SizedBox(height: 8),
            Text('Maintain strictly elite personnel standards.', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600)),
            const SizedBox(height: 32),
            CustomTextField(label: 'Full Name', hint: 'Jane Cooper', controller: nameCtrl, prefixIcon: Icons.badge_rounded),
            const SizedBox(height: 20),
            CustomTextField(label: 'Specialized Role', hint: 'Strategic Operations', controller: roleCtrl, prefixIcon: Icons.workspace_premium_rounded),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: CustomTextField(label: 'Contact', hint: '10 digits', controller: phoneCtrl, keyboardType: TextInputType.phone, prefixIcon: Icons.contact_phone_rounded)),
              const SizedBox(width: 16),
              Expanded(child: CustomTextField(label: 'Salary (₹)', hint: '0', controller: salaryCtrl, keyboardType: TextInputType.number, prefixIcon: Icons.payments_rounded)),
            ]),
            const SizedBox(height: 48),
              CustomButton(text: 'Finalize Hiring', icon: Icons.verified_user_rounded, onPressed: () async {
                if (nameCtrl.text.isEmpty || salaryCtrl.text.isEmpty) return;
                try {
                  await _adminRepo.createStaff(name: nameCtrl.text.trim(), role: roleCtrl.text.trim(), phone: phoneCtrl.text.trim(), salary: double.tryParse(salaryCtrl.text.trim()) ?? 0);
                  if (ctx.mounted) { 
                    Navigator.pop(ctx); 
                    CPToast.success(ctx, 'Personnel added effectively'); 
                    _loadData(); 
                  }
                } catch (_) { 
                  if (ctx.mounted) CPToast.error(ctx, 'Hiring protocol failed'); 
                }
              }),
          ],
        ),
      ),
    );
  }

  void _showAddPayrollSheet() {
    String? sid; final amtCtrl = TextEditingController(); String type = 'Salary'; final isDark = CT.isDark(context);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSS) => CPGlassCard(
        isDark: isDark, padding: EdgeInsets.fromLTRB(28, 16, 28, MediaQuery.of(ctx).viewInsets.bottom + 40), borderRadius: 40,
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 32),
            Text('Asset Disbursement', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -1)),
            const SizedBox(height: 32),
            Text('Identify Payee', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: sid, hint: Text('Select Elite Employee', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26), fontWeight: FontWeight.w600)), isExpanded: true, dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white, items: _staff.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name'].toString(), style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : AppColors.deepNavy, fontWeight: FontWeight.w700)))).toList(), onChanged: (v) => setSS(() => sid = v)))),
            const SizedBox(height: 24),
            CustomTextField(label: 'Disbursement Amount (₹)', hint: '0', controller: amtCtrl, keyboardType: TextInputType.number, prefixIcon: Icons.currency_rupee_rounded),
            const SizedBox(height: 32),
            Row(children: ['Salary', 'Bonus', 'Advance'].map((opt) => Expanded(child: CPPressable(onTap: () { HapticFeedback.selectionClick(); setSS(() => type = opt); }, child: AnimatedContainer(duration: 250.ms, margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: type == opt ? const Color(0xFFF0DE36) : const Color(0xFFEEEDED), border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: type == opt ? const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3))] : []), child: Center(child: Text(opt.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282), letterSpacing: 0.5))))))).toList()),
            const SizedBox(height: 48),
            CustomButton(text: 'Initiate Transfer', icon: Icons.bolt_rounded, onPressed: () async {
              if (sid == null || amtCtrl.text.isEmpty) return;
              try {
                await _adminRepo.createPayrollRecord(staffId: sid!, amount: double.tryParse(amtCtrl.text.trim()) ?? 0, type: type, month: DateFormat('MMMM').format(DateTime.now()), date: DateTime.now());
                if (ctx.mounted) { 
                  Navigator.pop(ctx); 
                  CPToast.success(ctx, 'Assets successfully dished out'); 
                  _loadData(); 
                }
              } catch (_) { 
                if (ctx.mounted) CPToast.error(ctx, 'Protocol failure'); 
              }
            }),
          ],
        ),
      )),
    );
  }
}
