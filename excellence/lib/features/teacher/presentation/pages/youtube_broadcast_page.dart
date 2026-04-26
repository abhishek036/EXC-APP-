import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/teacher_repository.dart';
import '../../../../core/theme/theme_aware.dart';

// ─────────────────────────────────────────────────────────────────────────────
// YoutubeBroadcastPage — In-App Broadcasting Studio
// Uses apivideo_live_stream to push RTMP to YouTube Live without OBS.
// ─────────────────────────────────────────────────────────────────────────────
class YoutubeBroadcastPage extends StatefulWidget {
  final String batchId;
  const YoutubeBroadcastPage({super.key, required this.batchId});

  @override
  State<YoutubeBroadcastPage> createState() => _YoutubeBroadcastPageState();
}

class _YoutubeBroadcastPageState extends State<YoutubeBroadcastPage>
    with ThemeAware<YoutubeBroadcastPage>, TickerProviderStateMixin {

  // ── Repo & Controller ────────────────────────────────────────────────────
  final _repo = sl<TeacherRepository>();
  ApiVideoLiveStreamController? _controller;

  // ── State Flags ──────────────────────────────────────────────────────────
  bool _controllerReady = false; // controller created, preview widget can render
  bool _isInit          = false; // startPreview() succeeded
  bool _isStreaming     = false;
  bool _isLoading       = false;
  bool _isMuted         = false;
  bool _isFrontCamera   = false;
  String? _initError;
  String? _watchUrl;


  // ── Stream Metadata ──────────────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  Timer? _timeoutTimer;
  Timer? _liveDurationTimer;
  Duration _liveDuration = Duration.zero;

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double>   _pulseAnim;
  late Animation<double>   _fadeAnim;

  // ── Palette (dark studio theme) ──────────────────────────────────────────
  static const _bg        = Color(0xFF0A0A0A);
  static const _surface   = Color(0xFF161616);
  static const _border    = Color(0xFF2A2A2A);
  static const _liveRed   = Color(0xFFE53935);
  static const _gold      = AppColors.moltenAmber;
  static const _blue      = AppColors.elitePrimary;
  static const _white     = Colors.white;
  static const _white60   = Colors.white60;
  static const _white30   = Colors.white30;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Pulse animation for the LIVE badge
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Fade in animation for UI
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _initCamera();
  }

  // ── Permission Check ─────────────────────────────────────────────────────
  Future<bool> _requestPermissions() async {
    final camera = await Permission.camera.request();
    final mic    = await Permission.microphone.request();

    if (camera.isPermanentlyDenied || mic.isPermanentlyDenied) {
      // User tapped "Never ask again" — send them to system settings
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _border),
            ),
            title: Text('Permissions Required',
              style: GoogleFonts.plusJakartaSans(
                color: _white, fontWeight: FontWeight.w800)),
            content: Text(
              'Camera and Microphone access were denied.\n\n'
              'Please go to App Settings → Permissions and enable both.',
              style: GoogleFonts.plusJakartaSans(color: _white60, fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                  style: GoogleFonts.plusJakartaSans(color: _white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _blue),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await openAppSettings();
                },
                child: Text('Open Settings',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }
      return false;
    }

    return camera.isGranted && mic.isGranted;
  }

  // ── Camera Init ──────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    // Reset state
    if (mounted) {
      setState(() {
        _initError       = null;
        _isInit          = false;
        _controllerReady = false;
      });
    }

    // ── Step 1: Request runtime permissions ────────────────────────────────
    final granted = await _requestPermissions();
    if (!granted) {
      if (mounted) {
        setState(() => _initError =
          'Camera & Microphone permissions are required to start a live stream.');
      }
      return;
    }

    // ── Step 2: Tear down any stale controller ─────────────────────────────
    if (_controller != null) {
      try { await _controller!.dispose(); } catch (_) {}
      _controller = null;
    }

    // ── Step 3: Create controller ──────────────────────────────────────────
    _controller = ApiVideoLiveStreamController(
      initialAudioConfig: AudioConfig(bitrate: 128000),
      initialVideoConfig: VideoConfig.withDefaultBitrate(
        resolution: Resolution.RESOLUTION_720,
      ),
      onConnectionSuccess: _onConnected,
      onConnectionFailed:  _onConnectionFailed,
      onDisconnection:     _onDisconnected,
    );

    // Show preview widget immediately so it can register the widget listener.
    if (mounted) setState(() => _controllerReady = true);

    // ── Step 4: Call initialize() AFTER the preview widget is in the tree ──
    // initialize() registers the platform texture, sets up events, configures
    // camera/audio, and calls startPreview() internally.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _controller == null) return;
      try {
        await _controller!.initialize();
        if (mounted) {
          setState(() => _isInit = true);
          _fadeCtrl.forward();
        }
      } catch (e) {
        if (mounted) setState(() => _initError = e.toString());
      }
    });
  }

  // ── RTMP Callbacks ───────────────────────────────────────────────────────
  void _onConnected() {
    _timeoutTimer?.cancel();
    if (!mounted) return;
    setState(() { _isStreaming = true; _isLoading = false; });
    _startLiveTimer();
    _showSnack('🔴 You are LIVE on YouTube!', _liveRed);
  }

  void _onConnectionFailed(String err) {
    _timeoutTimer?.cancel();
    if (!mounted) return;
    setState(() { _isStreaming = false; _isLoading = false; });
    _showSnack('Connection failed: $err', _liveRed, duration: 8);
  }

  void _onDisconnected() {
    _timeoutTimer?.cancel();
    _liveDurationTimer?.cancel();
    if (!mounted) return;
    setState(() { _isStreaming = false; _liveDuration = Duration.zero; });
  }

  // ── Go Live ──────────────────────────────────────────────────────────────
  Future<void> _goLive() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showSnack('Please enter a stream title.', _liveRed);
      return;
    }
    if (mounted) setState(() => _isLoading = true);

    try {
      final result = await _repo.createYoutubeLiveStream(
        title:         title,
        description:   _descCtrl.text.trim(),
        privacyStatus: 'unlisted',
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception(
          'YouTube API timed out. Check your internet connection.'),
      );

      final streamKey = (result['streamKey'] ?? result['stream_key'])?.toString();
      final rtmpUrl   = (result['streamUrl'] ?? result['rtmpUrl'] ??
                         'rtmp://a.rtmp.youtube.com/live2').toString();
      _watchUrl = result['watchUrl']?.toString();

      if (streamKey == null || streamKey.isEmpty) {
        throw Exception('No stream key returned. Re-authenticate YouTube in Settings.');
      }

      // 45-second RTMP connection timeout guard
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 45), () {
        if (mounted && _isLoading && !_isStreaming) {
          setState(() => _isLoading = false);
          _showSnack(
            'RTMP connection timed out. Verify YouTube OAuth & stable internet.',
            _liveRed, duration: 10);
        }
      });

      await _controller!.startStreaming(streamKey: streamKey, url: rtmpUrl);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack(e.toString().replaceFirst('Exception: ', ''), _liveRed, duration: 6);
      }
    }
  }

  // ── End Stream ───────────────────────────────────────────────────────────
  Future<void> _endStream() async {
    final confirm = await _showConfirmDialog(
      'End Live Stream?',
      'This will disconnect the broadcast from YouTube Live.',
    );
    if (confirm != true) return;
    _liveDurationTimer?.cancel();
    await _controller?.stopStreaming();
    if (mounted) setState(() { _isStreaming = false; _liveDuration = Duration.zero; });
  }

  // ── Camera / Mic ─────────────────────────────────────────────────────────
  Future<void> _flipCamera() async {
    await _controller?.switchCamera();
    if (mounted) setState(() => _isFrontCamera = !_isFrontCamera);
  }

  Future<void> _toggleMic() async {
    await _controller?.toggleMute();
    if (mounted) setState(() => _isMuted = !_isMuted);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  void _startLiveTimer() {
    _liveDurationTimer?.cancel();
    _liveDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _liveDuration += const Duration(seconds: 1));
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _showSnack(String msg, Color bg, {int duration = 4}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.plusJakartaSans(color: _white, fontSize: 13)),
      backgroundColor: bg,
      duration: Duration(seconds: duration),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  Future<bool?> _showConfirmDialog(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border),
        ),
        title: Text(title, style: GoogleFonts.plusJakartaSans(color: _white, fontWeight: FontWeight.w800)),
        content: Text(body, style: GoogleFonts.plusJakartaSans(color: _white60, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: _white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _liveRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('End Stream', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _liveDurationTimer?.cancel();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    if (_controller != null) {
      if (_isStreaming) {
        _controller!.stopStreaming();
      }
      _controller!.dispose();
    }
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark));
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_initError != null)    return _buildErrorScreen();
    // Controller is ready: render the studio (with loading overlay if preview
    // hasn't started yet, so ApiVideoCameraPreview can attach to the texture).
    if (_controllerReady)      return _buildStudio();
    return _buildLoadingScreen();
  }

  // ── Loading ───────────────────────────────────────────────────────────────
  Widget _buildLoadingScreen() => Scaffold(
    backgroundColor: _bg,
    body: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
          width: 52, height: 52,
          child: CircularProgressIndicator(color: _gold, strokeWidth: 3),
        ),
        const SizedBox(height: 20),
        Text('Initialising Camera…',
          style: GoogleFonts.plusJakartaSans(color: _white60, fontSize: 14)),
      ]),
    ),
  );

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildErrorScreen() => Scaffold(
    backgroundColor: _bg,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _liveRed.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: _liveRed.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.videocam_off_rounded, color: _liveRed, size: 48),
          ),
          const SizedBox(height: 28),
          Text('Camera Unavailable',
            style: GoogleFonts.plusJakartaSans(
              color: _white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(
            'Please grant Camera & Microphone permissions, then retry.\n\n${_initError!}',
            style: GoogleFonts.plusJakartaSans(color: _white60, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _StudioButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            color: _gold,
            onTap: () { setState(() => _initError = null); _initCamera(); },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => GoRouter.of(context).canPop()
                ? GoRouter.of(context).pop()
                : GoRouter.of(context).go('/teacher'),
            child: Text('Go Back',
              style: GoogleFonts.plusJakartaSans(color: _white30, fontSize: 14)),
          ),
        ]),
      ),
    ),
  );

  // ── Main Studio ───────────────────────────────────────────────────────────
  Widget _buildStudio() {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [

        // ── Camera Preview ────────────────────────────────────────────────
        // Rendered first so the texture surface exists before startPreview()
        Positioned.fill(
          child: ApiVideoCameraPreview(controller: _controller!)),

        // ── Preview loading overlay ───────────────────────────────────────
        // Shown while startPreview() is in progress (between _controllerReady
        // and _isInit). Hides once the camera feed is live.
        if (!_isInit)
          Positioned.fill(
            child: Container(
              color: _bg,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(
                    width: 48, height: 48,
                    child: CircularProgressIndicator(color: _gold, strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 16),
                  Text('Starting camera…',
                    style: GoogleFonts.plusJakartaSans(
                      color: _white60, fontSize: 14)),
                ]),
              ),
            ),
          ),


        // ── Gradient vignette top ─────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0, height: 200,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC000000), Colors.transparent],
              ),
            ),
          ),
        ),

        // ── Gradient vignette bottom ──────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0, height: 320,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xF0000000), Colors.transparent],
              ),
            ),
          ),
        ),

        // ── SafeArea Overlay ──────────────────────────────────────────────
        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(children: [

              // ── Top Bar ────────────────────────────────────────────────
              _buildTopBar(),

              const Spacer(),

              // ── Bottom Panel ───────────────────────────────────────────
              _buildBottomPanel(),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [

        // Back button
        _IconCircle(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => GoRouter.of(context).canPop()
              ? GoRouter.of(context).pop()
              : GoRouter.of(context).go('/teacher'),
        ),

        const SizedBox(width: 12),

        // Studio label
        Expanded(
          child: Text('BROADCASTING STUDIO',
            style: GoogleFonts.plusJakartaSans(
              color: _white, fontWeight: FontWeight.w900,
              fontSize: 14, letterSpacing: 1.5)),
        ),

        // LIVE badge (visible when streaming)
        if (_isStreaming) ...[
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Opacity(opacity: _pulseAnim.value, child: child!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _liveRed,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: _white, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('LIVE',
                  style: GoogleFonts.plusJakartaSans(
                    color: _white, fontWeight: FontWeight.w900,
                    fontSize: 13, letterSpacing: 1)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // Duration counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _border),
            ),
            child: Text(
              _formatDuration(_liveDuration),
              style: GoogleFonts.plusJakartaSans(
                color: _white, fontWeight: FontWeight.w700,
                fontSize: 13, fontFeatures: [const FontFeature.tabularFigures()]),
            ),
          ),
        ],

        // Watch link button (visible when streaming)
        if (_isStreaming && _watchUrl != null) ...[
          const SizedBox(width: 8),
          _IconCircle(
            icon: Icons.open_in_new_rounded,
            color: _gold,
            onTap: () => _showSnack('YouTube link: $_watchUrl', _blue),
          ),
        ],
      ]),
    );
  }

  // ── Bottom Panel ──────────────────────────────────────────────────────────
  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: _border, width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Drag handle
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: _border, borderRadius: BorderRadius.circular(2)),
        ),

        // Pre-stream form (title + description)
        if (!_isStreaming) ...[
          _buildTextField(
            controller: _titleCtrl,
            hint:       'Stream Title (e.g. Physics Chapter 12)',
            icon:       Icons.title_rounded,
          ),
          const SizedBox(height: 10),
          _buildTextField(
            controller:   _descCtrl,
            hint:         'Description (Optional)',
            icon:         Icons.description_outlined,
            maxLines:     2,
          ),
          const SizedBox(height: 20),
        ],

        // Post-stream info row
        if (_isStreaming) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _liveRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _liveRed.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Opacity(opacity: _pulseAnim.value, child: child!),
                child: Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(
                    color: _liveRed, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _titleCtrl.text.isEmpty ? 'Live Session' : _titleCtrl.text,
                  style: GoogleFonts.plusJakartaSans(
                    color: _white, fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ],

        // Controls row
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [

          // Flip camera
          _ControlChip(
            icon: _isFrontCamera
                ? Icons.camera_front_rounded
                : Icons.camera_rear_rounded,
            label: 'Flip',
            onTap: _flipCamera,
          ),

          const SizedBox(width: 8),

          // Main CTA — GO LIVE / END STREAM
          Expanded(child: _buildMainCta()),

          const SizedBox(width: 8),

          // Mic toggle
          _ControlChip(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _isMuted ? 'Unmute' : 'Mute',
            color: _isMuted ? _liveRed : null,
            onTap: _toggleMic,
          ),
        ]),
      ]),
    );
  }

  // ── Main CTA button ───────────────────────────────────────────────────────
  Widget _buildMainCta() {
    if (_isStreaming) {
      return _StudioButton(
        label: 'End Stream',
        icon:  Icons.stop_circle_rounded,
        color: _liveRed,
        onTap: _endStream,
      );
    }
    return _StudioButton(
      label:     _isLoading ? 'Connecting…' : 'Go Live',
      icon:      _isLoading ? null : Icons.play_circle_fill_rounded,
      color:     _blue,
      isLoading: _isLoading,
      onTap:     _isLoading ? null : _goLive,
    );
  }

  // ── Text Field ────────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Theme(
        data: ThemeData.dark().copyWith(
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: _gold,
            selectionColor: _gold.withValues(alpha: 0.3),
            selectionHandleColor: _gold,
          ),
        ),
        child: TextField(
          controller: controller,
          maxLines:   maxLines,
          cursorColor: _gold,
          style: GoogleFonts.plusJakartaSans(
            color: _white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText:        hint,
            hintStyle:       GoogleFonts.plusJakartaSans(color: _white30, fontSize: 14),
            prefixIcon:      Icon(icon, color: _white60, size: 20),
            border:          InputBorder.none,
            contentPadding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Round icon button for the top bar
class _IconCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  const _IconCircle({required this.icon, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 18),
      ),
    );
  }
}

/// Square control chip (Flip / Mic)
class _ControlChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback? onTap;
  final Color? color;
  const _ControlChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color?.withValues(alpha: 0.6) ?? const Color(0xFF2A2A2A)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color ?? Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(label,
            style: GoogleFonts.plusJakartaSans(
              color: color ?? Colors.white60, fontSize: 10,
              fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// Full-width studio action button
class _StudioButton extends StatelessWidget {
  final String     label;
  final IconData?  icon;
  final Color      color;
  final VoidCallback? onTap;
  final bool       isLoading;

  const _StudioButton({
    required this.label,
    required this.color,
    this.icon,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: onTap == null ? color.withValues(alpha: 0.5) : color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap == null
              ? null
              : [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (isLoading) ...[
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5)),
            const SizedBox(width: 10),
          ] else if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
          ],
          Text(label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.5,
            )),
        ]),
      ),
    );
  }
}
