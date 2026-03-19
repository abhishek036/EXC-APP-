import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';

class FeeHistoryPage extends StatelessWidget {
  const FeeHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text('Fee History', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(context),
            const SizedBox(height: 20),
            _buildPaymentSummary(context),
            const SizedBox(height: 24),
            _buildTransactionList(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: AppColors.heroGradient,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
      boxShadow: [BoxShadow(color: AppColors.electricBlue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Outstanding Balance', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 8),
        Text('₹12,500', style: GoogleFonts.jetBrainsMono(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 4),
        Text('Due: 5 March 2026', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white60)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: CT.card(context), borderRadius: BorderRadius.circular(AppDimensions.radiusFull)),
              child: Center(child: Text('Pay Now', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.electricBlue))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Center(child: Text('Download', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
            ),
          ),
        ]),
      ],
    ),
  ).animate().fadeIn(duration: 600.ms);

  Widget _buildPaymentSummary(BuildContext context) => Row(
    children: [
      _summaryCard(context, 'Total Paid', '₹62,500', AppColors.mintGreen),
      const SizedBox(width: 10),
      _summaryCard(context, 'Pending', '₹12,500', AppColors.moltenAmber),
      const SizedBox(width: 10),
      _summaryCard(context, 'Receipts', '5', AppColors.electricBlue),
    ],
  ).animate(delay: 200.ms).fadeIn();

  Widget _summaryCard(BuildContext context, String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: CT.cardDecor(context),
      child: Column(children: [
        Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: CT.textS(context)), textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _buildTransactionList(BuildContext context) {
    final transactions = [
      _Txn('Tuition Fee — March', '₹12,500', 'Pending', '1 Mar 2026', AppColors.moltenAmber, Icons.hourglass_top),
      _Txn('Tuition Fee — February', '₹12,500', 'Paid', '1 Feb 2026', AppColors.mintGreen, Icons.check_circle),
      _Txn('Exam Fee — Mid Term', '₹2,000', 'Paid', '15 Jan 2026', AppColors.mintGreen, Icons.check_circle),
      _Txn('Tuition Fee — January', '₹12,500', 'Paid', '2 Jan 2026', AppColors.mintGreen, Icons.check_circle),
      _Txn('Lab Fee — Q4', '₹3,000', 'Paid', '10 Dec 2025', AppColors.mintGreen, Icons.check_circle),
      _Txn('Tuition Fee — December', '₹12,500', 'Paid', '1 Dec 2025', AppColors.mintGreen, Icons.check_circle),
      _Txn('Admission Fee', '₹10,000', 'Paid', '1 Sep 2025', AppColors.mintGreen, Icons.check_circle),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Transactions', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: CT.card(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CT.border(context)),
            ),
            child: Row(children: [
              Icon(Icons.filter_list, size: 14, color: CT.textS(context)),
              const SizedBox(width: 4),
              Text('All', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: CT.textS(context))),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        ...transactions.asMap().entries.map((e) => _buildTxnCard(context, e.value, e.key)),
      ],
    ).animate(delay: 300.ms).fadeIn();
  }

  Widget _buildTxnCard(BuildContext context, _Txn txn, int index) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: CT.cardDecor(context, radius: AppDimensions.radiusSM),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: txn.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(txn.icon, size: 18, color: txn.color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(txn.name, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: CT.textH(context))),
          const SizedBox(height: 2),
          Text(txn.date, style: GoogleFonts.dmSans(fontSize: 11, color: CT.textM(context))),
        ],
      )),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(txn.amount, style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: CT.textH(context))),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: txn.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(txn.status, style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: txn.color)),
        ),
      ]),
    ]),
  ).animate(delay: Duration(milliseconds: 350 + index * 60)).fadeIn().slideX(begin: 0.05, end: 0);
}

class _Txn {
  final String name, amount, status, date;
  final Color color;
  final IconData icon;
  _Txn(this.name, this.amount, this.status, this.date, this.color, this.icon);
}
