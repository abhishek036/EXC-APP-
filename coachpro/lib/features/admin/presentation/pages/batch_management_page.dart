import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_shimmer.dart';
import '../../data/repositories/admin_repository.dart';

class BatchManagementPage extends StatefulWidget {
  const BatchManagementPage({super.key});

  @override
  State<BatchManagementPage> createState() => _BatchManagementPageState();
}

class _BatchManagementPageState extends State<BatchManagementPage> {
  final _adminRepo = sl<AdminRepository>();
  bool _isLoading = true;
  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _teachers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final batches = await _adminRepo.getBatches();
      final teachers = await _adminRepo.getTeachers();
      if (!mounted) return;
      setState(() {
        _batches = batches;
        _teachers = teachers;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    final active = _batches.where((batch) => (batch['is_active'] ?? batch['isActive']) == true).length;
    final totalStudents = _batches.fold<int>(0, (sum, batch) => sum + (batch['current_students'] as int? ?? 0));

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, isDark),
                Expanded(
                  child: _isLoading
                      ? ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          itemCount: 4,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (_, __) => const CPShimmer(width: double.infinity, height: 160, borderRadius: 28),
                        )
                      : RefreshIndicator(
                          color: AppColors.elitePrimary,
                          onRefresh: _loadData,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  _summaryStat('ACTIVE', '$active', AppColors.mintGreen, isDark),
                                  const SizedBox(width: 12),
                                  _summaryStat('ENROLLED', '$totalStudents', AppColors.elitePrimary, isDark),
                                  const SizedBox(width: 12),
                                  _summaryStat('PROGRAMS', '${_batches.length}', AppColors.elitePurple, isDark),
                                ]).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
                                const SizedBox(height: 32),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Academic Cohorts', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.6)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10)),
                                      child: Text('${_batches.length} TOTAL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 0.5)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                if (_batches.isEmpty)
                                  _buildEmptyState(isDark)
                                else
                                  ..._batches.asMap().entries.map((entry) => Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: _batchCard(context, entry.value, entry.key, isDark),
                                      )),
                                const SizedBox(height: 100),
                              ],
                            ),
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

  // Removed _glow method
  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          CPPressable(onTap: () => Navigator.pop(context), child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : AppColors.deepNavy)),
          const SizedBox(width: 16),
          Expanded(child: Text('Batch Academy', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.8))),
          _appBarAction(Icons.add_rounded, () => _showCreateBatchSheet(context), isDark, primary: true),
        ],
      ),
    );
  }

  Widget _appBarAction(IconData icon, VoidCallback onTap, bool isDark, {bool primary = false}) {
    return CPPressable(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: primary ? const Color(0xFFF0DE36) : const Color(0xFF0D1282), border: Border.all(color: const Color(0xFF0D1282), width: 3), boxShadow: primary ? const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3))] : null),
        child: Icon(icon, size: 22, color: primary ? const Color(0xFF0D1282) : Colors.white),
      ),
    );
  }

  Widget _summaryStat(String label, String value, Color color, bool isDark) => Expanded(
    child: CPGlassCard(
      isDark: isDark, padding: const EdgeInsets.symmetric(vertical: 20), borderRadius: 24,
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: color, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26), letterSpacing: 0.5)),
        ],
      ),
    ),
  );

  Widget _batchCard(BuildContext context, Map<String, dynamic> batchData, int i, bool isDark) {
    final name = (batchData['name'] ?? 'Batch').toString();
    final subject = (batchData['subject'] ?? '').toString();
    final teacherName = (batchData['teacher_name'] ?? 'Faculty Unassigned').toString();
    final currentStudents = (batchData['current_students'] as int?) ?? 0;
    final isActive = (batchData['is_active'] ?? batchData['isActive']) == true;
    final maxStudents = (batchData['capacity'] as int?) ?? 60;
    final fee = (batchData['fee'] as num?)?.toDouble() ?? 0;
    final timing = _buildTiming(batchData);

    return CPGlassCard(
      isDark: isDark, padding: const EdgeInsets.all(20), borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFEEEDED), border: Border.all(color: isActive ? AppColors.mintGreen : Colors.grey, width: 2), boxShadow: [BoxShadow(color: isActive ? AppColors.mintGreen : Colors.grey, offset: const Offset(2, 2))]), child: Icon(Icons.layers_rounded, size: 20, color: isActive ? AppColors.mintGreen : Colors.grey)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.4)),
                Text(subject.isNotEmpty ? subject : 'General Program', style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.w600)),
              ])),
              _badge(isActive ? 'LIVE' : 'PAUSED', isActive ? AppColors.mintGreen : (isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26)), isDark),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoSegment(Icons.groups_rounded, '$currentStudents / $maxStudents seats', isDark),
              if (fee > 0) Text('₹${fee.toInt()}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.mintGreen)),
            ],
          ),
          if (timing.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoSegment(Icons.schedule_rounded, timing, isDark),
          ],
          const SizedBox(height: 20),
          Divider(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(radius: 14, backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), child: Icon(Icons.person_pin_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black54)),
              const SizedBox(width: 12),
              Expanded(child: Text(teacherName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white60 : Colors.black87))),
              CPPressable(
                onTap: () { HapticFeedback.mediumImpact(); _toggleBatchStatus(batchData); },
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.power_settings_new_rounded, size: 16, color: isActive ? AppColors.coralRed : AppColors.mintGreen)),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: (100 * i).ms).fadeIn(duration: 500.ms).slideX(begin: 0.05);
  }

  Widget _infoSegment(IconData icon, String text, bool isDark) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.26)),
      const SizedBox(width: 8),
      Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.black45)),
    ],
  );

  Widget _badge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFEEEDED), border: Border.all(color: color, width: 2), boxShadow: [BoxShadow(color: color, offset: const Offset(2, 2))]),
      child: Text(text, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282), letterSpacing: 0.5)),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return CPGlassCard(
      isDark: isDark, padding: const EdgeInsets.all(48), borderRadius: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_clear_rounded, size: 64, color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          Text('Academic records are empty', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white.withValues(alpha:0.24) : Colors.black.withValues(alpha: 0.26))),
          const SizedBox(height: 24),
          CustomButton(text: 'Establish First Cohort', onPressed: () => _showCreateBatchSheet(context)),
        ],
      ),
    );
  }

  String _buildTiming(Map<String, dynamic> batchData) {
    final start = (batchData['start_time'] ?? '').toString();
    final end = (batchData['end_time'] ?? '').toString();
    if (start.isEmpty && end.isEmpty) return '';
    final days = (batchData['days_of_week'] as List?) ?? const [];
    final dayLabel = days.isNotEmpty ? _dayName((days.first as num).toInt()) : '';
    final time = [start, end].where((item) => item.isNotEmpty).join(' - ');
    return dayLabel.isEmpty ? time : '$dayLabel • $time';
  }

  String _dayName(int value) {
    const map = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return (value >= 0 && value < map.length) ? map[value] : '';
  }

  Future<void> _toggleBatchStatus(Map<String, dynamic> batch) async {
    final isActive = (batch['is_active'] ?? batch['isActive']) == true;
    try {
      await _adminRepo.toggleBatchStatus(batchId: (batch['id'] ?? '').toString(), isActive: !isActive);
      if (mounted) CPToast.success(context, !isActive ? 'Cohort live! 🚀' : 'Cohort paused');
      _loadData();
    } catch (_) {
      if (mounted) CPToast.error(context, 'Update failed');
    }
  }

  void _showCreateBatchSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final maxStudentsCtrl = TextEditingController(text: '60');
    final feeCtrl = TextEditingController();
    String? selectedTeacherId;
    final isDark = CT.isDark(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return CPGlassCard(
            isDark: isDark, borderRadius: 32,
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 32),
                  Text('Cohort Genesis', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.6)),
                  Text('Initialize a new academic grouping.', style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 32),
                  _sheetField('PROGRAM NAME', 'e.g. Foundation Plus A', nameCtrl, Icons.layers_rounded, isDark),
                  const SizedBox(height: 20),
                  _sheetField('DISCIPLINE', 'e.g. Physics & Logic', subjectCtrl, Icons.auto_awesome_rounded, isDark),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _sheetField('ENROLLMENT LIMIT', '60', maxStudentsCtrl, Icons.group_rounded, isDark, type: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: _sheetField('PROGRAM FEE', '0', feeCtrl, Icons.payments_rounded, isDark, type: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('LEAD SCHOLAR / FACULTY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: const Color(0xFFEEEDED), border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3))]),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedTeacherId, dropdownColor: const Color(0xFFEEEDED),
                        hint: Text('Select Faculty', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0D1282), fontWeight: FontWeight.w600)),
                        isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0D1282)),
                        items: _teachers.map((t) {
                          final u = t['user'] is Map ? t['user'] as Map : {};
                          return DropdownMenuItem(value: t['id'].toString(), child: Text(t['name'] ?? u['name'] ?? 'Faculty', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0D1282), fontWeight: FontWeight.w700)));
                        }).toList(),
                        onChanged: (v) => setSheetState(() => selectedTeacherId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  CustomButton(
                    text: 'Initialize Program',
                    icon: Icons.rocket_launch_rounded,
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty || subjectCtrl.text.isEmpty) { CPToast.warning(ctx, 'Complete mandatory fields'); return; }
                        try {
                          await _adminRepo.createBatch({
                            'name': nameCtrl.text, 'subject': subjectCtrl.text, 
                            'capacity': int.tryParse(maxStudentsCtrl.text) ?? 60,
                            'fee': double.tryParse(feeCtrl.text) ?? 0,
                            'teacher_id': selectedTeacherId
                          });
                          if (ctx.mounted) { 
                            Navigator.pop(ctx); 
                            CPToast.success(context, 'Cohort initialized! 🚀'); 
                          }
                          _loadData();
                        } catch (_) { 
                          if (ctx.mounted) CPToast.error(ctx, 'Initialization failed'); 
                        }
                    },
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _sheetField(String label, String hint, TextEditingController ctrl, IconData icon, bool isDark, {TextInputType type = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1)),
        const SizedBox(height: 10),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0xFFEEEDED), border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3))]),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF0D1282)),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: ctrl, keyboardType: type, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0D1282), fontWeight: FontWeight.w700), decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.inter(color: const Color(0xFF0D1282).withValues(alpha: 0.5), fontSize: 13), border: InputBorder.none))),
            ],
          ),
        ),
      ],
    );
  }
}
