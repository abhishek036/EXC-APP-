import 'package:flutter_test/flutter_test.dart';
import 'package:coachpro/core/models/quiz_model.dart';

void main() {
  group('QuizModel', () {
    test('fromFirestore maps values and computes derived fields', () {
      final model = QuizModel.fromFirestore(
        {
          'title': 'Weekly Quiz',
          'batchId': 'batch-1',
          'batchName': 'Batch A',
          'subject': 'Math',
          'teacherId': 'teacher-1',
          'teacherName': 'Riya',
          'timeLimit': 125,
          'questions': [
            {
              'question': '2 + 2 = ?',
              'options': ['3', '4', '5'],
              'correctIndex': 1,
            },
            {
              'question': '3 + 3 = ?',
              'options': ['5', '6', '7'],
              'correctIndex': 1,
            },
          ],
          'isPublished': true,
          'totalAttempts': 12,
          'createdAt': '2026-04-01T08:00:00.000Z',
        },
        'quiz-1',
      );

      expect(model.id, 'quiz-1');
      expect(model.title, 'Weekly Quiz');
      expect(model.questionCount, 2);
      expect(model.timeLimitMinutes, 3); // ceil(125/60)
      expect(model.isPublished, isTrue);
      expect(model.createdAt, isNotNull);
    });

    test('toFirestore preserves core quiz contract keys', () {
      const model = QuizModel(
        id: 'quiz-2',
        title: 'Science Quiz',
        batchId: 'batch-2',
        batchName: 'Batch B',
        subject: 'Science',
        teacherId: 'teacher-2',
        teacherName: 'Aman',
        timeLimit: 600,
        questions: [
          QuizQuestion(
            question: 'Water formula?',
            options: ['H2O', 'CO2'],
            correctIndex: 0,
          ),
        ],
      );

      final map = model.toFirestore();

      expect(map['title'], 'Science Quiz');
      expect(map['batchId'], 'batch-2');
      expect(map['questions'], isA<List>());
      expect((map['questions'] as List).length, 1);
      expect(map.containsKey('isPublished'), isTrue);
      expect(map.containsKey('totalAttempts'), isTrue);
    });
  });

  group('QuizAttemptModel', () {
    test('percentage and time formatting are computed correctly', () {
      final attempt = QuizAttemptModel.fromFirestore(
        {
          'quizId': 'quiz-1',
          'quizTitle': 'Weekly Quiz',
          'studentId': 'student-1',
          'studentName': 'Neha',
          'answers': [1, 0, 2],
          'score': 3,
          'totalQuestions': 4,
          'timeTaken': 125,
          'submittedAt': '2026-04-01T08:30:00.000Z',
          'percentile': 88.5,
        },
        'attempt-1',
      );

      expect(attempt.percentage, 75);
      expect(attempt.timeTakenFormatted, '2m 5s');
      expect(attempt.submittedAt.year, 2026);
    });

    test('percentage is zero when totalQuestions is zero', () {
      final attempt = QuizAttemptModel.fromFirestore(
        {
          'quizId': 'quiz-1',
          'quizTitle': 'Weekly Quiz',
          'studentId': 'student-2',
          'studentName': 'Rohit',
          'answers': const [],
          'score': 0,
          'totalQuestions': 0,
          'timeTaken': 0,
          'submittedAt': '2026-04-01T08:30:00.000Z',
        },
        'attempt-2',
      );

      expect(attempt.percentage, 0);
      expect(attempt.timeTakenFormatted, '0m 0s');
    });
  });
}
