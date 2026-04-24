import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'batch_detail_common_widgets.dart';
import '../../../../core/theme/theme_aware.dart';

class BatchFeesTab extends StatefulWidget {
  final Map<String, dynamic> feeStats;
  final List<Map<String, dynamic>> feeRecords;
  final Map<String, dynamic>? feeStructure;
  final String Function(Map<String, dynamic>) recordStatus;
  final double Function(Map<String, dynamic>) recordPaidAmount;
  final double Function(dynamic) toDouble;
  final String Function(dynamic) dateLabel;
  final VoidCallback onGenerateFees;
  final Function(Map<String, dynamic>) onMarkAsPaid;
  final VoidCallback onSendWhatsAppReminder;

  const BatchFeesTab({
    super.key,
    required this.feeStats,
    required this.feeRecords,
    required this.feeStructure,
    required this.recordStatus,
    required this.recordPaidAmount,
    required this.toDouble,
    required this.dateLabel,
    required this.onGenerateFees,
    required this.onMarkAsPaid,
    required this.onSendWhatsAppReminder,
  });

  @override
  State<BatchFeesTab> createState() => _BatchFeesTabState();
}

class _BatchFeesTabState extends State<BatchFeesTab> {
  String _feeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final rows = widget.feeRecords.where((record) {
      if (_feeFilter == 'All') return true;
      final status = widget.recordStatus(record);
      if (_feeFilter == 'Paid') return status == 'Paid';
      if (_feeFilter == 'Pending') return status == 'Pending';
      return true;
    }).toList();

    return Column(
      key: const ValueKey('fees-tab'),
      children: [
        sectionCard(
          context,
          title: 'Fee Summary',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _feeMetric(
                'Total Revenue',
                '₹${widget.toDouble(widget.feeStats['total']).toStringAsFixed(0)}',
                const Color(0xFF354388),
              ),
              _feeMetric(
                'Pending Fees',
                '₹${widget.toDouble(widget.feeStats['pending']).toStringAsFixed(0)}',
                const Color(0xFFB6231B),
              ),
              _feeMetric(
                'Collected Today',
                '₹${widget.toDouble(widget.feeStats['collectedToday']).toStringAsFixed(0)}',
                const Color(0xFFE5A100),
              ),
              _feeMetric(
                'Monthly Fee',
                '₹${widget.toDouble(widget.feeStructure?['monthly_fee']).toStringAsFixed(0)}',
                const Color(0xFF354388),
              ),
            ],
          ),
        ),
        sectionCard(
          context,
          title: 'Fee Records',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: widget.onGenerateFees,
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Generate Fees'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: widget.onSendWhatsAppReminder,
                child: const Text('WhatsApp Reminder'),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: ['All', 'Paid', 'Pending']
                    .map(
                      (label) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _feeFilter == label,
                          onSelected: (_) => setState(() => _feeFilter = label),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                Text(
                  'No fee records for selected filter',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: CT.textS(context),
                  ),
                )
              else
                ...rows.take(20).map((record) {
                  final status = widget.recordStatus(record);
                  final amount = widget.toDouble(
                    record['final_amount'] ?? record['amount'],
                  );
                  final paidAmount = widget.recordPaidAmount(record);
                  final studentName =
                      ((record['student'] as Map?)?['name'] ??
                              record['student_name'] ??
                              'Student')
                          .toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFF354388),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                studentName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            statusTag(
                              status,
                              status == 'Paid'
                                  ? const Color(0xFFE5A100)
                                  : const Color(0xFFB6231B),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Paid ₹${paidAmount.toStringAsFixed(0)} / ₹${amount.toStringAsFixed(0)} • Due ${widget.dateLabel(record['due_date'])}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: status == 'Paid'
                                  ? null
                                  : () => widget.onMarkAsPaid(record),
                              child: const Text('Mark paid'),
                            ),
                            OutlinedButton(
                              onPressed: widget.onSendWhatsAppReminder,
                              child: const Text('Send reminder'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _feeMetric(String label, String value, Color accent) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: accent, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: const Color(0xFF354388),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
