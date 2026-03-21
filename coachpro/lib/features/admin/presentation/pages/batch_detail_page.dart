import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/theme/theme_aware.dart';

class BatchDetailPage extends StatefulWidget {
  final String batchId;
  const BatchDetailPage({super.key, required this.batchId});

  @override
  State<BatchDetailPage> createState() => _BatchDetailPageState();
}

class _BatchDetailPageState extends State<BatchDetailPage> {
  final _adminRepo = sl<AdminRepository>();
  Map<String, dynamic>? _batch;
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBatch();
  }

  Future<void> _loadBatch() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final data = await _adminRepo.getBatchById(widget.batchId);
      if (!mounted) return;
      setState(() {
        _batch = data;
        _students = (data['students'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Text(
          _batch?['name'] ?? 'Batch Detail',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        actions: [
          if (_batch != null)
            IconButton(
              icon: Icon(Icons.toggle_on_outlined,
                  color: (_batch!['is_active'] ?? true) ? AppColors.success : AppColors.error),
              tooltip: 'Toggle Batch Status',
              onPressed: _toggleBatchStatus,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(_error!, style: GoogleFonts.dmSans(color: CT.textM(context))),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadBatch, child: const Text('Retry')),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _loadBatch,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildBatchInfo(isDark)),
                      SliverToBoxAdapter(child: _buildStats(isDark)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppDimensions.pagePaddingH, AppDimensions.lg, AppDimensions.pagePaddingH, AppDimensions.sm),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Enrolled Students (${_students.length})',
                                style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: CT.textH(context)),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.person_add_outlined, size: 16),
                                label: const Text('Add'),
                                onPressed: () => context.push('/admin/add-student'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _students.isEmpty
                          ? SliverFillRemaining(
                              child: Center(
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.group_outlined, size: 64, color: CT.textM(context)),
                                  const SizedBox(height: 16),
                                  Text('No students enrolled', style: GoogleFonts.sora(color: CT.textM(context))),
                                  const SizedBox(height: 8),
                                  Text('Add students to this batch', style: GoogleFonts.dmSans(color: CT.textS(context))),
                                ]),
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final s = _students[i];
                                  return _StudentListTile(
                                    student: s,
                                    index: i,
                                    onTap: () => context.push('/admin/students/${s['id']}'),
                                  );
                                },
                                childCount: _students.length,
                              ),
                            ),
                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBatchInfo(bool isDark) {
    if (_batch == null) return const SizedBox.shrink();
    final isActive = _batch!['is_active'] ?? true;
    final subject = _batch!['subject'] ?? 'General';
    final teacher = _batch!['teacher']?['name'] ?? 'Not assigned';
    final schedule = '${_batch!['start_time'] ?? '--'} - ${_batch!['end_time'] ?? '--'}';

    return Container(
      margin: const EdgeInsets.all(AppDimensions.pagePaddingH),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.premiumEliteGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        boxShadow: [BoxShadow(color: AppColors.elitePurple.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(isActive ? 'ACTIVE' : 'INACTIVE',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                    color: isActive ? AppColors.success : AppColors.error)),
          ),
          const Spacer(),
          Text(_batch!['name'] ?? '', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
        const SizedBox(height: 16),
        _infoRow(Icons.book_outlined, 'Subject', subject),
        const SizedBox(height: 8),
        _infoRow(Icons.person_outline, 'Teacher', teacher),
        const SizedBox(height: 8),
        _infoRow(Icons.schedule_outlined, 'Schedule', schedule),
      ]),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white70)),
        Expanded(child: Text(value, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis)),
      ]);

  Widget _buildStats(bool isDark) {
    final capacity = _batch?['capacity'] ?? 0;
    final enrolled = _students.length;
    final fillPercent = capacity > 0 ? enrolled / capacity : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
      child: Row(children: [
        Expanded(child: _statCard('Enrolled', enrolled.toString(), Icons.group_outlined, AppColors.elitePrimary, isDark)),
        const SizedBox(width: AppDimensions.sm),
        Expanded(child: _statCard('Capacity', capacity > 0 ? capacity.toString() : '∞', Icons.chair_outlined, AppColors.moltenAmber, isDark)),
        const SizedBox(width: AppDimensions.sm),
        Expanded(child: _statCard('Fill Rate', '${(fillPercent * 100).toInt()}%', Icons.bar_chart_outlined, AppColors.mintGreen, isDark)),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, bool isDark) => Container(
    padding: const EdgeInsets.all(AppDimensions.md),
    decoration: BoxDecoration(
      color: CT.card(context),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      boxShadow: AppDimensions.shadowSm(isDark),
    ),
    child: Column(children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(height: 8),
      Text(value, style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: CT.textH(context))),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: CT.textS(context))),
    ]),
  );

  Future<void> _toggleBatchStatus() async {
    final current = _batch!['is_active'] ?? true;
    try {
      await _adminRepo.toggleBatchStatus(batchId: widget.batchId, isActive: !current);
      setState(() => _batch!['is_active'] = !current);
      if (mounted) CPToast.success(context, 'Batch ${!current ? 'activated' : 'deactivated'}');
    } catch (e) {
      if (mounted) CPToast.error(context, 'Failed: $e');
    }
  }
}

class _StudentListTile extends StatelessWidget {
  final Map<String, dynamic> student;
  final int index;
  final VoidCallback onTap;

  const _StudentListTile({required this.student, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = student['name'] ?? 'Student';
    final phone = student['phone'] ?? '';
    final isActive = student['is_active'] ?? true;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH, vertical: 4),
      child: Material(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: AppColors.elitePrimary.withValues(alpha: 0.12),
                child: Text(initial, style: GoogleFonts.sora(color: AppColors.elitePrimary, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: CT.textH(context))),
                Text(phone, style: GoogleFonts.dmSans(fontSize: 12, color: CT.textS(context))),
              ])),
              if (!isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Inactive', style: GoogleFonts.inter(fontSize: 10, color: AppColors.error)),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: CT.textM(context)),
            ]),
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: 30 * index)).fadeIn(duration: 250.ms);
  }
}
