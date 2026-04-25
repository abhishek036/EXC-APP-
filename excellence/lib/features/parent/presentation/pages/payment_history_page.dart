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
          onPressed: () { if (GoRouter.of(context).canPop()) { GoRouter.of(context).pop(); } else { GoRouter.of(context).go('/parent'); } },
          icon: Icon(Icons.arrow_back_rounded, color: CT.textH(context)),
        ),
        title: Text(
          'Payment History',
          style: GoogleFonts.plusJakartaSans(
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
                  child: Text('Failed to load payment history', style: GoogleFonts.plusJakartaSans(color: CT.textS(context))),
                )
              : _items.isEmpty
                  ? Center(
                      child: Text('No payment records yet', style: GoogleFonts.plusJakartaSans(color: CT.textS(context))),
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
    final pendingCount = items
        .where(
          (e) =>
              e.status == _PaymentStatus.pending ||
              e.status == _PaymentStatus.rejected,
        )
        .length;
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
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
      _PaymentStatus.rejected => AppColors.error,
      _PaymentStatus.overdue => AppColors.error,
    };

    final statusLabel = switch (item.status) {
      _PaymentStatus.paid => 'Paid',
      _PaymentStatus.pending => 'Pending',
      _PaymentStatus.rejected => 'Rejected',
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
                  style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: CT.textS(context),
            ),
          ),
          if (item.status == _PaymentStatus.rejected && item.rejectionReason.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
              ),
              child: Text(
                'Reason: ${item.rejectionReason}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
          if (item.activityLog.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Activity',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: CT.textS(context),
              ),
            ),
            const SizedBox(height: 4),
            ...item.activityLog.take(3).map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '- $line',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: CT.textM(context),
                  ),
                ),
              ),
            ),
          ],
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
                style: GoogleFonts.plusJakartaSans(
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

enum _PaymentStatus { paid, pending, rejected, overdue }

class _PaymentItem {
  final String month;
  final String description;
  final String amount;
  final String date;
  final _PaymentStatus status;
  final String rejectionReason;
  final List<String> activityLog;

  const _PaymentItem({
    required this.month,
    required this.description,
    required this.amount,
    required this.date,
    required this.status,
    this.rejectionReason = '',
    this.activityLog = const [],
  });

  factory _PaymentItem.fromMap(Map<String, dynamic> map) {
    final rawStatus = (map['status'] ?? 'pending').toString().toLowerCase();
    final status = rawStatus == 'paid'
      ? _PaymentStatus.paid
      : rawStatus == 'rejected'
        ? _PaymentStatus.rejected
      : rawStatus == 'overdue'
        ? _PaymentStatus.overdue
        : _PaymentStatus.pending;

    String rejectionReason = (map['latest_rejection_reason'] ?? map['rejection_reason'] ?? '').toString().trim();
    final activityLog = _extractActivityLog(map);
    if (rejectionReason.isEmpty && map['payments'] is List) {
      final payments = (map['payments'] as List).cast<dynamic>();
      for (final payment in payments) {
        if (payment is! Map) continue;
        final pStatus = (payment['status'] ?? '').toString().toLowerCase();
        if (pStatus != 'rejected') continue;
        final reason = (payment['rejection_reason'] ?? '').toString().trim();
        if (reason.isNotEmpty) {
          rejectionReason = reason;
          break;
        }
      }
    }

    const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthNum = _toInt(map['month']) ?? 0;
    final year = _toInt(map['year']) ?? 0;
    final batchInfo = map['batch'] is Map ? (map['batch'] as Map)['name'] ?? '' : '';
    final monthLabel = monthNum > 0 && monthNum <= 12
        ? '${monthNames[monthNum]} $year'
        : (map['month'] ?? 'Unknown').toString();

    final totalAmount = _toDouble(map['final_amount'] ?? map['amount_due'] ?? map['amount'] ?? 0);
    final paidAmount = _toDouble(map['paid_amount']);
    final explicitRemaining = _toDouble(map['remaining_amount']);
    final remainingAmount = explicitRemaining > 0
      ? explicitRemaining
      : (totalAmount - paidAmount).clamp(0, double.infinity).toDouble();

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
      amount: (status == _PaymentStatus.paid ? totalAmount : remainingAmount).toStringAsFixed(0),
      date: formattedDate,
      status: status,
      rejectionReason: rejectionReason,
      activityLog: activityLog,
    );
  }

  static List<String> _extractActivityLog(Map<String, dynamic> map) {
    final payments = (map['payments'] as List?)?.cast<dynamic>() ?? const [];
    final lines = <String>[];

    for (final raw in payments) {
      if (raw is! Map) continue;
      final payment = Map<String, dynamic>.from(raw);
      final amount = _toDouble(payment['amount_paid']);
      final status = (payment['status'] ?? '').toString().toLowerCase();
      final submittedAt = _formatDate(payment['submitted_at']);
      final approvedAt = _formatDate(payment['approved_at'] ?? payment['paid_at']);
      final rejectedAt = _formatDate(payment['rejected_at']);
      final reason = (payment['rejection_reason'] ?? '').toString().trim();

      if (status == 'approved' || status == 'paid') {
        lines.add('Accepted ₹${amount.toStringAsFixed(0)} on ${approvedAt ?? submittedAt ?? 'unknown date'}');
      } else if (status == 'rejected') {
        final base = 'Rejected ₹${amount.toStringAsFixed(0)} on ${rejectedAt ?? submittedAt ?? 'unknown date'}';
        lines.add(reason.isNotEmpty ? '$base • $reason' : base);
      } else {
        lines.add('Submitted ₹${amount.toStringAsFixed(0)} on ${submittedAt ?? 'unknown date'}');
      }
    }

    return lines;
  }

  static String? _formatDate(dynamic value) {
    if (value == null) return null;
    final dt = value is DateTime ? value : DateTime.tryParse(value.toString());
    if (dt == null) return null;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  static int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

