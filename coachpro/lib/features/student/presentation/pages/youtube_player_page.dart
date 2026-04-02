import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;

  String _resolveVideoId(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return '';

    // Standard convertUrlToId handles watch?v= and youtu.be
    final idFromUrl = YoutubePlayer.convertUrlToId(raw);
    if (idFromUrl != null) return idFromUrl;

    final uri = Uri.tryParse(raw);
    if (uri != null) {
      final path = uri.path;
      final liveMatch = RegExp(r"/live/([a-zA-Z0-9_-]{11})").firstMatch(path);
      if (liveMatch != null) return liveMatch.group(1)!;

      final shortsMatch = RegExp(r"/shorts/([a-zA-Z0-9_-]{11})").firstMatch(path);
      if (shortsMatch != null) return shortsMatch.group(1)!;

      final embedMatch = RegExp(r"/embed/([a-zA-Z0-9_-]{11})").firstMatch(path);
      if (embedMatch != null) return embedMatch.group(1)!;

      final v = uri.queryParameters['v'];
      if (v != null && v.length == 11) return v;
    }

    if (raw.length == 11) return raw;

    return raw;
  }

  @override
  void initState() {
    super.initState();
    final videoId = _resolveVideoId(widget.videoId);
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        isLive: widget.videoId.contains('/live/') || widget.videoId.contains('live=1'),
      ),
    )..addListener(listener);
  }

  void listener() {
    if (_isPlayerReady && mounted && !_controller.value.isFullScreen) {
      setState(() {});
    }
  }

  @override
  void deactivate() {
    _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        player: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: AppColors.moltenAmber,
          progressColors: const ProgressBarColors(
            playedColor: AppColors.moltenAmber,
            handleColor: AppColors.elitePrimary,
          ),
          onReady: () {
            _isPlayerReady = true;
          },
        ),
        builder: (context, player) {
          return Column(
            children: [
              // The player
              player,
              
              const SizedBox(height: 20),
              
              // Video Details Below
              Padding(
                padding: const EdgeInsets.all(16.0),
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              ),
            ],
          );
        },
      ),
    );
  }
}
