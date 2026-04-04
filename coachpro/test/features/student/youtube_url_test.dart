import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// Helper to test regex logic from the player page without full widget creation
String resolveVideoId(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return '';

  // Standard convertUrlToId handles watch?v= and youtu.be
  final idFromUrl = YoutubePlayer.convertUrlToId(raw);
  if (idFromUrl != null) return idFromUrl;

  // Handle /live/ links specifically
  final liveMatch = RegExp(r"youtube\.com/live/([a-zA-Z0-9_-]{11})").firstMatch(raw);
  if (liveMatch != null) return liveMatch.group(1)!;

  // Handle other common patterns if needed
  if (raw.length == 11) return raw;
  
  return raw;
}

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
