import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/student_repository.dart';

class BatchesPage extends StatefulWidget {
  const BatchesPage({super.key});

  @override
  State<BatchesPage> createState() => _BatchesPageState();
}

class _BatchesPageState extends State<BatchesPage> {
  final _studentRepo = sl<StudentRepository>();
  List<Map<String, dynamic>> _myBatches = [];
  bool _isLoading = true;
  String? _error;

  String _selectedCategory = 'All';
  final _categories = [
    'All',
    'My Batches',
    'JEE',
    'NEET',
    'Foundation',
    'Boards',
  ];

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _studentRepo.getMyBatches();
      setState(() {
        _myBatches = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 18, color: CT.textH(context)),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/student'),
        ),
        title: Text(
          'My Batches',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: CT.textH(context),
          ),
        ),
        backgroundColor: CT.bg(context),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadBatches,
        child: Column(
          children: [
            // Category chips
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final selected = _selectedCategory == cat;
                  return CPPressable(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? CT.accent(context) : CT.card(context),
                        borderRadius: BorderRadius.circular(20),
                        border: selected
                            ? Border.all(
                                color: const Color(0xFF354388),
                                width: 2,
                              )
                            : Border.all(color: CT.border(context)),
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  color: Color(0xFF354388),
                                  offset: Offset(2, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        cat,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : CT.textS(context),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildErrorState()
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    List<Widget> children = [];

    // Filtered My Batches
    if (_selectedCategory == 'All' || _selectedCategory == 'My Batches') {
      if (_myBatches.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Active Enrollments',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: CT.textH(context),
              ),
            ),
          ),
        );
        children.addAll(_myBatches.map((b) => _myBatchCard(context, b)));
      } else {
        children.add(
          Center(
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.auto_awesome_motion_rounded,
                  size: 60,
                  color: CT.textM(context).withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Active Batches',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CT.textS(context),
                  ),
                ),
                Text(
                  'You haven\'t enrolled in any batches yet.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: CT.textM(context),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [...children, const SizedBox(height: 100)],
    );
  }

  Widget _myBatchCard(BuildContext context, Map<String, dynamic> b) {
    final subject = b['subject'] ?? 'Subject';
    final name = b['name'] ?? 'Batch';
    final teacher = b['teacher_name'] ?? 'TBA';
    final time = '${b['start_time'] ?? ''} - ${b['end_time'] ?? ''}';

    final teacherId = b['teacher_id'];
    final isDark = CT.isDark(context);

    return CPPressable(
      onTap: () => context.push('/student/batches/${b['id']}', extra: b),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: CT.cardDecor(context, radius: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mintGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ENROLLED',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mintGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  time,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CT.accent(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$subject: $name',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: CT.textH(context),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CT.accent(context).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 16,
                    color: CT.accent(context),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  teacher,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CT.textS(context),
                  ),
                ),
                const Spacer(),
                if (teacherId != null)
                  TextButton.icon(
                    onPressed: () => _showRateTeacherDialog(teacherId.toString(), teacher),
                    icon: const Icon(Icons.star_outline_rounded, size: 16),
                    label: Text(
                      'Rate',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.moltenAmber,
                      backgroundColor: isDark ? AppColors.moltenAmber.withValues(alpha: 0.1) : AppColors.eliteDarkBg,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.05, end: 0);
  }

  void _showRateTeacherDialog(String teacherId, String teacherName) {
    double rating = 5.0;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: CT.bg(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Rate $teacherName',
            style: GoogleFonts.plusJakartaSans(
              color: CT.textH(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Rating',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: CT.textH(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: rating,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: rating.toStringAsFixed(1),
                      activeColor: const Color(0xFFBDAE18),
                      inactiveColor: CT.textS(context).withValues(alpha: 0.2),
                      onChanged: (value) => setState(() => rating = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                style: GoogleFonts.plusJakartaSans(color: CT.textH(context)),
                decoration: InputDecoration(
                  hintText: 'Add a comment (optional)...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: CT.textM(context), fontSize: 14),
                  filled: true,
                  fillColor: CT.card(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: CT.textS(context))),
            ),
            ElevatedButton(
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  await _studentRepo.addTeacherFeedback(
                    teacherId: teacherId,
                    rating: rating,
                    comment: commentCtrl.text,
                    studentName: 'Student',
                  );
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Thank you for your feedback!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.elitePrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load batches',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              color: CT.textH(context),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadBatches, child: const Text('Retry')),
        ],
      ),
    );
  }
}

