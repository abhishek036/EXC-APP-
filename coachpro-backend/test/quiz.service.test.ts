import { QuizService } from '../src/modules/quiz/quiz.service';
import { QuizRepository } from '../src/modules/quiz/quiz.repository';

jest.mock('../src/modules/quiz/quiz.repository', () => ({
  QuizRepository: {
    findQuizById: jest.fn(),
    findAttempt: jest.fn(),
    getAttemptsByQuiz: jest.fn(),
  },
}));

jest.mock('../src/server', () => ({
  prisma: {
    studentBatch: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
    },
    teacher: {
      findFirst: jest.fn(),
    },
    user: {
      findUnique: jest.fn(),
    },
    student: {
      findMany: jest.fn(),
      update: jest.fn(),
    },
    $transaction: jest.fn(),
  },
}));

describe('QuizService security and reporting', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('blocks students from opening unpublished quizzes', async () => {
    (QuizRepository.findQuizById as jest.Mock).mockResolvedValue({
      id: 'quiz-1',
      teacher_id: 'teacher-1',
      batch_id: 'batch-1',
      is_published: false,
      scheduled_at: null,
      questions: [{ id: 'q1', correct_option: 'A' }],
    });

    jest.spyOn(QuizService as any, 'resolveStudentProfileId').mockResolvedValue('student-1');
    jest.spyOn(QuizService as any, 'ensureStudentCanAccessQuizBatch').mockResolvedValue(undefined);

    await expect(
      QuizService.getQuizById('quiz-1', 'inst-1', 'student', 'user-1'),
    ).rejects.toMatchObject({
      code: 'FORBIDDEN',
      message: 'This quiz is not published yet',
    });
  });

  it('rejects quiz submission with tampered question ids', async () => {
    (QuizRepository.findQuizById as jest.Mock).mockResolvedValue({
      id: 'quiz-1',
      title: 'Quiz 1',
      teacher_id: 'teacher-1',
      batch_id: 'batch-1',
      is_published: true,
      scheduled_at: null,
      time_limit_min: 30,
      negative_marking: 0,
      questions: [{ id: 'q1', correct_option: 'A', marks: 1 }],
    });

    (QuizRepository.findAttempt as jest.Mock).mockResolvedValue({
      id: 'attempt-1',
      started_at: new Date(),
      submitted_at: null,
    });

    jest.spyOn(QuizService as any, 'resolveStudentProfileId').mockResolvedValue('student-1');
    jest.spyOn(QuizService as any, 'ensureStudentCanAccessQuizBatch').mockResolvedValue(undefined);

    await expect(
      QuizService.submitQuiz('quiz-1', 'user-1', 'inst-1', { bad_question: 'A' }),
    ).rejects.toMatchObject({
      code: 'INVALID_ANSWERS',
      message: 'Submitted answers contain invalid question ids',
    });
  });

  it('enforces server-side quiz time limit during submit', async () => {
    (QuizRepository.findQuizById as jest.Mock).mockResolvedValue({
      id: 'quiz-1',
      title: 'Quiz 1',
      teacher_id: 'teacher-1',
      batch_id: 'batch-1',
      is_published: true,
      scheduled_at: null,
      time_limit_min: 1,
      negative_marking: 0,
      questions: [{ id: 'q1', correct_option: 'A', marks: 1 }],
    });

    const oldStart = new Date(Date.now() - 3 * 60 * 1000);
    (QuizRepository.findAttempt as jest.Mock).mockResolvedValue({
      id: 'attempt-1',
      started_at: oldStart,
      submitted_at: null,
    });

    jest.spyOn(QuizService as any, 'resolveStudentProfileId').mockResolvedValue('student-1');
    jest.spyOn(QuizService as any, 'ensureStudentCanAccessQuizBatch').mockResolvedValue(undefined);

    await expect(
      QuizService.submitQuiz('quiz-1', 'user-1', 'inst-1', { q1: 'A' }),
    ).rejects.toMatchObject({
      code: 'TIME_LIMIT_EXCEEDED',
      message: 'Time limit exceeded for this quiz',
    });
  });

  it('returns class results with submitted and pending students', async () => {
    (QuizRepository.findQuizById as jest.Mock).mockResolvedValue({
      id: 'quiz-1',
      title: 'Quiz 1',
      teacher_id: 'teacher-1',
      batch_id: 'batch-1',
      is_published: true,
      questions: [],
    });

    (QuizRepository.getAttemptsByQuiz as jest.Mock).mockResolvedValue([
      {
        student_id: 'student-1',
        obtained_marks: 8,
        total_marks: 10,
        submitted_at: new Date('2026-04-01T10:00:00.000Z'),
      },
    ]);

    const { prisma } = await import('../src/server');
    (prisma.studentBatch.findMany as jest.Mock).mockResolvedValue([
      {
        student_id: 'student-1',
        student: { id: 'student-1', name: 'Aarav', phone: '9999999991', photo_url: null },
      },
      {
        student_id: 'student-2',
        student: { id: 'student-2', name: 'Bhavya', phone: '9999999992', photo_url: null },
      },
    ]);

    jest.spyOn(QuizService as any, 'ensureTeacherOwnsQuiz').mockResolvedValue(undefined);

    const report = await QuizService.getFullReport('quiz-1', 'inst-1', 'teacher', 'teacher-user-1');

    expect(report.class_results).toHaveLength(2);
    expect(report.class_results[0]).toMatchObject({
      student_id: 'student-1',
      status: 'submitted',
      obtained_marks: 8,
    });
    expect(report.class_results[1]).toMatchObject({
      student_id: 'student-2',
      status: 'pending',
      obtained_marks: null,
    });
  });
});
