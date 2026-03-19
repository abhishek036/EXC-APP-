import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/domain/entities/user_entity.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;
  File? _coverImage;
  final _picker = ImagePicker();

  Future<void> _pickImage(bool isProfile) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (isProfile) {
          _profileImage = File(pickedFile.path);
        } else {
          _coverImage = File(pickedFile.path);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final role = authState is AuthAuthenticated ? authState.user.role : AppRole.student;
    final isStudent = role == AppRole.student;
    final isTeacher = role == AppRole.teacher;
    final isAdmin = role == AppRole.admin;
    final isParent = role == AppRole.parent;

    final roleName = role.name[0].toUpperCase() + role.name.substring(1);
    final roleSubtitle = isStudent ? 'Student · JEE Batch A'
        : isTeacher ? 'Faculty · Physics Department'
        : isAdmin ? 'Administrator'
        : 'Parent · Guardian';
    final userName = isStudent ? 'Priya Singh' : isTeacher ? 'Mr. Sharma' : isAdmin ? 'Admin User' : 'Mr. Singh';

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, 60, AppDimensions.pagePaddingH, 32),
            decoration: BoxDecoration(
              gradient: _coverImage == null ? AppColors.primaryGradient : null,
              image: _coverImage != null ? DecorationImage(
                image: FileImage(_coverImage!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.3), BlendMode.darken),
              ) : null,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppDimensions.radiusXL),
                bottomRight: Radius.circular(AppDimensions.radiusXL),
              ),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                CPPressable(
                  onTap: () => context.pop(),
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                ),
                Text('My Profile', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                Row(children: [
                   CPPressable(
                    onTap: () => _pickImage(false),
                    child: const Icon(Icons.add_a_photo_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  CPPressable(
                    onTap: () => context.go('/${role.name}/settings'),
                    child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                  ),
                ]),
              ]),
              const SizedBox(height: AppDimensions.lg),
              Stack(
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                      image: _profileImage != null ? DecorationImage(
                        image: FileImage(_profileImage!),
                        fit: BoxFit.cover,
                      ) : null,
                    ),
                    child: _profileImage == null 
                      ? Center(child: Text(roleName[0], style: GoogleFonts.sora(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white)))
                      : null,
                  ),
                  Positioned(
                    right: -4, bottom: -4,
                    child: CPPressable(
                      onTap: () => _pickImage(true),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]),
                        child: Icon(Icons.edit, size: 14, color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              Text(userName, style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text(roleSubtitle, style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 4),
              Text(isStudent ? 'STU-005' : isTeacher ? 'TCH-002' : isAdmin ? 'ADM-001' : 'PAR-003',
                style: GoogleFonts.jetBrainsMono(fontSize: 12, color: Colors.white54)),
            ]),
          ).animate().fadeIn(duration: 500.ms),

          // Stats
          Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: CT.elevatedCardDecor(context),
                child: Row(children: isStudent ? [
                  _profileStat(context, 'Attendance', '88%', AppColors.success),
                  _divider(context),
                  _profileStat(context, 'Tests', '12', AppColors.primary),
                  _divider(context),
                  _profileStat(context, 'Rank', '#5', AppColors.accent),
                  _divider(context),
                  _profileStat(context, 'Streak', '15d', AppColors.error),
                ] : isTeacher ? [
                  _profileStat(context, 'Classes', '48', AppColors.primary),
                  _divider(context),
                  _profileStat(context, 'Students', '120', AppColors.success),
                  _divider(context),
                  _profileStat(context, 'Rating', '4.8', AppColors.moltenAmber),
                  _divider(context),
                  _profileStat(context, 'Exp', '8yr', AppColors.accent),
                ] : isAdmin ? [
                  _profileStat(context, 'Students', '450', AppColors.primary),
                  _divider(context),
                  _profileStat(context, 'Teachers', '12', AppColors.success),
                  _divider(context),
                  _profileStat(context, 'Batches', '8', AppColors.accent),
                  _divider(context),
                  _profileStat(context, 'Revenue', '₹12L', AppColors.moltenAmber),
                ] : [
                  _profileStat(context, 'Child', '1', AppColors.primary),
                  _divider(context),
                  _profileStat(context, 'Attend.', '88%', AppColors.success),
                  _divider(context),
                  _profileStat(context, 'Fees', 'Paid', AppColors.accent),
                  _divider(context),
                  _profileStat(context, 'Reports', '4', AppColors.moltenAmber),
                ]),
              ),
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle(context, 'Personal Information'),
              _infoCard(context, [
                _infoRow(context, Icons.phone_outlined, 'Phone', '+91 98765 43210'),
                _infoRow(context, Icons.email_outlined, 'Email', 'test@Excellence Academy.app'),
                _infoRow(context, Icons.cake_outlined, 'DOB', '15 Aug 1990'),
                if (isStudent) _infoRow(context, Icons.family_restroom_outlined, 'Parent', 'Mr. Singh'),
                if (isTeacher) _infoRow(context, Icons.school_outlined, 'Subject', 'Physics'),
                if (isParent) _infoRow(context, Icons.child_care_outlined, 'Child', 'Priya Singh'),
                _infoRow(context, Icons.home_outlined, 'Address', 'Sector 21, Noida, UP'),
              ]),
              const SizedBox(height: AppDimensions.lg),

              _sectionTitle(context, isStudent ? 'Academic Details' : isTeacher ? 'Professional Details' : isAdmin ? 'Administrative Details' : 'Child\'s Details'),
              _infoCard(context, isStudent ? [
                _infoRow(context, Icons.class_outlined, 'Batch', 'JEE Batch A'),
                _infoRow(context, Icons.calendar_today_outlined, 'Joined', 'August 2025'),
                _infoRow(context, Icons.school_outlined, 'Class', '12th Science'),
                _infoRow(context, Icons.emoji_events_outlined, 'Target', 'JEE Advanced 2027'),
              ] : isTeacher ? [
                _infoRow(context, Icons.work_outlined, 'Dept.', 'Physics'),
                _infoRow(context, Icons.calendar_today_outlined, 'Joined', 'January 2020'),
                _infoRow(context, Icons.class_outlined, 'Batches', 'JEE Batch A, B'),
                _infoRow(context, Icons.star_outlined, 'Qual.', 'M.Sc Physics, B.Ed'),
              ] : isAdmin ? [
                _infoRow(context, Icons.business_outlined, 'Institute', 'Excellence Academy'),
                _infoRow(context, Icons.calendar_today_outlined, 'Since', 'March 2018'),
                _infoRow(context, Icons.admin_panel_settings_outlined, 'Access', 'Full Admin'),
                _infoRow(context, Icons.location_on_outlined, 'Branch', 'Main Campus'),
              ] : [
                _infoRow(context, Icons.child_care_outlined, 'Student', 'Priya Singh'),
                _infoRow(context, Icons.class_outlined, 'Batch', 'JEE Batch A'),
                _infoRow(context, Icons.school_outlined, 'Class', '12th Science'),
                _infoRow(context, Icons.calendar_today_outlined, 'Enrolled', 'August 2025'),
              ]),
              const SizedBox(height: AppDimensions.lg),

              _sectionTitle(context, 'Quick links'),
              Row(children: isStudent ? [
                _quickLink(context, Icons.assessment_outlined, 'Results', AppColors.primary, '/student/results'),
                const SizedBox(width: AppDimensions.sm),
                _quickLink(context, Icons.receipt_long_outlined, 'Fee History', AppColors.success, '/student/fee-history'),
                const SizedBox(width: AppDimensions.sm),
                _quickLink(context, Icons.fact_check_outlined, 'Attendance', AppColors.accent, '/student/performance'),
                const SizedBox(width: AppDimensions.sm),
                _quickLink(context, Icons.settings_outlined, 'Settings', AppColors.info, '/student/settings'),
              ] : isTeacher ? [
                _quickLink(context, Icons.people_outlined, 'Students', AppColors.primary, '/teacher/doubts'),
                const SizedBox(width: AppDimensions.sm),
                _quickLink(context, Icons.quiz_outlined, 'Quizzes', AppColors.success, '/teacher/quiz-results'),
                const SizedBox(width: AppDimensions.sm),
                _quickLink(context, Icons.upload_outlined, 'Materials', AppColors.accent, '/teacher/upload-material'),
                const SizedBox(width: AppDimensions.sm),
                _quickLink(context, Icons.settings_outlined, 'Settings', AppColors.info, '/teacher/settings'),
              ] : isAdmin ? [
                _quickLink(context, Icons.people_outlined, 'Students', AppColors.primary, '/admin/students'),
                const SizedBox(width: AppDimensions.sm),
                _quickLink(context, Icons.class_outlined, 'Batches', AppColors.success, '/admin/batches'),
                const SizedBox(width: AppDimensions.sm),
                _quickLink(context, Icons.assessment_outlined, 'Reports', AppColors.accent, '/admin/reports'),
                const SizedBox(width: AppDimensions.sm),
                _quickLink(context, Icons.settings_outlined, 'Settings', AppColors.info, '/admin/settings'),
              ] : [
                _quickLink(context, Icons.assessment_outlined, 'Reports', AppColors.primary, '/parent'),
                const SizedBox(width: AppDimensions.sm),
                _quickLink(context, Icons.receipt_long_outlined, 'Fees', AppColors.success, '/parent/fee-payment'),
                const SizedBox(width: AppDimensions.sm),
                _quickLink(context, Icons.chat_outlined, 'Chat', AppColors.accent, '/parent/chat-list'),
                const SizedBox(width: AppDimensions.sm),
                _quickLink(context, Icons.settings_outlined, 'Settings', AppColors.info, '/parent/settings'),
              ]),

              const SizedBox(height: 40),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _profileStat(BuildContext context, String label, String value, Color color) => Expanded(
    child: Column(children: [
      Text(value, style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: CT.textS(context))),
    ]),
  );

  Widget _divider(BuildContext context) => Container(width: 1, height: 36, color: CT.border(context));

  Widget _sectionTitle(BuildContext context, String t) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimensions.step),
    child: Text(t, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: CT.textH(context))),
  );

  Widget _infoCard(BuildContext context, List<Widget> children) => Container(
    padding: const EdgeInsets.all(AppDimensions.md),
    decoration: CT.cardDecor(context),
    child: Column(children: children.map((c) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: c)).toList()),
  );

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) => Row(children: [
    Icon(icon, size: 18, color: CT.textM(context)),
    const SizedBox(width: AppDimensions.step),
    SizedBox(width: 70, child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: CT.textM(context)))),
    Expanded(child: Text(value, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: CT.textH(context)))),
  ]);

  Widget _quickLink(BuildContext context, IconData icon, String label, Color color, String route) => Expanded(
    child: CPPressable(
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        ),
        child: Column(children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    ),
  );
}
