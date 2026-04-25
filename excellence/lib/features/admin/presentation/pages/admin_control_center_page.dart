import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/theme/theme_aware.dart';

class AdminControlCenterPage extends StatefulWidget {
  const AdminControlCenterPage({super.key});

  @override
  State<AdminControlCenterPage> createState() =>
      _AdminControlCenterPageState();
}

class _AdminControlCenterPageState extends State<AdminControlCenterPage>
    with ThemeAware<AdminControlCenterPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';

  final List<Map<String, dynamic>> _allFunctions = [
    // User Management Section
    {
      'section': 'USER MANAGEMENT',
      'title': 'Add Student',
      'icon': Icons.person_add_rounded,
      'color': AppColors.mintGreen,
      'route': '/admin/add-student',
      'description': 'Enroll new student',
    },
    {
      'section': 'USER MANAGEMENT',
      'title': 'Student List',
      'icon': Icons.school_rounded,
      'color': AppColors.mintGreen,
      'route': '/admin/students',
      'description': 'View & manage all students',
    },
    {
      'section': 'USER MANAGEMENT',
      'title': 'Add Teacher',
      'icon': Icons.person_add_rounded,
      'color': AppColors.elitePurple,
      'route': '/admin/add-teacher',
      'description': 'Hire new faculty member',
    },
    {
      'section': 'USER MANAGEMENT',
      'title': 'Teacher List',
      'icon': Icons.psychology_rounded,
      'color': AppColors.elitePurple,
      'route': '/admin/teachers',
      'description': 'Manage faculty members',
    },
    {
      'section': 'USER MANAGEMENT',
      'title': 'Staff Management',
      'icon': Icons.badge_rounded,
      'color': AppColors.moltenAmber,
      'route': '/admin/staff',
      'description': 'Manage support staff',
    },
    {
      'section': 'USER MANAGEMENT',
      'title': 'User Management',
      'icon': Icons.groups_rounded,
      'color': AppColors.coralRed,
      'route': '/admin/users',
      'description': 'Control user access & roles',
    },

    // Batch Management Section
    {
      'section': 'BATCH MANAGEMENT',
      'title': 'Batch Management',
      'icon': Icons.class_rounded,
      'color': AppColors.elitePrimary,
      'route': '/admin/batches',
      'description': 'Create & manage batches',
    },
    {
      'section': 'BATCH MANAGEMENT',
      'title': 'Timetable',
      'icon': Icons.calendar_month_rounded,
      'color': AppColors.elitePrimary,
      'route': '/admin/timetable',
      'description': 'Schedule batch timings',
    },
    {
      'section': 'BATCH MANAGEMENT',
      'title': 'Attendance Overview',
      'icon': Icons.check_circle_rounded,
      'color': AppColors.elitePrimary,
      'route': '/admin/attendance',
      'description': 'Track attendance records',
    },

    // Academic Management Section
    {
      'section': 'ACADEMIC MANAGEMENT',
      'title': 'Exam Management',
      'icon': Icons.assignment_rounded,
      'color': AppColors.deepNavy,
      'route': '/admin/exams',
      'description': 'Create & conduct exams',
    },
    {
      'section': 'ACADEMIC MANAGEMENT',
      'title': 'Bulk Result Entry',
      'icon': Icons.table_chart_rounded,
      'color': AppColors.deepNavy,
      'route': '/admin/exams/bulk-results',
      'description': 'Upload multiple results',
    },
    {
      'section': 'ACADEMIC MANAGEMENT',
      'title': 'Academic Oversight',
      'icon': Icons.auto_stories_rounded,
      'color': AppColors.deepNavy,
      'route': '/admin/academics',
      'description': 'Manage doubts & materials',
    },

    // Finance Management Section
    {
      'section': 'FINANCE MANAGEMENT',
      'title': 'Fee Collection',
      'icon': Icons.receipt_long_rounded,
      'color': AppColors.coralRed,
      'route': '/admin/fees',
      'description': 'Manage fee payments',
    },
    {
      'section': 'FINANCE MANAGEMENT',
      'title': 'Fee Verification',
      'icon': Icons.fact_check_rounded,
      'color': AppColors.coralRed,
      'route': '/admin/fee-payment',
      'description': 'Verify payment proofs',
    },

    // Leads & Operations Section
    {
      'section': 'LEADS & OPERATIONS',
      'title': 'Leads Management',
      'icon': Icons.person_search_rounded,
      'color': AppColors.elitePurple,
      'route': '/admin/leads',
      'description': 'Convert prospects to students',
    },
    {
      'section': 'LEADS & OPERATIONS',
      'title': 'Announcements',
      'icon': Icons.campaign_rounded,
      'color': AppColors.moltenAmber,
      'route': '/admin/announcements',
      'description': 'Broadcast messages to users',
    },
    {
      'section': 'LEADS & OPERATIONS',
      'title': 'Auto Notifications',
      'icon': Icons.notifications_rounded,
      'color': AppColors.moltenAmber,
      'route': '/admin/auto-notifications',
      'description': 'Setup automated alerts',
    },

    // Certificates & Credentials Section
    {
      'section': 'CERTIFICATES & CREDENTIALS',
      'title': 'Certificate Generator',
      'icon': Icons.card_giftcard_rounded,
      'color': AppColors.elitePrimary,
      'route': '/admin/certificates',
      'description': 'Generate & issue certificates',
    },

    // Reports & Analytics Section
    {
      'section': 'REPORTS & ANALYTICS',
      'title': 'Analytics Engine',
      'icon': Icons.bar_chart_rounded,
      'color': AppColors.elitePurple,
      'route': '/admin/reports',
      'description': 'View comprehensive reports',
    },
    {
      'section': 'REPORTS & ANALYTICS',
      'title': 'Audit Logs',
      'icon': Icons.history_rounded,
      'color': AppColors.elitePurple,
      'route': '/admin/audit-logs',
      'description': 'Track system activity',
    },
    {
      'section': 'REPORTS & ANALYTICS',
      'title': 'Data Export',
      'icon': Icons.download_rounded,
      'color': AppColors.elitePurple,
      'route': '/admin/data-export',
      'description': 'Export data for analysis',
    },

    // Settings & Configuration Section
    {
      'section': 'SETTINGS & CONFIGURATION',
      'title': 'Institute Settings',
      'icon': Icons.settings_rounded,
      'color': AppColors.deepNavy,
      'route': '/admin/settings',
      'description': 'Configure institute details',
    },
    {
      'section': 'SETTINGS & CONFIGURATION',
      'title': 'Notifications',
      'icon': Icons.notifications_rounded,
      'color': AppColors.deepNavy,
      'route': '/admin/notifications',
      'description': 'Manage notification settings',
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin');
    }
  }

  List<String> _getSections() {
    final sections = <String>[];
    for (final func in _allFunctions) {
      final section = func['section'] as String;
      if (!sections.contains(section)) {
        sections.add(section);
      }
    }
    return sections;
  }

  List<Map<String, dynamic>> _getFilteredFunctions(String section) {
    return _allFunctions.where((f) {
      final inSection = f['section'] == section;
      if (_query.isEmpty) return inSection;
      final q = _query.toLowerCase();
      final title = (f['title'] ?? '').toString().toLowerCase();
      final desc = (f['description'] ?? '').toString().toLowerCase();
      return inSection && (title.contains(q) || desc.contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    final sections = _getSections();
    final visibleFunctions = sections.fold<int>(
      0,
      (total, section) => total + _getFilteredFunctions(section).length,
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.elitePrimary,
          backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
          onRefresh: _refreshPage,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 12),
                Text(
                  'Same dashboard language, more admin tools.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.paleSlate2 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 18),
                _searchBar(isDark),
                const SizedBox(height: 18),
                _buildSummaryRow(
                  isDark,
                  sections.length,
                  _allFunctions.length,
                  visibleFunctions,
                ),
                const SizedBox(height: 26),
                if (visibleFunctions == 0)
                  _buildEmptyState(isDark)
                else ...[
                  ...sections.expand((section) {
                    final functions = _getFilteredFunctions(section);
                    if (functions.isEmpty) return const <Widget>[];
                    return <Widget>[
                      _buildSectionBlock(section, functions, isDark),
                      const SizedBox(height: 24),
                    ];
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshPage() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {});
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        CPPressable(
          onTap: _handleBack,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppColors.eliteDarkBg : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.elitePrimary, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.elitePrimary,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppColors.elitePrimary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMIN CONTROL CENTER',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                  letterSpacing: -0.7,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Everything the admin panel can do, grouped the same way as teacher and student dashboards.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.paleSlate2 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.moltenAmber.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.elitePrimary, width: 2),
          ),
          child: Text(
            '${_allFunctions.length} TOOLS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.elitePrimary,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    bool isDark,
    int sectionCount,
    int functionCount,
    int visibleCount,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _metricCard(
          'SECTIONS',
          '$sectionCount',
          Icons.dashboard_customize_rounded,
          AppColors.elitePrimary,
          isDark,
        ),
        _metricCard(
          'FEATURES',
          '$functionCount',
          Icons.grid_view_rounded,
          AppColors.moltenAmber,
          isDark,
        ),
        _metricCard(
          'VISIBLE',
          '$visibleCount',
          Icons.search_rounded,
          AppColors.coralRed,
          isDark,
        ),
      ],
    );
  }

  Widget _metricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.eliteDarkBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.elitePrimary, width: 2),
          boxShadow: const [
            BoxShadow(color: AppColors.elitePrimary, offset: Offset(3, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.paleSlate2 : AppColors.deepNavy.withValues(alpha: 0.7),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.eliteDarkBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.elitePrimary, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.elitePrimary, offset: Offset(3, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 42,
            color: AppColors.elitePrimary.withValues(alpha: 0.75),
          ),
          const SizedBox(height: 12),
          Text(
            'No admin tools match your search',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Clear the search box to see the full admin command center.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.paleSlate2 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionBlock(
    String section,
    List<Map<String, dynamic>> functions,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(section, functions.length, isDark),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 680 ? 2 : 1;
            final aspectRatio = crossAxisCount == 2 ? 2.3 : 4.6;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: functions.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: aspectRatio,
              ),
              itemBuilder: (context, index) {
                final func = functions[index];
                return _FunctionCard(
                  function: func,
                  blue: AppColors.elitePrimary,
                  yellow: AppColors.moltenAmber,
                  white: isDark ? AppColors.eliteDarkBg : Colors.white,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
              letterSpacing: 1.1,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.moltenAmber.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.elitePrimary, width: 1.5),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.elitePrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.eliteDarkBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elitePrimary, width: 2.5),
        boxShadow: const [
          BoxShadow(color: AppColors.elitePrimary, offset: Offset(3, 3)),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
        ),
        decoration: InputDecoration(
          hintText: 'Search functions',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AppColors.elitePrimary.withValues(alpha: 0.45),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.elitePrimary.withValues(alpha: 0.7),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
        ),
      ),
    );
  }
}

class _FunctionCard extends StatelessWidget {
  final Map<String, dynamic> function;
  final Color blue;
  final Color yellow;
  final Color white;

  const _FunctionCard({
    required this.function,
    required this.blue,
    required this.yellow,
    required this.white,
  });

  @override
  Widget build(BuildContext context) {
    final title = (function['title'] ?? 'Function').toString().toUpperCase();
    final description = function['description'] ?? '';
    final route = (function['route'] ?? '').toString();
    final icon = function['icon'] as IconData? ?? Icons.apps_rounded;
    final color = function['color'] as Color? ?? blue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: CPPressable(
        onTap: () {
          if (route.isNotEmpty) {
            context.go(route);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: white,
            border: Border.all(color: blue, width: 2.5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: AppColors.elitePrimary, offset: Offset(3, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: blue.withValues(alpha: 0.55),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: blue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.3,
                  color: blue.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }
}
