import 'package:equatable/equatable.dart';

/// XP activity types that earn points.
enum XPActivityType {
  attendance,
  quizCompleted,
  quizTopScore,
  doubtAnswered,
  assignmentSubmitted,
  streakBonus,
  materialViewed,
  liveSessionAttended,
}

/// A single XP earning record.
class XPRecord extends Equatable {
  final String id;
  final XPActivityType type;
  final int points;
  final String description;
  final DateTime earnedAt;

  const XPRecord({
    required this.id,
    required this.type,
    required this.points,
    required this.description,
    required this.earnedAt,
  });

  @override
  List<Object?> get props => [id, type, points, description, earnedAt];
}

/// Badge earned by a student.
class Badge extends Equatable {
  final String id;
  final String name;
  final String description;
  final String icon;
  final DateTime? earnedAt;
  final bool isLocked;

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.earnedAt,
    this.isLocked = true,
  });

  @override
  List<Object?> get props => [id, name, description, icon, earnedAt, isLocked];
}

/// Student's gamification profile snapshot.
class GamificationProfile extends Equatable {
  final String studentId;
  final String studentName;
  final String? avatarUrl;
  final int totalXP;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final int rank;
  final List<Badge> badges;
  final List<XPRecord> recentActivity;

  const GamificationProfile({
    required this.studentId,
    required this.studentName,
    this.avatarUrl,
    required this.totalXP,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
    required this.rank,
    required this.badges,
    required this.recentActivity,
  });

  /// XP needed for next level (each level requires 500 more XP).
  int get xpForNextLevel => (level + 1) * 500;

  /// XP earned in current level.
  int get xpInCurrentLevel => totalXP - (level * 500);

  /// Progress fraction toward next level (0.0 – 1.0).
  double get levelProgress => (xpInCurrentLevel / xpForNextLevel).clamp(0.0, 1.0);

  /// Title based on level.
  String get title {
    if (level >= 20) return 'Legend';
    if (level >= 15) return 'Master';
    if (level >= 10) return 'Expert';
    if (level >= 7) return 'Advanced';
    if (level >= 4) return 'Intermediate';
    if (level >= 2) return 'Beginner';
    return 'Newbie';
  }

  @override
  List<Object?> get props => [
        studentId,
        totalXP,
        level,
        currentStreak,
        longestStreak,
        rank,
        badges,
        recentActivity,
      ];
}

/// A single entry on the leaderboard.
class LeaderboardEntry extends Equatable {
  final String studentId;
  final String studentName;
  final String? avatarUrl;
  final int totalXP;
  final int rank;
  final int level;
  final String batch;

  const LeaderboardEntry({
    required this.studentId,
    required this.studentName,
    this.avatarUrl,
    required this.totalXP,
    required this.rank,
    required this.level,
    required this.batch,
  });

  @override
  List<Object?> get props => [studentId, totalXP, rank, level, batch];
}
