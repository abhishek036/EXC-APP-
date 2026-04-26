import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../../core/constants/app_colors.dart';

/// Locked-down YouTube lecture player.
/// Hides all YouTube branding, share, and related video buttons.
/// Students stay inside the app ecosystem.
class VideoPlayerPage extends StatefulWidget {
  final String? videoUrl;
  final String? title;
  final String? lectureId;
  final String? summary;
  final String? teacherName;
  final String? subject;
  final bool isLive;

  const VideoPlayerPage({
    super.key,
    this.videoUrl,
    this.title,
    this.lectureId,
    this.summary,
    this.teacherName,
    this.subject,
    this.isLive = false,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  YoutubePlayerController? _ctrl;
  bool _loading = true;
  bool _error = false;
  String? _errorMsg;

  static const _bg = Color(0xFF0A0A0F);
  static const _surface = Color(0xFF111118);
  static const _amber = AppColors.moltenAmber;

  // ── Extract video ID from any YouTube URL ───────────────────────────────
  String? _extractId(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();
    // Bare 11-char ID
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(s)) return s;
    // Library helper
    final lib = YoutubePlayerController.convertUrlToId(s);
    if (lib != null) return lib;
    // Manual extraction
    final uri = Uri.tryParse(s);
    if (uri == null) return null;
    final h = uri.host.toLowerCase();
    if (h.contains('youtu.be')) return uri.pathSegments.firstOrNull;
    for (final seg in ['/live/', '/shorts/', '/embed/']) {
      final m = RegExp('$seg([a-zA-Z0-9_-]{11})').firstMatch(uri.path);
      if (m != null) return m.group(1);
    }
    return uri.queryParameters['v'] ?? uri.queryParameters['vi'];
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    final id = _extractId(widget.videoUrl);
    if (id == null) {
      setState(() { _loading = false; _error = true; _errorMsg = 'Invalid or missing YouTube link.'; });
      return;
    }
    _ctrl = YoutubePlayerController.fromVideoId(
      videoId: id,
      autoPlay: true,
      params: const YoutubePlayerParams(
        // ── Lock-down flags ───────────────────────────────────────────────
        showControls: true,          // keep native controls (play/pause/seek)
        showFullscreenButton: true,
        strictRelatedVideos: true,   // hide related videos
        showVideoAnnotations: false, // hide annotations
        enableCaption: false,        // hide cc button
        loop: false,
        mute: false,
        // interfaceLanguage: 'en',  // locale — optional
        // These extra params are injected via playerVars to block UI elements
        color: 'white',
      ),
    );
    _ctrl!.setFullScreenListener((isFullScreen) {
      SystemChrome.setPreferredOrientations(
        isFullScreen
            ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
            : [DeviceOrientation.portraitUp],
      );
    });
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _ctrl?.close();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _buildTopBar(),
          if (_loading) const LinearProgressIndicator(color: _amber, minHeight: 2),
          if (_error) _buildError() else _buildPlayerArea(),
          if (!_error && !_loading) Expanded(child: _buildInfo()),
        ]),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: widget.isLive ? AppColors.coralRed : _amber,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.isLive) ...[
              const Icon(Icons.sensors_rounded, color: Colors.white, size: 10),
              const SizedBox(width: 4),
            ],
            Text(
              widget.isLive ? 'LIVE' : 'LECTURE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10, fontWeight: FontWeight.w900,
                color: widget.isLive ? Colors.white : Colors.black,
                letterSpacing: 1.5,
              ),
            ),
          ]),
        ),
        const Spacer(),
        Text(
          widget.title ?? 'Lecture',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
      ]),
    );
  }

  // ── Player area ─────────────────────────────────────────────────────────

  Widget _buildPlayerArea() {
    if (_loading || _ctrl == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator(color: _amber)),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: YoutubePlayer(
        controller: _ctrl!,
        aspectRatio: 16 / 9,
      ),
    );
  }

  // ── Info panel below player ─────────────────────────────────────────────

  Widget _buildInfo() {
    final title = (widget.title ?? '').isNotEmpty ? widget.title! : 'Lecture';
    final summary = widget.summary ?? '';
    final teacher = widget.teacherName ?? '';
    final subject = widget.subject ?? '';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title
          Text(title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white, fontSize: 20,
              fontWeight: FontWeight.w900, height: 1.3),
          ),

          // Teacher / Subject pills
          if (teacher.isNotEmpty || subject.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 10, children: [
              if (subject.isNotEmpty) _pill(Icons.menu_book_rounded, subject),
              if (teacher.isNotEmpty) _pill(Icons.person_rounded, teacher),
            ]),
          ],

          // Summary
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SUMMARY',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10, fontWeight: FontWeight.w900,
                    color: _amber, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text(summary,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70, fontSize: 13, height: 1.5)),
              ]),
            ),
          ],

          // Notice — no "Open in YouTube" button intentionally
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(children: [
              const Icon(Icons.lock_outline_rounded, color: Colors.white30, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This lecture is exclusive to your batch. Content is locked within the app.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white38, fontSize: 11, height: 1.4),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white54, size: 14),
        const SizedBox(width: 6),
        Text(label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────

  Widget _buildError() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: const Color(0xFF111118),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.broken_image_outlined, color: Colors.white24, size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMsg ?? 'Video unavailable',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 13),
          ),
        ]),
      ),
    );
  }
}
