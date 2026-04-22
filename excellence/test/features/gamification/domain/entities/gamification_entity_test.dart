import 'package:flutter_test/flutter_test.dart';
import 'package:excellence/features/gamification/domain/entities/gamification_entity.dart';

void main() {
  group('XPRecord', () {
    test('equality works with same props', () {
      final record1 = XPRecord(
        id: 'xp_001',
        type: XPActivityType.attendance,
        points: 10,
        description: 'Attended class',
        earnedAt: DateTime(2026, 3, 6),
      );
      final record2 = XPRecord(
        id: 'xp_001',
        type: XPActivityType.attendance,
        points: 10,
        description: 'Attended class',
        earnedAt: DateTime(2026, 3, 6),
      );
      expect(record1, equals(record2));
    });

    test('inequality when id differs', () {
      final record1 = XPRecord(
        id: 'xp_001',
        type: XPActivityType.attendance,
        points: 10,
        description: 'Attended class',
        earnedAt: DateTime(2026, 3, 6),
      );
      final record2 = XPRecord(
        id: 'xp_002',
        type: XPActivityType.attendance,
        points: 10,
        description: 'Attended class',
        earnedAt: DateTime(2026, 3, 6),
      );
      expect(record1, isNot(equals(record2)));
    });
  });

  group('Badge', () {
    test('equality works', () {
      const badge1 = Badge(
        id: 'b1',
        name: 'First Login',
        description: 'Logged in for the first time',
        icon: '🌟',
        isLocked: true,
      );
      const badge2 = Badge(
        id: 'b1',
        name: 'First Login',
        description: 'Logged in for the first time',
        icon: '🌟',
        isLocked: true,
      );
      expect(badge1, equals(badge2));
    });

    test('defaults isLocked to true', () {
      const badge = Badge(
        id: 'b1',
        name: 'Test',
        description: 'desc',
        icon: '🏆',
      );
      expect(badge.isLocked, isTrue);
    });

    test('earnedAt is nullable', () {
      const badge = Badge(
        id: 'b1',
        name: 'Test',
        description: 'desc',
        icon: '🏆',
      );
      expect(badge.earnedAt, isNull);
    });
  });

  group('GamificationProfile', () {
    GamificationProfile makeProfile({
      int totalXP = 2500,
      int level = 5,
      int currentStreak = 7,
      int longestStreak = 14,
      int rank = 3,
    }) {
      return GamificationProfile(
        studentId: 'stu_001',
        studentName: 'Test Student',
        totalXP: totalXP,
        level: level,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        rank: rank,
        badges: const [],
        recentActivity: const [],
      );
    }

    group('xpForNextLevel', () {
      test('calculates correctly at level 0', () {
        final profile = makeProfile(level: 0, totalXP: 0);
        expect(profile.xpForNextLevel, equals(500));
      });

      test('calculates correctly at level 5', () {
        final profile = makeProfile(level: 5);
        expect(profile.xpForNextLevel, equals(3000));
      });

      test('calculates correctly at level 20', () {
        final profile = makeProfile(level: 20, totalXP: 10000);
        expect(profile.xpForNextLevel, equals(10500));
      });
    });

    group('xpInCurrentLevel', () {
      test('correct for fresh level', () {
        final profile = makeProfile(level: 5, totalXP: 2500);
        expect(profile.xpInCurrentLevel, equals(0));
      });

      test('correct for mid-level', () {
        final profile = makeProfile(level: 5, totalXP: 3500);
        expect(profile.xpInCurrentLevel, equals(1000));
      });
    });

    group('levelProgress', () {
      test('returns 0.0 at level start', () {
        final profile = makeProfile(level: 5, totalXP: 2500);
        expect(profile.levelProgress, equals(0.0));
      });

      test('returns 0.5 at midpoint', () {
        final profile = makeProfile(level: 5, totalXP: 4000);
        expect(profile.levelProgress, closeTo(0.5, 0.01));
      });

      test('clamps to 1.0 when exceeding level XP', () {
        // Simulate a case where totalXP far exceeds current level threshold
        final profile = makeProfile(level: 1, totalXP: 5000);
        expect(profile.levelProgress, equals(1.0));
      });

      test('clamps to 0.0 when XP is somehow below level threshold', () {
        // Edge case: level set higher than XP would suggest
        final profile = makeProfile(level: 10, totalXP: 100);
        expect(profile.levelProgress, equals(0.0));
      });
    });

    group('title', () {
      test('returns Newbie for level 0-1', () {
        expect(makeProfile(level: 0).title, equals('Newbie'));
        expect(makeProfile(level: 1).title, equals('Newbie'));
      });

      test('returns Beginner for level 2-3', () {
        expect(makeProfile(level: 2).title, equals('Beginner'));
        expect(makeProfile(level: 3).title, equals('Beginner'));
      });

      test('returns Intermediate for level 4-6', () {
        expect(makeProfile(level: 4).title, equals('Intermediate'));
        expect(makeProfile(level: 6).title, equals('Intermediate'));
      });

      test('returns Advanced for level 7-9', () {
        expect(makeProfile(level: 7).title, equals('Advanced'));
        expect(makeProfile(level: 9).title, equals('Advanced'));
      });

      test('returns Expert for level 10-14', () {
        expect(makeProfile(level: 10).title, equals('Expert'));
        expect(makeProfile(level: 14).title, equals('Expert'));
      });

      test('returns Master for level 15-19', () {
        expect(makeProfile(level: 15).title, equals('Master'));
        expect(makeProfile(level: 19).title, equals('Master'));
      });

      test('returns Legend for level 20+', () {
        expect(makeProfile(level: 20).title, equals('Legend'));
        expect(makeProfile(level: 50).title, equals('Legend'));
      });
    });

    group('equality', () {
      test('two profiles with same data are equal', () {
        final p1 = makeProfile();
        final p2 = makeProfile();
        expect(p1, equals(p2));
      });

      test('profiles with different XP are not equal', () {
        final p1 = makeProfile(totalXP: 1000);
        final p2 = makeProfile(totalXP: 2000);
        expect(p1, isNot(equals(p2)));
      });
    });
  });

  group('LeaderboardEntry', () {
    test('equality works', () {
      const entry1 = LeaderboardEntry(
        studentId: 'stu_001',
        studentName: 'Test',
        totalXP: 500,
        rank: 1,
        level: 3,
        batch: 'JEE 2025',
      );
      const entry2 = LeaderboardEntry(
        studentId: 'stu_001',
        studentName: 'Test',
        totalXP: 500,
        rank: 1,
        level: 3,
        batch: 'JEE 2025',
      );
      expect(entry1, equals(entry2));
    });

    test('avatarUrl is nullable', () {
      const entry = LeaderboardEntry(
        studentId: 'stu_001',
        studentName: 'Test',
        totalXP: 500,
        rank: 1,
        level: 3,
        batch: 'JEE 2025',
      );
      expect(entry.avatarUrl, isNull);
    });
  });

  group('XPActivityType', () {
    test('has all expected types', () {
      expect(XPActivityType.values.length, equals(8));
      expect(
        XPActivityType.values.map((t) => t.name).toList(),
        containsAll([
          'attendance',
          'quizCompleted',
          'quizTopScore',
          'doubtAnswered',
          'assignmentSubmitted',
          'streakBonus',
          'materialViewed',
          'liveSessionAttended',
        ]),
      );
    });
  });
}
