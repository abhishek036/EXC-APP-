import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';

class YoutubePlayerPage extends StatefulWidget {
  final String videoId; // The YouTube Video ID or Broadcast ID
  final String title;

  const YoutubePlayerPage({
    super.key,
    required this.videoId,
    required this.title,
  });

  @override
  State<YoutubePlayerPage> createState() => _YoutubePlayerPageState();
}

class _YoutubePlayerPageState extends State<YoutubePlayerPage> {
  YoutubePlayerController? _controller;
  bool _isPlayerReady = false;
  late final String? _resolvedVideoId;
  late final bool _isLiveStream;

  String? _resolveVideoId(String input, {int depth = 0}) {
    if (depth > 3) return null;

    final raw = input.trim();
    if (raw.isEmpty) return null;

    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(raw)) {
      return raw;
    }

    // Standard convertUrlToId handles watch?v= and youtu.be
    final idFromUrl = YoutubePlayer.convertUrlToId(raw);
    if (idFromUrl != null && idFromUrl.length == 11) {
      return idFromUrl;
    }

    final uri = Uri.tryParse(raw);
    if (uri != null) {
      final host = uri.host.toLowerCase();
      final isYoutubeHost =
          host.contains('youtube.com') ||
          host.contains('youtu.be') ||
          host.contains('youtube-nocookie.com');

      if (host.isNotEmpty && !isYoutubeHost) {
        return null;
      }

      if (host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        final candidate = uri.pathSegments.first;
        if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(candidate)) {
          return candidate;
        }
      }

      final path = uri.path;
      final liveMatch =
          RegExp(r"/live/([a-zA-Z0-9_-]{11})").firstMatch(path);
      if (liveMatch != null) return liveMatch.group(1)!;

      final shortsMatch =
          RegExp(r"/shorts/([a-zA-Z0-9_-]{11})").firstMatch(path);
      if (shortsMatch != null) return shortsMatch.group(1)!;

      final embedMatch =
          RegExp(r"/embed/([a-zA-Z0-9_-]{11})").firstMatch(path);
      if (embedMatch != null) return embedMatch.group(1)!;

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
    }

    return null;
  }

  bool _detectLive(String input) {
    final lower = input.toLowerCase();
    return lower.contains('/live/') || lower.contains('live=1');
  }

  Uri _buildPublicYoutubeUrl() {
    final source = widget.videoId.trim();
    final parsed = Uri.tryParse(source);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }
    if (_resolvedVideoId != null) {
      return Uri.parse('https://www.youtube.com/watch?v=$_resolvedVideoId');
    }
    return Uri.parse('https://www.youtube.com');
  }

  Future<void> _openInYoutube() async {
    final webUri = _buildPublicYoutubeUrl();
    final id = _resolvedVideoId;
    final appUri =
        id == null ? null : Uri.parse('youtube://www.youtube.com/watch?v=$id');

    if (appUri != null && await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
      return;
    }
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open this video link.')),
    );
  }

  Future<void> _copyVideoLink() async {
    await Clipboard.setData(ClipboardData(text: _buildPublicYoutubeUrl().toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video link copied.')),
    );
  }

  Widget _buildUnavailablePlayer() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_disabled_rounded, size: 72, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              'Could not load this YouTube link in-app.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open it in YouTube for full controls like quality and captions.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openInYoutube,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open in YouTube'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.moltenAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
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
    _isLiveStream = _detectLive(widget.videoId);

    if (_resolvedVideoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: _resolvedVideoId!,
        flags: YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
          isLive: _isLiveStream,
          disableDragSeek: _isLiveStream,
          forceHD: false,
        ),
      )..addListener(listener);
    }
  }

  void listener() {
    if (_isPlayerReady &&
        mounted &&
        _controller != null &&
        !_controller!.value.isFullScreen) {
      setState(() {});
    }
  }

  @override
  void deactivate() {
    _controller?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller?.removeListener(listener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return _buildUnavailablePlayer();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: YoutubePlayerBuilder(
        onExitFullScreen: () {
          SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        },
        player: YoutubePlayer(
          controller: _controller!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: AppColors.moltenAmber,
          progressColors: const ProgressBarColors(
            playedColor: AppColors.moltenAmber,
            handleColor: AppColors.elitePrimary,
          ),
          topActions: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: _openInYoutube,
              icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
              tooltip: 'Open in YouTube',
            ),
          ],
          bottomActions: [
            const SizedBox(width: 12),
            const CurrentPosition(),
            const SizedBox(width: 8),
            ProgressBar(
              isExpanded: true,
              colors: const ProgressBarColors(
                playedColor: AppColors.moltenAmber,
                handleColor: AppColors.moltenAmber,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(width: 8),
            const RemainingDuration(),
            const PlaybackSpeedButton(),
            const FullScreenButton(),
          ],
          onReady: () {
            if (!mounted) return;
            setState(() {
              _isPlayerReady = true;
            });
          },
        ),
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
                      widget.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.moltenAmber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'YOUTUBE',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (_isLiveStream)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.coralRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'LIVE',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Tip: For advanced options like quality selection, open in the YouTube app.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openInYoutube,
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Open in YouTube'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copyVideoLink,
                            icon: const Icon(Icons.link_rounded),
                            label: const Text('Copy link'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
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
