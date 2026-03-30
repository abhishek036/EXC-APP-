import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/services/api_auth_service.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_role_shell.dart';
import '../../../../core/utils/role_prefix.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/data/models/user_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _editMode = false;
  bool _saving = false;

  // Editable controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _dobCtrl;
  late TextEditingController _addressCtrl;

  UserModel? _user;

  void _handleBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    final shellBack = CPRoleShellBack.maybeOf(context);
    if (shellBack != null) {
      shellBack.goBack();
    }
  }

  bool _uploadingAvatar = false;

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _uploadingAvatar = true);
      HapticFeedback.mediumImpact();

      final file = File(picked.path);
      final avatarUrl = await sl<ApiAuthService>().uploadAvatar(file);

      if (!mounted) return;

      // Refresh AuthBloc so the new avatar propagates everywhere
      context.read<AuthBloc>().add(const AuthRefreshRequested());

      setState(() => _uploadingAvatar = false);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Profile picture updated!', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text('Take Photo', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text('Choose from Gallery', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _user = authState.user as UserModel?;
    }
    _nameCtrl    = TextEditingController(text: _user?.name ?? '');
    _phoneCtrl   = TextEditingController(text: _user?.phone ?? '');
    _emailCtrl   = TextEditingController(text: _user?.email ?? '');
    _dobCtrl     = TextEditingController(text: '');
    _addressCtrl = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _emailCtrl.dispose(); _dobCtrl.dispose(); _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    // Persist updated user into backend, then local storage, then refresh bloc
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final oldUser = authState.user as UserModel;
        
        // 1. Sync to backend
        final profileData = await sl<ApiAuthService>().updateProfile(
          name: _nameCtrl.text.trim(),
          phone: null,
          email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        );

        final effectiveName = (profileData['name']?.toString().trim().isNotEmpty == true)
            ? profileData['name'].toString().trim()
            : _nameCtrl.text.trim();
        final effectiveEmail = (profileData['email']?.toString().trim().isNotEmpty == true)
            ? profileData['email'].toString().trim()
            : (_emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : oldUser.email);

        final updated = UserModel(
          id: oldUser.id,
          name: effectiveName,
          phone: oldUser.phone,
          role: oldUser.role,
          email: effectiveEmail,
        );
        
        // 2. Persist locally
        await sl<SecureStorageService>().saveUserJson(jsonEncode(updated.toJson()));
        
        if (mounted) {
          // 3. Update Global State
          context.read<AuthBloc>().add(AuthProfileCompleted(updated));
          context.read<AuthBloc>().add(const AuthRefreshRequested());
          setState(() {
            _editMode = false;
            _saving = false;
            _user = updated;
            _nameCtrl.text = updated.name;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Profile updated successfully!', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.white)),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;
        final role = user?.role ?? AppRole.admin;
        final isAdmin = role == AppRole.admin;
        final displayName = user?.name ?? _user?.name ?? 'Admin User';
        final roleLabel = switch (role) {
          AppRole.admin => 'Administrator',
          AppRole.teacher => 'Faculty',
          AppRole.student => 'Student',
          AppRole.parent => 'Parent',
        };

        final initials = displayName.trim().isEmpty ? 'A'
            : displayName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();

        return Scaffold(
          backgroundColor: const Color(0xFFF4F5FA),
          body: CustomScrollView(
            slivers: [
              // ── Sliver App Bar / Hero Header ───────────────
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: const Color(0xFF0D1282),
                leading: CPPressable(
                  onTap: _handleBack,
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
                actions: [
                  if (!_editMode)
                    CPPressable(
                      onTap: () => setState(() => _editMode = true),
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0DE36),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF0D1282)),
                          const SizedBox(width: 6),
                          Text('Edit', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282))),
                        ]),
                      ),
                    )
                  else
                    CPPressable(
                      onTap: () => setState(() {
                        _editMode = false;
                        _nameCtrl.text = (user?.name ?? _user?.name ?? '');
                      }),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: const Color(0xFF0D1282),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        Stack(alignment: Alignment.bottomRight, children: [
                          Container(
                            width: 96, height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.15),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2.5),
                              image: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(user.avatarUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                                ? (_uploadingAvatar
                                    ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                                    : null)
                                : Center(child: _uploadingAvatar
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Text(initials,
                                        style: GoogleFonts.plusJakartaSans(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white))),
                          ),
                          if (_editMode)
                            CPPressable(
                              onTap: _showImageOptions,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Color(0xFFF0DE36), shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt_rounded, size: 14, color: Color(0xFF0D1282)),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 12),
                        Text(displayName,
                          style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(roleLabel,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                        const SizedBox(height: 4),
                        Text(isAdmin ? 'ADM-001' : 'USR-001',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white.withValues(alpha: 0.45), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(child: Column(children: [
                const SizedBox(height: 24),

                // ── Personal Information ──────────────────────
                _section('Personal Information', [
                  _editableField(label: 'Full Name', icon: Icons.person_rounded, controller: _nameCtrl, editing: _editMode),
                  _editableField(label: 'Phone', icon: Icons.phone_android_rounded, controller: _phoneCtrl, editing: _editMode, editable: false, type: TextInputType.phone),
                  _editableField(label: 'Email', icon: Icons.email_rounded, controller: _emailCtrl, editing: _editMode, type: TextInputType.emailAddress),
                  _editableField(label: 'Date of Birth', icon: Icons.cake_rounded, controller: _dobCtrl, editing: _editMode, editable: false),
                  _editableField(label: 'Address', icon: Icons.home_rounded, controller: _addressCtrl, editing: _editMode, editable: false),
                ]).animate(delay: 150.ms).fadeIn().slideY(begin: 0.05),

                // ── Quick Actions ────────────────────────────
                _section(
                  isAdmin ? 'Quick Links' : 'Account Shortcuts',
                  isAdmin
                      ? [
                          _quickRow(context, Icons.people_rounded, 'Manage Students', route: '/admin/students'),
                          _quickRow(context, Icons.class_rounded, 'Manage Batches', route: '/admin/batches'),
                          _quickRow(context, Icons.bar_chart_rounded, 'Admin Reports', route: '/admin/reports'),
                          _quickRow(context, Icons.settings_rounded, 'App Settings', route: '/admin/settings'),
                        ]
                      : [
                          _quickRow(context, Icons.person_outline_rounded, 'Edit Profile', onTap: () => setState(() => _editMode = true)),
                          _quickRow(context, Icons.settings_rounded, 'Settings', route: role == AppRole.teacher ? '/teacher/profile/settings' : '${context.rolePrefix}/settings'),
                          _quickRow(context, Icons.notifications_outlined, 'Notification Settings', route: '${context.rolePrefix}/notification-settings'),
                          _quickRow(context, Icons.lock_reset_rounded, 'Change Password', route: '/change-password'),
                        ],
                ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.05),

                // ── Save Button ──────────────────────────────
                if (_editMode) ...[
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: CPPressable(
                      onTap: _saving ? null : _saveProfile,
                      child: Container(
                        height: 54,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1282),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: const Color(0xFF0D1282).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Center(
                          child: _saving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Text('Save Changes', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                              ]),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ])),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ─────────────────────────────────────────────────



  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0A0C1E))),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(children: children),
      ),
    ]),
  );

  Widget _editableField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool editing,
    bool editable = true,
    TextInputType? type,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(icon, size: 20, color: const Color(0xFF8F97B8)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF8F97B8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          (editing && editable)
            ? TextField(
                controller: controller,
                keyboardType: type,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0A0C1E)),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: const Color(0xFF0D1282).withValues(alpha: 0.4))),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0D1282), width: 1.5)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: const Color(0xFF0D1282).withValues(alpha: 0.25))),
                ),
              )
            : Text(
                controller.text.isEmpty ? '—' : controller.text,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0A0C1E)),
              ),
        ])),
      ]),
    );
  }



  Widget _quickRow(BuildContext context, IconData icon, String label, {String? route, VoidCallback? onTap}) => CPPressable(
    onTap: () {
      if (onTap != null) {
        onTap();
        return;
      }
      if (route != null && route.isNotEmpty) {
        context.go(route);
      }
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFF0D1282).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: const Color(0xFF0D1282)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0A0C1E)))),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF8F97B8), size: 20),
      ]),
    ),
  );
}
