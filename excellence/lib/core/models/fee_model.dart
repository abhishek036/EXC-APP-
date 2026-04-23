

/// Firestore model for fee records.
class FeeModel {
  final String id;
  final String studentId;
  final String studentName;
  final String batchId;
  final String batchName;
  final double amount;
  final DateTime dueDate;
  final String status; // paid, pending, overdue, partial
  final double paidAmount;
  final DateTime? paidDate;
  final String? paymentMode; // cash, upi, bank, cheque
  final String? receiptUrl;
  final String month; // e.g. "2026-03"
  final String? notes;
  final bool reminderSent;
  final DateTime? createdAt;

  const FeeModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.batchId,
    required this.batchName,
    required this.amount,
    required this.dueDate,
    this.status = 'pending',
    this.paidAmount = 0,
    this.paidDate,
    this.paymentMode,
    this.receiptUrl,
    required this.month,
    this.notes,
    this.reminderSent = false,
    this.createdAt,
  });

  factory FeeModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return FeeModel(
      id: docId,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      batchId: data['batchId'] as String? ?? '',
      batchName: data['batchName'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      dueDate: DateTime.tryParse(data['dueDate']?.toString() ?? '') ?? DateTime.now(),
      status: data['status'] as String? ?? 'pending',
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
      paidDate: DateTime.tryParse(data['paidDate']?.toString() ?? ''),
      paymentMode: data['paymentMode'] as String?,
      receiptUrl: data['receiptUrl'] as String?,
      month: data['month'] as String? ?? '',
      notes: data['notes'] as String?,
      reminderSent: data['reminderSent'] as bool? ?? false,
      createdAt: DateTime.tryParse((data['createdAt'])?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'batchId': batchId,
      'batchName': batchName,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'status': status,
      'paidAmount': paidAmount,
      'paidDate': paidDate?.toIso8601String(),
      'paymentMode': paymentMode,
      'receiptUrl': receiptUrl,
      'month': month,
      'notes': notes,
      'reminderSent': reminderSent,
    };
  }

  bool get isPaid => status == 'paid';
  bool get isOverdue => status == 'overdue' || (status == 'pending' && dueDate.isBefore(DateTime.now()));
  double get pendingAmount => amount - paidAmount;
}
