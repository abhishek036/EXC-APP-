import 'package:flutter/material.dart';

import '../services/download_registry.dart';

class DownloadStatusIcon extends StatelessWidget {
  final String downloadKey;
  final IconData idleIcon;
  final IconData downloadedIcon;
  final Color idleColor;
  final Color downloadedColor;
  final double size;
  final double spinnerSize;
  final double strokeWidth;

  const DownloadStatusIcon({
    super.key,
    required this.downloadKey,
    required this.idleIcon,
    required this.downloadedIcon,
    required this.idleColor,
    required this.downloadedColor,
    this.size = 24,
    this.spinnerSize = 22,
    this.strokeWidth = 2.2,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DownloadRegistry.instance,
      builder: (context, _) {
        final registry = DownloadRegistry.instance;
        final isDownloading = registry.isDownloading(downloadKey);
        final isDownloaded = registry.isDownloaded(downloadKey);

        if (isDownloading) {
          return SizedBox(
            width: spinnerSize,
            height: spinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              color: idleColor,
            ),
          );
        }

        return Icon(
          isDownloaded ? downloadedIcon : idleIcon,
          color: isDownloaded ? downloadedColor : idleColor,
          size: size,
        );
      },
    );
  }
}
