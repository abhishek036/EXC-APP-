import { Prisma } from '@prisma/client';
import { prisma } from '../../server';

export class QuizRepository {
  static async createQuiz(
    data: Prisma.QuizUncheckedCreateInput,
    questions: Prisma.QuizQuestionUncheckedCreateWithoutQuizInput[]
  ) {
    return prisma.quiz.create({
      data: {
        ...data,
        questions: {
          create: questions,
        },
      },
      include: {
        questions: true,
      },
    });
  }

  static async findQuizById(id: string, instituteId: string) {
    return prisma.quiz.findFirst({
      where: { id, institute_id: instituteId },
      include: {
        questions: {
          orderBy: { order_index: 'asc' },
        },
      },
    });
  }

  static async listQuizzes(instituteId: string, filter: any) {
    return prisma.quiz.findMany({
      where: { institute_id: instituteId, ...filter },
      include: {
        batch: { select: { name: true } },
      },
      orderBy: { created_at: 'desc' },
    });
  }

  static async updateQuiz(id: string, instituteId: string, data: Prisma.QuizUncheckedUpdateInput) {
    return prisma.quiz.updateMany({
      where: { id, institute_id: instituteId },
      data,
    });
  }

  static async publishQuiz(id: string, instituteId: string) {
    return prisma.quiz.updateMany({
      where: { id, institute_id: instituteId },
      data: { is_published: true },
    });
  }

  static async createAttempt(data: Prisma.QuizAttemptUncheckedCreateInput) {
    return prisma.quizAttempt.create({
      data,
    });
  }

  static async updateAttempt(quizId: string, studentId: string, data: Prisma.QuizAttemptUncheckedUpdateInput) {
    return prisma.quizAttempt.update({
      where: { quiz_id_student_id: { quiz_id: quizId, student_id: studentId } },
      data,
    });
  }

  static async findAttempt(quizId: string, studentId: string) {
    return prisma.quizAttempt.findUnique({
      where: { quiz_id_student_id: { quiz_id: quizId, student_id: studentId } },
    });
  }

  static async getLeaderboard(quizId: string, instituteId: string) {
    return prisma.quizAttempt.findMany({
      where: {
        quiz_id: quizId,
        institute_id: instituteId,
        submitted_at: { not: null },
      },
      include: {
        student: { select: { name: true, photo_url: true } },
      },
      orderBy: [
        { obtained_marks: 'desc' },
        { started_at: 'asc' },
      ],
    });
  }

  static async getAttemptsByQuiz(quizId: string, instituteId: string) {
    return prisma.quizAttempt.findMany({
      where: {
        quiz_id: quizId,
        institute_id: instituteId,
      },
      include: {
        student: { select: { name: true, phone: true } },
      },
    });
  }
}
