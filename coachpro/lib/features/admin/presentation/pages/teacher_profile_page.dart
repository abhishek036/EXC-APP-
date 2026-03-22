import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../data/repositories/admin_repository.dart';

class TeacherProfilePage extends StatefulWidget {
  final String teacherId;
  const TeacherProfilePage({super.key, required this.teacherId});

  @override
  State<TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> with SingleTickerProviderStateMixin {
  final AdminRepository _adminRepo = sl<AdminRepository>();
  late TabController _tabController;

  bool _isLoading = true;
  bool _editMode = false;
  bool _saving = false;

  Map<String, dynamic>? _teacher;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _attendance = {};
  Map<String, dynamic> _permissions = {};
  Map<String, dynamic> _feedbackSummary = {};
  List<Map<String, dynamic>> _activityTimeline = [];
  List<Map<String, dynamic>> _batches = [];

  late TextEditingController _nameCtrl;
  late TextEditingController _subjectsCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _qualificationCtrl;
  late TextEditingController _salaryCtrl;
  late TextEditingController _revenueCtrl;

  final TextEditingController _feedbackCommentCtrl = TextEditingController();
  final TextEditingController _feedbackStudentCtrl = TextEditingController();
  double _feedbackRating = 5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _nameCtrl = TextEditingController();
    _subjectsCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _qualificationCtrl = TextEditingController();
    _salaryCtrl = TextEditingController();
    _revenueCtrl = TextEditingController();
    _loadTeacherDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _subjectsCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _qualificationCtrl.dispose();
    _salaryCtrl.dispose();
    _revenueCtrl.dispose();
    _feedbackCommentCtrl.dispose();
    _feedbackStudentCtrl.dispose();
    super.dispose();
  }

