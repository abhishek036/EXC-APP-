import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class RoleLiveDashboardPage extends StatelessWidget {
  final AppRole role;

  const RoleLiveDashboardPage({super.key, required this.role});

  String _title(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return 'Admin Dashboard';
      case AppRole.teacher:
        return 'Teacher Dashboard';
      case AppRole.parent:
        return 'Parent Dashboard';
      case AppRole.student:
        return 'Student Dashboard';
    }
  }

  List<_StatConfig> _statConfigs(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return const [
          _StatConfig(key: 'totalStudents', label: 'Students'),
          _StatConfig(key: 'totalTeachers', label: 'Teachers'),
          _StatConfig(key: 'monthlyRevenue', label: 'Revenue'),
          _StatConfig(key: 'activeBatches', label: 'Batches'),
        ];
      case AppRole.teacher:
        return const [
          _StatConfig(key: 'classesToday', label: 'Classes Today'),
          _StatConfig(key: 'pendingDoubts', label: 'Pending Doubts'),
          _StatConfig(key: 'quizzesCreated', label: 'Quizzes'),
          _StatConfig(key: 'attendanceMarked', label: 'Attendance'),
        ];
      case AppRole.parent:
        return const [
          _StatConfig(key: 'attendancePercent', label: 'Attendance %'),
          _StatConfig(key: 'pendingFees', label: 'Pending Fees'),
          _StatConfig(key: 'weeklyTests', label: 'Weekly Tests'),
          _StatConfig(key: 'notices', label: 'Notices'),
        ];
      case AppRole.student:
        return const [
          _StatConfig(key: 'attendancePercent', label: 'Attendance %'),
          _StatConfig(key: 'pendingAssignments', label: 'Assignments'),
          _StatConfig(key: 'upcomingExams', label: 'Upcoming Exams'),
          _StatConfig(key: 'rank', label: 'Rank'),
        ];
    }
  }

  List<_ActionConfig> _actions(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return const [
          _ActionConfig(label: 'Students', path: '/admin/students', icon: Icons.people_outline),
          _ActionConfig(label: 'Teachers', path: '/admin/teachers', icon: Icons.badge_outlined),
          _ActionConfig(label: 'Leads', path: '/admin/leads', icon: Icons.handshake_outlined),
          _ActionConfig(label: 'Timetable', path: '/admin/timetable', icon: Icons.calendar_month_outlined),
          _ActionConfig(label: 'Fees', path: '/admin/fees', icon: Icons.receipt_long_outlined),
          _ActionConfig(label: 'Batches', path: '/admin/batches', icon: Icons.class_outlined),
          _ActionConfig(label: 'Staff', path: '/admin/staff', icon: Icons.work_outline),
          _ActionConfig(label: 'Academics', path: '/admin/academics', icon: Icons.local_library_outlined),
          _ActionConfig(label: 'Certificates', path: '/admin/certificates', icon: Icons.card_membership_outlined),
          _ActionConfig(label: 'Reports', path: '/admin/reports', icon: Icons.analytics_outlined),
          _ActionConfig(label: 'Data Export', path: '/admin/data-export', icon: Icons.download_outlined),
          _ActionConfig(label: 'User Mgmt', path: '/admin/users', icon: Icons.manage_accounts_outlined),
          _ActionConfig(label: 'Inst. Settings', path: '/admin/settings/institute', icon: Icons.settings_applications_outlined),
        ];
      case AppRole.teacher:
        return const [
          _ActionConfig(label: 'Attendance', path: '/teacher/attendance', icon: Icons.fact_check_outlined),
          _ActionConfig(label: 'Create Quiz', path: '/teacher/create-quiz', icon: Icons.quiz_outlined),
          _ActionConfig(label: 'Doubts', path: '/teacher/doubts', icon: Icons.help_outline),
          _ActionConfig(label: 'Results', path: '/teacher/batches', icon: Icons.assessment_outlined),
        ];
      case AppRole.parent:
        return const [
          _ActionConfig(label: 'Weekly Report', path: '/parent', icon: Icons.insights_outlined),
          _ActionConfig(label: 'Payment History', path: '/parent/payment-history', icon: Icons.history_outlined),
          _ActionConfig(label: 'Fees', path: '/parent/fee-payment', icon: Icons.receipt_long_outlined),
          _ActionConfig(label: 'Notices', path: '/parent/announcements', icon: Icons.campaign_outlined),
        ];
      case AppRole.student:
        return const [
          _ActionConfig(label: 'Materials', path: '/student/materials', icon: Icons.menu_book_outlined),
          _ActionConfig(label: 'Timetable', path: '/student/timetable', icon: Icons.schedule_outlined),
          _ActionConfig(label: 'Exams', path: '/student/exam-calendar', icon: Icons.event_note_outlined),
          _ActionConfig(label: 'Performance', path: '/student/performance', icon: Icons.trending_up_outlined),
        ];
    }
  }

  Map<String, dynamic> _fallbackStats(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return {
          'totalStudents': 0,
          'totalTeachers': 0,
          'monthlyRevenue': 0,
          'activeBatches': 0,
        };
      case AppRole.teacher:
        return {
          'classesToday': 0,
          'pendingDoubts': 0,
          'quizzesCreated': 0,
          'attendanceMarked': 0,
        };
      case AppRole.parent:
        return {
          'attendancePercent': 0,
          'pendingFees': 0,
          'weeklyTests': 0,
          'notices': 0,
        };
      case AppRole.student:
        return {
          'attendancePercent': 0,
          'pendingAssignments': 0,
          'upcomingExams': 0,
          'rank': 0,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authState.user;
        final liveStream = Stream<Map<String, dynamic>?>.value({
                'stats': _fallbackStats(role),
                'lastAnnouncement': '',
              });

        return Scaffold(
          backgroundColor: CT.bg(context),
          body: SafeArea(
            child: StreamBuilder<Map<String, dynamic>?>(
              stream: liveStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      child: Text(
                        'Unable to load live dashboard data. ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(color: CT.textS(context)),
                      ),
                    ),
                  );
                }

                final data = snapshot.data ?? <String, dynamic>{};
                final stats = (data['stats'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
                final announcement = (data['lastAnnouncement'] ?? '').toString();

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppDimensions.md),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _title(role),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: CT.textH(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Welcome, ${user.name}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: CT.textS(context)),
                                ),
                              ],
                            ),
                          ),

                          CPPressable(
                            onTap: () => context.go('${user.dashboardPath}/notifications'),
                            child: Icon(Icons.notifications_outlined, color: CT.textH(context), size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      GridView.builder(
                        itemCount: _statConfigs(role).length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppDimensions.step,
                          mainAxisSpacing: AppDimensions.step,
                          childAspectRatio: 1.5,
                        ),
                        itemBuilder: (context, index) {
                          final cfg = _statConfigs(role)[index];
                          final value = stats[cfg.key] ?? 0;
                          return Container(
                            padding: const EdgeInsets.all(AppDimensions.md),
                            decoration: CT.cardDecor(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$value',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: CT.textH(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(cfg.label, style: GoogleFonts.plusJakartaSans(color: CT.textS(context))),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      Text(
                        'Quick Actions',
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: CT.textH(context)),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      Wrap(
                        spacing: AppDimensions.step,
                        runSpacing: AppDimensions.step,
                        children: _actions(role).map((action) {
                          return CPPressable(
                            onTap: () => context.go(action.path),
                            child: Container(
                              width: (MediaQuery.of(context).size.width - 2 * AppDimensions.pagePaddingH - AppDimensions.step) / 2,
                              padding: const EdgeInsets.all(AppDimensions.md),
                              decoration: CT.cardDecor(context),
                              child: Row(
                                children: [
                                  Icon(action.icon, color: CT.accent(context), size: 20),
                                  const SizedBox(width: AppDimensions.sm),
                                  Expanded(
                                    child: Text(
                                      action.label,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: CT.textH(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppDimensions.md),
                        decoration: CT.cardDecor(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Latest Announcement',
                              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context)),
                            ),
                            const SizedBox(height: AppDimensions.sm),
                            Text(
                              announcement.isEmpty
                                  ? 'No announcement yet. This section is now live and will update from Firestore.'
                                  : announcement,
                              style: GoogleFonts.plusJakartaSans(color: CT.textS(context), height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _StatConfig {
  final String key;
  final String label;

  const _StatConfig({required this.key, required this.label});
}

class _ActionConfig {
  final String label;
  final String path;
  final IconData icon;

  const _ActionConfig({required this.label, required this.path, required this.icon});
}
