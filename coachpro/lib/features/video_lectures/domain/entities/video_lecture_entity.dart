import 'package:equatable/equatable.dart';

/// A recorded video lecture.
class VideoLecture extends Equatable {
  final String id;
  final String title;
  final String description;
  final String subject;
  final String chapter;
  final String teacherName;
  final String thumbnailUrl;
  final String videoUrl;
  final Duration duration;
  final DateTime uploadedAt;
  final String batchId;

  const VideoLecture({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.chapter,
    required this.teacherName,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.duration,
    required this.uploadedAt,
    required this.batchId,
  });

  @override
  List<Object?> get props => [id, title, subject, videoUrl];
}

/// Tracks a student's progress for a specific video.
class VideoProgress extends Equatable {
  final String videoId;
  final String studentId;
  final Duration watchedDuration;
  final Duration totalDuration;
  final DateTime lastWatchedAt;
  final bool isCompleted;

  const VideoProgress({
    required this.videoId,
    required this.studentId,
    required this.watchedDuration,
    required this.totalDuration,
    required this.lastWatchedAt,
    required this.isCompleted,
  });

  /// Percentage watched (0–100).
  double get progressPercent {
    if (totalDuration.inSeconds == 0) return 0;
    return (watchedDuration.inSeconds / totalDuration.inSeconds * 100).clamp(0, 100);
  }

  @override
  List<Object?> get props => [videoId, studentId, watchedDuration, isCompleted];
}
