import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_shimmer.dart';

class AcademicOversightPage extends StatefulWidget {
  const AcademicOversightPage({super.key});

  @override
  State<AcademicOversightPage> createState() => _AcademicOversightPageState();
}

class _AcademicOversightPageState extends State<AcademicOversightPage> {
  final _adminRepo = sl<AdminRepository>();
  int _tabIndex = 0; // 0: Pending Doubts, 1: Uploaded Materials
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _doubts = [];
  List<Map<String, dynamic>> _materials = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final results = await Future.wait([
        _adminRepo.getDoubts(status: 'pending'),
        _adminRepo.getMaterials(),
      ]);

      if (!mounted) return;
      setState(() {
        _doubts = results[0];
        _materials = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Oversight sync failed';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(isDark),
                const SizedBox(height: 12),
                _buildTabs(isDark),
                const SizedBox(height: 20),
                Expanded(
                  child: _loading
                      ? ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: 5,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) => const CPShimmer(
                            width: double.infinity,
                            height: 120,
                            borderRadius: 24,
                          ),
                        )
                      : _error.isNotEmpty
                      ? _buildErrorState(isDark)
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppColors.elitePrimary,
                          child: _tabIndex == 0
                              ? _buildDoubtsList(isDark)
                              : _buildMaterialsList(isDark),
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

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          CPPressable(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? Colors.white : AppColors.deepNavy,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Academic Oversight',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.deepNavy,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadData,
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDED),
        border: Border.all(color: const Color(0xFF0D1282), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF0D1282), offset: Offset(3, 3)),
        ],
      ),
      child: Row(
        children: [
          _tabItem('Pending Doubts', 0, isDark),
          _tabItem('Materials', 1, isDark),
        ],
      ),
    );
  }

  Widget _tabItem(String title, int idx, bool isDark) {
    final active = _tabIndex == idx;
    return Expanded(
      child: CPPressable(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _tabIndex = idx);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF0DE36) : const Color(0xFFEEEDED),
            border: active
                ? Border.all(color: const Color(0xFF0D1282), width: 2)
                : Border.all(color: Colors.transparent, width: 2),
            boxShadow: active
                ? const [
                    BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2)),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D1282),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoubtsList(bool isDark) {
    if (_doubts.isEmpty) {
      return _emptyState(
        'All clear! No pending doubts.',
        Icons.auto_awesome_rounded,
        isDark,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _doubts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (ctx, i) {
        final doubt = _doubts[i];
        final student = doubt['student'] as Map<String, dynamic>?;
        final subject = (doubt['subject'] ?? 'Doubt').toString();

        return CPGlassCard(
          isDark: isDark,
          padding: const EdgeInsets.all(20),
          borderRadius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEDED),
                      border: Border.all(color: AppColors.coralRed, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.coralRed,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'PENDING',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0D1282),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    subject,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                (doubt['question_text'] ??
                        doubt['question'] ??
                        'No question text')
                    .toString(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0D1282),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.elitePrimary.withValues(
                      alpha: 0.1,
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: AppColors.elitePrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Raised by ${(student?['name'] ?? doubt['studentName'] ?? 'Pupil')}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white24 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }

  Widget _buildMaterialsList(bool isDark) {
    if (_materials.isEmpty) {
      return _emptyState(
        'No educational resources yet.',
        Icons.library_books_rounded,
        isDark,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _materials.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final mat = _materials[i];
        final title = (mat['title'] ?? 'Document').toString();
        final teacher = (mat['teacher_name'] ?? mat['teacherName'] ?? 'Faculty')
            .toString();
        final batch = (mat['batch_name'] ?? mat['batchName'] ?? 'Academy')
            .toString();

        return CPGlassCard(
          isDark: isDark,
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEDED),
                  border: Border.all(color: const Color(0xFF0D1282), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2)),
                  ],
                ),
                child: const Icon(
                  Icons.article_rounded,
                  color: Color(0xFF0D1282),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D1282),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By $teacher • $batch',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0D1282),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF0D1282)),
            ],
          ),
        ).animate(delay: (i * 50).ms).fadeIn().slideX(begin: 0.05);
      },
    );
  }

  Widget _emptyState(String msg, IconData icon, bool isDark) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.03),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 40,
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          msg,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white24
                : Colors.black.withValues(alpha: 0.26),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _buildErrorState(bool isDark) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 40,
          color: AppColors.error.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        Text(
          _error,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        CPPressable(
          onTap: _loadData,
          child: Text(
            'Retry Sync',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: AppColors.elitePrimary,
            ),
          ),
        ),
      ],
    ),
  );
}
