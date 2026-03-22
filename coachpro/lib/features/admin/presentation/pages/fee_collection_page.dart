import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/utils/pdf_generator.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_shimmer.dart';

class FeeCollectionPage extends StatefulWidget {
  const FeeCollectionPage({super.key});
  @override
  State<FeeCollectionPage> createState() => _FeeCollectionPageState();
}

class _FeeCollectionPageState extends State<FeeCollectionPage> {
  final _adminRepo = sl<AdminRepository>();
  int _selectedStatus = 0;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _statuses = ['All', 'Paid', 'Pending', 'Overdue', 'Partial'];
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase()));
    _loadFeeRecords();
  }

  Future<void> _loadFeeRecords() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final records = await _adminRepo.getFeeRecords();
      if (!mounted) return;
      setState(() { _records = records; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to sync data'; _loading = false; });
    }
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  String _fmtCur(double amount) {
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toInt()}';
  }

  double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  floating: true, pinned: true,
                  backgroundColor: Colors.transparent, elevation: 0,
                  scrolledUnderElevation: 0,
                  title: Text('Revenue Ledger', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 24, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -1)),
                  actions: [
                    _appBarAction(Icons.auto_awesome_rounded, () => _showGenerateFeesSheet(context), isDark),
                    const SizedBox(width: 12),
                    _appBarAction(Icons.settings_suggest_rounded, () => _showFeeStructureSheet(context), isDark),
                    const SizedBox(width: 20),
                  ],
                ),
              ],
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 12),
                      _buildSummaryHeader(isDark),
                      const SizedBox(height: 28),
                      _buildFilters(isDark),
                      const SizedBox(height: 16),
                      _buildSearchBar(isDark),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _loading 
                      ? ListView.separated(padding: const EdgeInsets.all(20), itemCount: 5, separatorBuilder: (_, _) => const SizedBox(height: 16), itemBuilder: (_, _) => CPShimmer(width: double.infinity, height: 90, borderRadius: 24))
                      : _error.isNotEmpty 
                        ? Center(child: Text(_error, style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w800)))
                        : RefreshIndicator(onRefresh: _loadFeeRecords, color: AppColors.elitePrimary, child: _buildRecordsList(isDark)),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30, right: 20,
            child: CPPressable(
              onTap: () {
                HapticFeedback.heavyImpact();
                _showCollectFeeSheet(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(color: const Color(0xFF0D1282), border: Border.all(color: const Color(0xFF0D1282), width: 3), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(4, 4), blurRadius: 0)]),
                child: Row(children: [const Icon(Icons.add_rounded, color: Color(0xFFEEEDED), size: 24), const SizedBox(width: 8), Text('COLLECT FEE', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFFEEEDED), fontSize: 13, letterSpacing: 0.5))]),
              ),
            ),
          ).animate().slideY(begin: 1, duration: 600.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }

  // Removed glow method

  Widget _appBarAction(IconData icon, VoidCallback onTap, bool isDark) {
    return CPPressable(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: const Color(0xFFF0DE36), border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3), blurRadius: 0)]),
        child: Icon(icon, size: 20, color: const Color(0xFF0D1282)),
      ),
    );
  }

  Widget _buildSummaryHeader(bool isDark) {
    double col = 0, pen = 0, over = 0;
    for (final f in _records) {
      final amt = _toDouble(f['final_amount'] ?? f['amount']);
      final pays = (f['payments'] as List?) ?? const [];
      final paid = pays.fold<double>(0, (sum, p) => sum + _toDouble((p as Map)['amount_paid']));
      final status = (f['status'] ?? '').toString().toLowerCase();
      col += paid;
      if (status == 'overdue') {
        over += (amt - paid).clamp(0, double.infinity);
      } else if (status != 'paid') {
        pen += (amt - paid).clamp(0, double.infinity);
      }
    }
    return Row(
      children: [
        _heroStat('Total Revenue', col, AppColors.premiumEliteGradient, isDark),
        const SizedBox(width: 12),
        Expanded(child: Column(children: [
          _miniStat('Pending', pen, AppColors.feePending, isDark),
          const SizedBox(height: 8),
          _miniStat('Overdue', over, AppColors.error, isDark),
        ])),
      ],
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _heroStat(String label, double val, Gradient grad, bool isDark) {
    return Container(
      width: 170, height: 110, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF0D1282), border: Border.all(color: const Color(0xFF0D1282), width: 3), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(4, 4), blurRadius: 0)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFFF0DE36), letterSpacing: 0.5)),
        const SizedBox(height: 6),
        FittedBox(child: Text(_fmtCur(val), style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.5))),
      ]),
    );
  }

  Widget _miniStat(String label, double val, Color color, bool isDark) {
    return SizedBox(
      height: 51,
      child: CPGlassCard(
      isDark: isDark, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), borderRadius: 20,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 0.5)),
        Text(_fmtCur(val), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
      ]),
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _statuses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => CPPressable(
          onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedStatus = i); },
          child: AnimatedContainer(
            duration: 250.ms, padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _selectedStatus == i ? const Color(0xFFF0DE36) : const Color(0xFFEEEDED),
              border: Border.all(color: const Color(0xFF0D1282), width: 2),
              boxShadow: _selectedStatus == i ? const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3))] : [],
            ),
            child: Center(child: Text(_statuses[i].toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282), letterSpacing: 0.5))),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFFEEEDED), border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3))]),
      child: TextField(
        controller: _searchCtrl,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.deepNavy),
        decoration: InputDecoration(hintText: 'Search ledger entries...', hintStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26)), prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16)),
      ),
    );
  }

  Widget _buildRecordsList(bool isDark) {
    var filtered = List<Map<String, dynamic>>.from(_records);
    if (_selectedStatus > 0) {
      final status = _statuses[_selectedStatus].toLowerCase();
      filtered = filtered.where((r) => (r['status'] ?? '').toString().toLowerCase() == status).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) {
        final stu = (r['student']?['name'] ?? '').toString().toLowerCase();
        final bat = (r['batch']?['name'] ?? '').toString().toLowerCase();
        return stu.contains(_searchQuery) || bat.contains(_searchQuery);
      }).toList();
    }

    if (filtered.isEmpty) return _emptyState(isDark);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _feeCard(filtered[i], i, isDark),
    );
  }

  Widget _feeCard(Map<String, dynamic> r, int i, bool isDark) {
    final name = (r['student']?['name'] ?? 'Pupil').toString();
    final batch = (r['batch']?['name'] ?? 'Batch').toString();
    final month = _monthLabel(r['month'], r['year']);
    final status = (r['status'] ?? 'pending').toString().toUpperCase();
    final total = _toDouble(r['final_amount'] ?? r['amount']);


    final sColor = status == 'PAID' ? AppColors.mintGreen : status == 'OVERDUE' ? AppColors.error : status == 'PARTIAL' ? AppColors.moltenAmber : AppColors.feePending;

    return CPPressable(
      onTap: () {
        HapticFeedback.lightImpact();
        _showFeeDetailSheet(context, r);
      },
      child: CPGlassCard(
        isDark: isDark, padding: const EdgeInsets.all(20), borderRadius: 28,
        child: Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFF0DE36), border: Border.all(color: const Color(0xFF0D1282), width: 2)), child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282))))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282), letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text('${batch.toUpperCase()} • ${month.toUpperCase()}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282), letterSpacing: 0.5)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${total.toInt()}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282), letterSpacing: -0.8)),
            const SizedBox(height: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFEEEDED), border: Border.all(color: sColor, width: 2), boxShadow: [BoxShadow(color: sColor, offset: const Offset(2, 2))]), child: Text(status, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282), letterSpacing: 0.5))),
          ]),
        ]),
      ),
    ).animate(delay: Duration(milliseconds: 30 * (i % 10))).fadeIn(duration: 500.ms).slideX(begin: 0.05);
  }

  Widget _emptyState(bool isDark) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03), shape: BoxShape.circle), child: Icon(Icons.receipt_long_rounded, size: 48, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1))),
      const SizedBox(height: 24),
      Text('No ledger entries found', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26))),
    ]));
  }

  void _showFeeDetailSheet(BuildContext context, Map<String, dynamic> fee) {
    final isDark = CT.isDark(context);
    final status = (fee['status'] ?? 'pending').toString().toUpperCase();
    final name = (fee['student']?['name'] ?? 'Pupil').toString();
    final amt = _toDouble(fee['final_amount'] ?? fee['amount']);
    final pays = (fee['payments'] as List?) ?? const [];
    final paid = pays.fold<double>(0, (sum, p) => sum + _toDouble((p as Map)['amount_paid']));
    final id = (fee['id'] ?? '').toString();

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => CPGlassCard(
        isDark: isDark, padding: EdgeInsets.fromLTRB(28, 16, 28, MediaQuery.of(ctx).viewInsets.bottom + 40), borderRadius: 40,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 32),
          Text(name, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -1)),
          const SizedBox(height: 6),
          Text('${(fee['batch']?['name'] ?? 'Batch').toString().toUpperCase()} • ${_monthLabel(fee['month'], fee['year']).toUpperCase()}', style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(height: 40),
          Row(children: [
            _detailStat('BILLED', '₹${amt.toInt()}', isDark),
            _detailStat('CLEARED', '₹${paid.toInt()}', isDark),
            _detailStat('PENDING', '₹${(amt - paid).toInt()}', isDark),
          ]),
          const SizedBox(height: 40),
          if (status != 'PAID') ...[
            CustomButton(text: 'Settle Full Amount', icon: Icons.offline_pin_rounded, onPressed: () async {
              try {
                final pend = (amt - paid).clamp(0, double.infinity);
                if (pend <= 0) return;
                await _adminRepo.recordFeePayment(feeRecordId: id, amountPaid: pend, paymentMode: 'cash', note: 'Bulk update');
                if (ctx.mounted) { Navigator.pop(ctx); CPToast.success(context, 'Ledger updated ✅'); _loadFeeRecords(); }
              } catch (_) { if (ctx.mounted) CPToast.error(ctx, 'Update failed'); }
            }),
            const SizedBox(height: 16),
          ],
          CPPressable(
            onTap: () { Navigator.pop(ctx); PdfGenerator.generateFeeReceipt(fee); }, 
            child: Container(
              width: double.infinity, height: 56, 
              decoration: BoxDecoration(color: const Color(0xFFF0DE36), border: Border.all(color: const Color(0xFF0D1282), width: 3), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3))]), 
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.print_rounded, size: 20, color: const Color(0xFF0D1282)), const SizedBox(width: 10), Text('Generate Receipt', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF0D1282), fontSize: 13, letterSpacing: 0.5))]))
            )
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _detailStat(String l, String v, bool isDark) => Expanded(child: Column(children: [Text(v, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)), const SizedBox(height: 6), Text(l, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 0.5))]));

  void _showCollectFeeSheet(BuildContext context) {
    final isDark = CT.isDark(context);
    final debtors = _records
        .where((r) => (r['status'] ?? '').toString().toLowerCase() != 'paid')
        .toList();
    String? sid = debtors.isNotEmpty ? debtors.first['id'].toString() : null;
    final amtC = TextEditingController();
    final nC = TextEditingController();
    String mode = 'cash';

    if (sid != null && debtors.isNotEmpty) {
      final first = debtors.first;
      final pend = _toDouble(first['final_amount'] ?? first['amount']) - (_toDouble((first['payments'] as List? ?? []).fold<double>(0, (s, p) => s + _toDouble((p as Map)['amount_paid']))));
      amtC.text = pend > 0 ? pend.toInt().toString() : '';
    }

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom), child: CPGlassCard(isDark: isDark, padding: EdgeInsets.fromLTRB(28, 16, 28, MediaQuery.of(ctx).viewInsets.bottom + 40), borderRadius: 40, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)))),
      const SizedBox(height: 32),
      Text('Immediate Collection', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -1)),
      const SizedBox(height: 32),
      _sheetLabel('ACTIVE DEBTORS', isDark),
      const SizedBox(height: 10),
      if (debtors.isEmpty) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : AppColors.deepNavy).withValues(alpha: 0.05),
            border: Border.all(color: const Color(0xFF0D1282), width: 2),
          ),
          child: Text(
            'No outstanding accounts available',
            style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600),
          ),
        ),
      ] else ...[
      Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), decoration: BoxDecoration(color: (isDark ? Colors.white : AppColors.deepNavy).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: sid, hint: Text('Select outstanding account', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26), fontWeight: FontWeight.w600)), isExpanded: true, dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white, icon: const Icon(Icons.keyboard_arrow_down_rounded), items: debtors.map((r) {
        final pend = _toDouble(r['final_amount'] ?? r['amount']) - (_toDouble((r['payments'] as List? ?? []).fold<double>(0, (s, p) => s + _toDouble((p as Map)['amount_paid']))));
        return DropdownMenuItem(value: r['id'].toString(), child: Text('${r['student']?['name']} • ₹${pend.toInt()}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.deepNavy)));
      }).toList(), onChanged: (v) { setS(() { sid = v; final r = _records.firstWhere((e) => e['id'].toString() == v); final pend = _toDouble(r['final_amount'] ?? r['amount']) - (_toDouble((r['payments'] as List? ?? []).fold<double>(0, (s, p) => s + _toDouble((p as Map)['amount_paid'])))); amtC.text = pend.toInt().toString(); }); }))),
      ],
      const SizedBox(height: 24),
      CustomTextField(label: 'Amount Tendered (₹)', hint: '0', controller: amtC, prefixIcon: Icons.currency_rupee_rounded, keyboardType: TextInputType.number),
      const SizedBox(height: 28),
      _sheetLabel('TENDER TYPE', isDark),
      const SizedBox(height: 12),
      Row(children: ['cash', 'upi', 'bank'].map((m) => Expanded(child: CPPressable(onTap: () { HapticFeedback.selectionClick(); setS(() => mode = m); }, child: AnimatedContainer(duration: 250.ms, margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: mode == m ? AppColors.elitePrimary : (isDark ? Colors.white : AppColors.deepNavy).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: mode == m ? Colors.transparent : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)))), child: Center(child: Text(m.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: mode == m ? Colors.white : (isDark ? Colors.white38 : Colors.black38), letterSpacing: 0.5))))))).toList()),
      const SizedBox(height: 48),
      CustomButton(text: 'Process Payment', icon: Icons.offline_bolt_rounded, onPressed: () async {
        if (debtors.isEmpty) { CPToast.warning(ctx, 'No outstanding accounts to collect'); return; }
        if (sid == null || amtC.text.isEmpty) { CPToast.warning(ctx, 'Select an account and enter an amount'); return; }
        try { await _adminRepo.recordFeePayment(feeRecordId: sid!, amountPaid: double.parse(amtC.text), paymentMode: mode, note: nC.text); if (ctx.mounted) { Navigator.pop(ctx); CPToast.success(context, 'Transaction Confirmed'); _loadFeeRecords(); } } catch (_) { if (ctx.mounted) CPToast.error(ctx, 'Transaction Error'); }
      }),
      const SizedBox(height: 12),
    ]))))));
  }

  Widget _sheetLabel(String l, bool isDark) => Padding(padding: const EdgeInsets.only(left: 4), child: Text(l, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 0.5)));

  void _showGenerateFeesSheet(BuildContext context) {
    final isDark = CT.isDark(context);
    String? bid; int m = DateTime.now().month; int y = DateTime.now().year; bool loading = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => CPGlassCard(
        isDark: isDark, padding: EdgeInsets.fromLTRB(28, 16, 28, MediaQuery.of(ctx).viewInsets.bottom + 40), borderRadius: 40,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 32),
          Text('Batch Propagation', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -1)),
          const SizedBox(height: 8),
          Text('Deploy fee contracts to all enrolled members.', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600)),
          const SizedBox(height: 40),
          _sheetLabel('TARGET OPERATION BATCH', isDark),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _adminRepo.getBatches(),
            builder: (ctx, snap) {
              final batches = snap.data ?? [];
              return Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), decoration: BoxDecoration(color: (isDark ? Colors.white : AppColors.deepNavy).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: bid, hint: Text('Select Academy Batch', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26))), isExpanded: true, dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white, items: batches.map((b) => DropdownMenuItem(value: b['id'].toString(), child: Text(b['name'].toString(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.deepNavy)))).toList(), onChanged: (v) => setS(() => bid = v))));
            }
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sheetLabel('BILLING CYCLE', isDark),
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: (isDark ? Colors.white : AppColors.deepNavy).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))), child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: m, isExpanded: true, dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white, items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat('MMMM').format(DateTime(2024, i + 1)), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.deepNavy)))), onChanged: (v) => setS(() => m = v!)))),
            ])),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sheetLabel('TICK YEAR', isDark),
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: (isDark ? Colors.white : AppColors.deepNavy).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))), child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: y, isExpanded: true, dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white, items: [y, y+1].map((year) => DropdownMenuItem(value: year, child: Text(year.toString(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.deepNavy)))).toList(), onChanged: (v) => setS(() => y = v!)))),
            ])),
          ]),
          const SizedBox(height: 48),
          CustomButton(text: 'Deploy Contracts', isLoading: loading, icon: Icons.rocket_launch_rounded, onPressed: () async {
            if (bid == null) { CPToast.warning(ctx, 'Identify a batch target'); return; }
            setS(() => loading = true);
            try {
              await _adminRepo.generateMonthlyFees(batchId: bid!, month: m, year: y);
              if (ctx.mounted) { Navigator.pop(ctx); CPToast.success(context, 'Propagation successful. 🌐'); _loadFeeRecords(); }
            } catch (_) { if (ctx.mounted) { CPToast.error(ctx, 'Propagation protocol failed.'); setS(() => loading = false); } }
          }),
          const SizedBox(height: 12),
        ]),
      )),
    );
  }

  void _showFeeStructureSheet(BuildContext context) {
    final isDark = CT.isDark(context);
    String? bid; final fC = TextEditingController(); final aC = TextEditingController(); final lC = TextEditingController(); bool loading = false; bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSS) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom), child: CPGlassCard(
        isDark: isDark, padding: EdgeInsets.fromLTRB(28, 16, 28, 40), borderRadius: 40,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 32),
          Text('Financial Policy', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -1)),
          const SizedBox(height: 32),
          _sheetLabel('REGULATION BATCH', isDark),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _adminRepo.getBatches(),
            builder: (ctx, snap) {
              final batches = snap.data ?? [];
              return Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), decoration: BoxDecoration(color: (isDark ? Colors.white : AppColors.deepNavy).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: bid, hint: Text('Select Regulated Batch', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26))), isExpanded: true, dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white, items: batches.map((b) => DropdownMenuItem(value: b['id'].toString(), child: Text(b['name'].toString(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.deepNavy)))).toList(), onChanged: (v) async {
                setSS(() { bid = v; loading = true; });
                try {
                  final struct = await _adminRepo.getFeeStructure(v!);
                  setSS(() { fC.text = (struct['monthly_fee'] ?? '').toString(); aC.text = (struct['admission_fee'] ?? '').toString(); lC.text = (struct['late_fee_amount'] ?? '').toString(); loading = false; });
                } catch (_) { setSS(() { fC.clear(); aC.clear(); lC.clear(); loading = false; }); }
              })));
            }
          ),
          const SizedBox(height: 32),
          if (loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.elitePrimary)))
          else if (bid != null) ...[
            CustomTextField(label: 'Monthly Tariff (₹)', controller: fC, keyboardType: TextInputType.number, prefixIcon: Icons.payments_rounded),
            const SizedBox(height: 24),
            CustomTextField(label: 'Registration Tariff (₹)', controller: aC, keyboardType: TextInputType.number, prefixIcon: Icons.how_to_reg_rounded),
            const SizedBox(height: 24),
            CustomTextField(label: 'Penalty Threshold (₹)', controller: lC, keyboardType: TextInputType.number, prefixIcon: Icons.gavel_rounded),
            const SizedBox(height: 48),
            CustomButton(text: 'Enforce Policy', isLoading: saving, icon: Icons.gavel_rounded, onPressed: () async {
              setSS(() => saving = true);
              try {
                await _adminRepo.defineFeeStructure({'batch_id': bid, 'monthly_fee': double.tryParse(fC.text) ?? 0, 'admission_fee': double.tryParse(aC.text) ?? 0, 'late_fee_amount': double.tryParse(lC.text) ?? 0});
                if (ctx.mounted) { Navigator.pop(ctx); CPToast.success(context, 'Regulations Enforced! ⚖️'); }
              } catch (_) { if (ctx.mounted) { CPToast.error(ctx, 'Enforcement failure'); setSS(() => saving = false); } }
            }),
          ],
        ])),
      ))),
    );
  }

  String _monthLabel(dynamic month, dynamic year) {
    if (month is int && year is int && month >= 1 && month <= 12) {
      return DateFormat('MMM yyyy').format(DateTime(year, month));
    }
    return '';
  }
}
