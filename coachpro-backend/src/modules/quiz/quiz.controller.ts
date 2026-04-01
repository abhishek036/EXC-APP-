import { Request, Response, NextFunction } from 'express';
import { QuizService } from './quiz.service';
import { sendResponse } from '../../utils/response';

export class QuizController {
  static async listQuizzes(req: Request, res: Response, next: NextFunction) {
    try {
      const { batch_id, assessment_type } = req.query;
      const quizzes = await QuizService.listQuizzes(req.instituteId!, batch_id as string, assessment_type as string);
      return sendResponse({ res, data: quizzes });
    } catch (error) {
      next(error);
    }
  }

  static async getAvailableQuizzes(req: Request, res: Response, next: NextFunction) {
      try {
          const { prisma } = await import('../../server');
          const student = await prisma.student.findFirst({
              where: { user_id: req.user!.userId, institute_id: req.instituteId! },
              include: { student_batches: { select: { batch_id: true } } }
          });
          
          if (!student) {
              return sendResponse({ res, data: [] });
          }

          const batchIds = student.student_batches.map(sb => sb.batch_id);

          const { subject } = req.query;
          const puzzles = await prisma.quiz.findMany({
              where: {
                  institute_id: req.instituteId!,
                  is_published: true,
                  batch_id: { in: batchIds },
                  attempts: { none: { student_id: student.id } }, // Only not attempted
                  ...(subject ? { subject: subject as string } : {})
              },
              include: {
                  batch: { select: { name: true } },
                  _count: { select: { questions: true } }
              },
              orderBy: { created_at: 'desc' }
          });

          return sendResponse({ res, data: puzzles, message: 'Available quizzes fetched' });
      } catch (error) { next(error); }
  }


  static async createQuiz(req: Request, res: Response, next: NextFunction) {
    try {
      const {
        batch_id,
        title,
        subject,
        time_limit_min,
        questions,
        assessment_type,
        scheduled_at,
        negative_marking,
        allow_retry,
        show_instant_result,
      } = req.body;
      const quiz = await QuizService.createQuiz(
        req.instituteId!,
        req.user!.userId,
        batch_id,
        title,
        subject,
        time_limit_min,
        questions,
        assessment_type,
        scheduled_at,
        negative_marking,
        allow_retry,
        show_instant_result,
      );
      return sendResponse({ res, data: quiz, message: 'Quiz created successfully', statusCode: 201 });
    } catch (error) {
      next(error);
    }
  }

  static async getQuiz(req: Request, res: Response, next: NextFunction) {
    try {
      const quiz = await QuizService.getQuizById(req.params.id, req.instituteId!, req.user!.role);
      return sendResponse({ res, data: quiz });
    } catch (error) {
      next(error);
    }
  }

  static async updateQuiz(req: Request, res: Response, next: NextFunction) {
    try {
      const quiz = await QuizService.updateQuiz(
        req.params.id,
        req.instituteId!,
        req.body,
        req.user!.role,
        req.user!.userId,
      );
      return sendResponse({ res, data: quiz, message: 'Quiz updated successfully' });
    } catch (error) {
      next(error);
    }
  }

  static async publishQuiz(req: Request, res: Response, next: NextFunction) {
    try {
      await QuizService.publishQuiz(req.params.id, req.instituteId!, req.user!.role, req.user!.userId);
      return sendResponse({ res, data: null, message: 'Quiz published successfully' });
    } catch (error) {
      next(error);
    }
  }

  static async deleteQuiz(req: Request, res: Response, next: NextFunction) {
    try {
      const data = await QuizService.deleteQuiz(req.params.id, req.instituteId!, req.user!.role, req.user!.userId);
      return sendResponse({ res, data, message: 'Quiz deleted successfully' });
    } catch (error) {
      next(error);
    }
  }

  static async startAttempt(req: Request, res: Response, next: NextFunction) {
    try {
      const attempt = await QuizService.startAttempt(req.params.id, req.user!.userId, req.instituteId!);
      return sendResponse({ res, data: attempt, message: 'Attempt started successfully' });
    } catch (error) {
      next(error);
    }
  }

  static async submitAttempt(req: Request, res: Response, next: NextFunction) {
    try {
      const { answers } = req.body;
      const attempt = await QuizService.submitQuiz(req.params.id, req.user!.userId, req.instituteId!, answers);
      return sendResponse({ res, data: attempt, message: 'Quiz submitted successfully' });
    } catch (error) {
      next(error);
    }
  }

  static async getResult(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await QuizService.getStudentResult(req.params.id, req.user!.userId, req.instituteId!);
      return sendResponse({ res, data: result });
    } catch (error) {
      next(error);
    }
  }

  static async getLeaderboard(req: Request, res: Response, next: NextFunction) {
    try {
      const leaderboard = await QuizService.getLeaderboard(req.params.id, req.instituteId!);
      return sendResponse({ res, data: leaderboard });
    } catch (error) {
      next(error);
    }
  }

  static async getReport(req: Request, res: Response, next: NextFunction) {
    try {
      const report = await QuizService.getFullReport(req.params.id, req.instituteId!);
      return sendResponse({ res, data: report });
    } catch (error) {
      next(error);
    }
  }
}
