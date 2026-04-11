import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/webview_platform_initializer.dart';

class YoutubePlayerPage extends StatefulWidget {
  final String videoId;
  final String title;
  final String summary;
  final String teacherName;
  final String subject;

  const YoutubePlayerPage({
    super.key,
    required this.videoId,
    required this.title,
    this.summary = '',
    this.teacherName = '',
    this.subject = '',
  });

  @override
  State<YoutubePlayerPage> createState() => _YoutubePlayerPageState();
}

class _YoutubePlayerPageState extends State<YoutubePlayerPage> {
  YoutubePlayerController? _controller;
  bool _isInitializing = true;
  bool _hasInitError = false;
  bool _isMuted = true;
  late final String? _resolvedVideoId;

  String? _resolveVideoId(String input, {int depth = 0}) {
    if (depth > 3) return null;

    final raw = input.trim();
    if (raw.isEmpty) return null;

    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(raw)) {
      return raw;
    }

    final idFromUrl = YoutubePlayerController.convertUrlToId(raw);
    if (idFromUrl != null && idFromUrl.length == 11) {
      return idFromUrl;
    }

    final uri = Uri.tryParse(raw);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    final isYoutubeHost =
        host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('youtube-nocookie.com');

    if (host.isNotEmpty && !isYoutubeHost) return null;

    if (host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      final candidate = uri.pathSegments.first;
      if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(candidate)) {
        return candidate;
      }
    }

    final path = uri.path;

    final liveMatch = RegExp(r'/live/([a-zA-Z0-9_-]{11})').firstMatch(path);
    if (liveMatch != null) return liveMatch.group(1);

    final shortsMatch = RegExp(r'/shorts/([a-zA-Z0-9_-]{11})').firstMatch(path);
    if (shortsMatch != null) return shortsMatch.group(1);

    final embedMatch = RegExp(r'/embed/([a-zA-Z0-9_-]{11})').firstMatch(path);
    if (embedMatch != null) return embedMatch.group(1);

    final v = uri.queryParameters['v'];
    if (v != null && v.length == 11) return v;

    final vi = uri.queryParameters['vi'];
    if (vi != null && vi.length == 11) return vi;

    final nested = uri.queryParameters['u'];
    if (nested != null && nested.isNotEmpty) {
      final decoded = Uri.decodeComponent(nested);
      final nestedUrl = decoded.startsWith('http')
          ? decoded
          : 'https://www.youtube.com$decoded';
      final nestedId = _resolveVideoId(nestedUrl, depth: depth + 1);
      if (nestedId != null) return nestedId;
    }

    return null;
  }

  Widget _buildUnavailablePlayer() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.play_disabled_rounded,
              size: 72,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load this lecture right now.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again in a moment.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _resolvedVideoId = _resolveVideoId(widget.videoId);

    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final resolvedVideoId = _resolvedVideoId;

    if (resolvedVideoId == null) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _hasInitError = true;
      });
      return;
    }

    try {
      await ensureWebViewPlatformInitialized();

      final controller = YoutubePlayerController(
        params: const YoutubePlayerParams(
          mute: true,
          showControls: false,
          showFullscreenButton: false,
          pointerEvents: PointerEvents.none,
          enableKeyboard: false,
          strictRelatedVideos: true,
          enableCaption: false,
          showVideoAnnotations: false,
          loop: false,
        ),
      );

      controller.setFullScreenListener((isFullScreen) {
        if (!isFullScreen) {
          SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        }
      });
      controller.loadVideoById(videoId: resolvedVideoId);

      if (!mounted) {
        controller.close();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitializing = false;
        _hasInitError = false;
      });
    } catch (e, st) {
      debugPrint('YouTube player initialization failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _controller = null;
        _isInitializing = false;
        _hasInitError = true;
      });
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;

    if (_isMuted) {
      await controller.unMute();
      await controller.setVolume(85);
      await controller.playVideo();
    } else {
      await controller.mute();
    }

    if (!mounted) return;
    setState(() => _isMuted = !_isMuted);
  }

  Widget _buildLoadingPlayer() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.moltenAmber,
        ),
      ),
    );
  }

  String get _lectureTitle {
    final raw = widget.title.trim();
    return raw.isEmpty ? 'Lecture' : raw;
  }

  String get _summary {
    return widget.summary.trim();
  }

  String get _teacherName {
    final raw = widget.teacherName.trim();
    return raw.isEmpty ? 'Teacher' : raw;
  }

  String get _subject {
    final raw = widget.subject.trim();
    return raw.isEmpty ? 'General' : raw;
  }

  @override
  void deactivate() {
    _controller?.pauseVideo();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _buildLoadingPlayer();
    }

    if (_controller == null || _hasInitError) {
      return _buildUnavailablePlayer();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: YoutubePlayerScaffold(
        controller: _controller!,
        aspectRatio: 16 / 9,
        builder: (context, player) {
          return ListView(
            children: [
              player,
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lectureTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _toggleMute,
                        icon: Icon(
                          _isMuted
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          size: 16,
                        ),
                        label: Text(_isMuted ? 'Enable Sound' : 'Mute Sound'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    if (_summary.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Summary',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.moltenAmber,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _summary,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          color: Colors.white60,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _teacherName,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white60,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _subject,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
