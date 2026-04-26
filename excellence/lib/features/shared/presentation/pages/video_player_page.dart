import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
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
  YoutubePlayerController? _ytCtrl;
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

    _ytCtrl = YoutubePlayerController.fromVideoId(
      videoId: id,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        loop: false,
        playsInline: true,
        strictRelatedVideos: true,
        showVideoAnnotations: false,
        pointerEvents: PointerEvents.none,
      ),
    );

    _playerSub = _ytCtrl!.stream.listen((value) {
      if (value.playerState == PlayerState.playing) {
        _isPlayingNotifier.value = true;
      } else if (value.playerState == PlayerState.paused || value.playerState == PlayerState.ended) {
        _isPlayingNotifier.value = false;
      }
    });

    setState(() => _loading = false);
  }

  @override
  void deactivate() {
    _ytCtrl?.pauseVideo();
    super.deactivate();
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _ytCtrl?.close();
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
          else if (_videoId != null) ...[
            _buildWebPlayer(_videoId!),
            _buildCustomControls(),
          ]
          else
            _buildSpinner(),
          if (!_loading) Expanded(child: _buildInfo()),
        ]),
      ),
    );
  }

  double _videoDuration = 0.0;
  bool _isZoomed = true;
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(true);
  StreamSubscription? _playerSub;

  Widget _buildWebPlayer(String id) {
    if (_ytCtrl == null) return _buildSpinner();
    return Flexible(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          // Calculate the target height for a 16:9 video
          final h = w * 9 / 16;
          // Absolute pixels to crop from top and bottom to hide YouTube's UI overlays
          const cropSize = 60.0;
          // The total height of the iframe including the cropped areas
          final iframeH = h + (cropSize * 2);
          // The aspect ratio to force the YoutubePlayer to be
          final aspect = w / iframeH;

          return ClipRect(
            child: SizedBox(
              width: w,
              height: h,
              child: OverflowBox(
                minHeight: iframeH,
                maxHeight: iframeH,
                minWidth: w,
                maxWidth: w,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: _isZoomed ? 1.85 : 1.0,
                      child: YoutubePlayer(
                        controller: _ytCtrl!,
                        aspectRatio: aspect,
                      ),
                    ),
                    // Intercept taps to play/pause since PointerEvents.none disables iframe interactions
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () async {
                          if (_isPlayingNotifier.value) {
                            _ytCtrl!.pauseVideo();
                            _isPlayingNotifier.value = false;
                          } else {
                            _ytCtrl!.playVideo();
                            _isPlayingNotifier.value = true;
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomControls() {
    if (_ytCtrl == null) return const SizedBox.shrink();

    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: StreamBuilder<YoutubeVideoState>(
        stream: _ytCtrl!.videoStateStream,
        builder: (context, snapshot) {
          final position = snapshot.data?.position.inSeconds.toDouble() ?? 0.0;
          
          // Fetch duration asynchronously if it's 0
          if (_videoDuration == 0.0) {
            _ytCtrl!.duration.then((dur) {
              if (dur > 0 && mounted) {
                setState(() {
                  _videoDuration = dur;
                });
              }
            });
          }

          final maxDur = _videoDuration > 0 ? _videoDuration : 1.0;
          final validPosition = position.clamp(0.0, maxDur);

          return Row(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _isPlayingNotifier,
                builder: (context, isPlaying, _) {
                  return IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (isPlaying) {
                        _ytCtrl!.pauseVideo();
                        _isPlayingNotifier.value = false;
                      } else {
                        _ytCtrl!.playVideo();
                        _isPlayingNotifier.value = true;
                      }
                    },
                  );
                },
              ),
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: validPosition,
                    max: maxDur,
                    activeColor: _amber,
                    inactiveColor: Colors.white24,
                    onChanged: (val) {
                      _ytCtrl!.seekTo(seconds: val, allowSeekAhead: true);
                    },
                  ),
                ),
              ),
              Text(
                '${_formatTime(snapshot.data?.position ?? Duration.zero)} / ${_formatTime(Duration(seconds: _videoDuration.toInt()))}',
                style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isZoomed ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isZoomed = !_isZoomed;
                  });
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildSpinner() => Flexible(
    child: const AspectRatio(
      aspectRatio: 16 / 9,
      child: Center(child: CircularProgressIndicator(color: _amber)),
    ),
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
    return Flexible(
      child: AspectRatio(
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
    ),
    );
  }
}
