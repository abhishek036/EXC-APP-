import 'dart:async';
import 'dart:convert';

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
  StreamSubscription<YoutubePlayerValue>? _valueSub;
  StreamSubscription<YoutubeVideoState>? _videoStateSub;
  Timer? _controlsHideTimer;

  bool _isInitializing = true;
  bool _hasInitError = false;
  bool _isMuted = true;
  bool _isPlaying = false;
  bool _showVideoControls = true;
  bool _isDraggingSeek = false;

  double _positionSeconds = 0;
  double _durationSeconds = 0;
  double _bufferedFraction = 0;
  double _playbackRate = 1.0;

  String _selectedQuality = 'auto';
  List<String> _availableQualities = const ['auto'];

  static const List<double> _speedOptions =
      <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

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

      _bindControllerStreams(controller);
      await controller.loadVideoById(videoId: resolvedVideoId);
      await _syncMuteState(controller);
      await _loadAvailableQualities(controller);

      if (!mounted) {
        await controller.close();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitializing = false;
        _hasInitError = false;
      });
      _showControlsTemporarily();
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

  void _bindControllerStreams(YoutubePlayerController controller) {
    _valueSub?.cancel();
    _videoStateSub?.cancel();

    _valueSub = controller.listen((value) {
      if (!mounted) return;

      final isPlayingNow = value.playerState == PlayerState.playing;
      final durationFromMeta = value.metaData.duration.inMilliseconds / 1000;
      final playbackRate = value.playbackRate;
      final playbackQuality = (value.playbackQuality ?? '').trim();

      setState(() {
        _isPlaying = isPlayingNow;
        if (durationFromMeta > 0) {
          _durationSeconds = durationFromMeta;
        }
        if (playbackRate > 0) {
          _playbackRate = playbackRate;
        }
        if (playbackQuality.isNotEmpty) {
          _selectedQuality = playbackQuality;
        }
        if (!isPlayingNow) {
          _showVideoControls = true;
        }
      });

      if (isPlayingNow) {
        _startControlsAutoHideTimer();
      } else {
        _controlsHideTimer?.cancel();
      }
    });

    _videoStateSub = controller.videoStateStream.listen((videoState) {
      if (!mounted) return;
      setState(() {
        _bufferedFraction = videoState.loadedFraction.clamp(0.0, 1.0);
        if (!_isDraggingSeek) {
          _positionSeconds = videoState.position.inMilliseconds / 1000;
        }
      });
    });
  }

  Future<void> _syncMuteState(YoutubePlayerController controller) async {
    try {
      final muted = await controller.isMuted;
      if (!mounted) return;
      setState(() => _isMuted = muted);
    } catch (_) {
      // Keep default mute state.
    }
  }

  Future<void> _loadAvailableQualities(YoutubePlayerController controller) async {
    try {
      // ignore: invalid_use_of_internal_member
      final raw = await controller.webViewController.runJavaScriptReturningResult(
        'JSON.stringify(player.getAvailableQualityLevels && player.getAvailableQualityLevels())',
      );

      var rawText = raw.toString().trim();
      if (rawText.isEmpty || rawText == 'null') {
        return;
      }

      if (rawText.startsWith('"') && rawText.endsWith('"') && rawText.length > 1) {
        rawText = rawText.substring(1, rawText.length - 1).replaceAll(r'\"', '"');
      }

      final decoded = jsonDecode(rawText);
      if (decoded is! List) return;

      final levels = decoded
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);

      if (!mounted || levels.isEmpty) return;

      setState(() {
        _availableQualities = ['auto', ...levels.where((q) => q != 'auto')];
      });
    } catch (_) {
      // Ignore quality read failures and keep auto fallback.
    }
  }

  Future<void> _setPlaybackQuality(String quality) async {
    final controller = _controller;
    if (controller == null) return;

    try {
      final qualityArg = quality == 'auto' ? 'default' : quality;
      // ignore: invalid_use_of_internal_member
      await controller.webViewController.runJavaScript(
        "if (player && player.setPlaybackQuality) { player.setPlaybackQuality('$qualityArg'); }",
      );
      if (!mounted) return;
      setState(() => _selectedQuality = quality);
    } catch (_) {
      // Quality can be controlled by YouTube adaptive logic on some sessions.
    }
  }

  void _startControlsAutoHideTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showVideoControls = false);
    });
  }

  void _showControlsTemporarily() {
    if (!mounted) return;
    setState(() => _showVideoControls = true);
    if (_isPlaying) {
      _startControlsAutoHideTimer();
    }
  }

  void _toggleControlsVisibility() {
    if (!mounted) return;
    if (_showVideoControls) {
      _controlsHideTimer?.cancel();
      setState(() => _showVideoControls = false);
    } else {
      _showControlsTemporarily();
    }
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null) return;

    if (_isPlaying) {
      await controller.pauseVideo();
    } else {
      await controller.playVideo();
    }
    _showControlsTemporarily();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;

    if (_isMuted) {
      await controller.unMute();
      await controller.setVolume(85);
    } else {
      await controller.mute();
    }
    await _syncMuteState(controller);
    _showControlsTemporarily();
  }

  Future<void> _skipBy(double seconds) async {
    final controller = _controller;
    if (controller == null || _durationSeconds <= 0) return;

    final target =
      (_positionSeconds + seconds).clamp(0.0, _durationSeconds).toDouble();
    await controller.seekTo(seconds: target, allowSeekAhead: true);
    _showControlsTemporarily();
  }

  Future<void> _seekTo(double seconds) async {
    final controller = _controller;
    if (controller == null || _durationSeconds <= 0) return;

    final target = seconds.clamp(0.0, _durationSeconds).toDouble();
    await controller.seekTo(seconds: target, allowSeekAhead: true);
  }

  Future<void> _setPlaybackRate(double speed) async {
    final controller = _controller;
    if (controller == null) return;

    await controller.setPlaybackRate(speed);
    if (!mounted) return;
    setState(() => _playbackRate = speed);
    _showControlsTemporarily();
  }

  void _openSettingsSheet() {
    if (_controller == null) return;

    _showControlsTemporarily();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Playback Settings',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Speed',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _speedOptions
                      .map(
                        (speed) => ChoiceChip(
                          label: Text('${speed}x'),
                          selected: (_playbackRate - speed).abs() < 0.01,
                          onSelected: (_) => _setPlaybackRate(speed),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Quality',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableQualities
                      .map(
                        (quality) => ChoiceChip(
                          label: Text(_qualityLabel(quality)),
                          selected: _selectedQuality == quality,
                          onSelected: (_) => _setPlaybackQuality(quality),
                        ),
                      )
                      .toList(),
                ),
                if (_availableQualities.length <= 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Quality options may be limited for this stream.',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _qualityLabel(String quality) {
    switch (quality) {
      case 'auto':
        return 'Auto';
      case 'tiny':
        return '144p';
      case 'small':
        return '240p';
      case 'medium':
        return '360p';
      case 'large':
        return '480p';
      case 'hd720':
        return '720p';
      case 'hd1080':
        return '1080p';
      case 'highres':
        return 'High';
      default:
        return quality.toUpperCase();
    }
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

  String get _summary => widget.summary.trim();

  String get _teacherName {
    final raw = widget.teacherName.trim();
    return raw.isEmpty ? 'Teacher' : raw;
  }

  String get _subject {
    final raw = widget.subject.trim();
    return raw.isEmpty ? 'General' : raw;
  }

  String _formatTime(double secondsRaw) {
    final seconds = secondsRaw.round().clamp(0, 864000);
    final d = Duration(seconds: seconds);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secondsPart = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$secondsPart';
    }
    return '${d.inMinutes.toString().padLeft(2, '0')}:$secondsPart';
  }

  Widget _buildVideoOverlay(Widget player) {
    final sliderMax = _durationSeconds > 0 ? _durationSeconds : 1.0;
    final sliderValue = _positionSeconds.clamp(0.0, sliderMax).toDouble();

    return GestureDetector(
      onTap: _toggleControlsVisibility,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Positioned.fill(child: player),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_showVideoControls,
              child: AnimatedOpacity(
                opacity: _showVideoControls ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x77000000),
                        Colors.transparent,
                        Color(0xAA000000),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: _toggleMute,
                            icon: Icon(
                              _isMuted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            onPressed: _openSettingsSheet,
                            icon: const Icon(
                              Icons.settings_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                iconSize: 34,
                                onPressed: () => _skipBy(-10),
                                icon: const Icon(
                                  Icons.replay_10_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _togglePlayPause,
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xB3000000),
                                  ),
                                  child: Icon(
                                    _isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                iconSize: 34,
                                onPressed: () => _skipBy(10),
                                icon: const Icon(
                                  Icons.forward_10_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              minHeight: 2,
                              value: _bufferedFraction,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white54,
                              ),
                            ),
                            Slider(
                              value: sliderValue,
                              min: 0,
                              max: sliderMax,
                              activeColor: AppColors.moltenAmber,
                              inactiveColor: Colors.white30,
                              onChangeStart: (_) {
                                _isDraggingSeek = true;
                                _controlsHideTimer?.cancel();
                              },
                              onChanged: (value) {
                                setState(() => _positionSeconds = value);
                              },
                              onChangeEnd: (value) async {
                                _isDraggingSeek = false;
                                await _seekTo(value);
                                _showControlsTemporarily();
                              },
                            ),
                            Row(
                              children: [
                                Text(
                                  _formatTime(_positionSeconds),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatTime(_durationSeconds),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void deactivate() {
    _controller?.pauseVideo();
    super.deactivate();
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    _valueSub?.cancel();
    _videoStateSub?.cancel();
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
              SizedBox(
                width: double.infinity,
                child: _buildVideoOverlay(player),
              ),
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
