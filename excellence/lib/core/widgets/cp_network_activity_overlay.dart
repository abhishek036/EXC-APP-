import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../di/injection_container.dart';
import '../services/network_activity_service.dart';

class CPNetworkActivityOverlay extends StatelessWidget {
  final Widget child;

  const CPNetworkActivityOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final activity = sl<NetworkActivityService>();

    return AnimatedBuilder(
      animation: activity,
      builder: (context, _) {
        return Stack(
          children: [
            child,
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedOpacity(
                  opacity: activity.isBusy ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: const LinearProgressIndicator(
                    minHeight: 2.5,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.elitePrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}