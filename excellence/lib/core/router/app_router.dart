import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/admin/presentation/pages/student_list_page.dart';
import '../../features/admin/presentation/pages/student_profile_page.dart';
import '../../features/admin/presentation/pages/batch_management_page.dart';
import '../../features/admin/presentation/pages/fee_collection_page.dart';
import '../../features/admin/presentation/pages/announcements_page.dart';
import '../../features/admin/presentation/pages/attendance_overview_page.dart';
import '../../features/admin/presentation/pages/exam_management_page.dart';
import '../../features/admin/presentation/pages/admin_reports_page.dart';
import '../../features/admin/presentation/pages/add_student_page.dart';
import '../../features/admin/presentation/pages/student_import_page.dart';
import '../../features/teacher/presentation/pages/upload_material_page.dart';
import '../../features/teacher/presentation/pages/create_quiz_page.dart';
import '../../features/teacher/presentation/pages/attendance_marking_page.dart';
import '../../features/teacher/presentation/pages/assignment_review_page.dart';
import '../../features/teacher/presentation/pages/quiz_results_page.dart';
import '../../features/teacher/presentation/pages/youtube_broadcast_page.dart';
import '../../features/teacher/presentation/pages/pending_doubts_page.dart';
import '../../features/teacher/presentation/pages/doubt_response_page.dart';
import '../../features/student/presentation/pages/quiz_taking_page.dart';
import '../../features/student/presentation/pages/quiz_result_page.dart';
import '../../features/student/presentation/pages/quizzes_list_page.dart';
import '../../features/student/presentation/pages/exam_results_page.dart';
import '../../features/student/presentation/pages/syllabus_tracker_page.dart';
import '../../features/student/presentation/pages/study_materials_page.dart';
import '../../features/student/presentation/pages/ask_doubt_page.dart';
import '../../features/student/presentation/pages/assignment_submission_page.dart';
import '../../features/student/presentation/pages/performance_dashboard_page.dart';
import '../../features/student/presentation/pages/timetable_page.dart';
import '../../features/student/presentation/pages/fee_history_page.dart';
import '../../features/student/presentation/pages/exam_calendar_page.dart';
import '../../features/student/presentation/pages/batches_page.dart';
import '../../features/student/presentation/pages/student_batch_panel_page.dart';
import '../../features/parent/presentation/pages/weekly_report_page.dart';
import '../../features/parent/presentation/pages/payment_history_page.dart';
import '../../features/parent/presentation/pages/parent_doubts_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/chat/presentation/pages/chat_list_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/legal_document_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/shared/presentation/pages/live_session_page.dart';
import '../../features/shared/presentation/pages/notifications_page.dart';
import '../../features/shared/presentation/pages/video_player_page.dart';
import '../../features/shared/presentation/pages/fee_payment_page.dart';
import '../../features/shared/presentation/pages/force_update_page.dart';
import '../../features/gamification/presentation/pages/leaderboard_page.dart';
import '../../features/video_lectures/presentation/pages/video_lectures_page.dart';
import '../../features/whatsapp/presentation/pages/whatsapp_broadcast_page.dart';
import '../../features/shared/presentation/pages/notification_settings_page.dart';
import '../../features/shared/presentation/pages/language_selection_page.dart';
import '../../features/admin/presentation/pages/audit_logs_page.dart';
import '../../features/admin/presentation/pages/data_export_page.dart';
import '../../features/admin/presentation/pages/bulk_result_entry_page.dart';
import '../../features/student/presentation/pages/my_doubts_history_page.dart';
// YoutubePlayerPage removed — unified into VideoPlayerPage
import '../../features/admin/presentation/pages/automated_notifications_page.dart';
import '../../features/admin/presentation/pages/teacher_list_page.dart';
import '../../features/admin/presentation/pages/teacher_profile_page.dart';
import '../../features/admin/presentation/pages/add_teacher_page.dart';
import '../../features/admin/presentation/pages/leads_page.dart';
import '../../features/admin/presentation/pages/timetable_management_page.dart';
import '../../features/admin/presentation/pages/institute_settings_page.dart';
import '../../features/admin/presentation/pages/academic_oversight_page.dart';
import '../../features/admin/presentation/pages/staff_management_page.dart';
import '../../features/admin/presentation/pages/certificate_generator_page.dart';
import '../../features/admin/presentation/pages/admin_control_center_page.dart';
import '../../features/auth/presentation/pages/profile_completion_page.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';
import '../../features/admin/presentation/pages/user_management_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/teacher/presentation/pages/teacher_dashboard_page.dart';
import '../../features/student/presentation/pages/student_dashboard_page.dart';
import '../../features/parent/presentation/pages/parent_dashboard_page.dart';
import '../../features/admin/presentation/pages/edit_student_page.dart';
import '../../features/admin/presentation/pages/edit_teacher_page.dart';
import '../../features/admin/presentation/pages/batch_detail_page.dart';
import '../../features/teacher/presentation/pages/teacher_batches_page.dart';
import '../../features/teacher/presentation/pages/teacher_batch_panel_page.dart';
import '../../features/teacher/presentation/pages/teacher_schedule_page.dart';
import '../widgets/cp_bottom_nav.dart';
import '../widgets/cp_role_shell.dart';

class AppRouter {
  AppRouter._();

  // ── Root navigator key ───────────────────────────────────────────
  static final _rootKey = GlobalKey<NavigatorState>(
    debugLabel: 'rootNavigator',
  );

