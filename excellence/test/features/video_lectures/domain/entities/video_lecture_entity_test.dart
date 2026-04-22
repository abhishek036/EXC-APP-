import 'package:flutter_test/flutter_test.dart';
import 'package:excellence/features/video_lectures/domain/entities/video_lecture_entity.dart';

void main() {
  group('VideoLecture', () {
    test('equality works based on props', () {
      final lecture1 = VideoLecture(
        id: 'vl_001',
        title: 'Kinematics Part 1',
        description: 'Introduction to Kinematics',
        subject: 'Physics',
        chapter: 'Kinematics',
        teacherName: 'Mr. Sharma',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        videoUrl: 'https://example.com/video.mp4',
        duration: const Duration(minutes: 45),
        uploadedAt: DateTime(2026, 3, 1),
        batchId: 'batch_001',
      );
      final lecture2 = VideoLecture(
        id: 'vl_001',
        title: 'Kinematics Part 1',
        description: 'Different description',
        subject: 'Physics',
        chapter: 'Different chapter',
        teacherName: 'Someone else',
        thumbnailUrl: 'different_url',
        videoUrl: 'https://example.com/video.mp4',
        duration: const Duration(minutes: 60),
        uploadedAt: DateTime(2026, 3, 5),
        batchId: 'batch_002',
      );
      // Props are [id, title, subject, videoUrl] — these match
      expect(lecture1, equals(lecture2));
    });

    test('different id means different lecture', () {
      final lecture1 = VideoLecture(
        id: 'vl_001',
        title: 'Test',
        description: 'desc',
        subject: 'Math',
        chapter: 'Ch1',
        teacherName: 'T',
        thumbnailUrl: 'url',
        videoUrl: 'video_url',
        duration: const Duration(minutes: 30),
        uploadedAt: DateTime(2026, 1, 1),
        batchId: 'b1',
      );
      final lecture2 = VideoLecture(
        id: 'vl_002',
        title: 'Test',
        description: 'desc',
        subject: 'Math',
        chapter: 'Ch1',
        teacherName: 'T',
        thumbnailUrl: 'url',
        videoUrl: 'video_url',
        duration: const Duration(minutes: 30),
        uploadedAt: DateTime(2026, 1, 1),
        batchId: 'b1',
      );
      expect(lecture1, isNot(equals(lecture2)));
    });
  });

  group('VideoProgress', () {
    group('progressPercent', () {
      test('returns 0 when nothing watched', () {
        final progress = VideoProgress(
          videoId: 'v1',
          studentId: 's1',
          watchedDuration: Duration.zero,
          totalDuration: const Duration(minutes: 45),
          lastWatchedAt: DateTime(2026, 3, 6),
          isCompleted: false,
        );
        expect(progress.progressPercent, equals(0));
      });

      test('returns 50 for halfway watched', () {
        final progress = VideoProgress(
          videoId: 'v1',
          studentId: 's1',
          watchedDuration: const Duration(minutes: 22, seconds: 30),
          totalDuration: const Duration(minutes: 45),
          lastWatchedAt: DateTime(2026, 3, 6),
          isCompleted: false,
        );
        expect(progress.progressPercent, equals(50.0));
      });

      test('returns 100 when fully watched', () {
        final progress = VideoProgress(
          videoId: 'v1',
          studentId: 's1',
          watchedDuration: const Duration(minutes: 45),
          totalDuration: const Duration(minutes: 45),
          lastWatchedAt: DateTime(2026, 3, 6),
          isCompleted: true,
        );
        expect(progress.progressPercent, equals(100.0));
      });

      test('clamps to 100 when watched exceeds total', () {
        final progress = VideoProgress(
          videoId: 'v1',
          studentId: 's1',
          watchedDuration: const Duration(minutes: 60),
          totalDuration: const Duration(minutes: 45),
          lastWatchedAt: DateTime(2026, 3, 6),
          isCompleted: true,
        );
        expect(progress.progressPercent, equals(100));
      });

      test('returns 0 when total duration is zero', () {
        final progress = VideoProgress(
          videoId: 'v1',
          studentId: 's1',
          watchedDuration: const Duration(minutes: 5),
          totalDuration: Duration.zero,
          lastWatchedAt: DateTime(2026, 3, 6),
          isCompleted: false,
        );
        expect(progress.progressPercent, equals(0));
      });
    });

    group('equality', () {
      test('equality based on props', () {
        final p1 = VideoProgress(
          videoId: 'v1',
          studentId: 's1',
          watchedDuration: const Duration(minutes: 20),
          totalDuration: const Duration(minutes: 45),
          lastWatchedAt: DateTime(2026, 3, 6),
          isCompleted: false,
        );
        final p2 = VideoProgress(
          videoId: 'v1',
          studentId: 's1',
          watchedDuration: const Duration(minutes: 20),
          totalDuration: const Duration(minutes: 30), // different total
          lastWatchedAt: DateTime(2026, 3, 1), // different date
          isCompleted: false,
        );
        // Props are [videoId, studentId, watchedDuration, isCompleted]
        expect(p1, equals(p2));
      });
    });
  });
}
