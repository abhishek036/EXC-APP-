import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/utils/webview_platform_initializer.dart';

/// Unified custom video player that handles **both** YouTube URLs
/// and direct video links. All YouTube identity is stripped —
/// no logos, no channel info, no branding. Fully custom controls.
class VideoPlayerPage extends StatefulWidget {
  final String? videoUrl;
  final String? title;
  final String? lectureId;
  final String? summary;
  final String? teacherName;
  final String? subject;

  const VideoPlayerPage({
    super.key,
    this.videoUrl,
    this.title,
    this.lectureId,
    this.summary,
    this.teacherName,
    this.subject,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> with SingleTickerProviderStateMixin, ThemeAware<VideoPlayerPage> {
  // ── YouTube player (iframe) ──────────────────────────────
  YoutubePlayerController? _ytController;
  StreamSubscription<YoutubePlayerValue>? _valueSub;
  StreamSubscription<YoutubeVideoState>? _videoStateSub;

  // ── State ────────────────────────────────────────────────
  bool _isYoutube = false;
  bool _isInitializing = true;
  bool _hasError = false;
  bool _forceExternalFallback = false;
  bool _isMuted = true;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isDraggingSeek = false;
  bool _isBuffering = false;
  String? _fallbackReason;
  String? _youtubeVideoId;

  double _positionSeconds = 0;
  double _durationSeconds = 0;
  double _playbackRate = 1.0;

  Timer? _controlsHideTimer;
  Timer? _embedHealthTimer;
  late AnimationController _controlsFadeController;

  static const List<double> _speedOptions = [
    0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0,
  ];

  // ── Helpers ──────────────────────────────────────────────

  String? _extractYoutubeId(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    // Bare 11-char ID
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(raw)) return raw;

    // Use library helper first
    final fromLib = YoutubePlayerController.convertUrlToId(raw);
    if (fromLib != null && fromLib.length == 11) return fromLib;

    final uri = Uri.tryParse(raw);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    final isYoutubeHost = host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('youtube-nocookie.com');

    if (host.isNotEmpty && !isYoutubeHost) return null;

    // Short links
    if (host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      final candidate = uri.pathSegments.first;
      if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(candidate)) return candidate;
    }

    final path = uri.path;

    // /live/, /shorts/, /embed/
    for (final prefix in ['/live/', '/shorts/', '/embed/']) {
      final match =
          RegExp('$prefix([a-zA-Z0-9_-]{11})').firstMatch(path);
      if (match != null) return match.group(1);
    }

    // ?v= or ?vi=
    final v = uri.queryParameters['v'];
    if (v != null && v.length == 11) return v;
    final vi = uri.queryParameters['vi'];
    if (vi != null && vi.length == 11) return vi;

    return null;
  }

  Uri? _externalVideoUri() {
    final ytId = _youtubeVideoId?.trim();
    if (ytId != null && ytId.isNotEmpty) {
      return Uri.tryParse('https://www.youtube.com/watch?v=$ytId');
    }

    final raw = (widget.videoUrl ?? '').trim();
    if (raw.isEmpty) return null;
    return Uri.tryParse(raw);
  }

  Future<void> _openExternally() async {
    final uri = _externalVideoUri();
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video link is not available.')),
      );
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open external player.')),
      );
    }
  }

  void _switchToExternalFallback(String reason) {
    if (!mounted || _forceExternalFallback) return;
    setState(() {
      _forceExternalFallback = true;
      _fallbackReason = reason;
      _isInitializing = false;
      _hasError = false;
    });
  }

  void _startEmbedHealthWatchdog() {
    // Watchdog removed: It was aggressively forcing external fallback for live streams 
    // (which have 0 duration) or when autoplay was blocked by the browser. 
    // We now provide a manual 'Open in YouTube' button in the info panel instead.
  }

  // ── Lifecycle ────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _controlsFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0, // start visible
    );
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final url = widget.videoUrl ?? '';
    final videoId = _extractYoutubeId(url);

    if (videoId != null) {
      _isYoutube = true;
      _youtubeVideoId = videoId;
      await _initYoutubePlayer(videoId, url);
    } else if (url.trim().isNotEmpty) {
      // Non-YouTube direct link — show fallback (open externally)
      _isYoutube = false;
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _initYoutubePlayer(String videoId, String rawUrl) async {
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

      _bindStreams(controller);

      if (!mounted) {
        await controller.close();
        return;
      }

      setState(() {
        _ytController = controller;
        _isInitializing = false;
        _hasError = false;
        _forceExternalFallback = false;
        _fallbackReason = null;
      });

      // Load after widget mounts the scaffold
      unawaited(_postMountSetup(controller, videoId));
    } catch (e) {
      debugPrint('YouTube init failed: $e');
      if (!mounted) return;
      _switchToExternalFallback(
        'Embedded player initialization failed. Open this lecture in YouTube.',
      );
    }
  }

  Future<void> _postMountSetup(
    YoutubePlayerController controller,
    String videoId,
  ) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      await controller.loadVideoById(videoId: videoId);
      _startEmbedHealthWatchdog();
    } catch (e) {
      debugPrint('Post-mount setup failed: $e');
      _switchToExternalFallback(
        'Video could not be embedded. Open this lecture in YouTube.',
      );
    }
  }

  void _bindStreams(YoutubePlayerController controller) {
    _valueSub?.cancel();
    _videoStateSub?.cancel();

    _valueSub = controller.listen((value) {
      if (!mounted) return;

      final playerState = value.playerState;
      final isPlayingNow = playerState == PlayerState.playing;
      final isBufferingNow = playerState == PlayerState.buffering;
      final shouldForceControls = playerState == PlayerState.paused ||
          playerState == PlayerState.ended ||
          playerState == PlayerState.cued;
      final durationMs = value.metaData.duration.inMilliseconds / 1000;
      final rate = value.playbackRate;

      setState(() {
        _isPlaying = isPlayingNow;
        _isBuffering = isBufferingNow;
        if (durationMs > 0) _durationSeconds = durationMs;
        if (rate > 0) _playbackRate = rate;
        if (shouldForceControls) _setControlsVisible(true);
      });

      if (isPlayingNow && _showControls) {
        _startAutoHideTimer();
      } else if (!isPlayingNow) {
        _controlsHideTimer?.cancel();
      }
    });

    _videoStateSub = controller.videoStateStream.listen((vs) {
      if (!mounted) return;
      setState(() {
        if (!_isDraggingSeek) {
          _positionSeconds = vs.position.inMilliseconds / 1000;
        }
      });
    });
  }

  // ── Controls visibility ──────────────────────────────────

  void _setControlsVisible(bool visible) {
    _showControls = visible;
    if (visible) {
      _controlsFadeController.forward();
    } else {
      _controlsFadeController.reverse();
    }
  }

  void _toggleControlsVisibility() {
    if (_showControls) {
      _setControlsVisible(false);
      _controlsHideTimer?.cancel();
    } else {
      _setControlsVisible(true);
      if (_isPlaying) _startAutoHideTimer();
    }
  }

  void _startAutoHideTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !_isPlaying || _isDraggingSeek) return;
      _setControlsVisible(false);
    });
  }

  // ── Playback actions ─────────────────────────────────────

  Future<void> _togglePlayPause() async {
    final c = _ytController;
    if (c == null) return;
    if (_isPlaying) {
      await c.pauseVideo();
    } else {
      await c.playVideo();
    }
    _setControlsVisible(true);
    if (!_isPlaying) _startAutoHideTimer();
  }

  Future<void> _toggleMute() async {
    final c = _ytController;
    if (c == null) return;
    if (_isMuted) {
      await c.unMute();
      await c.setVolume(85);
    } else {
      await c.mute();
    }
    try {
      final muted = await c.isMuted;
      if (mounted) setState(() => _isMuted = muted);
    } catch (_) {}
  }

  Future<void> _skipBy(double seconds) async {
    final c = _ytController;
    if (c == null || _durationSeconds <= 0) return;
    
    double currentPos = _positionSeconds;
    try {
      currentPos = await c.currentTime;
    } catch (_) {}

    final target = (currentPos + seconds).clamp(0.0, _durationSeconds).toDouble();
    await c.seekTo(seconds: target, allowSeekAhead: true);
    
    if (mounted) {
      setState(() => _positionSeconds = target);
    }
  }

  Future<void> _seekTo(double seconds) async {
    final c = _ytController;
    if (c == null || _durationSeconds <= 0) return;
    final target = seconds.clamp(0.0, _durationSeconds).toDouble();
    await c.seekTo(seconds: target, allowSeekAhead: true);
  }

  Future<void> _setPlaybackRate(double speed) async {
    final c = _ytController;
    if (c == null) return;
    await c.setPlaybackRate(speed);
    if (mounted) setState(() => _playbackRate = speed);
  }

  // ── Formatters & getters ─────────────────────────────────

  String _formatTime(double secondsRaw) {
    final seconds = secondsRaw.round().clamp(0, 864000);
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String get _lectureTitle =>
      (widget.title ?? '').trim().isEmpty ? 'Lecture' : widget.title!.trim();

  String get _summary => (widget.summary ?? '').trim();

  String get _teacherName =>
      (widget.teacherName ?? '').trim().isEmpty
          ? ''
          : widget.teacherName!.trim();

  String get _subjectName =>
      (widget.subject ?? '').trim().isEmpty ? '' : widget.subject!.trim();

  // ── Dispose ──────────────────────────────────────────────

  @override
  void deactivate() {
    _ytController?.pauseVideo();
    super.deactivate();
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    _embedHealthTimer?.cancel();
    _controlsFadeController.dispose();
    _valueSub?.cancel();
    _videoStateSub?.cancel();
    _ytController?.close();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return _buildLoadingScreen();
    if (_forceExternalFallback) {
      return _buildFallback(
        helperMessage: _fallbackReason,
        actionLabel: 'OPEN IN YOUTUBE',
      );
    }
    if (_hasError) return _buildErrorScreen();
    if (!_isYoutube) return _buildFallback();
    if (_ytController == null) return _buildErrorScreen();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            _buildVideoArea(YoutubePlayer(controller: _ytController!)),
            Expanded(child: _buildInfoPanel()),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.moltenAmber,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'LECTURE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Spacer(),
          if (_playbackRate != 1.0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_playbackRate}x',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.moltenAmber,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Video Area with overlay controls ─────────────────────

  Widget _buildVideoArea(Widget player) {
    final sliderMax = _durationSeconds > 0 ? _durationSeconds : 1.0;
    final sliderValue = _positionSeconds.clamp(0.0, sliderMax).toDouble();

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          // ── Actual player (no YouTube UI) ──
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: Transform.scale(
                  scale: 1.25, // Zoom to push YouTube branding completely off-screen
                  child: player,
                ),
              ),
            ),
          ),

          // ── Unified Tap/Controls layer ──
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {}, // Crucial: claims pointer event from DOM on Web
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControlsVisibility,
                onDoubleTapDown: (details) {
                  final width = context.size?.width ?? 400;
                  final tapX = details.localPosition.dx;
                  if (tapX < width / 3) {
                    _skipBy(-10);
                  } else if (tapX > width * 2 / 3) {
                    _skipBy(10);
                  } else {
                    _togglePlayPause();
                  }
                },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Force Hit Testing Layer ──
                  Container(color: Colors.black.withValues(alpha: 0.001)),

                  // ── Buffering indicator ──
                  if (_isBuffering)
                    const Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: AppColors.moltenAmber,
                          strokeWidth: 3,
                        ),
                      ),
                    ),

                  // ── Controls overlay ──
                  FadeTransition(
                    opacity: _controlsFadeController,
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.3, 0.7, 1.0],
                      colors: [
                        Color(0x99000000),
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xCC000000),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // ── Top controls row ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _controlIcon(
                              _isMuted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              _toggleMute,
                            ),
                            _controlIcon(
                              Icons.tune_rounded,
                              _openSettingsSheet,
                            ),
                          ],
                        ),
                      ),

                      // ── Center play/pause + skip ──
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_durationSeconds > 0)
                                _skipButton(Icons.replay_10_rounded, () => _skipBy(-10)),
                              const SizedBox(width: 16),
                              _playPauseButton(),
                              const SizedBox(width: 16),
                              if (_durationSeconds > 0)
                                _skipButton(Icons.forward_10_rounded, () => _skipBy(10)),
                            ],
                          ),
                        ),
                      ),

                      // ── Bottom seek bar or LIVE badge ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: _durationSeconds <= 0
                            ? Row(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(left: 14, bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.coralRed,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.sensors_rounded, color: Colors.white, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          'LIVE STREAM',
                                          style: GoogleFonts.jetBrainsMono(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 7,
                                      ),
                                      overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 14,
                                      ),
                                      activeTrackColor: AppColors.moltenAmber,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: AppColors.moltenAmber,
                                      overlayColor: AppColors.moltenAmber.withValues(alpha: 0.2),
                                    ),
                                    child: Slider(
                                      value: sliderValue,
                                      min: 0,
                                      max: sliderMax,
                                      onChangeStart: (_) {
                                        _isDraggingSeek = true;
                                        _controlsHideTimer?.cancel();
                                      },
                                      onChanged: (v) {
                                        setState(() => _positionSeconds = v);
                                      },
                                      onChangeEnd: (v) async {
                                        _isDraggingSeek = false;
                                        await _seekTo(v);
                                        if (_isPlaying) _startAutoHideTimer();
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: Row(
                                      children: [
                                        Text(
                                          _formatTime(_positionSeconds),
                                          style: GoogleFonts.jetBrainsMono(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatTime(_durationSeconds),
                                          style: GoogleFonts.jetBrainsMono(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ), // Container
              ), // IgnorePointer
            ), // FadeTransition
          ], // Inner Stack children
        ), // Inner Stack
      ), // GestureDetector
    ), // Listener
  ), // Positioned
],
),
);
  }

  Widget _controlIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _skipButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _playPauseButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: _togglePlayPause,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.5),
            border: Border.all(
              color: Colors.white24,
              width: 2,
            ),
          ),
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }

  // ── Info Panel ───────────────────────────────────────────

  Widget _buildInfoPanel() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F14),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              _lectureTitle,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.3,
              ),
            ),

            if (_subjectName.isNotEmpty || _teacherName.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_subjectName.isNotEmpty)
                    _infoPill(Icons.menu_book_rounded, _subjectName),
                  if (_subjectName.isNotEmpty && _teacherName.isNotEmpty)
                    const SizedBox(width: 12),
                  if (_teacherName.isNotEmpty)
                    _infoPill(Icons.person_rounded, _teacherName),
                ],
              ),
            ],

            if (_summary.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUMMARY',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.moltenAmber,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _summary,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Quick speed buttons
            if (_durationSeconds > 0) ...[
              Text(
                'PLAYBACK SPEED',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white38,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _speedOptions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final speed = _speedOptions[i];
                    final isActive = (_playbackRate - speed).abs() < 0.01;
                    return GestureDetector(
                      onTap: () => _setPlaybackRate(speed),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.moltenAmber
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isActive
                                ? AppColors.moltenAmber
                                : Colors.white12,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${speed}x',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isActive ? Colors.black : Colors.white60,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Open in YouTube button
            if (_isYoutube)
              InkWell(
                onTap: _openExternally,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'OPEN IN YOUTUBE',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings bottom sheet ────────────────────────────────

  void _openSettingsSheet() {
    if (_ytController == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111118),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'PLAYBACK SETTINGS',
                  style: GoogleFonts.jetBrainsMono(
                    color: AppColors.moltenAmber,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'SPEED',
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white54,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _speedOptions.map((speed) {
                    final isActive = (_playbackRate - speed).abs() < 0.01;
                    return GestureDetector(
                      onTap: () {
                        _setPlaybackRate(speed);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.moltenAmber
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isActive ? AppColors.moltenAmber : Colors.white12,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          '${speed}x',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isActive ? Colors.black : Colors.white60,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Loading / Error / Fallback screens ───────────────────

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: AppColors.moltenAmber,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'LOADING LECTURE...',
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(
                  Icons.play_disabled_rounded,
                  size: 40,
                  color: Colors.white24,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'UNAVAILABLE',
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This lecture could not be loaded right now.\nPlease try again in a moment.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (_externalVideoUri() != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openExternally,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.moltenAmber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'OPEN IN YOUTUBE',
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallback({
    String? helperMessage,
    String actionLabel = 'OPEN EXTERNALLY',
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          'LECTURE',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white54,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.moltenAmber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.moltenAmber.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.open_in_new_rounded,
                size: 40,
                color: AppColors.moltenAmber,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _lectureTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              helperMessage ??
                  'This content is hosted externally.\nTap below to open it in your browser.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openExternally,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.moltenAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.black, width: 2),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  actionLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