  // ── Admin branch navigator keys ──────────────────────────────────
  static final _adm0 = GlobalKey<NavigatorState>(debugLabel: 'adm0');
  static final _adm1 = GlobalKey<NavigatorState>(debugLabel: 'adm1');
  static final _adm2 = GlobalKey<NavigatorState>(debugLabel: 'adm2');
  static final _adm3 = GlobalKey<NavigatorState>(debugLabel: 'adm3');
  static final _adm4 = GlobalKey<NavigatorState>(debugLabel: 'adm4');

  // ── Teacher branch navigator keys ────────────────────────────────
  static final _tch0 = GlobalKey<NavigatorState>(debugLabel: 'tch0');
  static final _tch1 = GlobalKey<NavigatorState>(debugLabel: 'tch1');
  static final _tch2 = GlobalKey<NavigatorState>(debugLabel: 'tch2');
  static final _tch3 = GlobalKey<NavigatorState>(debugLabel: 'tch3');
  static final _tch4 = GlobalKey<NavigatorState>(debugLabel: 'tch4');

  // ── Student branch navigator keys ────────────────────────────────
  static final _stu0 = GlobalKey<NavigatorState>(debugLabel: 'stu0');
  static final _stu1 = GlobalKey<NavigatorState>(debugLabel: 'stu1');
  static final _stu2 = GlobalKey<NavigatorState>(debugLabel: 'stu2');
  static final _stu3 = GlobalKey<NavigatorState>(debugLabel: 'stu3');
  static final _stu4 = GlobalKey<NavigatorState>(debugLabel: 'stu4');

  // ── Parent branch navigator keys ─────────────────────────────────
  static final _par0 = GlobalKey<NavigatorState>(debugLabel: 'par0');
  static final _par1 = GlobalKey<NavigatorState>(debugLabel: 'par1');
  static final _par2 = GlobalKey<NavigatorState>(debugLabel: 'par2');
  static final _par3 = GlobalKey<NavigatorState>(debugLabel: 'par3');

  // ── Path sets for redirect logic ─────────────────────────────────
  static const _publicPaths = <String>{
    '/splash',
    '/login',
    '/otp',
    '/forgot-password',
    '/terms-of-service',
    '/privacy-policy',
    '/update',
    '/profile-completion', // New users complete profile after first OTP
  };

  static const _authenticatedUtilityPaths = <String>{
    '/change-password',
  };

  static const _rolePrefixes = <AppRole, List<String>>{
    AppRole.admin: ['/admin'],
    AppRole.teacher: ['/teacher'],
    AppRole.student: ['/student'],
    AppRole.parent: ['/parent'],
  };

