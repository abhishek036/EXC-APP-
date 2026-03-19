import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/cp_pressable.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  bool _isPlaying = false;
  final double _progress = 0.3; // 30% played

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark mode for video focus
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.cast, color: Colors.white),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Simulated Video Feed
          Positioned.fill(
            child: Container(
              color: const Color(0xFF1A1A1A),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_outline, size: 80, color: Colors.white24),
                    const SizedBox(height: 16),
                    Text(
                      'Lecture: Mechanics L1 - Rotational Motion',
                      style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 16),
                    )
                  ],
                ),
              ),
            ),
          ),
          
          // Overlay UI (Controls)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 60, bottom: 40, left: 24, right: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rotational Dynamics Part 1',
                    style: GoogleFonts.sora(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Physics - 45 mins • Mr. Sharma',
                    style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  
                  // Progress Bar
                  Row(
                    children: [
                      Text('12:45', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                Container(
                                  height: 4, width: double.infinity,
                                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                                ),
                                Container(
                                  height: 4, width: constraints.maxWidth * _progress,
                                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                                ),
                                Positioned(
                                  left: (constraints.maxWidth * _progress) - 6,
                                  top: -4,
                                  child: Container(
                                    height: 12, width: 12,
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  ),
                                ),
                              ],
                            );
                          }
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('45:00', style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Controls Layer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(onPressed: () {}, icon: const Icon(Icons.replay_10, color: Colors.white, size: 28)),
                      IconButton(
                        onPressed: () {}, 
                        icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32)
                      ),
                      CPPressable(
                        onTap: () => setState(() => _isPlaying = !_isPlaying),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36),
                        ),
                      ).animate(target: _isPlaying ? 1 : 0).scaleXY(begin: 1, end: 1.1, duration: 200.ms),
                      IconButton(
                        onPressed: () {}, 
                        icon: const Icon(Icons.skip_next, color: Colors.white, size: 32)
                      ),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.forward_10, color: Colors.white, size: 28)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Bottom options
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.speed, color: Colors.white70, size: 18),
                        label: Text('1.0x', style: GoogleFonts.dmSans(color: Colors.white70, fontWeight: FontWeight.bold)),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.subtitles_outlined, color: Colors.white70, size: 18),
                        label: Text('CC', style: GoogleFonts.dmSans(color: Colors.white70, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.fullscreen, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
