import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/teacher/data/repositories/teacher_repository.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/secure_storage_service.dart';
 '../../../../core/theme/theme_aware.dart';
PendingDoubtsPage extends StatefulWidget {
  const PendingDoubtsPage({super.key});

  @override
  State<PendingDoubtsPage> createState() => _PendingDoubtsPageState();
}

class _PendingDoubtsPageState extends State<PendingDoubtsPage> with ThemeAware<PendingDoubtsPage> {
  final _teacherRepo = sl<TeacherRepository>();
  List<Map<String, dynamic>> _doubts = [];
  bool _isLoading = true;
  String? _error;
  String _view = 'pending';

  @override
  void initState() {
    super.initState();
    _loadDoubts();
  }

  Future<void> _loadDoubts() async {
    final token = await sl<SecureStorageService>().getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _doubts = [];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final fetched = _view == 'pending'
          ? await _teacherRepo.getDoubts(status: 'pending')
          : await _teacherRepo.getDoubts();
      final doubts = fetched.where((item) {
        final status = (item['status'] ?? 'pending').toString().toLowerCase();
        if (_view == 'pending') return status == 'pending';
        return status != 'pending';
      }).toList();
      if (!mounted) return;
      setState(() {
        _doubts = doubts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _handleBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    final shellBack = CPRoleShellBack.maybeOf(context);
    if (shellBack != null) {
      shellBack.goBack();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);
    const yellow = Color(0xFFF0DE36);

    return Scaffold(
      backgroundColor: blue,
      appBar: AppBar(
        title: Text(
          _view == 'pending' ? 'PENDING DOUBTS' : 'DOUBT HISTORY',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 22,
          ),
          onPressed: _handleBack,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryBar(blue, surface, yellow),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _buildViewButton(
                    label: 'PENDING',
                    value: 'pending',
                    blue: blue,
                    yellow: yellow,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildViewButton(
                    label: 'HISTORY',
                    value: 'history',
                    blue: blue,
                    yellow: yellow,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: yellow))
                : _error != null
                ? _buildErrorState(blue, surface, yellow)
                : _doubts.isEmpty
                ? _buildEmptyState(blue, yellow)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: _doubts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, i) =>
                        _buildDoubtCard(_doubts[i], i, blue, surface, yellow),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(Color blue, Color surface, Color yellow) {
    final summaryLabel = _view == 'pending'
        ? '${_doubts.length} DOUBTS AWAITING ACTION'
        : '${_doubts.length} RESOLVED/OLDER THREADS';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: yellow,
          border: Border.all(color: blue, width: 3),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.black, size: 24),
            const SizedBox(width: 12),
            Text(
              summaryLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(begin: -0.2),
    );
  }

  Widget _buildViewButton({
    required String label,
    required String value,
    required Color blue,
    required Color yellow,
  }) {
    final selected = _view == value;
    return InkWell(
      onTap: () {
        if (_view == value) return;
        setState(() => _view = value);
        _loadDoubts();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? yellow : Colors.white,
          border: Border.all(color: blue, width: 2.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [BoxShadow(color: blue, offset: const Offset(3, 3))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: blue,
          ),
        ),
      ),
    );
  }

  Widget _buildDoubtCard(
    Map<String, dynamic> d,
    int i,
    Color blue,
    Color surface,
    Color yellow,
  ) {
    final studentName =
        (d['student'] as Map?)?['name']?.toString().toUpperCase() ?? 'STUDENT';
    final studentInitial = studentName.isNotEmpty ? studentName[0] : 'S';
    final batchName =
        (d['batch'] as Map?)?['name']?.toString().toUpperCase() ?? 'BATCH';
    final preview = _buildPreviewText(d);

    String timeAgo = 'JUST NOW';
    final createdAt = d['created_at']?.toString();
    if (createdAt != null && createdAt.isNotEmpty) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) {
          timeAgo = 'JUST NOW';
        } else if (diff.inHours < 1) {
          timeAgo = '${diff.inMinutes}M AGO';
        } else if (diff.inDays < 1) {
          timeAgo = '${diff.inHours}H AGO';
        } else if (diff.inDays < 7) {
          timeAgo = '${diff.inDays}D AGO';
        } else {
          timeAgo = '${dt.day}/${dt.month}/${dt.year}';
        }
      }
    }

    return InkWell(
      onTap: () => _openDoubtChat(d),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: blue, width: 3),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: yellow,
                border: Border.all(color: blue, width: 2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                studentInitial,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: blue,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          studentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: blue.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    batchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: blue.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chat_rounded, color: blue, size: 22),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  String _buildPreviewText(Map<String, dynamic> doubt) {
    final question =
        (doubt['question_text'] ?? doubt['questionText'] ?? '').toString().trim();
    if (question.isEmpty) return 'Open chat';

    final lines = question
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (line.startsWith('[') && line.endsWith(']')) continue;
      if (line.toLowerCase().startsWith('image:')) continue;
      final normalized = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized.isNotEmpty) return normalized;
    }

    return 'Open chat';
  }

  Future<void> _openDoubtChat(Map<String, dynamic> doubt) async {
    final result = await context.pushNamed('doubt-response', extra: doubt);
    if (!mounted) return;
    if (result == true) {
      await _loadDoubts();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Doubt resolved')));
    }
  }

  Widget _btn(
    String label,
    VoidCallback onTap,
    Color bg,
    Color fg,
    bool isPrimary,
    Color blue,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: blue, width: 2.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isPrimary
              ? [BoxShadow(color: blue, offset: const Offset(3, 3))]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color blue, Color yellow) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: yellow,
            border: Border.all(color: blue, width: 3),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.celebration_rounded, size: 48, color: blue),
        ),
        const SizedBox(height: 24),
        Text(
          _view == 'pending' ? 'CLEAN SLATE!' : 'NO HISTORY YET',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _view == 'pending'
              ? 'ALL DOUBTS HAVE BEEN RESOLVED'
              : 'NO RESOLVED/OLDER DOUBTS AVAILABLE',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    ),
  );

  Widget _buildErrorState(Color blue, Color surface, Color yellow) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 48),
        const SizedBox(height: 16),
        Text(
          'ERROR LOADING DOUBTS',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 24),
        _btn('RETRY', _loadDoubts, yellow, blue, true, blue),
      ],
    ),
  );
}

