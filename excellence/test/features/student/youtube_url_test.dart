import 'package:flutter_test/flutter_test.dart';

// Helper to test regex logic from the player page without full widget creation
String resolveVideoId(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return '';

  final uri = Uri.tryParse(raw);
  if (uri != null) {
    final host = uri.host.toLowerCase();

    if (host == 'youtu.be' || host == 'www.youtu.be') {
      if (uri.pathSegments.isNotEmpty) {
        final id = uri.pathSegments.first;
        if (_isYoutubeId(id)) return id;
      }
    }

    if (host.contains('youtube.com')) {
      final videoId = uri.queryParameters['v'];
      if (videoId != null && _isYoutubeId(videoId)) return videoId;

      final segments = uri.pathSegments;
      final liveIndex = segments.indexOf('live');
      if (liveIndex >= 0 && segments.length > liveIndex + 1) {
        final id = segments[liveIndex + 1];
        if (_isYoutubeId(id)) return id;
      }

      final shortsIndex = segments.indexOf('shorts');
      if (shortsIndex >= 0 && segments.length > shortsIndex + 1) {
        final id = segments[shortsIndex + 1];
        if (_isYoutubeId(id)) return id;
      }
    }
  }

  if (_isYoutubeId(raw)) return raw;

  return raw;
}

bool _isYoutubeId(String value) => RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(value);

void main() {
  group('YouTube URL Resolution Tests', () {
    test('standard watch?v= link', () {
      expect(resolveVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('short youtu.be link', () {
      expect(resolveVideoId('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('live session link (/live/)', () {
      expect(resolveVideoId('https://www.youtube.com/live/dQw4w9WgXcQ?si=abcdef'), 'dQw4w9WgXcQ');
    });

    test('raw video id', () {
      expect(resolveVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('empty string', () {
      expect(resolveVideoId('   '), '');
    });
  });
}
