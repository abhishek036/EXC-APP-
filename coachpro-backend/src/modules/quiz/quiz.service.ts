import { QuizRepository } from './quiz.repository';
import { Prisma } from '@prisma/client';
import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';

export class QuizService {
  private static async resolveTeacherProfileId(userId: string, instituteId: string): Promise<string> {
    const teacher = await prisma.teacher.findFirst({
      where: { user_id: userId, institute_id: instituteId, is_active: true },
      select: { id: true },
    });
    if (!teacher) {
      throw new ApiError('Teacher profile not found for this account', 404, 'NOT_FOUND');
    }
    return teacher.id;
  }

  private static async resolveStudentProfileId(userId: string, instituteId: string): Promise<string> {
    const student = await prisma.student.findFirst({
      where: { user_id: userId, institute_id: instituteId, is_active: true },
      select: { id: true },
    });
    if (!student) {
      throw new ApiError('Student profile not found for this account', 404, 'NOT_FOUND');
    }
    return student.id;
  }

  static async createQuiz(
    instituteId: string,
    teacherUserId: string,
    batchId: string,
    title: string,
    subject?: string,
    timeLimitMin?: number,
    questions?: any[]
  ) {
    const teacherId = await QuizService.resolveTeacherProfileId(teacherUserId, instituteId);

    const quizData: Prisma.QuizUncheckedCreateInput = {
      batch_id: batchId,
      institute_id: instituteId,
      teacher_id: teacherId,
      title,
      subject,
      time_limit_min: timeLimitMin,
      is_published: false,
    };

    const formattedQuestions: Prisma.QuizQuestionUncheckedCreateWithoutQuizInput[] = (questions || []).map((q, index) => ({
      question_text: q.question_text,
      image_url: q.image_url,
      option_a: q.option_a,
      option_b: q.option_b,
      option_c: q.option_c,
      option_d: q.option_d,
      correct_option: q.correct_option,
      marks: q.marks ?? 1,
      order_index: q.order_index ?? index,
    }));

    return QuizRepository.createQuiz(quizData, formattedQuestions);
  }

  static async listQuizzes(instituteId: string, batchId?: string) {
    const filter = batchId ? { batch_id: batchId } : {};
    return QuizRepository.listQuizzes(instituteId, filter);
  }

  static async getQuizById(id: string, instituteId: string, role: string) {
    const quiz = await QuizRepository.findQuizById(id, instituteId);
    if (!quiz) throw new Error('Quiz not found');

    if (role === 'student' && !quiz.is_published) {
      throw new Error('This quiz is not published yet');
    }

    if (role === 'student') {
        const studentQuiz = JSON.parse(JSON.stringify(quiz));
        studentQuiz.questions.forEach((q: any) => {
            delete q.correct_option; // Don't expose answers to students
        });
        return studentQuiz;
    }

    return quiz;
  }

  static async updateQuiz(id: string, instituteId: string, data: any) {
    const quiz = await QuizRepository.findQuizById(id, instituteId);
    if (!quiz) throw new Error('Quiz not found');
    if (quiz.is_published) throw new Error('Cannot edit a published quiz');

    return QuizRepository.updateQuiz(id, instituteId, data);
  }

  static async publishQuiz(id: string, instituteId: string) {
    const quiz = await QuizRepository.findQuizById(id, instituteId);
    if (!quiz) throw new Error('Quiz not found');
    if (quiz.is_published) throw new Error('Quiz is already published');

    return QuizRepository.publishQuiz(id, instituteId);
  }

  static async startAttempt(quizId: string, studentId: string, instituteId: string) {
    const studentProfileId = await QuizService.resolveStudentProfileId(studentId, instituteId);

    const quiz = await QuizRepository.findQuizById(quizId, instituteId);
    if (!quiz) throw new Error('Quiz not found');
    if (!quiz.is_published) throw new Error('Quiz is not published yet');

    const existingAttempt = await QuizRepository.findAttempt(quizId, studentProfileId);
    if (existingAttempt) {
      return existingAttempt; // Resuming attempt
    }

    return QuizRepository.createAttempt({
      quiz_id: quizId,
      student_id: studentProfileId,
      institute_id: instituteId,
    });
  }

  static async submitQuiz(quizId: string, studentId: string, instituteId: string, answers: Record<string, string>) {
    const studentProfileId = await QuizService.resolveStudentProfileId(studentId, instituteId);

    const quiz = await QuizRepository.findQuizById(quizId, instituteId);
    if (!quiz) throw new Error('Quiz not found');

    const attempt = await QuizRepository.findAttempt(quizId, studentProfileId);
    if (!attempt) throw new Error('Quiz attempt not started');
    if (attempt.submitted_at) throw new Error('Quiz already submitted');

    let totalMarks = 0;
    let obtainedMarks = 0;

    for (const q of quiz.questions) {
      const qMarks = q.marks ?? 1;
      totalMarks += qMarks;

      const studentAnswer = answers[q.id];
      if (studentAnswer && studentAnswer === q.correct_option) {
        obtainedMarks += qMarks;
      }
    }

    return QuizRepository.updateAttempt(quizId, studentProfileId, {
      submitted_at: new Date(),
      total_marks: totalMarks,
      obtained_marks: obtainedMarks,
      answers: answers as Prisma.JsonObject,
    });
  }

  static async getStudentResult(quizId: string, studentId: string, instituteId: string) {
    const studentProfileId = await QuizService.resolveStudentProfileId(studentId, instituteId);

    const attempt = await QuizRepository.findAttempt(quizId, studentProfileId);
    if (!attempt) throw new Error('Attempt not found');
    if (!attempt.submitted_at) throw new Error('Quiz not submitted yet');
    
    return attempt;
  }

  static async getLeaderboard(quizId: string, instituteId: string) {
    return QuizRepository.getLeaderboard(quizId, instituteId);
  }

  static async getFullReport(quizId: string, instituteId: string) {
    const attempts = await QuizRepository.getAttemptsByQuiz(quizId, instituteId);
    const quiz = await QuizRepository.findQuizById(quizId, instituteId);
    
    return {
       quiz,
       attempts
    };
  }
}
