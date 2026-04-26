import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';

/// Locked-down YouTube lecture player using an in-app web view.
/// Hides external navigation and keeps playback inside the app.
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
  InAppWebViewController? _webCtrl;
  String? _videoId;
  bool _loading = true;
  bool _error = false;
  String? _errorMsg;

  static const _bg = Color(0xFF0A0A0F);
  static const _surface = Color(0xFF111118);
  static const _amber = AppColors.moltenAmber;

  // ── Extract video ID ────────────────────────────────────────────────────
  String? _extractId(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();

    final uri = Uri.tryParse(s);
    if (uri != null) {
      final host = uri.host.toLowerCase();

      // https://youtu.be/<id>
      if (host.contains('youtu.be')) {
        final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
        if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(segment)) return segment;
      }

      // https://www.youtube.com/watch?v=<id>
      final qv = uri.queryParameters['v'];
      if (qv != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(qv)) return qv;

      // https://www.youtube.com/embed/<id> or /shorts/<id>
      if (uri.pathSegments.length >= 2) {
        final marker = uri.pathSegments.first.toLowerCase();
        final segment = uri.pathSegments[1];
        if ((marker == 'embed' || marker == 'shorts') &&
            RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(segment)) {
          return segment;
        }
      }
    }

    // Bare 11-char ID
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(s)) return s;
    return null;
  }

  Uri _embedUri(String id) {
    return Uri.https('www.youtube.com', '/embed/$id', {
      'autoplay': '1',
      'playsinline': '1',
      'rel': '0',
      'modestbranding': '1',
      'iv_load_policy': '3',
      'enablejsapi': '1',
      'origin': 'https://www.youtube.com',
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    final id = _extractId(widget.videoUrl);
    if (id == null) {
      setState(() {
        _loading = false;
        _error = true;
        _errorMsg = 'Invalid or missing YouTube link.\nPlease check the URL and try again.';
      });
      return;
    }

    _videoId = id;

    setState(() => _loading = false);
  }

  @override
  void deactivate() {
    _webCtrl?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _webCtrl = null;
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
          if (_error)
            _buildError()
          else if (_videoId != null)
            _buildWebPlayer(_videoId!)
          else
            _buildSpinner(),
          if (!_loading) Expanded(child: _buildInfo()),
        ]),
      ),
    );
  }

  Widget _buildWebPlayer(String id) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          InAppWebView(
            initialData: InAppWebViewInitialData(
              data: '''
                <!DOCTYPE html>
                <html>
                <head>
                  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                  <style>
                    body, html { margin: 0; padding: 0; width: 100%; height: 100%; background-color: #0A0A0F; overflow: hidden; }
                    iframe { width: 100%; height: 100%; border: none; }
                  </style>
                </head>
                <body>
                  <iframe src="https://www.youtube.com/embed/$id?autoplay=1&playsinline=1&rel=0&modestbranding=1&enablejsapi=1&origin=https://excellenceacademy.site" allow="autoplay; fullscreen" allowfullscreen></iframe>
                </body>
                </html>
              ''',
              baseUrl: WebUri.uri(Uri.parse("https://excellenceacademy.site/")),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              iframeAllowFullscreen: true,
              supportZoom: false,
              useShouldOverrideUrlLoading: true,
            ),
            onWebViewCreated: (controller) {
              _webCtrl = controller;
            },
            onLoadStart: (controller, uri) {
              if (!mounted || _error) return;
              setState(() => _loading = true);
            },
            onLoadStop: (controller, uri) {
              if (!mounted || _error) return;
              setState(() => _loading = false);
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final uri = navigationAction.request.url;
              if (uri != null && !uri.toString().contains('youtube.com/embed')) {
                // Prevent navigating away from the embed
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
            onReceivedError: (_, request, error) {
              if (!mounted || _error || !(request.isForMainFrame ?? false)) return;
              setState(() {
                _error = true;
                _loading = false;
                _errorMsg = 'Video playback error (${error.type}). Please try again later.';
              });
            },
            onConsoleMessage: (_, message) {
              if (!mounted || _error) return;
              final text = message.message.toLowerCase();
              if (text.contains('error 153') || text.contains('error 150') || text.contains('playback on other websites')) {
                setState(() {
                  _error = true;
                  _loading = false;
                  _errorMsg = 'This video has embedding disabled.\n\n'
                      'The teacher must open YouTube Studio → Edit Video → '
                      'More Options → enable "Allow embedding".';
                });
              }
            },
          ),
          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(color: _amber, minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildSpinner() => const AspectRatio(
    aspectRatio: 16 / 9,
    child: Center(child: CircularProgressIndicator(color: _amber)),
  );

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
        Flexible(
          child: Text(
            widget.title ?? 'Lecture',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
      ]),
    );
  }

  // ── Info panel ──────────────────────────────────────────────────────────

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
          Text(title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white, fontSize: 20,
              fontWeight: FontWeight.w900, height: 1.3)),

          if (teacher.isNotEmpty || subject.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 8, children: [
              if (subject.isNotEmpty) _pill(Icons.menu_book_rounded, subject),
              if (teacher.isNotEmpty) _pill(Icons.person_rounded, teacher),
            ]),
          ],

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

          const SizedBox(height: 20),

          if (widget.isLive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.coralRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.coralRed.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.sensors_rounded, color: AppColors.coralRed, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('This is a live lecture. Watch in real-time.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.coralRed, fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            ),
            const SizedBox(height: 14),
          ],

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
                    color: Colors.white38, fontSize: 11, height: 1.4)),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMsg ?? 'Video unavailable',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white38, size: 16),
            label: Text('Go Back',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
