import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../data/repositories/parent_repository.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  final ParentRepository _parentRepo = sl<ParentRepository>();
  List<_PaymentItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeeRecords();
  }

  Future<void> _loadFeeRecords() async {
    try {
      final records = await _parentRepo.getPaymentHistory();
      if (!mounted) return;
      setState(() {
        _items = records.map(_PaymentItem.fromMap).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        leading: IconButton(
          onPressed: () { if (context.canPop()) { context.pop(); } else { context.go('/parent'); } },
          icon: Icon(Icons.arrow_back_rounded, color: CT.textH(context)),
        ),
        title: Text(
          'Payment History',
          style: GoogleFonts.sora(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: CT.textH(context),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text('Failed to load payment history', style: GoogleFonts.dmSans(color: CT.textS(context))),
                )
              : _items.isEmpty
                  ? Center(
                      child: Text('No payment records yet', style: GoogleFonts.dmSans(color: CT.textS(context))),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.pagePaddingH,
                        AppDimensions.md,
                        AppDimensions.pagePaddingH,
                        110,
                      ),
                      itemCount: _items.length + 1,
                      separatorBuilder: (context, idx) => const SizedBox(height: AppDimensions.step),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _summaryCard(context, _items);
                        }
                        final item = _items[index - 1];
                        return _paymentTile(context, item);
                      },
                    ),
    );
  }

  Widget _summaryCard(BuildContext context, List<_PaymentItem> items) {
    final paidCount = items.where((e) => e.status == _PaymentStatus.paid).length;
    final pendingCount = items.where((e) => e.status == _PaymentStatus.pending).length;
    final overdueCount = items.where((e) => e.status == _PaymentStatus.overdue).length;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: CT.elevatedCardDecor(context),
      child: Row(
        children: [
          Expanded(child: _miniMetric(context, 'Paid', '$paidCount', AppColors.success)),
          const SizedBox(width: AppDimensions.step),
          Expanded(child: _miniMetric(context, 'Pending', '$pendingCount', AppColors.warning)),
          const SizedBox(width: AppDimensions.step),
          Expanded(child: _miniMetric(context, 'Overdue', '$overdueCount', AppColors.error)),
        ],
      ),
    );
  }

  Widget _miniMetric(BuildContext context, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CT.textS(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentTile(BuildContext context, _PaymentItem item) {
    final statusColor = switch (item.status) {
      _PaymentStatus.paid => AppColors.success,
      _PaymentStatus.pending => AppColors.warning,
      _PaymentStatus.overdue => AppColors.error,
    };

    final statusLabel = switch (item.status) {
      _PaymentStatus.paid => 'Paid',
      _PaymentStatus.pending => 'Pending',
      _PaymentStatus.overdue => 'Overdue',
    };

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: CT.cardDecor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.month,
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CT.textH(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            item.description,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: CT.textS(context),
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Text(
                '₹${item.amount}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CT.textH(context),
                ),
              ),
              const Spacer(),
              Text(
                item.date,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: CT.textM(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _PaymentStatus { paid, pending, overdue }

class _PaymentItem {
  final String month;
  final String description;
  final String amount;
  final String date;
  final _PaymentStatus status;

  const _PaymentItem({
    required this.month,
    required this.description,
    required this.amount,
    required this.date,
    required this.status,
  });

  factory _PaymentItem.fromMap(Map<String, dynamic> map) {
    final rawStatus = (map['status'] ?? 'pending').toString().toLowerCase();
    final status = rawStatus == 'paid'
        ? _PaymentStatus.paid
        : rawStatus == 'overdue'
            ? _PaymentStatus.overdue
            : _PaymentStatus.pending;

    const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthNum = (map['month'] as num?)?.toInt() ?? 0;
    final year = (map['year'] as num?)?.toInt() ?? 0;
    final batchInfo = map['batch'] is Map ? (map['batch'] as Map)['name'] ?? '' : '';
    final monthLabel = monthNum > 0 && monthNum <= 12
        ? '${monthNames[monthNum]} $year'
        : (map['month'] ?? 'Unknown').toString();

    final rawDueDate = map['due_date']?.toString() ?? '';
    String formattedDate = (map['dateLabel'] ?? '').toString();
    if (formattedDate.isEmpty && rawDueDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDueDate);
        formattedDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {
        formattedDate = rawDueDate;
      }
    }

    return _PaymentItem(
      month: monthLabel,
      description: batchInfo.toString().isNotEmpty
          ? 'Batch: $batchInfo'
          : (map['description'] ?? 'Fee Payment').toString(),
      amount: (map['final_amount'] ?? map['amount_due'] ?? map['amount'] ?? 0).toString(),
      date: formattedDate,
      status: status,
    );
  }
}
