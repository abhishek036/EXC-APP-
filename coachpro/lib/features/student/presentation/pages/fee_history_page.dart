import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../student/data/repositories/student_repository.dart';

class FeeHistoryPage extends StatefulWidget {
  const FeeHistoryPage({super.key});

  @override
  State<FeeHistoryPage> createState() => _FeeHistoryPageState();
}

class _FeeHistoryPageState extends State<FeeHistoryPage> {
  final _repo = sl<StudentRepository>();
  bool _isLoading = true;
  String? _error;

  // Overview data
  double _totalPaid = 0;
  double _totalPending = 0;
  int _totalRecords = 0;

  // Transaction list
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final overview = await _repo.getFeeOverview();
      final summary = overview['summary'] ?? {};
      final records = (overview['records'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      if (!mounted) return;
      setState(() {
        _totalPaid = (summary['total_paid'] ?? 0).toDouble();
        _totalPending = (summary['total_pending'] ?? 0).toDouble();
        _totalRecords = (summary['total_records'] ?? 0) as int;
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return f.format(amount);
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      return DateFormat('d MMM yyyy').format(d);
    } catch (_) {
      return date.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text(
          'Fee History',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: CT.textM(context)),
              const SizedBox(height: 12),
              Text('Failed to load fee data',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );

  Widget _buildBalanceCard(BuildContext context) {
    final nextDue = _records.firstWhere(
      (r) => (r['status'] ?? '') == 'pending',
      orElse: () => {},
    );
    final dueDate = nextDue.isNotEmpty ? _formatDate(nextDue['due_date']) : 'No dues';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1282),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        boxShadow: const [
          BoxShadow(
            color: AppColors.elitePrimary,
            blurRadius: 0,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Outstanding Balance',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(_totalPending),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _totalPending > 0 ? 'Due: $dueDate' : 'All fees cleared ✓',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white60),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildPaymentSummary(BuildContext context) => Row(
        children: [
          _summaryCard(context, 'Total Paid', _formatCurrency(_totalPaid), AppColors.mintGreen),
          const SizedBox(width: 10),
          _summaryCard(context, 'Pending', _formatCurrency(_totalPending), AppColors.moltenAmber),
          const SizedBox(width: 10),
          _summaryCard(context, 'Receipts', '$_totalRecords', AppColors.electricBlue),
        ],
      ).animate(delay: 200.ms).fadeIn();

  Widget _summaryCard(BuildContext context, String label, String value, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: CT.cardDecor(context),
          child: Column(
            children: [
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 14, fontWeight: FontWeight.w700, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.w600, color: CT.textS(context)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _buildTransactionList(BuildContext context) {
    if (_records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No fee records yet',
            style: GoogleFonts.plusJakartaSans(color: CT.textS(context)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transactions',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context)),
        ),
        const SizedBox(height: 12),
        ...List.generate(_records.length, (i) => _buildTxnCard(context, _records[i], i)),
      ],
    ).animate(delay: 300.ms).fadeIn();
  }

  Widget _buildTxnCard(BuildContext context, Map<String, dynamic> record, int index) {
    final status = (record['status'] ?? 'pending').toString();
    final isPaid = status == 'paid';
    final color = isPaid ? AppColors.mintGreen : AppColors.moltenAmber;
    final icon = isPaid ? Icons.check_circle : Icons.hourglass_top;
    final amount = (record['final_amount'] ?? 0).toDouble();
    final batchName = record['batch']?['name'] ?? 'General';
    final month = record['month']?.toString() ?? '';
    final year = record['year']?.toString() ?? '';
    final label = month.isNotEmpty ? '$batchName — $month/$year' : batchName;
    final date = _formatDate(record['due_date'] ?? record['created_at']);

    return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: CT.cardDecor(context, radius: AppDimensions.radiusSM),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w600, color: CT.textH(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textM(context)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(amount),
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 14, fontWeight: FontWeight.w700, color: CT.textH(context)),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPaid ? 'Paid' : 'Pending',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 9, fontWeight: FontWeight.w700, color: color),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: 350 + index * 60))
        .fadeIn()
        .slideX(begin: 0.05, end: 0);
  }
}
