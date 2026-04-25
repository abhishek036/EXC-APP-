import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/app_permission_service.dart';
import '../../../../core/services/cloud_storage_service.dart';
import '../../../../core/utils/role_prefix.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../admin/data/repositories/admin_repository.dart';
import '../../../parent/data/repositories/parent_repository.dart';
import '../../../student/data/repositories/student_repository.dart';

class FeePaymentPage extends StatefulWidget {
  final String? recordId;
  const FeePaymentPage({super.key, this.recordId});

  @override
  State<FeePaymentPage> createState() => _FeePaymentPageState();
}

class _FeePaymentPageState extends State<FeePaymentPage> {
  final _adminRepo = sl<AdminRepository>();
  final _studentRepo = sl<StudentRepository>();
  final _parentRepo = sl<ParentRepository>();
  final _storage = sl<CloudStorageService>();

  bool _loading = true;
  String? _error;
  String _invoiceLabel = 'CURRENT DUE';
  String _batchName = 'Batch';
  String _status = 'unpaid';
  String? _selectedFeeRecordId;
  double _amountDue = 0;
  int _pendingReviewCount = 0;
  String _dueText = 'DUE DATE UNAVAILABLE';
  String _latestRejectionReason = '';
  List<Map<String, dynamic>> _feeRecords = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFeeData();
    });
  }

  Future<void> _loadFeeData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final rolePrefix = context.rolePrefix;
      final isAdmin = rolePrefix == '/admin';
      final isParent = rolePrefix == '/parent';

      debugPrint('💰 [FeePaymentPage] Loading data for role: $rolePrefix');

      if (isAdmin) {
        final queue = await _adminRepo.getFeeVerificationQueue(status: 'pending');
        final double pendingAmount = queue.fold<double>(0, (sum, item) {
          return sum + _toDouble(item['amount']);
        });

        if (!mounted) return;
        setState(() {
          _invoiceLabel = 'PENDING REVIEWS';
          _batchName = 'Verification Queue';
          _status = queue.isEmpty ? 'paid' : 'pending_verification';
          _selectedFeeRecordId = null;
          _amountDue = pendingAmount;
          _pendingReviewCount = queue.length;
          _dueText = queue.isEmpty
              ? 'NO PAYMENT PROOFS PENDING'
              : '${queue.length} PROOFS WAITING';
          _latestRejectionReason = '';
          _feeRecords = queue;
          _loading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> records = isParent
          ? await _parentRepo.getPaymentHistory()
          : await _studentRepo.getFeeHistory();

      debugPrint('💰 [FeePaymentPage] Received ${records.length} records');

      if (!mounted) return;

      final normalizedRecords = records.map((entry) {
        try {
          return Map<String, dynamic>.from(entry);
        } catch (e) {
          return <String, dynamic>{};
        }
      }).where((e) => e.isNotEmpty).toList();

      final pending = normalizedRecords.where((record) {
        final status = (record['status'] ?? record['fee_status'] ?? '').toString().toLowerCase();
        final remaining = _remainingAmountForRecord(record);
        return remaining > 0 ||
            status == 'pending_verification' ||
            status == 'rejected' ||
            status == 'unpaid' ||
            status == 'partial';
      }).toList();

      debugPrint('💰 [FeePaymentPage] Filtered ${pending.length} pending records');

      Map<String, dynamic>? target;
      if (widget.recordId != null) {
        target = normalizedRecords.firstWhere(
          (r) => r['id']?.toString() == widget.recordId,
          orElse: () => pending.isNotEmpty ? pending.first : (normalizedRecords.isNotEmpty ? normalizedRecords.first : <String, dynamic>{}),
        );
      } else if (pending.isNotEmpty) {
        target = pending.first;
      } else if (normalizedRecords.isNotEmpty) {
        target = normalizedRecords.first;
      }

      if (target != null && target.isNotEmpty) {
        final double amount = _remainingAmountForRecord(target);
        final int? month = _toInt(target['month']);
        final int? year = _toInt(target['year']);
        const monthNames = ['', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

        final label = (month != null && month >= 1 && month <= 12 && year != null)
            ? '${monthNames[month]} $year'
            : 'CURRENT DUE';

        final dueDtRaw = target['due_date'];
        DateTime? dueDt;
        if (dueDtRaw != null) {
          if (dueDtRaw is DateTime) {
            dueDt = dueDtRaw;
          } else {
            dueDt = DateTime.tryParse(dueDtRaw.toString());
          }
        }

        final dueStr = dueDt == null
            ? 'DUE DATE UNAVAILABLE'
            : 'DUE BY ${dueDt.day} ${monthNames[dueDt.month]} ${dueDt.year}';
        final rejectionReason = _extractRejectionReason(target);

        setState(() {
          _selectedFeeRecordId = target?['id']?.toString();
          _invoiceLabel = label;
          _batchName = (target?['batch']?['name'] ?? 'Batch').toString();
          _status = (target?['status'] ?? target?['fee_status'] ?? 'unpaid').toString().toLowerCase();
          _amountDue = amount;
          _pendingReviewCount = 0;
          
          if (_status == 'pending_verification' || _status == 'under_review') {
            _dueText = 'VERIFICATION PENDING';
          } else if (_status == 'rejected') {
            _dueText = 'PAYMENT REJECTED - RETRY';
          } else {
            _dueText = amount > 0 ? dueStr : 'CLEARED';
          }

          _latestRejectionReason = _status == 'rejected' ? rejectionReason : '';
          
          _feeRecords = pending.isNotEmpty ? pending : normalizedRecords;
          _loading = false;
        });
      } else {
        setState(() {
          _invoiceLabel = 'NONE';
          _selectedFeeRecordId = null;
          _amountDue = 0;
          _batchName = 'No active records';
          _dueText = 'NO PENDING DUES';
          _latestRejectionReason = '';
          _feeRecords = normalizedRecords;
          _loading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('❌ [FeePaymentPage] Load error: $e\n$stack');
      if (mounted) {
        setState(() {
          _error = 'Unable to load fee details: $e';
          _loading = false;
        });
      }
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _safeString(dynamic value) => value == null ? '' : value.toString();

  String _extractRejectionReason(Map<String, dynamic> record) {
    final explicitReason =
        (record['latest_rejection_reason'] ?? record['rejection_reason'] ?? '')
            .toString()
            .trim();
    if (explicitReason.isNotEmpty) return explicitReason;

    final payments = (record['payments'] as List?)?.cast<dynamic>() ?? const [];
    for (final payment in payments) {
      if (payment is! Map) continue;
      final status = (payment['status'] ?? '').toString().toLowerCase();
      if (status != 'rejected') continue;
      final reason = (payment['rejection_reason'] ?? '').toString().trim();
      if (reason.isNotEmpty) return reason;
    }

    return '';
  }

  double _remainingAmountForRecord(Map<String, dynamic> record) {
    final rawRemaining = record['remaining_amount'];
    final totalAmount = _toDouble(
      record['final_amount'] ?? record['amount_due'] ?? record['amount'] ?? 0,
    );
    final paidAmount = _toDouble(record['paid_amount'] ?? 0);

    // If backend provides a specific remaining amount, use it if it seems valid
    if (rawRemaining != null) {
      final rem = _toDouble(rawRemaining);
      // If it's 0 but total > 0 and status isn't paid, it might be a malformed payload
      final String status = (record['status'] ?? '').toString().toLowerCase();
      if (rem <= 0 && totalAmount > 0 && status != 'paid') {
        return (totalAmount - paidAmount).clamp(0, double.infinity).toDouble();
      }
      return rem;
    }

    return (totalAmount - paidAmount).clamp(0, double.infinity).toDouble();
  }

  String _formatFeeRecordLabel(Map<String, dynamic> record) {
    final month = _toInt(record['month']);
    final year = _toInt(record['year']);
    final batchName = (record['batch'] is Map)
        ? ((record['batch']['name'] ?? 'Batch').toString())
        : 'Batch';
    final studentName = (record['student'] is Map && record['student']['name'] != null)
        ? ' (${record['student']['name']})'
        : '';
    final monthNames = const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final period = (month != null && month >= 1 && month <= 12 && year != null)
        ? '${monthNames[month]} $year'
        : 'Current due';
    final due = _remainingAmountForRecord(record);
    return '$batchName$studentName • $period • Due ₹${due.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final primary = CT.textH(context);
    final borderColor = CT.border(context);
      final rolePrefix = context.rolePrefix;
      final isAdmin = rolePrefix == '/admin';
      final actionLabel = isAdmin
      ? (_pendingReviewCount > 0
        ? 'REVIEW $_pendingReviewCount PROOFS'
        : 'NO PROOFS TO REVIEW')
      : (_amountDue > 0
        ? 'SUBMIT PROOF ₹${_amountDue.toStringAsFixed(0)}'
        : 'SUBMIT / VERIFY PAYMENT');

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text(
          'SECURE CHECKOUT',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 1.5,
            color: CT.textH(context),
          ),
        ),
        centerTitle: true,
        backgroundColor: CT.bg(context),
        elevation: 0,
        foregroundColor: CT.textH(context),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.pagePaddingH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // NEO-BRUTALIST BILL CARD
                  Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: CT.success(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: borderColor,
                              offset: const Offset(4, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    _invoiceLabel,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      color: CT.elevated(context),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: CT.elevated(context),
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '₹${_amountDue.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 36,
                                  color: CT.elevated(context),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.event_available,
                                        color: CT.elevated(context),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _dueText,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: CT.elevated(context),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_status == 'pending_verification') ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange.withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: Text(
                                        'Payment proof is pending admin verification',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: CT.elevated(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (_status == 'rejected' && _latestRejectionReason.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Text(
                                        'Rejection reason: $_latestRejectionReason',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: CT.elevated(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.05, end: 0),

                  const SizedBox(height: 40),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CT.error(context),
                        ),
                      ),
                    ),
                  Text(
                    'PAYMENT METHOD',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: CT.textH(context),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: CT.card(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.1),
                          offset: const Offset(8, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/qr.jpeg',
                              height: 240,
                              fit: BoxFit.contain,
                              errorBuilder: (_, error, stackTrace) => Column(
                                children: [
                                  const SizedBox(height: 40),
                                  Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 140,
                                    color: CT.textH(context).withValues(alpha: 0.1),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'SCAN QR TO PAY',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: CT.textS(context),
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: CT.success(context).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: CT.success(context).withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.security_rounded, size: 18, color: CT.success(context)),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Secure UPI Payment Gateway',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: CT.success(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Scan the QR above with any UPI app (GPay, PhonePe, Paytm, etc.). Once done, upload your screenshot below.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: CT.textM(context),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scaleXY(begin: 0.95),

                  const SizedBox(height: 40),
                  
                  // Security footer
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 20, color: CT.textS(context)),
                        const SizedBox(height: 8),
                        Text(
                          '256-BIT SSL ENCRYPTED CONNECTION',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: CT.textS(context),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
aleXY(begin: 0.98),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
          // Fixed Action Block
          Container(
            padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
            decoration: BoxDecoration(
              color: CT.bg(context),
              border: Border(
                top: BorderSide(color: CT.border(context), width: 1),
              ),
            ),
            child: SafeArea(
              child: CPPressable(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  if (isAdmin) {
                    _showAdminReviewSheet();
                    return;
                  }

                  final selectedFeeRecordId = _safeString(_selectedFeeRecordId).trim();

                  if (selectedFeeRecordId.isEmpty) {
                    if (_feeRecords.isNotEmpty) {
                      _selectedFeeRecordId = (_feeRecords.first['id'] ?? '').toString();
                    }
                  }

                  if (_safeString(_selectedFeeRecordId).trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No fee record available for proof submission.')),
                    );
                    return;
                  }

                  if (rolePrefix == '/student') {
                    _showProofSubmissionSheet();
                    return;
                  }

                  if (rolePrefix == '/parent') {
                    _showProofSubmissionSheet();
                    return;
                  }
                },
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 2.5),
                    boxShadow: [
                      BoxShadow(color: borderColor, offset: const Offset(4, 4)),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isAdmin ? Icons.fact_check_outlined : Icons.security,
                          color: CT.elevated(context),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          actionLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: CT.elevated(context),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ).animate().slideY(begin: 0.5, end: 0, delay: 400.ms),
        ],
      ),
    );
  }

  Future<void> _showAdminReviewSheet() async {
    try {
      final initialQueue = await _adminRepo.getFeeVerificationQueue(status: 'pending');
      if (!mounted) return;

      final processing = <String>{};
      var queue = List<Map<String, dynamic>>.from(initialQueue);

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setSheet) {
              Future<void> refreshQueue() async {
                final refreshed = await _adminRepo.getFeeVerificationQueue(status: 'pending');
                if (!ctx.mounted) return;
                setSheet(() => queue = List<Map<String, dynamic>>.from(refreshed));
                if (mounted) _loadFeeData();
              }

              Future<void> approve(Map<String, dynamic> item) async {
                final paymentId = (item['id'] ?? '').toString();
                if (paymentId.isEmpty) return;
                setSheet(() => processing.add(paymentId));
                try {
                  await _adminRepo.approveFeePaymentProof(paymentId: paymentId);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Payment proof approved.')),
                    );
                  }
                  await refreshQueue();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Approval failed: $e')),
                    );
                  }
                } finally {
                  if (ctx.mounted) setSheet(() => processing.remove(paymentId));
                }
              }

              Future<void> reject(Map<String, dynamic> item) async {
                final paymentId = (item['id'] ?? '').toString();
                if (paymentId.isEmpty) return;

                final reason = await _askRejectionReason(ctx);
                if (reason == null || reason.trim().isEmpty) return;

                setSheet(() => processing.add(paymentId));
                try {
                  await _adminRepo.rejectFeePaymentProof(
                    paymentId: paymentId,
                    rejectionReason: reason.trim(),
                  );
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Payment proof rejected.')),
                    );
                  }
                  await refreshQueue();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Rejection failed: $e')),
                    );
                  }
                } finally {
                  if (ctx.mounted) setSheet(() => processing.remove(paymentId));
                }
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Material(
                  color: CT.card(context),
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: MediaQuery.of(ctx).size.height * 0.84,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Proof Verification',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: CT.textH(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${queue.length} pending submissions',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: CT.textS(context),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: queue.isEmpty
                                ? Center(
                                    child: Text(
                                      'No pending payment proofs right now.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: CT.textS(context),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: queue.length,
                                  separatorBuilder: (_, separatorIndex) => const SizedBox(height: 12),
                                    itemBuilder: (_, index) {
                                      final item = queue[index];
                                      final paymentId = (item['id'] ?? '').toString();
                                      final amount = _toDouble(item['amount_paid']);
                                      final submittedAt = DateTime.tryParse(
                                        (item['submitted_at'] ?? '').toString(),
                                      );
                                      final student = item['student'] is Map
                                          ? Map<String, dynamic>.from(item['student'] as Map)
                                          : <String, dynamic>{};
                                      final batch = item['batch'] is Map
                                          ? Map<String, dynamic>.from(item['batch'] as Map)
                                          : <String, dynamic>{};
                                      final screenshotUrl = (item['screenshot_url'] ?? '').toString();
                                      final isProcessing = processing.contains(paymentId);

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: CT.bg(context),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: CT.border(context)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (student['name'] ?? 'Student').toString(),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: CT.textH(context),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Batch: ${(batch['name'] ?? 'Unknown').toString()}',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: CT.textS(context),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Amount: ₹${amount.toStringAsFixed(0)}',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: CT.textH(context),
                                              ),
                                            ),
                                            if (submittedAt != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Submitted: ${submittedAt.day.toString().padLeft(2, '0')}/${submittedAt.month.toString().padLeft(2, '0')}/${submittedAt.year}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: CT.textS(context),
                                                ),
                                              ),
                                            ],
                                            if (screenshotUrl.isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: Image.network(
                                                  screenshotUrl,
                                                  width: double.infinity,
                                                  height: 150,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, error, stackTrace) => Container(
                                                    height: 120,
                                                    alignment: Alignment.center,
                                                    color: CT.card(context),
                                                    child: Text(
                                                      'Could not load screenshot preview',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        color: CT.textS(context),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: isProcessing ? null : () => approve(item),
                                                    child: Text(
                                                      isProcessing ? 'Processing...' : 'Approve',
                                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: isProcessing ? null : () => reject(item),
                                                    child: Text(
                                                      'Reject',
                                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load verification queue: $e')),
      );
    }
  }

  Future<String?> _askRejectionReason(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Reject Payment Proof',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter rejection reason',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return value;
  }

  Future<String?> _pickAndUploadScreenshot() async {
    final granted = await AppPermissionService.requestMediaAccess(context);
    if (!granted) return null;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null || file.bytes!.isEmpty) return null;

    return _storage.uploadBytes(file.bytes!, 'fee-proofs', file.name);
  }

  Future<void> _openWhatsAppMessage(num amount) async {
    final message =
        'Fee payment update%0AStudent: Student%0ABatch: $_batchName%0AAmount: ₹${amount.toStringAsFixed(0)}%0AStatus: Submitted for manual verification';
    final uri = Uri.parse('https://wa.me/?text=$message');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showProofSubmissionSheet() {
    final validRecords = _feeRecords
      .where((record) => (record['id'] ?? '').toString().isNotEmpty)
      .toList();

    String selectedFeeRecordId = _selectedFeeRecordId ??
      (validRecords.isNotEmpty ? (validRecords.first['id'] ?? '').toString() : '');

    Map<String, dynamic> selectedRecord = selectedFeeRecordId.isEmpty
      ? <String, dynamic>{}
      : validRecords.firstWhere(
        (record) => (record['id'] ?? '').toString() == selectedFeeRecordId,
        orElse: () => validRecords.isNotEmpty ? validRecords.first : <String, dynamic>{},
        );

    final defaultAmount = selectedRecord.isNotEmpty
      ? _remainingAmountForRecord(selectedRecord)
      : _amountDue;

    final amountCtrl = TextEditingController(text: defaultAmount.toStringAsFixed(0));
    final noteCtrl = TextEditingController();
    String? screenshotUrl;
    bool uploading = false;
    bool submitting = false;
    bool whatsappNotified = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Material(
                color: CT.card(context),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Submit Payment Proof',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: CT.textH(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: CT.accent(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: CT.accent(context).withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          'BATCH: $_batchName'.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: CT.accent(context),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (validRecords.length > 1) ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey(selectedFeeRecordId),
                          isExpanded: true,
                          initialValue: selectedFeeRecordId.isEmpty ? null : selectedFeeRecordId,
                          decoration: InputDecoration(
                            labelText: 'Select Fee Cycle',
                            labelStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: CT.textS(context),
                            ),
                            filled: true,
                            fillColor: CT.bg(context),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: CT.border(context), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: CT.accent(context), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          items: validRecords
                              .map(
                                (record) => DropdownMenuItem<String>(
                                  value: (record['id'] ?? '').toString(),
                                  child: Text(
                                    _formatFeeRecordLabel(record),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: CT.textH(context),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null || value.isEmpty) return;
                            final nextRecord = validRecords.firstWhere(
                              (record) => (record['id'] ?? '').toString() == value,
                              orElse: () => selectedRecord,
                            );
                            setSheet(() {
                              selectedFeeRecordId = value;
                              selectedRecord = nextRecord;
                              amountCtrl.text = _remainingAmountForRecord(nextRecord).toStringAsFixed(0);
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      CustomTextField(
                        label: 'Payment Amount',
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Note (Optional)',
                        hint: 'Ref ID or Student Name',
                        controller: noteCtrl,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),
                      CPPressable(
                        onTap: uploading
                            ? null
                            : () async {
                                try {
                                  setSheet(() => uploading = true);
                                  final url = await _pickAndUploadScreenshot();
                                  if (url == null || url.isEmpty) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(content: Text('Please select a screenshot file.')),
                                      );
                                    }
                                  } else {
                                    setSheet(() => screenshotUrl = url);
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Upload failed: $e')),
                                    );
                                  }
                                } finally {
                                  if (ctx.mounted) setSheet(() => uploading = false);
                                }
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: screenshotUrl != null ? CT.success(context) : CT.border(context),
                              width: 2,
                            ),
                            color: screenshotUrl != null 
                                ? CT.success(context).withValues(alpha: 0.05) 
                                : CT.bg(context),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                screenshotUrl != null ? Icons.check_circle_rounded : Icons.add_photo_alternate_outlined,
                                size: 22,
                                color: screenshotUrl != null ? CT.success(context) : CT.textM(context),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  screenshotUrl == null
                                      ? (uploading ? 'UPLOADING...' : 'UPLOAD PAYMENT SCREENSHOT')
                                      : 'SCREENSHOT ATTACHED',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: screenshotUrl != null ? CT.success(context) : CT.textH(context),
                                  ),
                                ),
                              ),
                              if (screenshotUrl != null)
                                Icon(Icons.verified_rounded, size: 18, color: CT.success(context)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Spacer(),
                          CPPressable(
                            onTap: () async {
                              final amount = _toDouble(amountCtrl.text);
                              await _openWhatsAppMessage(amount);
                              if (ctx.mounted) setSheet(() => whatsappNotified = true);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: CT.accent(context).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 14, color: CT.accent(context)),
                                  const SizedBox(width: 8),
                                  Text(
                                    whatsappNotified ? 'NOTIFIED' : 'INFORM VIA WHATSAPP',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: CT.accent(context),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CT.accent(context),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: submitting
                              ? null
                              : () async {
                                  final amount = _toDouble(amountCtrl.text);
                                  if (amount <= 0) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Enter a valid amount.')),
                                    );
                                    return;
                                  }
                                  if (screenshotUrl == null || screenshotUrl!.isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Upload payment screenshot first.')),
                                    );
                                    return;
                                  }

                                  try {
                                    setSheet(() => submitting = true);
                                    final rolePrefix = context.rolePrefix;
                                    if (selectedFeeRecordId.isEmpty) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(content: Text('Select a fee record first.')),
                                      );
                                      return;
                                    }
                                    if (rolePrefix == '/parent') {
                                      await _parentRepo.submitFeePaymentProof(
                                        feeRecordId: selectedFeeRecordId,
                                        amount: amount,
                                        screenshotUrl: screenshotUrl!,
                                        note: noteCtrl.text,
                                        whatsappNotified: whatsappNotified,
                                      );
                                    } else {
                                      await _studentRepo.submitFeePaymentProof(
                                        feeRecordId: selectedFeeRecordId,
                                        amount: amount,
                                        screenshotUrl: screenshotUrl!,
                                        note: noteCtrl.text,
                                        whatsappNotified: whatsappNotified,
                                      );
                                    }
                                    _selectedFeeRecordId = selectedFeeRecordId;
                                    if (!ctx.mounted) return;
                                    Navigator.of(ctx).pop();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Payment proof submitted for verification.')),
                                    );
                                    _loadFeeData();
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Submission failed: $e')),
                                      );
                                    }
                                  } finally {
                                    if (ctx.mounted) setSheet(() => submitting = false);
                                  }
                                },
                          child: Text(
                            submitting ? 'Submitting...' : 'Submit Proof',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

}
