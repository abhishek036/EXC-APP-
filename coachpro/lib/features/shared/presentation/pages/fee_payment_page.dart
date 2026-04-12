import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/cloud_storage_service.dart';
import '../../../../core/utils/role_prefix.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../admin/data/repositories/admin_repository.dart';
import '../../../parent/data/repositories/parent_repository.dart';
import '../../../student/data/repositories/student_repository.dart';

class FeePaymentPage extends StatefulWidget {
  const FeePaymentPage({super.key});

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
  List<Map<String, dynamic>> _feeRecords = [];

  @override
  void initState() {
    super.initState();
    _loadFeeData();
  }

  Future<void> _loadFeeData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rolePrefix = context.rolePrefix;

      if (rolePrefix == '/admin') {
        final queue = await _adminRepo.getFeeVerificationQueue(status: 'pending');
        final pendingAmount = queue.fold<double>(
          0,
          (sum, item) => sum + _toDouble(item['amount_paid']),
        );

        if (!mounted) return;
        setState(() {
          _invoiceLabel = 'PENDING REVIEWS';
          _batchName = 'All Batches';
          _status = queue.isEmpty ? 'paid' : 'pending_verification';
          _selectedFeeRecordId = null;
          _amountDue = pendingAmount;
          _pendingReviewCount = queue.length;
          _dueText = queue.isEmpty
              ? 'NO PAYMENT PROOFS PENDING REVIEW'
              : '${queue.length} PROOFS WAITING FOR VERIFICATION';
          _loading = false;
        });
        return;
      }

      final records = rolePrefix == '/parent'
          ? await _parentRepo.getPaymentHistory()
          : await _studentRepo.getFeeHistory();

        final normalizedRecords = records
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();