  // ── Smooth fade + micro-slide page builder ────────────────────────
  static Page<void> _page(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final slide =
            Tween<Offset>(
              begin: const Offset(0.04, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }

  // ── Router factory ────────────────────────────────────────────────
  static GoRouter router(AuthBloc authBloc) => GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: _AuthNotifier(authBloc),
    errorPageBuilder: (context, state) => _page(
      state,
      Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/login');
                    }
                  },
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF354388),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Page not found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF354388),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Route: ${state.uri}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.black54),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF354388),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Go to Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = authBloc.state;
      final location = state.matchedLocation;
      final uri = state.uri;

      // 1. Initial/Loading: Save where we wanted to go
      if (authState is AuthInitial || authState is AuthLoading) {
        if (_publicPaths.contains(location)) return null;
        // Prevent splash recursion
        if (location == '/splash') return null;
        // Append target location to splash
        return '/splash?from=${Uri.encodeComponent(uri.toString())}';
      }

      final isPublic = _publicPaths.contains(location);

      // 2. OTP flow: Stay on public auth pages
      if (authState is AuthOtpSent) {
        return isPublic ? null : '/login';
      }

      // 3. Unauthenticated: Redirect to onboarding/login
      if (authState is AuthUnauthenticated || authState is AuthError) {
        if (location == '/splash') return '/login';
        return isPublic ? null : '/login';
      }

      // 4. Authenticated: Respect deep links if on splash
      if (authState is AuthAuthenticated) {
        // Restore deep link or go to dashboard
        if (location == '/splash' || location == '/login') {
          final from = uri.queryParameters['from'];
          if (from != null && from.isNotEmpty) {
            return Uri.decodeComponent(from);
          }
          return authState.user.dashboardPath;
        }

        if (_publicPaths.contains(location) ||
            _authenticatedUtilityPaths.contains(location)) {
          return null;
        }

        final allowed = _rolePrefixes[authState.user.role] ?? [];
        final hasAccess = allowed.any((prefix) => location.startsWith(prefix));
        if (!hasAccess) return authState.user.dashboardPath;
      }

      // 5. New user: Force profile completion
      if (authState is AuthNewUser) {
        if (location == '/profile-completion') return null;
        return '/profile-completion';
      }

      return null;
    },
    routes: [
      // ── Redirect root to splash ───────────────────────────────
      GoRoute(path: '/', redirect: (_, _) => '/splash'),
      // ── Public / Auth routes ─────────────────────────────────
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (c, s) => _page(s, const SplashPage()),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (c, s) => _page(s, const LoginPage()),
      ),
      GoRoute(
        path: '/register',
        redirect: (c, s) => '/login',
      ),
      GoRoute(
        path: '/otp',
        name: 'otp',
        pageBuilder: (c, s) {
          String? phone;
          String? infoMessage;
          String? debugOtp;
          final extra = s.extra;

          if (extra is OtpRouteArgs) {
            phone = extra.phoneNumber;
            infoMessage = extra.infoMessage;
            debugOtp = extra.debugOtp;
          } else if (extra is String) {
            phone = extra;
          }

          return _page(
            s,
            OtpPage(
              phoneNumber: phone,
              infoMessage: infoMessage,
              debugOtp: debugOtp,
            ),
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        pageBuilder: (c, s) => _page(s, const ForgotPasswordPage()),
      ),
      GoRoute(
        path: '/profile-completion',
        name: 'profile-completion',
        pageBuilder: (c, s) => _page(s, const ProfileCompletionPage()),
      ),
      GoRoute(
        path: '/change-password',
        name: 'change-password',
        pageBuilder: (c, s) => _page(s, const ChangePasswordPage()),
      ),
      GoRoute(
        path: '/terms-of-service',
        name: 'terms-of-service',
        pageBuilder: (c, s) => _page(
          s,
          const LegalDocumentPage(
            title: 'Terms of Service',
            content: LegalDocumentTexts.termsOfService,
          ),
        ),
      ),
      GoRoute(
        path: '/privacy-policy',
        name: 'privacy-policy',
        pageBuilder: (c, s) => _page(
          s,
          const LegalDocumentPage(
            title: 'Privacy Policy',
            content: LegalDocumentTexts.privacyPolicy,
          ),
        ),
      ),
      GoRoute(
        path: '/update',
        name: 'force-update',
        pageBuilder: (c, s) => _page(
          s,
          ForceUpdatePage(
            latestVersion: s.uri.queryParameters['latest'] ?? '',
            minSupportedVersion: s.uri.queryParameters['min'] ?? '',
            storeUrl: s.uri.queryParameters['storeUrl'] ?? '',
          ),
        ),
      ),

      // ── Admin Shell ─────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (context, state, shell) => CPRoleShell(
          navigationShell: shell,
          items: const [
            CPBottomNavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              label: 'Home',
            ),
            CPBottomNavItem(
              icon: Icons.class_outlined,
              activeIcon: Icons.class_,
              label: 'Batches',
            ),
            CPBottomNavItem(
              icon: Icons.people_outline,
              activeIcon: Icons.people,
              label: 'Students',
            ),
            CPBottomNavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long,
              label: 'Fees',
            ),
            CPBottomNavItem(
              icon: Icons.more_horiz,
              activeIcon: Icons.more_horiz,
              label: 'More',
            ),
          ],
        ),
        branches: [
          // Branch 0 — Home
          StatefulShellBranch(
            navigatorKey: _adm0,
            routes: [
              GoRoute(
                path: '/admin',
                name: 'admin-dashboard',
                pageBuilder: (c, s) => _page(s, const AdminDashboardPage()),
                routes: [
                  GoRoute(
                    path: 'attendance',
                    name: 'admin-attendance',
                    pageBuilder: (c, s) =>
                        _page(s, const AttendanceOverviewPage()),
                  ),
                  GoRoute(
                    path: 'exams',
                    name: 'admin-exams',
                    pageBuilder: (c, s) => _page(s, const ExamManagementPage()),
                    routes: [
                      GoRoute(
                        path: 'bulk-results',
                        name: 'admin-bulk-results',
                        pageBuilder: (c, s) => _page(
                          s,
                          BulkResultEntryPage(
                            exam: (s.extra as Map<String, dynamic>?) ?? const {},
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'reports',
                    name: 'admin-reports',
                    pageBuilder: (c, s) => _page(s, const AdminReportsPage()),
                  ),
                  GoRoute(
                    path: 'add-student',
                    name: 'admin-add-student',
                    pageBuilder: (c, s) => _page(s, const AddStudentPage()),
                  ),
                  GoRoute(
                    path: 'student-import',
                    name: 'admin-student-import',
                    pageBuilder: (c, s) => _page(s, const StudentImportPage()),
                  ),
                  GoRoute(
                    path: 'announcements',
                    name: 'admin-announcements',
                    pageBuilder: (c, s) => _page(s, const AnnouncementsPage()),
                  ),
                  GoRoute(
                    path: 'notifications',
                    name: 'admin-notifications',
                    pageBuilder: (c, s) => _page(s, const NotificationsPage()),
                  ),
                  GoRoute(
                    path: 'profile',
                    name: 'admin-profile',
                    pageBuilder: (c, s) => _page(
                      s,
                      ProfilePage(
                        edit: s.uri.queryParameters['edit'] == 'true',
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'chat-list',
                    name: 'admin-chat-list',
                    pageBuilder: (c, s) => _page(s, const ChatListPage()),
                    routes: [
                      GoRoute(
                        path: 'chat/:id',
                        name: 'admin-chat',
                        pageBuilder: (c, s) => _page(
                          s,
                          ChatPage(batchId: s.pathParameters['id'] ?? ''),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'live-session',
                    name: 'admin-live-session',
                    pageBuilder: (c, s) => _page(s, const LiveSessionPage()),
                  ),
                  GoRoute(
                    path: 'video-player',
                    name: 'admin-video-player',
                    pageBuilder: (c, s) {
                      final args = s.extra as Map<String, dynamic>? ?? {};
                      return _page(
                        s,
                        VideoPlayerPage(
                          videoUrl: args['videoUrl'] ?? args['videoId'],
                          title: args['title'],
                          lectureId: args['lectureId'],
                          summary: args['summary']?.toString(),
                          teacherName: args['teacherName']?.toString(),
                          subject: args['subject']?.toString(),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'fee-payment',
                    name: 'admin-fee-payment',
                    pageBuilder: (c, s) => _page(s, const FeePaymentPage()),
                    routes: [
                      GoRoute(
                        path: ':recordId',
                        name: 'admin-fee-payment-with-id',
                        pageBuilder: (c, s) => _page(
                          s,
                          FeePaymentPage(
                            recordId: s.pathParameters['recordId'],
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'whatsapp-broadcast',
                    name: 'admin-whatsapp',
                    pageBuilder: (c, s) =>
                        _page(s, const WhatsAppBroadcastPage()),
                  ),
                  GoRoute(
                    path: 'data-export',
                    name: 'admin-data-export',
                    pageBuilder: (c, s) => _page(s, const DataExportPage()),
                  ),
                  GoRoute(
                    path: 'auto-notifications',
                    name: 'admin-auto-notifications',
                    pageBuilder: (c, s) =>
                        _page(s, const AutomatedNotificationsPage()),
                  ),
                  GoRoute(
                    path: 'notification-settings',
                    name: 'admin-notification-settings',
                    pageBuilder: (c, s) =>
                        _page(s, const NotificationSettingsPage()),
                  ),
                  GoRoute(
                    path: 'language',
                    name: 'admin-language',
                    pageBuilder: (c, s) =>
                        _page(s, const LanguageSelectionPage()),
                  ),
                  GoRoute(
                    path: 'teachers',
                    name: 'admin-teachers',
                    pageBuilder: (c, s) => _page(s, const TeacherListPage()),
                    routes: [
                      GoRoute(
                        path: 'add',
                        name: 'admin-add-teacher',
                        pageBuilder: (c, s) => _page(s, const AddTeacherPage()),
                      ),
                      GoRoute(
                        path: ':id',
                        name: 'admin-teacher-profile',
                        pageBuilder: (c, s) => _page(
                          s,
                          TeacherProfilePage(
                            teacherId: s.pathParameters['id'] ?? '',
                          ),
                        ),
                      ),
                      GoRoute(
                        path: ':id/edit',
                        name: 'admin-edit-teacher',
                        pageBuilder: (c, s) => _page(
                          s,
                          EditTeacherPage(
                            teacherId: s.pathParameters['id'] ?? '',
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'leads',
                    name: 'admin-leads',
                    pageBuilder: (c, s) => _page(s, const LeadsPage()),
                  ),
                  GoRoute(
                    path: 'timetable',
                    name: 'admin-timetable',
                    pageBuilder: (c, s) =>
                        _page(s, const TimetableManagementPage()),
                  ),
                  GoRoute(
                    path: 'academics',
                    name: 'admin-academics',
                    pageBuilder: (c, s) =>
                        _page(s, const AcademicOversightPage()),
                  ),
                  GoRoute(
                    path: 'staff',
                    name: 'admin-staff',
                    pageBuilder: (c, s) =>
                        _page(s, const StaffManagementPage()),
                  ),
                  GoRoute(
                    path: 'certificates',
                    name: 'admin-certificates',
                    pageBuilder: (c, s) =>
                        _page(s, const CertificateGeneratorPage()),
                  ),
                  GoRoute(
                    path: 'users',
                    name: 'admin-users',
                    pageBuilder: (c, s) => _page(s, const UserManagementPage()),
                  ),
                  GoRoute(
                    path: 'audit-logs',
                    name: 'admin-audit-logs',
                    pageBuilder: (c, s) => _page(s, const AuditLogsPage()),
                  ),
                ],
              ),
            ],
          ),
          // Branch 1 — Batches
          StatefulShellBranch(
            navigatorKey: _adm1,
            routes: [
              GoRoute(
                path: '/admin/batches',
                name: 'batch-management',
                pageBuilder: (c, s) => _page(s, const BatchManagementPage()),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'admin-batch-detail',
                    pageBuilder: (c, s) => _page(
                      s,
                      BatchDetailPage(batchId: s.pathParameters['id'] ?? ''),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/admin/all-functions',
                name: 'admin-control-center',
                pageBuilder: (c, s) => _page(s, const AdminControlCenterPage()),
              ),
            ],
          ),
          // Branch 2 — Students
          StatefulShellBranch(
            navigatorKey: _adm2,
            routes: [
              GoRoute(
                path: '/admin/students',
                name: 'student-list',
                pageBuilder: (c, s) => _page(s, const StudentListPage()),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'student-profile',
                    pageBuilder: (c, s) => _page(
                      s,
                      StudentProfilePage(
                        studentId: s.pathParameters['id'] ?? '',
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':id/edit',
                    name: 'admin-edit-student',
                    pageBuilder: (c, s) => _page(
                      s,
                      EditStudentPage(studentId: s.pathParameters['id'] ?? ''),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 3 — Fees
          StatefulShellBranch(
            navigatorKey: _adm3,
            routes: [
              GoRoute(
                path: '/admin/fees',
                name: 'fee-collection',
                pageBuilder: (c, s) => _page(s, const FeeCollectionPage()),
              ),
            ],
          ),
          // Branch 4 — More / Settings
          StatefulShellBranch(
            navigatorKey: _adm4,
            routes: [
              GoRoute(
                path: '/admin/settings',
                name: 'admin-settings',
                pageBuilder: (c, s) => _page(s, const SettingsPage()),
                routes: [
                  GoRoute(
                    path: 'institute',
                    name: 'admin-institute-settings',
                    pageBuilder: (c, s) =>
                        _page(s, const InstituteSettingsPage()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── Teacher Shell ───────────────────────────────────────
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (context, state, shell) => CPRoleShell(
          navigationShell: shell,
          items: const [
            CPBottomNavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              label: 'Home',
            ),
            CPBottomNavItem(
              icon: Icons.class_outlined,
              activeIcon: Icons.class_,
              label: 'My Batches',
            ),
            CPBottomNavItem(
              icon: Icons.help_outline,
              activeIcon: Icons.help,
              label: 'Doubts',
            ),
            CPBottomNavItem(
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month,
              label: 'Schedule',
            ),
            CPBottomNavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'More',
            ),
          ],
        ),
        branches: [
          // Branch 0 — Home
          StatefulShellBranch(
            navigatorKey: _tch0,
            routes: [
              GoRoute(
                path: '/teacher',
                name: 'teacher-dashboard',
                pageBuilder: (c, s) => _page(s, const TeacherDashboardPage()),
                routes: [
                  GoRoute(
                    path: 'attendance',
                    name: 'teacher-attendance',
                    pageBuilder: (c, s) =>
                        _page(s, const AttendanceMarkingPage()),
                  ),
                  GoRoute(
                    path: 'upload-material',
                    name: 'upload-material',
                    pageBuilder: (c, s) => _page(s, const UploadMaterialPage()),
                  ),
                  GoRoute(
                    path: 'create-quiz',
                    name: 'create-quiz',
                    pageBuilder: (c, s) => _page(s, const CreateQuizPage()),
                  ),
                  GoRoute(
                    path: 'notifications',
                    name: 'teacher-notifications',
                    pageBuilder: (c, s) => _page(s, const NotificationsPage()),
                  ),
                  GoRoute(
                    path: 'announcements',
                    name: 'teacher-announcements',
                    pageBuilder: (c, s) => _page(s, const AnnouncementsPage()),
                  ),
                  GoRoute(
                    path: 'chat-list',
                    name: 'teacher-chat-list',
                    pageBuilder: (c, s) => _page(s, const ChatListPage()),
                    routes: [
                      GoRoute(
                        path: 'chat/:id',
                        name: 'teacher-chat',
                        pageBuilder: (c, s) => _page(
                          s,
                          ChatPage(batchId: s.pathParameters['id'] ?? ''),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'live-session',
                    name: 'teacher-live-session',
                    pageBuilder: (c, s) => _page(s, const LiveSessionPage()),
                  ),
                  GoRoute(
                    path: 'video-player',
                    name: 'teacher-video-player',
                    pageBuilder: (c, s) {
                      final args = s.extra as Map<String, dynamic>? ?? {};
                      return _page(
                        s,
                        VideoPlayerPage(
                          videoUrl: args['videoUrl'] ?? args['videoId'],
                          title: args['title'],
                          lectureId: args['lectureId'],
                          summary: args['summary']?.toString(),
                          teacherName: args['teacherName']?.toString(),
                          subject: args['subject']?.toString(),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'video-lectures',
                    name: 'teacher-video-lectures',
                    pageBuilder: (c, s) => _page(s, const VideoLecturesPage()),
                  ),
                  GoRoute(
                    path: 'notification-settings',
                    name: 'teacher-notification-settings',
                    pageBuilder: (c, s) =>
                        _page(s, const NotificationSettingsPage()),
                  ),
                  GoRoute(
                    path: 'language',
                    name: 'teacher-language',
                    pageBuilder: (c, s) =>
                        _page(s, const LanguageSelectionPage()),
                  ),
                ],
              ),
            ],
          ),
          // Branch 1 — My Batches
          StatefulShellBranch(
            navigatorKey: _tch1,
            routes: [
              GoRoute(
                path: '/teacher/batches',
                name: 'teacher-batches-tab',
                pageBuilder: (c, s) => _page(s, const TeacherBatchesPage()),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'teacher-batch-detail-tab',
                    pageBuilder: (c, s) {
                      final tabQuery = (s.uri.queryParameters['tab'] ?? '')
                          .toLowerCase();
                      final tabMap = <String, int>{
                        'overview': 0,
                        'content': 1,
                        'students': 2,
                        'tests': 3,
                        'attendance': 4,
                        'doubts': 5,
                      };
                      final rawTabIndex =
                          tabMap[tabQuery] ?? int.tryParse(tabQuery) ?? 0;
                      final maxIndex = tabMap.length - 1;
                      final tabIndex = rawTabIndex.clamp(0, maxIndex).toInt();
                      return _page(
                        s,
                        TeacherBatchPanelPage(
                          batchId: s.pathParameters['id'] ?? '',
                          initialTabIndex: tabIndex,
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'assignment-review',
                        name: 'teacher-batch-assignment-review',
                        pageBuilder: (c, s) {
                          final extra = s.extra;
                          final args = extra is Map<String, dynamic>
                              ? extra
                              : <String, dynamic>{};
                          return _page(
                            s,
                            AssignmentReviewPage(
                              batchId: s.pathParameters['id'] ?? '',
                              initialAssignmentId:
                                  args['initialAssignmentId']?.toString(),
                              initialAssignmentTitle:
                                  args['initialAssignmentTitle']?.toString(),
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'youtube-live',
                        name: 'teacher-batch-youtube-live',
                        pageBuilder: (c, s) => _page(
                          s,
                          YoutubeBroadcastPage(
                            batchId: s.pathParameters['id'] ?? '',
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'upload-material',
                        name: 'teacher-batch-upload-material',
                        pageBuilder: (c, s) {
                          final extra = s.extra;
                          final args = extra is Map<String, dynamic>
                              ? extra
                              : <String, dynamic>{};
                          final rawItem = args['initialItem'];
                          return _page(
                            s,
                            UploadMaterialPage.withInitials(
                              initialBatchId: s.pathParameters['id'],
                              initialType: args['initialType']?.toString(),
                              initialSubject:
                                  args['initialSubject']?.toString(),
                              initialItem: rawItem is Map
                                  ? Map<String, dynamic>.from(rawItem)
                                  : null,
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'create-quiz',
                        name: 'teacher-batch-create-quiz',
                        pageBuilder: (c, s) {
                          final extra = s.extra;
                          final args = extra is Map<String, dynamic>
                              ? extra
                              : <String, dynamic>{};
                          return _page(
                            s,
                            CreateQuizPage(
                              initialBatchId: s.pathParameters['id'],
                              initialSubject:
                                  args['initialSubject']?.toString(),
                              quizId: args['quizId']?.toString(),
                              initialAssessmentType:
                                  args['initialAssessmentType']?.toString(),
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'quiz-results/:quizId',
                        name: 'teacher-batch-quiz-results',
                        pageBuilder: (c, s) => _page(
                          s,
                          QuizResultsPage(
                            quizId: s.pathParameters['quizId'] ?? '',
                            fallbackTitle: s.uri.queryParameters['title'],
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'attendance',
                        name: 'teacher-batch-attendance',
                        pageBuilder: (c, s) {
                          final extra = s.extra;
                          final args = extra is Map<String, dynamic>
                              ? extra
                              : <String, dynamic>{};
                          final rawDate = args['initialDate'];
                          final initialDate = rawDate is DateTime
                              ? rawDate
                              : DateTime.tryParse(
                                  rawDate?.toString() ?? '',
                                );
                          return _page(
                            s,
                            AttendanceMarkingPage(
                              initialBatchId: s.pathParameters['id'],
                              initialDate: initialDate,
                              initialSubject:
                                  args['initialSubject']?.toString(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Branch 2 — Doubts
          StatefulShellBranch(
            navigatorKey: _tch2,
            routes: [
              GoRoute(
                path: '/teacher/doubts',
                name: 'pending-doubts',
                pageBuilder: (c, s) => _page(s, const PendingDoubtsPage()),
                routes: [
                  GoRoute(
                    path: 'response',
                    name: 'doubt-response',
                    pageBuilder: (c, s) {
                      final extra = s.extra;
                      final doubt = extra is Map<String, dynamic>
                          ? extra
                          : <String, dynamic>{};
                      return _page(s, DoubtResponsePage(doubt: doubt));
                    },
                  ),
                ],
              ),
            ],
          ),
          // Branch 3 — Schedule
          StatefulShellBranch(
            navigatorKey: _tch3,
            routes: [
              GoRoute(
                path: '/teacher/schedule',
                name: 'teacher-schedule',
                pageBuilder: (c, s) => _page(s, const TeacherSchedulePage()),
              ),
            ],
          ),
          // Branch 4 — Profile / More
          StatefulShellBranch(
            navigatorKey: _tch4,
            routes: [
              GoRoute(
                path: '/teacher/settings',
                pageBuilder: (c, s) => _page(s, const SettingsPage()),
              ),
              GoRoute(
                path: '/teacher/profile',
                name: 'teacher-profile-self',
                pageBuilder: (c, s) => _page(
                  s,
                  ProfilePage(
                    edit: s.uri.queryParameters['edit'] == 'true',
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'settings',
                    name: 'teacher-settings',
                    pageBuilder: (c, s) => _page(s, const SettingsPage()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── Student Shell ───────────────────────────────────────
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (context, state, shell) => CPRoleShell(
          navigationShell: shell,
          items: const [
            CPBottomNavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Home',
            ),
            CPBottomNavItem(
              icon: Icons.class_outlined,
              activeIcon: Icons.class_rounded,
              label: 'Batches',
            ),
            CPBottomNavItem(
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book_rounded,
              label: 'Materials',
            ),
            CPBottomNavItem(
              icon: Icons.live_help_outlined,
              activeIcon: Icons.live_help_rounded,
              label: 'Doubts',
            ),
            CPBottomNavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        ),
        branches: [
          // Branch 0 — Home
          StatefulShellBranch(
            navigatorKey: _stu0,
            routes: [
              GoRoute(
                path: '/student',
                name: 'student-dashboard',
                pageBuilder: (c, s) => _page(s, const StudentDashboardPage()),
                routes: [
                  GoRoute(
                    path: 'quiz',
                    name: 'quizzes-list',
                    pageBuilder: (c, s) => _page(s, const QuizzesListPage()),
                    routes: [
                      GoRoute(
                        path: ':id/result',
                        name: 'quiz-result',
                        pageBuilder: (c, s) => _page(
                          s,
                          QuizResultPage(
                            quizId: s.pathParameters['id'] ?? '',
                          ),
                        ),
                      ),
                      GoRoute(
                        path: ':id',
                        name: 'quiz-taking',
                        pageBuilder: (c, s) => _page(
                          s,
                          QuizTakingPage(quizId: s.pathParameters['id'] ?? ''),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'syllabus',
                    name: 'syllabus-tracker',
                    pageBuilder: (c, s) =>
                        _page(s, const SyllabusTrackerPage()),
                  ),
                  GoRoute(
                    path: 'results',
                    name: 'exam-results',
                    pageBuilder: (c, s) => _page(s, const ExamResultsPage()),
                  ),
                  GoRoute(
                    path: 'performance',
                    name: 'student-performance',
                    pageBuilder: (c, s) =>
                        _page(s, const PerformanceDashboardPage()),
                  ),
                  GoRoute(
                    path: 'timetable',
                    name: 'student-timetable',
                    pageBuilder: (c, s) => _page(s, const TimetablePage()),
                  ),
                  GoRoute(
                    path: 'schedule',
                    name: 'student-schedule-legacy',
                    pageBuilder: (c, s) => _page(s, const TimetablePage()),
                  ),
                  GoRoute(
                    path: 'fee-history',
                    name: 'student-fee-history',
                    pageBuilder: (c, s) => _page(s, const FeeHistoryPage()),
                  ),
                  GoRoute(
                    path: 'exam-calendar',
                    name: 'student-exam-calendar',
                    pageBuilder: (c, s) => _page(s, const ExamCalendarPage()),
                  ),
                  GoRoute(
                    path: 'assignment-submit',
                    name: 'assignment-submit',
                    pageBuilder: (c, s) {
                      final args = s.extra as Map<String, dynamic>? ?? {};
                      return _page(
                        s,
                        AssignmentSubmissionPage(
                          initialAssignmentId: args['assignmentId']?.toString(),
                          initialFileUrl: args['fileUrl']?.toString(),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'notifications',
                    name: 'student-notifications',
                    pageBuilder: (c, s) => _page(s, const NotificationsPage()),
                  ),
                  GoRoute(
                    path: 'announcements',
                    name: 'student-announcements',
                    pageBuilder: (c, s) => _page(s, const AnnouncementsPage()),
                  ),
                  GoRoute(
                    path: 'live-session',
                    name: 'student-live-session',
                    pageBuilder: (c, s) => _page(s, const LiveSessionPage()),
                  ),
                  GoRoute(
                    path: 'video-player',
                    name: 'student-video-player',
                    pageBuilder: (c, s) {
                      final args = s.extra as Map<String, dynamic>? ?? {};
                      return _page(
                        s,
                        VideoPlayerPage(
                          videoUrl: args['videoUrl'] ?? args['videoId'],
                          title: args['title'],
                          lectureId: args['lectureId'],
                          summary: args['summary']?.toString(),
                          teacherName: args['teacherName']?.toString(),
                          subject: args['subject']?.toString(),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'youtube-player',
                    name: 'student-youtube-player',
                    pageBuilder: (c, s) {
                      final args = s.extra as Map<String, dynamic>? ?? {};
                      return _page(
                        s,
                        VideoPlayerPage(
                          videoUrl: args['videoId'] ?? args['videoUrl'] ?? '',
                          title: args['title'] ?? 'Video',
                          summary: args['summary']?.toString(),
                          teacherName: args['teacherName']?.toString(),
                          subject: args['subject']?.toString(),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'fee-payment',
                    name: 'student-fee-payment',
                    pageBuilder: (c, s) => _page(s, const FeePaymentPage()),
                  ),
                  GoRoute(
                    path: 'settings',
                    name: 'student-settings',
                    pageBuilder: (c, s) => _page(s, const SettingsPage()),
                  ),
                  GoRoute(
                    path: 'leaderboard',
                    name: 'student-leaderboard',
                    pageBuilder: (c, s) => _page(s, const LeaderboardPage()),
                  ),
                  GoRoute(
                    path: 'video-lectures',
                    name: 'student-video-lectures',
                    pageBuilder: (c, s) => _page(s, const VideoLecturesPage()),
                  ),
                  GoRoute(
                    path: 'notification-settings',
                    name: 'student-notification-settings',
                    pageBuilder: (c, s) =>
                        _page(s, const NotificationSettingsPage()),
                  ),
                  GoRoute(
                    path: 'language',
                    name: 'student-language',
                    pageBuilder: (c, s) =>
                        _page(s, const LanguageSelectionPage()),
                  ),
                ],
              ),
            ],
          ),
          // Branch 1 — Batches
          StatefulShellBranch(
            navigatorKey: _stu1,
            routes: [
              GoRoute(
                path: '/student/batches',
                name: 'student-batches',
                pageBuilder: (c, s) => _page(s, const BatchesPage()),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'student-batch-detail',
                    pageBuilder: (c, s) => _page(
                      s,
                      StudentBatchPanelPage(
                        batchId: s.pathParameters['id'] ?? '',
                        batchInfo: s.extra is Map<String, dynamic>
                            ? s.extra as Map<String, dynamic>
                            : const {},
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 2 — Materials
          StatefulShellBranch(
            navigatorKey: _stu2,
            routes: [
              GoRoute(
                path: '/student/materials',
                name: 'study-materials',
                pageBuilder: (c, s) => _page(s, const StudyMaterialsPage()),
              ),
            ],
          ),
          // Branch 3 — Doubts
          StatefulShellBranch(
            navigatorKey: _stu3,
            routes: [
              GoRoute(
                path: '/student/doubts',
                name: 'doubts-history',
                pageBuilder: (c, s) => _page(s, const MyDoubtsHistoryPage()),
                routes: [
                  GoRoute(
                    path: 'history',
                    name: 'doubts-history-alias',
                    pageBuilder: (c, s) => _page(s, const MyDoubtsHistoryPage()),
                  ),
                  GoRoute(
                    path: 'ask',
                    name: 'ask-doubt',
                    pageBuilder: (c, s) => _page(
                      s,
                      AskDoubtPage(
                        initialData: s.extra as Map<String, dynamic>?,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 4 — Profile
          StatefulShellBranch(
            navigatorKey: _stu4,
            routes: [
              GoRoute(
                path: '/student/profile',
                name: 'student-self-profile',
                pageBuilder: (c, s) => _page(
                  s,
                  ProfilePage(
                    edit: s.uri.queryParameters['edit'] == 'true',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Parent Shell ────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (context, state, shell) => CPRoleShell(
          navigationShell: shell,
          items: const [
            CPBottomNavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              label: 'Home',
            ),
            CPBottomNavItem(
              icon: Icons.chat_bubble_outline,
              activeIcon: Icons.chat_bubble,
              label: 'Chat',
            ),
            CPBottomNavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long,
              label: 'Fees',
            ),
            CPBottomNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
            ),
          ],
        ),
        branches: [
          // Branch 0 — Home
          StatefulShellBranch(
            navigatorKey: _par0,
            routes: [
              GoRoute(
                path: '/parent',
                name: 'parent-dashboard',
                pageBuilder: (c, s) => _page(s, const ParentDashboardPage()),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    name: 'parent-notifications',
                    pageBuilder: (c, s) => _page(s, const NotificationsPage()),
                  ),
                  GoRoute(
                    path: 'settings',
                    name: 'parent-settings',
                    pageBuilder: (c, s) => _page(s, const SettingsPage()),
                  ),
                  GoRoute(
                    path: 'announcements',
                    name: 'parent-announcements',
                    pageBuilder: (c, s) => _page(s, const AnnouncementsPage()),
                  ),
                  GoRoute(
                    path: 'live-session',
                    name: 'parent-live-session',
                    pageBuilder: (c, s) => _page(s, const LiveSessionPage()),
                  ),
                  GoRoute(
                    path: 'video-player',
                    name: 'parent-video-player',
                    pageBuilder: (c, s) {
                      final args = s.extra as Map<String, dynamic>? ?? {};
                      return _page(
                        s,
                        VideoPlayerPage(
                          videoUrl: args['videoUrl'] ?? args['videoId'],
                          title: args['title'],
                          lectureId: args['lectureId'],
                          summary: args['summary']?.toString(),
                          teacherName: args['teacherName']?.toString(),
                          subject: args['subject']?.toString(),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'weekly-report/:id',
                    name: 'parent-weekly-report',
                    pageBuilder: (c, s) => _page(
                      s,
                      WeeklyReportPage(studentId: s.pathParameters['id'] ?? ''),
                    ),
                  ),
                  GoRoute(
                    path: 'payment-history',
                    name: 'parent-payment-history',
                    pageBuilder: (c, s) => _page(s, const PaymentHistoryPage()),
                  ),
                  GoRoute(
                    path: 'video-lectures',
                    name: 'parent-video-lectures',
                    pageBuilder: (c, s) => _page(s, const VideoLecturesPage()),
                  ),
                  GoRoute(
                    path: 'notification-settings',
                    name: 'parent-notification-settings',
                    pageBuilder: (c, s) =>
                        _page(s, const NotificationSettingsPage()),
                  ),
                  GoRoute(
                    path: 'language',
                    name: 'parent-language',
                    pageBuilder: (c, s) =>
                        _page(s, const LanguageSelectionPage()),
                  ),
                ],
              ),
            ],
          ),
          // Branch 1 — Chat
          StatefulShellBranch(
            navigatorKey: _par1,
            routes: [
              GoRoute(
                path: '/parent/chat-list',
                name: 'parent-chat-list',
                pageBuilder: (c, s) => _page(s, const ParentDoubtsPage()),
                routes: [
                  GoRoute(
                    path: 'chat/:id',
                    name: 'parent-chat',
                    pageBuilder: (c, s) => _page(
                      s,
                      ChatPage(batchId: s.pathParameters['id'] ?? ''),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 2 — Fees
          StatefulShellBranch(
            navigatorKey: _par2,
            routes: [
              GoRoute(
                path: '/parent/fee-payment',
                name: 'parent-fee-payment',
                pageBuilder: (c, s) => _page(
                  s,
                  const FeePaymentPage(),
                ),
                routes: [
                  GoRoute(
                    path: ':recordId',
                    name: 'parent-fee-payment-with-id',
                    pageBuilder: (c, s) => _page(
                      s,
                      FeePaymentPage(recordId: s.pathParameters['recordId']),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 3 — Profile
          StatefulShellBranch(
            navigatorKey: _par3,
            routes: [
              GoRoute(
                path: '/parent/profile',
                name: 'parent-self-profile',
                pageBuilder: (c, s) => _page(
                  s,
                  ProfilePage(
                    edit: s.uri.queryParameters['edit'] == 'true',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Converts BLoC Stream into a ChangeNotifier for GoRouter.refreshListenable
// ─────────────────────────────────────────────────────────────────────────────
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(AuthBloc bloc) {
    bloc.stream.listen((_) => notifyListeners());
  }
}
