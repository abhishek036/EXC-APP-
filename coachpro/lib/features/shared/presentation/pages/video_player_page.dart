import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        ),
        title: Text('LAB MODULE', 
          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 2)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.cast, color: Colors.white, size: 20)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 24)),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // SIMULATED CINEMATIC FEED
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0A0A0A),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grain_rounded, size: 48, color: Colors.white.withValues(alpha: 0.1)),
                    const SizedBox(height: 24),
                    Text(
                      'ENCODING STREAM...',
                      style: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 10, letterSpacing: 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // NEO-BRUTALIST OVERLAY
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [
                    Colors.black,
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Node
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.moltenAmber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('LIVE', 
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ROTATIONAL DYNAMICS L1',
                          style: GoogleFonts.sora(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PHYSICS • UNIT 4 • BY DR. SHARMA',
                    style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // PROGRESS AXIS
                  Row(
                    children: [
                      Text('12:45', style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(
                                  height: 6, width: double.infinity,
                                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(3)),
                                ),
                                Container(
                                  height: 6, width: constraints.maxWidth * _progress,
                                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3)),
                                ),
                                Positioned(
                                  left: (constraints.maxWidth * _progress) - 8,
                                  child: Container(
                                    height: 16, width: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text('45:00', style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                  
                  const SizedBox(height: 40),

                  // CORE CONTROLS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(onPressed: () {}, icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 28)),
                      const SizedBox(width: 24),
                      CPPressable(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          setState(() => _isPlaying = !_isPlaying);
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 3),
                            boxShadow: const [BoxShadow(color: Colors.white12, blurRadius: 20)],
                          ),
                          child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 48),
                        ),
                      ).animate(target: _isPlaying ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.05, 1.05)),
                      const SizedBox(width: 24),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 28)),
                    ],
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // OPTION STRIP
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _playerAction(Icons.speed_rounded, '1.5X'),
                        _playerAction(Icons.closed_caption_rounded, 'ENG'),
                        _playerAction(Icons.high_quality_rounded, '1080P'),
                        _playerAction(Icons.fullscreen_rounded, 'FULL'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerAction(IconData icon, String label) {
    return TextButton.icon(
      onPressed: () => HapticFeedback.selectionClick(),
      icon: Icon(icon, color: Colors.white70, size: 18),
      label: Text(label, style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}