  num _toNum(dynamic value, {num fallback = 0}) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _loadTeacherDashboard() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _adminRepo.getTeacherProfileDashboard(widget.teacherId);
      final teacher = Map<String, dynamic>.from(data['teacher'] as Map? ?? {});
      final subjects = ((teacher['subjects'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();

      _nameCtrl.text = (teacher['name'] ?? '').toString();
      _subjectsCtrl.text = subjects.join(', ');
      _phoneCtrl.text = (teacher['phone'] ?? '').toString();
      _emailCtrl.text = (teacher['email'] ?? '').toString();
      _qualificationCtrl.text = (teacher['qualification'] ?? '').toString();

      final compensation = Map<String, dynamic>.from(data['compensation'] as Map? ?? {});
      _salaryCtrl.text = compensation['salary']?.toString() ?? '';
      _revenueCtrl.text = compensation['revenue_share']?.toString() ?? '';

      if (!mounted) return;
      setState(() {
        _teacher = teacher;
        _stats = Map<String, dynamic>.from(data['stats'] as Map? ?? {});
        _attendance = Map<String, dynamic>.from(data['attendance'] as Map? ?? {});
        _permissions = Map<String, dynamic>.from(data['permissions'] as Map? ?? {});
        _feedbackSummary = Map<String, dynamic>.from(data['feedback_summary'] as Map? ?? {});
        _activityTimeline = ((data['activity_timeline'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _batches = ((teacher['batches'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CPToast.error(context, 'Failed to load teacher profile: $e');
    }
  }

  Future<void> _saveTeacherBasics() async {
    if (_teacher == null) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final subjects = _subjectsCtrl.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      await _adminRepo.updateTeacher(widget.teacherId, {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'qualification': _qualificationCtrl.text.trim(),
        'subject': _subjectsCtrl.text.trim(),
        'subjects': subjects,
      });

      await _adminRepo.updateTeacherSettings(
        teacherId: widget.teacherId,
        permissions: _permissions,
        salary: num.tryParse(_salaryCtrl.text.trim()),
        revenueShare: num.tryParse(_revenueCtrl.text.trim()),
      );

      if (!mounted) return;
      setState(() {
        _editMode = false;
        _saving = false;
      });
      CPToast.success(context, 'Teacher profile updated');
      _loadTeacherDashboard();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      CPToast.error(context, 'Update failed: $e');
    }
  }

  Future<void> _updatePermissions() async {
    try {
      await _adminRepo.updateTeacherSettings(
        teacherId: widget.teacherId,
        permissions: _permissions,
        salary: num.tryParse(_salaryCtrl.text.trim()),
        revenueShare: num.tryParse(_revenueCtrl.text.trim()),
      );
      if (!mounted) return;
      CPToast.success(context, 'Access settings updated');
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Failed to update access: $e');
    }
  }

  Future<void> _submitFeedback() async {
    try {
      await _adminRepo.addTeacherFeedback(
        teacherId: widget.teacherId,
        rating: _feedbackRating,
        comment: _feedbackCommentCtrl.text.trim().isEmpty ? null : _feedbackCommentCtrl.text.trim(),
        studentName: _feedbackStudentCtrl.text.trim().isEmpty ? null : _feedbackStudentCtrl.text.trim(),
      );
      if (!mounted) return;
      _feedbackCommentCtrl.clear();
      _feedbackStudentCtrl.clear();
      _feedbackRating = 5;
      setState(() {});
      CPToast.success(context, 'Feedback added');
      _loadTeacherDashboard();
    } catch (e) {
      if (!mounted) return;
      CPToast.error(context, 'Failed to add feedback: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_teacher == null) {
      return const Scaffold(body: Center(child: Text('Teacher not found')));
    }

    final teacherName = (_teacher!['name'] ?? 'Teacher').toString();
    final subjects = (( _teacher!['subjects'] as List?) ?? const []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF0D1282),
            leading: CPPressable(
              onTap: () => context.pop(),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
            actions: [
              CPPressable(
                onTap: () {
                  if (_saving) return;
                  if (_editMode) {
                    _saveTeacherBasics();
                  } else {
                    setState(() => _editMode = true);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF0DE36), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      _saving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D1282)))
                          : Icon(_editMode ? Icons.check_rounded : Icons.edit_rounded, size: 14, color: const Color(0xFF0D1282)),
                      const SizedBox(width: 6),
                      Text(
                        _editMode ? (_saving ? 'SAVING...' : 'SAVE') : 'EDIT',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0D1282), Color(0xFF1A1F71)]),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), color: Colors.white24),
                      alignment: Alignment.center,
                      child: Text(
                        teacherName.isNotEmpty ? teacherName[0].toUpperCase() : 'T',
                        style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(teacherName, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text(subjects.isNotEmpty ? subjects.join(', ') : 'Faculty Mentor', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildTabBar(isDark),
                SizedBox(
                  height: MediaQuery.of(context).size.height - 300,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProfileTab(isDark),
                      _buildBatchesTab(isDark),
                      _buildAttendanceTab(isDark),
                      _buildActivityTab(isDark),
                      _buildAccessAndFeedbackTab(isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      color: isDark ? AppColors.eliteDarkBg : Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF0D1282),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFFF0DE36),
        indicatorWeight: 4,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
        tabs: const [
          Tab(text: 'PROFILE'),
          Tab(text: 'BATCHES'),
          Tab(text: 'ATTENDANCE'),
          Tab(text: 'ACTIVITY'),
          Tab(text: 'ACCESS + FEEDBACK'),
        ],
      ),
    );
  }

  Widget _buildProfileTab(bool isDark) {
    final avgRating = _toNum(_stats['average_rating']).toStringAsFixed(1);
    final classesWeek = _toNum(_stats['classes_this_week']).toInt();
    final pendingDoubts = _toNum(_stats['pending_doubts']).toInt();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionHeader('Editable Profile Details'),
        const SizedBox(height: 16),
        _field('Full Name', _nameCtrl, Icons.person_rounded, isDark),
        _field('Subject Expertise (comma separated)', _subjectsCtrl, Icons.book_rounded, isDark),
        _field('Phone', _phoneCtrl, Icons.phone_rounded, isDark, keyboard: TextInputType.phone),
        _field('Email', _emailCtrl, Icons.email_rounded, isDark, keyboard: TextInputType.emailAddress),
        _field('Qualification', _qualificationCtrl, Icons.workspace_premium_rounded, isDark),
        const SizedBox(height: 20),
        _sectionHeader('Performance Snapshot'),
        const SizedBox(height: 12),
        CPGlassCard(
          isDark: isDark,
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricItem(avgRating, 'Rating', Icons.star_rounded, Colors.orange),
              _metricItem('$classesWeek', 'Classes (7d)', Icons.event_available_rounded, Colors.green),
              _metricItem('$pendingDoubts', 'Pending Doubts', Icons.help_center_rounded, Colors.blue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBatchesTab(bool isDark) {
    if (_batches.isEmpty) {
      return _emptyState('No assigned batches', Icons.layers_clear_rounded);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _batches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final batch = _batches[index];
        final studentCount = _toNum(((batch['_count'] as Map?)?['student_batches'])).toInt();
        return CPPressable(
          onTap: () => context.push('/admin/batches/${batch['id']}'),
          child: CPGlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            child: Row(
              children: [
                const Icon(Icons.group_rounded, color: Color(0xFF0D1282)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((batch['name'] ?? 'Batch').toString(), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF0D1282))),
                      const SizedBox(height: 4),
                      Text('Students: $studentCount', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF0D1282)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceTab(bool isDark) {
    final totalSessions = _toNum(_attendance['total_sessions_taken']).toInt();
    final sessionsLast30 = _toNum(_attendance['sessions_last_30_days']).toInt();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionHeader('Attendance in Assigned Classes'),
        const SizedBox(height: 12),
        CPGlassCard(
          isDark: isDark,
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total sessions marked: $totalSessions', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
              const SizedBox(height: 8),
              Text('Sessions in last 30 days: $sessionsLast30', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
              const SizedBox(height: 8),
              Text('Batches currently assigned: ${_batches.length}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTab(bool isDark) {
    if (_activityTimeline.isEmpty) {
      return _emptyState('No recent activity', Icons.timeline_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _activityTimeline.length,
      itemBuilder: (context, index) {
        final item = _activityTimeline[index];
        final at = DateTime.tryParse((item['at'] ?? '').toString());
        final title = (item['title'] ?? 'Activity').toString();
        final batchName = (item['batch_name'] ?? '').toString();
        final type = (item['type'] ?? 'update').toString().replaceAll('_', ' ');

        return IntrinsicHeight(
          child: Row(
            children: [
              Column(
                children: [
                  Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFF0DE36), shape: BoxShape.circle)),
                  Expanded(child: Container(width: 2, color: Colors.grey.withValues(alpha: 0.3))),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: CPGlassCard(
                    isDark: isDark,
                    padding: const EdgeInsets.all(12),
                    borderRadius: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFF0D1282))),
                        if (batchName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(batchName, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${type.toUpperCase()} • ${at != null ? '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}' : 'Unknown time'}',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).animate(delay: (20 * index).ms).fadeIn(duration: 250.ms);
      },
    );
  }

  Widget _buildAccessAndFeedbackTab(bool isDark) {
    final recentFeedbacks = ((_feedbackSummary['recent_feedbacks'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionHeader('Permission Toggles'),
        const SizedBox(height: 12),
        _toggleRow('Can edit attendance', 'can_edit_attendance', isDark),
        _toggleRow('Can see fee data', 'can_see_fee_data', isDark),
        _toggleRow('Can upload study material', 'can_upload_study_material', isDark),
        _toggleRow('Can create exams', 'can_create_exams', isDark),
        _toggleRow('Can manage students', 'can_manage_students', isDark),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _field('Salary', _salaryCtrl, Icons.payments_rounded, isDark, keyboard: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: _field('Revenue %', _revenueCtrl, Icons.percent_rounded, isDark, keyboard: TextInputType.number)),
          ],
        ),
        CustomButton(text: 'Save Access Settings', onPressed: _updatePermissions),
        const SizedBox(height: 20),
        _sectionHeader('Performance / Feedback'),
        const SizedBox(height: 12),
        CPGlassCard(
          isDark: isDark,
          padding: const EdgeInsets.all(14),
          borderRadius: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricItem(_toNum(_feedbackSummary['average_rating']).toStringAsFixed(2), 'Avg Rating', Icons.star_rounded, Colors.orange),
              _metricItem('${_toNum(_feedbackSummary['feedback_count']).toInt()}', 'Feedback Count', Icons.rate_review_rounded, Colors.blue),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _feedbackStudentCtrl,
          decoration: InputDecoration(
            hintText: 'Student name (optional)',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _feedbackCommentCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add feedback comment',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Rating', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                value: _feedbackRating,
                min: 1,
                max: 5,
                divisions: 4,
                label: _feedbackRating.toStringAsFixed(1),
                activeColor: const Color(0xFFF0DE36),
                inactiveColor: const Color(0xFF0D1282).withValues(alpha: 0.2),
                onChanged: (value) => setState(() => _feedbackRating = value),
              ),
            ),
          ],
        ),
        CustomButton(text: 'Add Feedback', onPressed: _submitFeedback),
        const SizedBox(height: 12),
        if (recentFeedbacks.isEmpty)
          Text('No feedback entries yet.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600))
        else
          ...recentFeedbacks.map((item) {
            final createdAt = DateTime.tryParse((item['created_at'] ?? '').toString());
            return CPGlassCard(
              isDark: isDark,
              padding: const EdgeInsets.all(12),
              borderRadius: 12,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('⭐ ${_toNum(item['rating']).toStringAsFixed(1)}  ${item['student_name'] ?? ''}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
                    if ((item['comment'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text((item['comment'] ?? '').toString(), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade800)),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      createdAt == null
                          ? 'Unknown date'
                          : '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller, IconData icon, bool isDark, {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: _editMode || label == 'Salary' || label == 'Revenue %',
        keyboardType: keyboard,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.deepNavy),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF0D1282)),
          filled: true,
          fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _toggleRow(String label, String key, bool isDark) {
    final current = (_permissions[key] ?? false) == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CPGlassCard(
        isDark: isDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderRadius: 12,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
            Switch(
              value: current,
              onChanged: (value) {
                setState(() => _permissions[key] = value);
              },
              activeThumbColor: const Color(0xFFF0DE36),
              activeTrackColor: const Color(0xFF0D1282),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282), letterSpacing: 1.1),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}


