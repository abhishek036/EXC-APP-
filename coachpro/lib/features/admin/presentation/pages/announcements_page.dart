import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../data/repositories/admin_repository.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final _adminRepo = sl<AdminRepository>();

  int _selectedFilter = 0;
  final _filters = ['All', 'Academic', 'Fee', 'Holiday', 'Event'];
  final _filterColors = [AppColors.primary, AppColors.primary, AppColors.warning, AppColors.success, AppColors.accent];

  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _loading = true);
    try {
      final filterValue = _filters[_selectedFilter];
      final data = await _adminRepo.getAnnouncements(category: filterValue == 'All' ? null : filterValue);
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    final catColors = {
      'Fee': AppColors.warning,
      'Holiday': AppColors.success,
      'Academic': AppColors.primary,
      'Event': AppColors.accent,
    };

    return Scaffold(
      backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ── HEADER ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      CPPressable(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFEEEDED), border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2))]),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0D1282)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text('Broadcast Center', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -1.0)),
                      const Spacer(),
                      CPPressable(
                        onTap: () => _showAddAnnouncementSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(color: const Color(0xFFF0DE36), border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2))]),
                          child: Row(
                            children: [
                              const Icon(Icons.add_alert_rounded, size: 20, color: Color(0xFF0D1282)),
                              const SizedBox(width: 8),
                              Text('Broadcast', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282), letterSpacing: -0.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── FILTERS ──
                Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final isActive = _selectedFilter == i;
                      return CPPressable(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedFilter = i);
                          _loadAnnouncements();
                        },
                        child: AnimatedContainer(
                          duration: 300.ms,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: isActive ? _filterColors[i] : const Color(0xFFEEEDED),
                            border: Border.all(color: const Color(0xFF0D1282), width: 2),
                            boxShadow: isActive ? const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2))] : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(_filters[i].toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: isActive ? Colors.white : const Color(0xFF0D1282), letterSpacing: 0.5)),
                        ),
                      );
                    },
                  ),
                ),
                
                // ── FEED ──
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : RefreshIndicator(
                          onRefresh: _loadAnnouncements,
                          child: _items.isEmpty
                              ? ListView(
                                  children: [
                                    const SizedBox(height: 120),
                                    Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.campaign_outlined, size: 64, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.12)),
                                          const SizedBox(height: 16),
                                          Text('No Active Broadcasts', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white54 : Colors.black54, letterSpacing: -0.5)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ).animate().fadeIn()
                              : ListView.separated(
                                  padding: const EdgeInsets.all(24),
                                  itemCount: _items.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                                  itemBuilder: (context, i) {
                                    final announcement = _items[i];
                                    final category = (announcement['category'] ?? 'Academic').toString();
                                    final title = (announcement['title'] ?? '').toString();
                                    final body = (announcement['body'] ?? '').toString();
                                    final author = (announcement['author'] ?? 'Admin').toString();
                                    final pinned = announcement['pinned'] == true;
                                    final createdAt = DateTime.tryParse((announcement['createdAt'] ?? '').toString());
                                    final dateStr = createdAt != null ? DateFormat('dd MMM, hh:mm a').format(createdAt) : 'Recently';
        
                                    final color = catColors[category] ?? AppColors.primary;
                                    
                                    return CPGlassCard(
                                      isDark: isDark,
                                      padding: const EdgeInsets.all(20),
                                      border: Border.all(color: const Color(0xFF0D1282), width: pinned ? 4 : 2),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(color: color, border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2))]),
                                              child: Text(category.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0)),
                                            ),
                                            const Spacer(),
                                            if (pinned) Icon(Icons.push_pin_rounded, size: 16, color: AppColors.warning),
                                            if (pinned) const SizedBox(width: 8),
                                            Text(dateStr, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.black38)),
                                            const SizedBox(width: 12),
                                            CPPressable(
                                              onTap: () => _deleteAnnouncement((announcement['id'] ?? '').toString()),
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(color: AppColors.error, border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2))]),
                                                child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                                              ),
                                            ),
                                          ]),
                                          const SizedBox(height: 16),
                                          Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)),
                                          const SizedBox(height: 8),
                                          Text(body, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87, height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 16),
                                          Row(children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.12), shape: BoxShape.circle),
                                              child: Icon(Icons.person_rounded, size: 12, color: isDark ? Colors.white54 : Colors.black54),
                                            ),
                                            const SizedBox(width: 8),
                                            Text('AUTHOR: ${author.toUpperCase()}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 0.5)),
                                          ]),
                                        ],
                                      ),
                                    ).animate(delay: Duration(milliseconds: 30 * i)).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAnnouncement(String id) async {
    final isDark = CT.isDark(context);
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: const Color(0xFF0D1282), width: 3)),
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.error, border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2))]), child: const Icon(Icons.warning_rounded, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Retract Broadcast?', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)),
          ],
        ),
        content: Text('This action will permanently remove this broadcast from all feeds. Proceed?', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), style: TextButton.styleFrom(side: const BorderSide(color: Color(0xFF0D1282), width: 2), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), backgroundColor: const Color(0xFFEEEDED)), child: Text('CANCEL', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF0D1282)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(side: const BorderSide(color: Color(0xFF0D1282), width: 2), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), backgroundColor: AppColors.error), child: Text('RETRACT', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white))),
        ],
      ),
    );

    if (conf == true) {
      try {
        await _adminRepo.deleteAnnouncement(id);
        if (mounted) CPToast.success(context, 'Broadcast retracted safely.');
        _loadAnnouncements();
      } catch (_) {
        if (mounted) CPToast.error(context, 'Core error retracting broadcast.');
      }
    }
  }

  void _showAddAnnouncementSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String category = 'Academic';
    bool pin = false;
    final isDark = CT.isDark(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEDED),
              border: Border.all(color: const Color(0xFF0D1282), width: 4),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.campaign_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Broadcast Setup', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.deepNavy, letterSpacing: -0.5)),
                            Text('Draft a message to sync globally', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text('BROADCAST PROTOCOL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF0D1282), letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2))]),
                    child: TextField(
                      controller: titleCtrl,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282)),
                      decoration: InputDecoration(hintText: 'Enter broadcast subject', hintStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0D1282).withValues(alpha: 0.5)), prefixIcon: const Icon(Icons.subject_rounded, color: Color(0xFF0D1282)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2))]),
                    child: TextField(
                      controller: bodyCtrl,
                      maxLines: 4,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282)),
                      decoration: InputDecoration(hintText: 'Detailed transmission content...', hintStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282).withValues(alpha: 0.5)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: category,
                              isExpanded: true,
                              dropdownColor: isDark ? AppColors.eliteDarkBg : Colors.white,
                              icon: Icon(Icons.arrow_drop_down_rounded, color: isDark ? Colors.white54 : Colors.black54),
                              items: ['Academic', 'Fee', 'Holiday', 'Event'].map((item) => DropdownMenuItem(value: item, child: Text(item, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.deepNavy)))).toList(),
                              onChanged: (value) => setSS(() => category = value ?? 'Academic'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      CPPressable(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSS(() => pin = !pin);
                        },
                        child: AnimatedContainer(
                          duration: 200.ms,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: pin ? const Color(0xFFF0DE36) : const Color(0xFFEEEDED),
                            border: Border.all(color: const Color(0xFF0D1282), width: 2),
                            boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(2, 2))],
                          ),
                          child: Icon(pin ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: const Color(0xFF0D1282), size: 24),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 32),
                  CPPressable(
                    onTap: () async {
                      if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
                        CPToast.warning(ctx, 'Complete transmission data before executing.');
                        return;
                      }
                      HapticFeedback.heavyImpact();
                      try {
                        await _adminRepo.createAnnouncement(
                          title: titleCtrl.text.trim(),
                          body: bodyCtrl.text.trim(),
                          category: category,
                          pinned: pin,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          CPToast.success(context, 'Broadcast globally synced.');
                        }
                        _loadAnnouncements();
                      } catch (_) {
                        if (ctx.mounted) CPToast.error(ctx, 'System malfunction during sync.');
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(color: const Color(0xFF0D1282), border: Border.all(color: const Color(0xFF0D1282), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF0D1282), offset: Offset(4, 4))]),
                      alignment: Alignment.center,
                      child: Text('EXECUTE SYNC', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
