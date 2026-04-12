import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/gamification_repository.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'This Week';
  final _repo = sl<GamificationRepository>();

  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboard = [];
  Map<String, dynamic> _myProfile = {
    'name': 'You', 'xp': 0, 'level': 1, 'rank': 0, 'streak': 0, 
    'longestStreak': 0, 'title': 'Beginner', 
    'badges': [], 'recentXP': [],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      _leaderboard = List<Map<String, dynamic>>.from((await _repo.getLeaderboard(period: _selectedPeriod))['list'] ?? []);
      _myProfile = await _repo.getMyProfile();
    } catch (e) {
      // API currently missing: fallback gracefully for UI preservation or show empty
      _leaderboard = [];
    }
    setState(() => _isLoading = false);
  }

  void _onPeriodChanged(String period) {
    setState(() => _selectedPeriod = period);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    final accent = CT.accent(context);

    return Scaffold(
      backgroundColor: CT.bg(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: CT.bg(context),
            elevation: 0,
            floating: true,
            pinned: true,
            expandedHeight: 100,
            title: Text(
              'Leaderboard & XP',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: CT.textH(context)),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: TabBar(
                controller: _tabController,
                labelColor: accent,
                unselectedLabelColor: CT.textS(context),
                indicatorColor: accent,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 14),
                tabs: const [
                  Tab(text: 'Leaderboard'),
                  Tab(text: 'My XP'),
                  Tab(text: 'Badges'),
                ],
              ),
            ),
          ),
        ],
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLeaderboardTab(isDark, accent),
                _buildMyXPTab(isDark, accent),
                _buildBadgesTab(isDark, accent),
              ],
            ),
      ),
    );
  }

  // ── Leaderboard Tab ─────────────────────────────────────────────
  Widget _buildLeaderboardTab(bool isDark, Color accent) {
    return CustomScrollView(
      slivers: [
        // Period selector
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppDimensions.pagePaddingH, AppDimensions.md, AppDimensions.pagePaddingH, AppDimensions.sm),
            child: Row(
              children: ['This Week', 'This Month', 'All Time'].map((period) {
                final isActive = _selectedPeriod == period;
                return Padding(
                  padding: const EdgeInsets.only(right: AppDimensions.sm),
                  child: CPPressable(
                    onTap: () => _onPeriodChanged(period),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? accent : CT.card(context),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        border: Border.all(color: isActive ? accent : CT.border(context)),
                      ),
                      child: Text(
                        period,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : CT.textS(context),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Top 3 podium
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH, vertical: AppDimensions.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildPodiumSlot(_leaderboard[1], 2, isDark, accent, 100),
                const SizedBox(width: 12),
                _buildPodiumSlot(_leaderboard[0], 1, isDark, accent, 130),
                const SizedBox(width: 12),
                _buildPodiumSlot(_leaderboard[2], 3, isDark, accent, 80),
              ],
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
          ),
        ),

        // Remaining list
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePaddingH),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final entry = _leaderboard[index + 3];
                final isMe = entry['rank'] == _myProfile['rank'];
                return _buildLeaderboardRow(entry, isDark, accent, isMe)
                    .animate()
                    .fadeIn(delay: (50 * index).ms, duration: 300.ms)
                    .slideX(begin: 0.05);
              },
              childCount: _leaderboard.length - 3,
            ),
          ),
        ),

        // My position card (sticky at bottom if not in top 10)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    child: Center(
                      child: Text('#${_myProfile['rank']}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Your Position', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: CT.textH(context))),
                      Text('${_myProfile['xp']} XP · Level ${_myProfile['level']} · ${_myProfile['title']}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: CT.textS(context))),
                    ]),
                  ),
                  Icon(Icons.arrow_upward_rounded, color: Colors.green.shade400, size: 20),
                  Text('+2', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.green.shade400)),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms),
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumSlot(Map<String, dynamic> entry, int rank, bool isDark, Color accent, double height) {
    final colors = [Colors.amber, const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];
    final medalColor = colors[rank - 1];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        Container(
          width: rank == 1 ? 64 : 52,
          height: rank == 1 ? 64 : 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [medalColor, medalColor.withValues(alpha: 0.6)]),
            boxShadow: [BoxShadow(color: medalColor.withValues(alpha: 0.3), blurRadius: 12)],
          ),
          child: Center(child: Text(entry['avatar'] as String, style: TextStyle(fontSize: rank == 1 ? 28 : 22))),
        ),
        const SizedBox(height: 8),
        Text(
          (entry['name'] as String).split(' ').first,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: CT.textH(context)),
        ),
        Text('${entry['xp']} XP', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textS(context))),
        const SizedBox(height: 6),
        // Podium bar
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [medalColor.withValues(alpha: 0.8), medalColor.withValues(alpha: 0.3)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Center(
            child: Text('#$rank', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardRow(Map<String, dynamic> entry, bool isDark, Color accent, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.step),
      decoration: BoxDecoration(
        color: isMe ? accent.withValues(alpha: 0.1) : CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        border: Border.all(color: isMe ? accent.withValues(alpha: 0.4) : CT.border(context)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('#${entry['rank']}',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: CT.textS(context))),
          ),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.15)),
            child: Center(child: Text(entry['avatar'] as String, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isMe ? 'You' : entry['name'] as String,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
              Text('Level ${entry['level']} · ${entry['batch']}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: CT.textS(context))),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${entry['xp']} XP', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: accent)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.orange.shade400),
              const SizedBox(width: 2),
              Text('${entry['streak']}d', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textM(context))),
            ]),
          ]),
        ],
      ),
    );
  }

  // ── My XP Tab ──────────────────────────────────────────────────
  Widget _buildMyXPTab(bool isDark, Color accent) {
    final recentXP = _myProfile['recentXP'] as List<Map<String, dynamic>>;
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
      children: [
        // XP Overview card
        CPGlassCard(
          isDark: isDark,
          child: Column(
            children: [
              Row(
                children: [
                  // Level ring
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: 0.65, // 65% to next level
                            strokeWidth: 6,
                            backgroundColor: CT.border(context),
                            valueColor: AlwaysStoppedAnimation(accent),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('${_myProfile['level']}', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: accent)),
                          Text('Level', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: CT.textS(context))),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_myProfile['title'] as String,
                          style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: CT.textH(context))),
                      const SizedBox(height: 4),
                      Text('${_myProfile['xp']} Total XP',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: CT.textS(context))),
                      const SizedBox(height: 8),
                      // XP bar to next level
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 0.65,
                          minHeight: 8,
                          backgroundColor: CT.border(context),
                          valueColor: AlwaysStoppedAnimation(accent),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('325 XP to Level ${(_myProfile['level'] as int) + 1}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textM(context))),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: AppDimensions.lg),

        // Stats row
        Row(
          children: [
            _buildStatChip(Icons.local_fire_department_rounded, '${_myProfile['streak']}d', 'Current\nStreak', Colors.orange, isDark),
            const SizedBox(width: 12),
            _buildStatChip(Icons.emoji_events_rounded, '#${_myProfile['rank']}', 'Weekly\nRank', accent, isDark),
            const SizedBox(width: 12),
            _buildStatChip(Icons.whatshot_rounded, '${_myProfile['longestStreak']}d', 'Longest\nStreak', Colors.red.shade400, isDark),
          ],
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

        const SizedBox(height: AppDimensions.lg),

        // XP Points system
        Text('How to Earn XP', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: CT.textH(context))),
        const SizedBox(height: AppDimensions.sm),
        ...[
          {'action': 'Attend a class', 'points': '+10 XP', 'icon': Icons.school_rounded},
          {'action': 'Complete a quiz', 'points': '+50 XP', 'icon': Icons.quiz_rounded},
          {'action': 'Top scorer bonus', 'points': '+100 XP', 'icon': Icons.star_rounded},
          {'action': 'Submit assignment', 'points': '+20 XP', 'icon': Icons.assignment_turned_in_rounded},
          {'action': 'View study material', 'points': '+5 XP', 'icon': Icons.menu_book_rounded},
          {'action': '7-day streak bonus', 'points': '+70 XP', 'icon': Icons.local_fire_department_rounded},
          {'action': 'Attend live session', 'points': '+30 XP', 'icon': Icons.videocam_rounded},
        ].asMap().entries.map((e) {
          final item = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: CT.card(context),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            ),
            child: Row(children: [
              Icon(item['icon'] as IconData, size: 20, color: accent),
              const SizedBox(width: 12),
              Expanded(child: Text(item['action'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: CT.textH(context)))),
              Text(item['points'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade400)),
            ]),
          ).animate().fadeIn(delay: (100 * e.key).ms);
        }),

        const SizedBox(height: AppDimensions.lg),

        // Recent XP Activity
        Text('Recent Activity', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: CT.textH(context))),
        const SizedBox(height: AppDimensions.sm),
        ...recentXP.asMap().entries.map((e) {
          final item = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CT.card(context),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
              border: Border.all(color: CT.border(context)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getXPIcon(item['type'] as String), size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['desc'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: CT.textH(context))),
                Text(item['time'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textM(context))),
              ])),
              Text('+${item['points']} XP',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade400)),
            ]),
          ).animate().fadeIn(delay: (80 * e.key).ms);
        }),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: CT.textS(context))),
        ]),
      ),
    );
  }

  IconData _getXPIcon(String type) {
    switch (type) {
      case 'attendance': return Icons.school_rounded;
      case 'quiz': return Icons.quiz_rounded;
      case 'bonus': return Icons.star_rounded;
      case 'streak': return Icons.local_fire_department_rounded;
      case 'material': return Icons.menu_book_rounded;
      case 'assignment': return Icons.assignment_turned_in_rounded;
      default: return Icons.emoji_events_rounded;
    }
  }

  // ── Badges Tab ─────────────────────────────────────────────────
  Widget _buildBadgesTab(bool isDark, Color accent) {
    final badges = _myProfile['badges'] as List<Map<String, dynamic>>;
    final earned = badges.where((b) => b['earned'] == true).length;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          child: Row(children: [
            const Text('🏅', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$earned / ${badges.length} Badges Earned',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: CT.textH(context))),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: earned / badges.length,
                  minHeight: 6,
                  backgroundColor: CT.border(context),
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
              const SizedBox(height: 4),
              Text('Keep going! ${badges.length - earned} more to unlock.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: CT.textS(context))),
            ])),
          ]),
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: AppDimensions.lg),

        // Badge grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: badges.length,
          itemBuilder: (context, index) {
            final badge = badges[index];
            final isEarned = badge['earned'] as bool;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isEarned ? accent.withValues(alpha: 0.1) : CT.card(context),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                border: Border.all(
                  color: isEarned ? accent.withValues(alpha: 0.4) : CT.border(context),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    badge['icon'] as String,
                    style: TextStyle(fontSize: 32, color: isEarned ? null : Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    badge['name'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isEarned ? CT.textH(context) : CT.textM(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge['desc'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textM(context)),
                  ),
                  if (!isEarned) ...[
                    const SizedBox(height: 4),
                    Icon(Icons.lock_rounded, size: 14, color: CT.textM(context)),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: (80 * index).ms).scale(begin: const Offset(0.95, 0.95));
          },
        ),
      ],
    );
  }
}