        final pending = normalizedRecords.where((r) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        return status == 'pending' ||
            status == 'overdue' ||
            status == 'unpaid' ||
            status == 'pending_verification' ||
            status == 'rejected';
      }).toList();

      pending.sort((a, b) {
        final aDue = DateTime.tryParse((a['due_date'] ?? '').toString());
        final bDue = DateTime.tryParse((b['due_date'] ?? '').toString());
        if (aDue == null && bDue == null) return 0;
        if (aDue == null) return 1;
        if (bDue == null) return -1;
        return aDue.compareTo(bDue);
      });

        final target = pending.isNotEmpty
          ? pending.first
          : (normalizedRecords.isNotEmpty
            ? normalizedRecords.first
            : <String, dynamic>{});
      final totalAmount = _toDouble(target['final_amount'] ?? target['amount_due'] ?? target['amount'] ?? 0);
      final paidAmount = _toDouble(target['paid_amount'] ?? 0);
      final amount = (totalAmount - paidAmount).clamp(0, double.infinity).toDouble();

        final month = _toInt(target['month']);
        final year = _toInt(target['year']);
      final monthNames = const ['', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
      final label = (month != null && month >= 1 && month <= 12 && year != null)
          ? '${monthNames[month]} $year'
          : 'CURRENT DUE';

      final dueDt = DateTime.tryParse((target['due_date'] ?? '').toString());
      final dueStr = dueDt == null
          ? 'DUE DATE UNAVAILABLE'
          : 'DUE BY ${dueDt.day.toString().padLeft(2, '0')} ${monthNames[dueDt.month]}, ${dueDt.year}';

      if (!mounted) return;
      setState(() {
        _invoiceLabel = label;
        _batchName = (target['batch']?['name'] ?? 'Batch').toString();
        _status = (target['status'] ?? 'unpaid').toString().toLowerCase();
        _selectedFeeRecordId = target['id']?.toString();
        _amountDue = amount > 0 ? amount : totalAmount;
        _pendingReviewCount = 0;
        _dueText = dueStr;
        _feeRecords = pending.isNotEmpty ? pending : normalizedRecords;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load fee details';
        _feeRecords = [];
        _loading = false;
      });
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

  double _remainingAmountForRecord(Map<String, dynamic> record) {
    final totalAmount = _toDouble(record['final_amount'] ?? record['amount_due'] ?? record['amount'] ?? 0);
    final paidAmount = _toDouble(record['paid_amount'] ?? 0);
    return (totalAmount - paidAmount).clamp(0, double.infinity).toDouble();
  }

  String _formatFeeRecordLabel(Map<String, dynamic> record) {
    final month = _toInt(record['month']);
    final year = _toInt(record['year']);
    final batchName = (record['batch'] is Map)
        ? ((record['batch']['name'] ?? 'Batch').toString())
        : 'Batch';
    final monthNames = const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final period = (month != null && month >= 1 && month <= 12 && year != null)
        ? '${monthNames[month]} $year'
        : 'Current due';
    final due = _remainingAmountForRecord(record);
    return '$batchName • $period • Due ₹${due.toStringAsFixed(0)}';
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
          style: GoogleFonts.sora(
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
                              offset: const Offset(5, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _invoiceLabel,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    color: CT.elevated(context),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
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
                            Text(
                              '₹${_amountDue.toStringAsFixed(2)}',
                              style: GoogleFonts.sora(
                                fontSize: 36,
                                color: CT.elevated(context),
                                fontWeight: FontWeight.w900,
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
                                          style: GoogleFonts.sora(
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
                                        style: GoogleFonts.dmSans(
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
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CT.error(context),
                        ),
                      ),
                    ),

                  Text(
                    'QR PAYMENT ONLY',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: CT.textH(context),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    key: const ValueKey('upi_qr_only'),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: CT.card(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.05),
                          offset: const Offset(4, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CT.isDark(context)
                                ? CT.elevated(context).withValues(alpha: 0.05)
                                : primary.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/images/qr.jpeg',
                              height: 190,
                              fit: BoxFit.contain,
                              errorBuilder: (_, error, stackTrace) => Icon(
                                Icons.qr_code_2_rounded,
                                size: 120,
                                color: CT.textH(context),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'SCAN THIS QR TO PAY',
                          style: GoogleFonts.sora(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: CT.textS(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Only QR-based payment is accepted. Upload payment screenshot for admin verification.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: CT.textM(context),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scaleXY(begin: 0.98),

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

                  if (_selectedFeeRecordId == null || _selectedFeeRecordId!.isEmpty) {
                    if (_feeRecords.isNotEmpty) {
                      _selectedFeeRecordId = (_feeRecords.first['id'] ?? '').toString();
                    }
                  }

                  if (_selectedFeeRecordId == null || _selectedFeeRecordId!.isEmpty) {
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
                          style: GoogleFonts.sora(
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
                            style: GoogleFonts.sora(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: CT.textH(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${queue.length} pending submissions',
                            style: GoogleFonts.dmSans(
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
                                      style: GoogleFonts.dmSans(
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
                                              style: GoogleFonts.sora(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: CT.textH(context),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Batch: ${(batch['name'] ?? 'Unknown').toString()}',
                                              style: GoogleFonts.dmSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: CT.textS(context),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Amount: ₹${amount.toStringAsFixed(0)}',
                                              style: GoogleFonts.dmSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: CT.textH(context),
                                              ),
                                            ),
                                            if (submittedAt != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Submitted: ${submittedAt.day.toString().padLeft(2, '0')}/${submittedAt.month.toString().padLeft(2, '0')}/${submittedAt.year}',
                                                style: GoogleFonts.dmSans(
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
                                                      style: GoogleFonts.dmSans(
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
                                                      style: GoogleFonts.sora(fontWeight: FontWeight.w700),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: isProcessing ? null : () => reject(item),
                                                    child: Text(
                                                      'Reject',
                                                      style: GoogleFonts.sora(fontWeight: FontWeight.w700),
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
            style: GoogleFonts.sora(fontWeight: FontWeight.w800),
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
                        style: GoogleFonts.sora(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: CT.textH(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Batch: $_batchName',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CT.textS(context),
                        ),
                      ),
                      if (validRecords.length > 1) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(selectedFeeRecordId),
                          initialValue: selectedFeeRecordId.isEmpty ? null : selectedFeeRecordId,
                          decoration: const InputDecoration(
                            labelText: 'Fee record',
                          ),
                          items: validRecords
                              .map(
                                (record) => DropdownMenuItem<String>(
                                  value: (record['id'] ?? '').toString(),
                                  child: Text(
                                    _formatFeeRecordLabel(record),
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
                      ],
                      const SizedBox(height: 12),
                      CustomTextField(
                        label: 'Amount',
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        isRequired: true,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        label: 'Note (optional)',
                        controller: noteCtrl,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
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
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: CT.border(context)),
                            color: CT.bg(context),
                          ),
                          child: Text(
                            screenshotUrl == null
                                ? (uploading ? 'Uploading screenshot...' : 'Upload payment screenshot')
                                : 'Screenshot uploaded successfully',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: CT.textH(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      CPPressable(
                        onTap: () async {
                          final amount = _toDouble(amountCtrl.text);
                          await _openWhatsAppMessage(amount);
                          if (ctx.mounted) setSheet(() => whatsappNotified = true);
                        },
                        child: Text(
                          whatsappNotified ? 'WhatsApp message opened' : 'Inform via WhatsApp (optional)',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: CT.accent(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
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
                            style: GoogleFonts.sora(fontWeight: FontWeight.w700),
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
