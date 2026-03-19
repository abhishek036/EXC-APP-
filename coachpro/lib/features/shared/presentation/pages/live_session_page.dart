import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';

class LiveSessionPage extends StatefulWidget {
  const LiveSessionPage({super.key});

  @override
  State<LiveSessionPage> createState() => _LiveSessionPageState();
}

class _LiveSessionPageState extends State<LiveSessionPage> {
  bool _isMicMuted = false;
  bool _isVideoOff = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background for video call
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text('JEE Mains Physics - Live', style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                const Icon(Icons.circle, color: AppColors.error, size: 8),
                const SizedBox(width: 6),
                Text('REC', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.error)),
              ],
            ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(duration: 800.ms),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Main Video Feed (Teacher)
          Positioned.fill(
            child: Container(
              color: CT.textM(context),
              child: const Center(
                child: Icon(Icons.person, size: 200, color: Colors.white12),
              ), // Placeholder for Jitsi/WebRTC view
            ),
          ),
          
          // Participant PiP (Student's own video)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 16,
            child: Container(
              width: 100, height: 140,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CT.onAccent(context).withValues(alpha: 0.2)),
                boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.5), blurRadius: 10)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const Center(child: Icon(Icons.person, size: 60, color: Colors.white24)), // Placeholder
                    if (_isVideoOff) Container(color: Colors.black87, child: const Center(child: Icon(Icons.videocam_off, color: Colors.white))),
                  ],
                ),
              ),
            ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),
          ),
          
          // Viewer count overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(100)),
              child: Row(
                children: [
                  const Icon(Icons.visibility, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('145', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),

          // Bottom Controls Wrapper
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.only(bottom: 32, top: 60, left: 16, right: 16),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mic button
                    _buildControlButton(
                      icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                      color: _isMicMuted ? Colors.white : Colors.white24,
                      iconColor: _isMicMuted ? Colors.black : Colors.white,
                      onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                    ),
                    // Video button
                    _buildControlButton(
                      icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                      color: _isVideoOff ? Colors.white : Colors.white24,
                      iconColor: _isVideoOff ? Colors.black : Colors.white,
                      onTap: () => setState(() => _isVideoOff = !_isVideoOff),
                    ),
                    // Screen share
                    _buildControlButton(
                      icon: Icons.screen_share,
                      color: Colors.white24,
                      iconColor: Colors.white,
                      onTap: () {},
                    ),
                    // Hand raise
                    _buildControlButton(
                      icon: Icons.back_hand,
                      color: Colors.white24,
                      iconColor: Colors.white,
                      onTap: () {},
                    ),
                    // End call
                    _buildControlButton(
                      icon: Icons.call_end,
                      color: AppColors.error,
                      iconColor: Colors.white,
                      onTap: () => Navigator.of(context).pop(),
                      isLarge: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required Color color, required Color iconColor, required VoidCallback onTap, bool isLarge = false}) {
    return CPPressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isLarge ? 18 : 14),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: isLarge ? 28 : 24),
      ),
    );
  }
}
