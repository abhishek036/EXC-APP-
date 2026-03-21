import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/di/injection_container.dart';
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
  Map<String, dynamic>? _teacher;
  bool _editMode = false;

  // Controllers for editing
  late TextEditingController _nameCtrl;
  late TextEditingController _subjectCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _salaryCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTeacher();
  }

  Future<void> _loadTeacher() async {
    try {
      final data = await _adminRepo.getTeacherById(widget.teacherId);
      if (mounted) {
        setState(() {
          _teacher = data;
          _isLoading = false;
          _nameCtrl = TextEditingController(text: data['name'] ?? '');
          _subjectCtrl = TextEditingController(text: data['subject'] ?? '');
          _phoneCtrl = TextEditingController(text: data['phone'] ?? '');
          _salaryCtrl = TextEditingController(text: (data['salary'] ?? '0').toString());
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTeacher() async {
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      await _adminRepo.updateTeacher(widget.teacherId, {
        'name': _nameCtrl.text.trim(),
        'subject': _subjectCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'salary': _salaryCtrl.text.trim(),
      });
      if (mounted) {
        setState(() { _editMode = false; _saving = false; });
        _loadTeacher();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faculty profile updated successfully')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  bool _saving = false;


  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_teacher == null) return const Scaffold(body: Center(child: Text('Teacher not found')));

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isDark),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildTabSwitcher(isDark),
                SizedBox(
                  height: MediaQuery.of(context).size.height - 300,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInfoTab(isDark),
                      _buildBatchesTab(isDark),
                      _buildActivityTab(isDark),
                      _buildSettingsTab(isDark),
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

  Widget _buildSliverAppBar(bool isDark) {
    final name = _teacher!['name'] ?? 'Faculty';
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF0D1282),
      leading: CPPressable(onTap: () => context.pop(), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
      actions: [
        CPPressable(
          onTap: () {
            if (_editMode) {
              _saveTeacher();
            } else {
              setState(() => _editMode = true);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF0DE36), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              _saving 
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D1282)))
                : Icon(_editMode ? Icons.check_rounded : Icons.edit_rounded, size: 14, color: const Color(0xFF0D1282)),
              const SizedBox(width: 6),
              Text(_editMode ? (_saving ? 'SAVING...' : 'SAVE') : 'EDIT', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
            ]),
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
                width: 80, height: 80,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), color: Colors.white24),
                child: Center(child: Text(name[0].toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white))),
              ),
              const SizedBox(height: 12),
              Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              Text(_teacher!['subject'] ?? 'Faculty Mentor', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSwitcher(bool isDark) {
    return Container(
      color: isDark ? AppColors.eliteDarkBg : Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF0D1282),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFFF0DE36),
        indicatorWeight: 4,
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
        tabs: const [
          Tab(text: 'PROFILE'),
          Tab(text: 'BATCHES'),
          Tab(text: 'LOGS'),
          Tab(text: 'ACCESS'),
        ],
      ),
    );
  }

  Widget _buildInfoTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('Basic Information', isDark),
        const SizedBox(height: 16),
        _buildProfileField('Full Name', _nameCtrl, Icons.person_rounded, isDark),
        _buildProfileField('Subject Expertise', _subjectCtrl, Icons.book_rounded, isDark),
        _buildProfileField('Contact Phone', _phoneCtrl, Icons.phone_rounded, isDark, keyboard: TextInputType.phone),
        _buildProfileField('Salary / Rev Share', _salaryCtrl, Icons.payments_rounded, isDark, keyboard: TextInputType.number),
        
        const SizedBox(height: 24),
        _buildSectionHeader('Performance Index', isDark),
        const SizedBox(height: 16),
        CPGlassCard(
          isDark: isDark, padding: const EdgeInsets.all(16), borderRadius: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('4.8', 'Rating', Icons.star_rounded, Colors.orange),
              _buildStatItem('92%', 'Attendance', Icons.calendar_today_rounded, Colors.green),
              _buildStatItem('12', 'Batches', Icons.grid_view_rounded, Colors.blue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBatchesTab(bool isDark) {
    final batches = _teacher!['batches'] as List? ?? [];
    if (batches.isEmpty) return _buildEmptyTab('No assigned batches yet', Icons.layers_clear_rounded, isDark);
    
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: batches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => CPGlassCard(
        isDark: isDark, padding: const EdgeInsets.all(16), borderRadius: 16,
        child: Row(
          children: [
            const Icon(Icons.group_rounded, color: Color(0xFF0D1282)),
            const SizedBox(width: 16),
            Text(batches[i]['name'] ?? 'Batch Name', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTab(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (ctx, i) => IntrinsicHeight(
        child: Row(
          children: [
            Column(
              children: [
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFF0DE36), shape: BoxShape.circle)),
                Expanded(child: Container(width: 2, color: Colors.grey.withValues(alpha: 0.3))),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Marked Attendance for Batch B1', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Mar 21, 2026 • 10:30 AM', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('Permissions & Access', isDark),
        const SizedBox(height: 16),
        _buildToggle('Can take Attendance', true, isDark),
        _buildToggle('Can see Student Data', true, isDark),
        _buildToggle('Can manage Fees', false, isDark),
        _buildToggle('Can upload Materials', true, isDark),
        _buildToggle('Can create Exams', false, isDark),
      ],
    );
  }

  Widget _buildProfileField(String label, TextEditingController ctrl, IconData icon, bool isDark, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            enabled: _editMode,
            keyboardType: keyboard,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.deepNavy),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 18, color: const Color(0xFF0D1282)),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CPGlassCard(
        isDark: isDark, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), borderRadius: 12,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            Switch(value: value, onChanged: (v) {}, activeColor: const Color(0xFFF0DE36), activeTrackColor: const Color(0xFF0D1282)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(title.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282), letterSpacing: 1.2));
  }

  Widget _buildStatItem(String val, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(val, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildEmptyTab(String msg, IconData icon, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(msg, style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
