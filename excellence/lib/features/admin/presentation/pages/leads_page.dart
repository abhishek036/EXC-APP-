import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_shimmer.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final _adminRepo = sl<AdminRepository>();
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _leads = [];
  String _activeTab = 'New';
  final _tabs = ['New', 'Follow Up', 'Trial', 'Converted'];

  List<Map<String, dynamic>> _dedupeById(List<Map<String, dynamic>> items) {
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final item in items) {
      final id = (item['id'] ?? '').toString();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      unique.add(item);
    }
    return unique;
  }

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  Future<void> _loadLeads() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _adminRepo.getLeads();
      if (mounted) {
        setState(() {
          _leads = _dedupeById(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addLead() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final isDark = CT.isDark(context);

    HapticFeedback.lightImpact();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBorder
                        : Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.electricBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: AppColors.electricBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lead Generation',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Input potential prospect data',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.paleSlate2 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildInputLabel('PROSPECT NAME', isDark),
              const SizedBox(height: 8),
              _buildTextField(
                nameCtrl,
                'Enter full name',
                Icons.person_outline_rounded,
                isDark,
              ),
              const SizedBox(height: 20),
              _buildInputLabel('CONTACT NUMBER', isDark),
              const SizedBox(height: 8),
              _buildTextField(
                phoneCtrl,
                'Enter 10-digit number',
                Icons.phone_outlined,
                isDark,
                isNumber: true,
              ),
              const SizedBox(height: 32),
              CPPressable(
                onTap: () async {
                  if (_isSubmitting) return;
                  if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                  HapticFeedback.mediumImpact();
                  setState(() => _isSubmitting = true);
                  try {
                    await _adminRepo.createLead(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    await _loadLeads();
                  } finally {
                    if (mounted) setState(() => _isSubmitting = false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.electricBlue,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.electricBlue.withValues(alpha: 0.3),
                        blurRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Add to Pipeline',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label, bool isDark) => Text(
    label,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 10,
      fontWeight: FontWeight.w900,
      color: isDark ? AppColors.paleSlate2 : Colors.black54,
      letterSpacing: 1.0,
    ),
  );

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    bool isDark, {
    bool isNumber = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.paleSlate1 : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.paleSlate2 : Colors.black38,
          ),
          prefixIcon: Icon(
            icon,
            color: isDark ? AppColors.paleSlate2 : Colors.black54,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _updateLeadStatus(String id, String newStatus) async {
    if (id.isEmpty) return;
    setState(() => _isLoading = true);
    await _adminRepo.updateLeadStatus(leadId: id, status: newStatus);
    _loadLeads();
  }

  Future<void> _editLead(Map<String, dynamic> lead) async {
    final leadId = (lead['id'] ?? '').toString();
    if (leadId.isEmpty) return;
    final nameCtrl = TextEditingController(
      text: (lead['name'] ?? '').toString(),
    );
    final phoneCtrl = TextEditingController(
      text: (lead['phone'] ?? '').toString(),
    );
    final isDark = CT.isDark(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Lead',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                nameCtrl,
                'Enter full name',
                Icons.person_outline_rounded,
                isDark,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                phoneCtrl,
                'Enter 10-digit number',
                Icons.phone_outlined,
                isDark,
                isNumber: true,
              ),
              const SizedBox(height: 20),
              CPPressable(
                onTap: () async {
                  if (_isSubmitting) return;
                  if (nameCtrl.text.trim().isEmpty ||
                      phoneCtrl.text.trim().isEmpty) {
                    return;
                  }
                  setState(() => _isSubmitting = true);
                  try {
                    await _adminRepo.updateLead(leadId, {
                      'name': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                    });
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    await _loadLeads();
                  } finally {
                    if (mounted) setState(() => _isSubmitting = false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.electricBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteLead(Map<String, dynamic> lead) async {
    final leadId = (lead['id'] ?? '').toString();
    if (leadId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Lead?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            color: const Color(0xFF354388),
          ),
        ),
        content: Text(
          'This will remove ${(lead['name'] ?? 'this lead')} permanently.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFB6231B)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await _adminRepo.deleteLead(leadId);
    } finally {
      if (mounted) {
        await _loadLeads();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLeads = _leads
        .where((lead) => (lead['status'] ?? 'New') == _activeTab)
        .toList();
    final isDark = CT.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          Positioned(top: -100, right: -100, child: const SizedBox.shrink()),
          Positioned(bottom: -100, left: -100, child: const SizedBox.shrink()),

          SafeArea(
            child: Column(
              children: [
                // ── HEADER ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      CPPressable(
                        onTap: () { if (GoRouter.of(context).canPop()) { GoRouter.of(context).pop(); } else { GoRouter.of(context).go('/admin'); } },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                            color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Opportunity Pipeline',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const Spacer(),
                      CPPressable(
                        onTap: _addLead,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.electricBlue,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.electricBlue.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.add_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Add Lead',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── PIPELINE STAGES ──
                Container(
                  height: 48,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final tab = _tabs[index];
                      final isActive = _activeTab == tab;
                      final count = _leads
                          .where((lead) => (lead['status'] ?? 'New') == tab)
                          .length;
                      return CPPressable(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _activeTab = tab);
                        },
                        child: AnimatedContainer(
                          duration: 300.ms,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: isActive
                                ? (isDark ? AppColors.paleSlate1 : AppColors.deepNavy)
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: isActive
                                  ? Colors.transparent
                                  : (isDark
                                        ? Colors.white10
                                        : Colors.black.withValues(alpha: 0.12)),
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color:
                                          (isDark
                                                  ? Colors.white
                                                  : AppColors.deepNavy)
                                              .withValues(alpha: 0.3),
                                      blurRadius: 0,
                                    ),
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            children: [
                              Text(
                                tab.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: isActive
                                      ? (isDark
                                            ? AppColors.deepNavy
                                            : Colors.white)
                                      : (isDark
                                            ? Colors.white54
                                            : Colors.black54),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? (isDark
                                              ? AppColors.deepNavy.withValues(
                                                  alpha: 0.2,
                                                )
                                              : Colors.white.withValues(
                                                  alpha: 0.2,
                                                ))
                                        : (isDark
                                              ? AppColors.darkBorder
                                              : Colors.black.withValues(
                                                  alpha: 0.2,
                                                )),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: isActive
                                          ? (isDark
                                                ? AppColors.deepNavy
                                                : Colors.white)
                                          : (isDark
                                                ? Colors.white
                                                : Colors.black),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Expanded(
                  child: _isLoading
                      ? ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: 5,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) => const CPShimmer(
                            width: double.infinity,
                            height: 100,
                            borderRadius: 24,
                          ),
                        )
                      : currentLeads.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_rounded,
                                size: 64,
                                color: isDark
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: 0.12),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Pipeline Empty',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn()
                      : RefreshIndicator(
                          onRefresh: _loadLeads,
                          color: AppColors.electricBlue,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: currentLeads.length,
                            itemBuilder: (context, index) {
                              final lead = currentLeads[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: CPGlassCard(
                                  isDark: isDark,
                                  padding: const EdgeInsets.all(20),
                                  borderRadius: 24,
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.05),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.electricBlue
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person_outline_rounded,
                                          color: AppColors.electricBlue,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (lead['name'] ?? 'Unknown')
                                                  .toString(),
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                    color: isDark
                                                        ? Colors.white
                                                        : AppColors.deepNavy,
                                                    letterSpacing: -0.5,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.phone_enabled_rounded,
                                                  size: 12,
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.black54,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  (lead['phone'] ?? 'No Phone')
                                                      .toString(),
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.black87,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        color: isDark
                                            ? AppColors.eliteDarkBg
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          side: BorderSide(
                                            color: isDark
                                                ? Colors.white12
                                                : Colors.black.withValues(
                                                    alpha: 0.12,
                                                  ),
                                          ),
                                        ),
                                        icon: Icon(
                                          Icons.more_vert_rounded,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _editLead(lead);
                                            return;
                                          }
                                          if (value == 'delete') {
                                            _deleteLead(lead);
                                            return;
                                          }
                                          _updateLeadStatus(
                                            (lead['id'] ?? '').toString(),
                                            value,
                                          );
                                        },
                                        itemBuilder: (context) {
                                          final statusItems = _tabs
                                              .where(
                                                (tabName) =>
                                                    tabName != lead['status'],
                                              )
                                              .map(
                                                (
                                                  tabName,
                                                ) => PopupMenuItem<String>(
                                                  value: tabName,
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .fast_forward_rounded,
                                                        size: 16,
                                                        color: isDark
                                                            ? Colors.white54
                                                            : Colors.black54,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        'Move to $tabName',
                                                        style:
                                                            GoogleFonts.plusJakartaSans(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: isDark
                                                                  ? Colors.white
                                                                  : AppColors
                                                                        .deepNavy,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                              .toList();
                                          return [
                                            ...statusItems,
                                            const PopupMenuDivider(),
                                            PopupMenuItem<String>(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit_outlined,
                                                    size: 16,
                                                    color: isDark
                                                        ? Colors.white54
                                                        : Colors.black54,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Edit',
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: isDark
                                                              ? Colors.white
                                                              : AppColors
                                                                    .deepNavy,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 16,
                                                    color: Color(0xFFB6231B),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Delete',
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: const Color(
                                                            0xFFB6231B,
                                                          ),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ];
                                        },
                                      ),
                                    ],
                                  ),
                                ).animate().fadeIn(delay: (30 * index).ms).slideX(begin: 0.1, delay: (30 * index).ms),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


