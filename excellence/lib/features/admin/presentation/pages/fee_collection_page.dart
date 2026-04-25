import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/realtime_sync_service.dart';
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
  final _realtime = sl<RealtimeSyncService>();
  StreamSubscription<Map<String, dynamic>>? _syncSub;
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
    _searchCtrl.addListener(
      () =>
          setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase()),
    );
    _loadFeeRecords();
    _initRealtime();
  }

  Future<void> _initRealtime() async {
    await _realtime.connect();
    if (!mounted) return;
    _syncSub?.cancel();
    _syncSub = _realtime.updates.listen((event) {
      if (!mounted) return;
      final type = (event['type'] ?? '').toString();
      final reason = (event['reason'] ?? '').toString().toLowerCase();
      if (type == 'dashboard_sync' ||
          type == 'batch_sync' ||
          reason.contains('fee') ||
          reason.contains('payment')) {
        _loadFeeRecords();
      }
    });
  }

  Future<void> _loadFeeRecords({bool silent = false}) async {
    if (!silent) {
      if (mounted) setState(() => _loading = true);
    }
    try {
      final records = await _adminRepo.getFeeRecords();
      if (!mounted) return;

      setState(() {
        _records = List<Map<String, dynamic>>.from(records);
        _loading = false;
        _error = '';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = !silent ? 'Unable to load fee records: $e' : '';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmtCur(double amount) {
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toInt()}';
  }

  double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  DateTime? _toDate(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _fmtDateTime(DateTime? value) {
    if (value == null) return 'Unknown time';
    return DateFormat('dd MMM yyyy, hh:mm a').format(value);
  }

  List<Map<String, dynamic>> _extractFeeActivityLogs(Map<String, dynamic> fee) {
    final rawPayments = (fee['payments'] as List?)?.cast<dynamic>() ?? const [];
    final logs = <Map<String, dynamic>>[];

    for (final raw in rawPayments) {
      if (raw is! Map) continue;
      final payment = Map<String, dynamic>.from(raw);
      final amount = _toDouble(payment['amount_paid']);
      final mode = (payment['payment_mode'] ?? payment['payment_channel'] ?? 'manual_qr')
          .toString()
          .toUpperCase();
      final submittedAt = _toDate(payment['submitted_at']);
      final approvedAt = _toDate(payment['approved_at']) ?? _toDate(payment['paid_at']);
      final rejectedAt = _toDate(payment['rejected_at']);
      final status = (payment['status'] ?? '').toString().toLowerCase();
      final rejectionReason = (payment['rejection_reason'] ?? '').toString().trim();

      if (submittedAt != null) {
        logs.add({
          'timestamp': submittedAt,
          'title': 'Payment Submitted',
          'detail': '₹${amount.toStringAsFixed(0)} via $mode',
          'color': AppColors.feePending,
        });
      }

      if (status == 'approved' || status == 'paid') {
        logs.add({
          'timestamp': approvedAt ?? submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          'title': 'Payment Accepted',
          'detail': '₹${amount.toStringAsFixed(0)} accepted',
          'color': AppColors.success,
        });
      } else if (status == 'rejected') {
        logs.add({
          'timestamp': rejectedAt ?? submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          'title': 'Payment Rejected',
          'detail': rejectionReason.isNotEmpty
              ? '₹${amount.toStringAsFixed(0)} • $rejectionReason'
              : '₹${amount.toStringAsFixed(0)} rejected',
          'color': AppColors.error,
        });
      }
    }

    logs.sort((a, b) {
      final left = a['timestamp'] as DateTime;
      final right = b['timestamp'] as DateTime;
      return right.compareTo(left);
    });

    return logs;
  }

  ({double total, double paid, double outstanding, String status}) _feeMetrics(
    Map<String, dynamic> record,
  ) {
    final total = _toDouble(
      record['final_amount'] ?? record['amount'] ?? record['total_amount'],
    );
    final paid = _toDouble(record['paid_amount']);
    final explicitRemaining = record['remaining_amount'];
    
    // Use explicit remaining if available, else derive
    final outstanding = explicitRemaining != null
        ? _toDouble(explicitRemaining)
        : (total - paid).clamp(0, double.infinity).toDouble();

    final rawStatus = (record['fee_status'] ?? record['status'] ?? '')
        .toString()
        .toLowerCase();

    // 1. Fully Paid logic
    if (outstanding <= 0 || rawStatus == 'paid') {
      return (total: total, paid: paid, outstanding: 0.0, status: 'paid');
    }

    // 2. Pending Review
    if (rawStatus == 'pending_verification' || rawStatus == 'under_review') {
      return (total: total, paid: paid, outstanding: outstanding, status: 'pending');
    }

    // 3. Overdue check
    final dueDate = DateTime.tryParse((record['due_date'] ?? '').toString());
    if (dueDate != null) {
      final now = DateTime.now();
      if (dueDate.isBefore(DateTime(now.year, now.month, now.day))) {
        return (total: total, paid: paid, outstanding: outstanding, status: 'overdue');
      }
    }

    // 4. Partial check (outstanding > 0 and paid > 0)
    if (paid > 0) {
      return (total: total, paid: paid, outstanding: outstanding, status: 'partial');
    }

    // 5. Default
    return (total: total, paid: paid, outstanding: outstanding, status: 'pending');
  }

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
                  floating: true,
                  pinned: true,
                  leading: CPPressable(
                    onTap: () {
                      if (GoRouter.of(context).canPop()) {
                        GoRouter.of(context).pop();
                      } else {
                        GoRouter.of(context).go('/admin');
                      }
                    },
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: Text(
                    'Revenue Ledger',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                      letterSpacing: -1,
                    ),
                  ),
                  actions: [
                    _appBarAction(
                      Icons.fact_check_outlined,
                      () => GoRouter.of(context).push('/admin/fee-payment'),
                      isDark,
                    ),
                    const SizedBox(width: 12),
                    _appBarAction(
                      Icons.auto_awesome_rounded,
                      () => _showGenerateFeesSheet(context),
                      isDark,
                    ),
                    const SizedBox(width: 12),
                    _appBarAction(
                      Icons.settings_suggest_rounded,
                      () => _showFeeStructureSheet(context),
                      isDark,
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ],
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        _buildSummaryHeader(isDark),
                        const SizedBox(height: 28),
                        _buildFilters(isDark),
                        const SizedBox(height: 16),
                        _buildSearchBar(isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _loading
                        ? ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: 5,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 16),
                            itemBuilder: (_, _) => CPShimmer(
                              width: double.infinity,
                              height: 90,
                              borderRadius: 24,
                            ),
                          )
                        : _error.isNotEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () => _loadFeeRecords(silent: false),
                                  child: Text(
                                    'Retry',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.elitePrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadFeeRecords(silent: false),
                            color: AppColors.elitePrimary,
                            child: _buildRecordsList(isDark),
                          ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            right: 20,
            child: CPPressable(
              onTap: () {
                HapticFeedback.heavyImpact();
                _showAdjustFeeSheet(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chambrayBlue,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.chambrayBlue.withValues(alpha: 0.3),
                      offset: const Offset(0, 8),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ADJUST FEE',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().slideY(
            begin: 1,
            duration: 600.ms,
            curve: Curves.easeOutBack,
          ),
        ],
      ),
    );
  }

  // Removed glow method

  Widget _appBarAction(IconData icon, VoidCallback onTap, bool isDark) {
    return CPPressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.saharaYellow,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.chambrayBlue.withValues(alpha: 0.1),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Icon(icon, size: 22, color: AppColors.chambrayBlue),
      ),
    );
  }

  Widget _buildSummaryHeader(bool isDark) {
    double revenue = 0, pending = 0, overdue = 0;
    for (final record in _records) {
      final metrics = _feeMetrics(record);
      revenue += metrics.paid;
      
      if (metrics.status == 'overdue') {
        overdue += metrics.outstanding;
      } else if (metrics.status == 'pending' || metrics.status == 'partial') {
        // Only count actual outstanding for pending/partial
        pending += metrics.outstanding;
      }
    }
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: _heroStat('Total Revenue', revenue, AppColors.premiumEliteGradient, isDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _miniStat('Pending', pending, AppColors.feePending, isDark),
              const SizedBox(height: 8),
              _miniStat('Overdue', overdue, AppColors.error, isDark),
            ],
          ),
        ),
      ],
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _heroStat(String label, double val, Gradient grad, bool isDark) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.chambrayBlue,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.chambrayBlue.withValues(alpha: 0.3),
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.saharaYellow.withValues(alpha: 0.8),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              _fmtCur(val),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double val, Color color, bool isDark) {
    return SizedBox(
      height: 51,
      child: CPGlassCard(
        isDark: isDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        borderRadius: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isDark ? AppColors.paleSlate2 : Colors.black38,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              _fmtCur(val),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
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
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedStatus = i);
          },
          child: AnimatedContainer(
            duration: 250.ms,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: _selectedStatus == i
                  ? AppColors.saharaYellow
                  : (isDark ? AppColors.gunmetal : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedStatus == i
                    ? AppColors.saharaYellow
                    : (isDark ? AppColors.ironGrey : AppColors.chambrayBlue.withValues(alpha: 0.1)),
                width: 1.5,
              ),
              boxShadow: _selectedStatus == i
                  ? [
                      BoxShadow(
                        color: AppColors.saharaYellow.withValues(alpha: 0.3),
                        offset: const Offset(0, 4),
                        blurRadius: 8,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                _statuses[i].toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.chambrayBlue,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.gunmetal : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.ironGrey : AppColors.chambrayBlue.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
        ),
        decoration: InputDecoration(
          hintText: 'Search ledger entries...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkBorder
                : Colors.black.withValues(alpha: 0.26),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: isDark
                ? AppColors.darkBorder
                : Colors.black.withValues(alpha: 0.26),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildRecordsList(bool isDark) {
    var filtered = List<Map<String, dynamic>>.from(_records);
    if (_selectedStatus > 0) {
      final status = _statuses[_selectedStatus].toLowerCase();
      filtered = filtered
          .where((r) => _feeMetrics(r).status == status)
          .toList();
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
    final metrics = _feeMetrics(r);
    final status = metrics.status.toUpperCase();
    final total = metrics.total;

    final sColor = status == 'PAID'
        ? AppColors.mintGreen
        : status == 'OVERDUE'
        ? AppColors.error
        : status == 'PARTIAL'
        ? AppColors.moltenAmber
        : AppColors.feePending;

    return CPPressable(
          onTap: () {
            HapticFeedback.lightImpact();
            _showFeeDetailSheet(context, r);
          },
          child: CPGlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(20),
            borderRadius: 28,
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.saharaYellow.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.saharaYellow,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.chambrayBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.paleSlate1 : AppColors.chambrayBlue,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${batch.toUpperCase()} • ${month.toUpperCase()}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.paleSlate2 : AppColors.chambrayBlue.withValues(alpha: 0.6),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${total.toInt()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.paleSlate1 : AppColors.chambrayBlue,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: sColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: sColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: 30 * (i % 10)))
        .fadeIn(duration: 500.ms)
        .slideX(begin: 0.05);
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No ledger entries found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkBorder
                  : Colors.black.withValues(alpha: 0.26),
            ),
          ),
        ],
      ),
    );
  }

  void _showFeeDetailSheet(BuildContext context, Map<String, dynamic> fee) {
    final isDark = CT.isDark(context);
    final metrics = _feeMetrics(fee);
    final status = metrics.status.toUpperCase();
    final name = (fee['student']?['name'] ?? 'Pupil').toString();
    final amt = metrics.total;
    final paid = metrics.paid;
    final outstanding = metrics.outstanding;
    final id = (fee['id'] ?? '').toString();
    final activityLogs = _extractFeeActivityLogs(fee);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CPGlassCard(
        isDark: isDark,
        padding: EdgeInsets.fromLTRB(
          28,
          16,
          28,
          MediaQuery.of(ctx).viewInsets.bottom + 40,
        ),
        borderRadius: 40,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 6,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white12
                      : Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(fee['batch']?['name'] ?? 'Batch').toString().toUpperCase()} • ${_monthLabel(fee['month'], fee['year']).toUpperCase()}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: isDark ? AppColors.paleSlate2 : Colors.black38,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                _detailStat('BILLED', '₹${amt.toInt()}', isDark),
                _detailStat('CLEARED', '₹${paid.toInt()}', isDark),
                _detailStat('PENDING', '₹${outstanding.toInt()}', isDark),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Payment Activity',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isDark ? AppColors.paleSlate2 : AppColors.deepNavy,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            if (activityLogs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.paleSlate1 : AppColors.deepNavy)
                      .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No fee activity logs yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.paleSlate2 : Colors.black38,
                  ),
                ),
              )
            else
              ...activityLogs.take(8).map((log) {
                final color = log['color'] as Color;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (log['title'] ?? '').toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (log['detail'] ?? '').toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.paleSlate2 : AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fmtDateTime(log['timestamp'] as DateTime?),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.paleSlate2 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 40),
            if (status != 'PAID') ...[
              CustomButton(
                text: 'Settle Full Amount',
                icon: Icons.offline_pin_rounded,
                onPressed: () async {
                  try {
                    final pend = outstanding;
                    if (pend <= 0) return;

                    // Optimistic Local Update
                    setState(() {
                      final idx = _records.indexWhere(
                        (r) => r['id'].toString() == id,
                      );
                      if (idx != -1) {
                        final updated = Map<String, dynamic>.from(
                          _records[idx],
                        );
                        final payments = List<Map<String, dynamic>>.from(
                          (updated['payments'] as List?) ?? [],
                        );
                        payments.add({
                          'amount_paid': pend,
                          'payment_mode': 'manual_qr_admin',
                        });
                        updated['payments'] = payments;
                        updated['status'] = 'paid';
                        _records[idx] = updated;
                      }
                    });

                    await _adminRepo.recordFeePayment(
                      feeRecordId: id,
                      amountPaid: pend,
                      paymentMode: 'manual_qr_admin',
                      note: 'Bulk update',
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      CPToast.success(context, 'Ledger updated ✅');
                      _loadFeeRecords(silent: true);
                    }
                  } catch (_) {
                    if (ctx.mounted) {
                      CPToast.error(ctx, 'Update failed');
                      _loadFeeRecords(silent: true);
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
            CPPressable(
              onTap: () {
                Navigator.pop(ctx);
                PdfGenerator.generateFeeReceipt(fee);
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5A100),
                  border: Border.all(color: const Color(0xFF354388), width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF354388), offset: Offset(3, 3)),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.print_rounded,
                        size: 20,
                        color: const Color(0xFF354388),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Generate Receipt',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF354388),
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailStat(String l, String v, bool isDark) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: isDark ? AppColors.paleSlate2 : Colors.black38,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );

  void _showAdjustFeeSheet(BuildContext context) {
    final isDark = CT.isDark(context);
    final adjustableRecords = List<Map<String, dynamic>>.from(_records);
    String? sid = adjustableRecords.isNotEmpty
      ? adjustableRecords.first['id'].toString()
      : null;
    final amtC = TextEditingController();
    final reasonC = TextEditingController();
    final noteC = TextEditingController();
    String adjustmentType = 'decrease';

    if (sid != null && adjustableRecords.isNotEmpty) {
      final first = adjustableRecords.first;
      final pend = _feeMetrics(first).outstanding;
      amtC.text = pend > 0 ? pend.toInt().toString() : '';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: CPGlassCard(
            isDark: isDark,
            padding: EdgeInsets.fromLTRB(
              28,
              16,
              28,
              MediaQuery.of(ctx).viewInsets.bottom + 40,
            ),
            borderRadius: 40,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Manual Fee Adjustment',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _sheetLabel('FEE RECORDS', isDark),
                  const SizedBox(height: 10),
                  if (adjustableRecords.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.paleSlate1 : AppColors.deepNavy)
                            .withValues(alpha: 0.05),
                        border: Border.all(
                          color: const Color(0xFF354388),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'No fee records available',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: isDark ? AppColors.paleSlate2 : Colors.black38,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.paleSlate1 : AppColors.deepNavy)
                            .withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: sid,
                          hint: Text(
                            'Select fee record',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.darkBorder
                                  : Colors.black.withValues(alpha: 0.26),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          isExpanded: true,
                          dropdownColor: isDark
                              ? const Color(0xFF354388)
                              : Colors.white,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: adjustableRecords.map((r) {
                            final pend = _feeMetrics(r).outstanding;
                            final studentName = (r['student']?['name'] ?? 'Pupil').toString();
                            final month = _monthLabel(r['month'], r['year']);
                            final batchName = (r['batch']?['name'] ?? 'Batch').toString();
                            
                            return DropdownMenuItem(
                              value: r['id'].toString(),
                              child: Text(
                                '$studentName • $month • $batchName • ₹${pend.toInt()}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, // Slightly smaller for dense info
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.deepNavy,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setS(() {
                              sid = v;
                              final matches = _records
                                  .where((e) => e['id'].toString() == v)
                                  .toList();
                              if (matches.isEmpty) {
                                amtC.text = '';
                                return;
                              }
                              final r = matches.first;
                              final pend = _feeMetrics(r).outstanding;
                              amtC.text = pend.toInt().toString();
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  CustomTextField(
                    label: 'Adjustment Amount (₹)',
                    hint: '0',
                    controller: amtC,
                    prefixIcon: Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 28),
                  _sheetLabel('ADJUSTMENT TYPE', isDark),
                  const SizedBox(height: 12),
                  Row(
                    children: ['decrease', 'increase']
                        .map(
                          (m) => Expanded(
                            child: CPPressable(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setS(() => adjustmentType = m);
                              },
                              child: AnimatedContainer(
                                duration: 250.ms,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: adjustmentType == m
                                      ? AppColors.elitePrimary
                                      : (isDark
                                                ? Colors.white
                                                : AppColors.deepNavy)
                                            .withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: adjustmentType == m
                                        ? Colors.transparent
                                        : (isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.08,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.05,
                                                )),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    m.toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: adjustmentType == m
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white38
                                                : Colors.black38),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    label: 'Reason *',
                    hint: 'Why is this adjustment needed?',
                    controller: reasonC,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Internal Note (optional)',
                    hint: 'Additional context for audit trail',
                    controller: noteC,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 36),
                  CustomButton(
                    text: 'Apply Adjustment',
                    icon: Icons.tune_rounded,
                    onPressed: () async {
                      if (adjustableRecords.isEmpty) {
                        CPToast.warning(
                          ctx,
                          'No fee records to adjust',
                        );
                        return;
                      }
                      if (sid == null || amtC.text.isEmpty) {
                        CPToast.warning(
                          ctx,
                          'Select an account and enter an amount',
                        );
                        return;
                      }
                      if (reasonC.text.trim().isEmpty) {
                        CPToast.warning(ctx, 'Reason is required for manual adjustments');
                        return;
                      }

                      final amount = double.tryParse(amtC.text) ?? 0;
                      if (amount <= 0) {
                        CPToast.warning(ctx, 'Adjustment amount must be greater than zero');
                        return;
                      }

                      try {
                        await _adminRepo.adjustFeeRecord(
                          feeRecordId: sid!,
                          adjustmentType: adjustmentType,
                          amount: amount,
                          reason: reasonC.text.trim(),
                          note: noteC.text,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          CPToast.success(
                            context,
                            'Adjustment applied successfully',
                          );
                          _loadFeeRecords(silent: true);
                        }
                      } catch (_) {
                        if (ctx.mounted) {
                          CPToast.error(
                            ctx,
                            'Adjustment failed. Please try again.',
                          );
                          _loadFeeRecords(silent: true);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetLabel(String l, bool isDark) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      l,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: isDark ? AppColors.paleSlate2 : Colors.black38,
        letterSpacing: 0.5,
      ),
    ),
  );

  void _showGenerateFeesSheet(BuildContext context) {
    final isDark = CT.isDark(context);
    String? bid;
    int m = DateTime.now().month;
    int y = DateTime.now().year;
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => CPGlassCard(
          isDark: isDark,
          padding: EdgeInsets.fromLTRB(
            28,
            16,
            28,
            MediaQuery.of(ctx).viewInsets.bottom + 40,
          ),
          borderRadius: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white12
                        : Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Generate Monthly Fees',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Deploy fee contracts to all enrolled members.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: isDark ? AppColors.paleSlate2 : Colors.black38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 40),
              _sheetLabel('TARGET OPERATION BATCH', isDark),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _adminRepo.getBatches(),
                builder: (ctx, snap) {
                  final batches = snap.data ?? [];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.paleSlate1 : AppColors.deepNavy)
                          .withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: bid,
                        hint: Text(
                          'Select Academy Batch',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkBorder
                                : Colors.black.withValues(alpha: 0.26),
                          ),
                        ),
                        isExpanded: true,
                        dropdownColor: isDark
                            ? const Color(0xFF354388)
                            : Colors.white,
                        items: batches
                            .map(
                              (b) => DropdownMenuItem(
                                value: b['id'].toString(),
                                child: Text(
                                  b['name'].toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.deepNavy,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setS(() => bid = v),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sheetLabel('BILLING CYCLE', isDark),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.paleSlate1 : AppColors.deepNavy)
                                .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: m,
                              isExpanded: true,
                              dropdownColor: isDark
                                  ? const Color(0xFF354388)
                                  : Colors.white,
                              items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text(
                                    DateFormat(
                                      'MMMM',
                                    ).format(DateTime(2024, i + 1)),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.deepNavy,
                                    ),
                                  ),
                                ),
                              ),
                              onChanged: (v) => setS(() => m = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sheetLabel('TICK YEAR', isDark),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.paleSlate1 : AppColors.deepNavy)
                                .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: y,
                              isExpanded: true,
                              dropdownColor: isDark
                                  ? const Color(0xFF354388)
                                  : Colors.white,
                              items: [y, y + 1]
                                  .map(
                                    (year) => DropdownMenuItem(
                                      value: year,
                                      child: Text(
                                        year.toString(),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.deepNavy,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setS(() => y = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              CustomButton(
                text: 'Generate Fee Records',
                isLoading: loading,
                icon: Icons.rocket_launch_rounded,
                onPressed: () async {
                  if (bid == null) {
                    CPToast.warning(ctx, 'Select a batch first');
                    return;
                  }
                  setS(() => loading = true);
                  try {
                    await _adminRepo.generateMonthlyFees(
                      batchId: bid!,
                      month: m,
                      year: y,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      CPToast.success(
                        context,
                        'Fee records generated successfully',
                      );
                      _loadFeeRecords(silent: false);
                    }
                  } catch (_) {
                    if (ctx.mounted) {
                      CPToast.error(ctx, 'Failed to generate fee records');
                      setS(() => loading = false);
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeeStructureSheet(BuildContext context) {
    final isDark = CT.isDark(context);
    String? bid;
    final fC = TextEditingController();
    final aC = TextEditingController();
    final lC = TextEditingController();
    bool loading = false;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: CPGlassCard(
            isDark: isDark,
            padding: EdgeInsets.fromLTRB(28, 16, 28, 40),
            borderRadius: 40,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Financial Policy',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _sheetLabel('REGULATION BATCH', isDark),
                  const SizedBox(height: 10),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _adminRepo.getBatches(),
                    builder: (ctx, snap) {
                      final batches = snap.data ?? [];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.paleSlate1 : AppColors.deepNavy)
                              .withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: bid,
                            hint: Text(
                              'Select Regulated Batch',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkBorder
                                    : Colors.black.withValues(alpha: 0.26),
                              ),
                            ),
                            isExpanded: true,
                            dropdownColor: isDark
                                ? const Color(0xFF354388)
                                : Colors.white,
                            items: batches
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b['id'].toString(),
                                    child: Text(
                                      b['name'].toString(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.deepNavy,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) async {
                              setSS(() {
                                bid = v;
                                loading = true;
                              });
                              try {
                                final struct = await _adminRepo.getFeeStructure(
                                  v!,
                                );
                                setSS(() {
                                  fC.text = (struct['monthly_fee'] ?? '')
                                      .toString();
                                  aC.text = (struct['admission_fee'] ?? '')
                                      .toString();
                                  lC.text = (struct['late_fee_amount'] ?? '')
                                      .toString();
                                  loading = false;
                                });
                              } catch (_) {
                                setSS(() {
                                  fC.clear();
                                  aC.clear();
                                  lC.clear();
                                  loading = false;
                                });
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  if (loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: AppColors.elitePrimary,
                        ),
                      ),
                    )
                  else if (bid != null) ...[
                    CustomTextField(
                      label: 'Monthly Tariff (₹)',
                      controller: fC,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.payments_rounded,
                    ),
                    const SizedBox(height: 24),
                    CustomTextField(
                      label: 'Registration Tariff (₹)',
                      controller: aC,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.how_to_reg_rounded,
                    ),
                    const SizedBox(height: 24),
                    CustomTextField(
                      label: 'Penalty Threshold (₹)',
                      controller: lC,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.gavel_rounded,
                    ),
                    const SizedBox(height: 48),
                    CustomButton(
                      text: 'Enforce Policy',
                      isLoading: saving,
                      icon: Icons.gavel_rounded,
                      onPressed: () async {
                        setSS(() => saving = true);
                        try {
                          await _adminRepo.defineFeeStructure({
                            'batch_id': bid,
                            'monthly_fee': double.tryParse(fC.text) ?? 0,
                            'admission_fee': double.tryParse(aC.text) ?? 0,
                            'late_fee_amount': double.tryParse(lC.text) ?? 0,
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            CPToast.success(context, 'Fee structure saved');
                          }
                        } catch (_) {
                          if (ctx.mounted) {
                            CPToast.error(ctx, 'Failed to save fee structure');
                            setSS(() => saving = false);
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _monthLabel(dynamic month, dynamic year) {
    if (month is int && year is int && month >= 1 && month <= 12) {
      return DateFormat('MMM yyyy').format(DateTime(year, month));
    }
    return '';
  }
}


