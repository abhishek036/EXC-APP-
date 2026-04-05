import { Request, Response, NextFunction } from 'express';
import { QuizService } from './quiz.service';
import { sendResponse } from '../../utils/response';
import { isLegacyColumnError } from '../../utils/prisma-errors';

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
          const user = await prisma.user.findUnique({
            where: { id: req.user!.userId },
            select: { phone: true },
          });

          const phones = new Set<string>();
          const raw = String(user?.phone ?? '').replace(/[\s\-()]/g, '');
          if (raw) {
            phones.add(raw);
            if (raw.startsWith('+91') && raw.length >= 13) phones.add(raw.substring(3));
            if (raw.startsWith('91') && raw.length === 12) {
              const ten = raw.substring(2);
              phones.add(ten);
              phones.add(`+91${ten}`);
            }
            if (/^\d{10}$/.test(raw)) {
              phones.add(`+91${raw}`);
              phones.add(`91${raw}`);
            }
          }

          const loadCandidates = async (includeInactive: boolean) =>
            prisma.student.findMany({
              where: {
                institute_id: req.instituteId!,
                AND: [
                  ...(includeInactive ? [] : [{ OR: [{ is_active: true }, { is_active: null }] }]),
                  {
                    OR: [
                      { user_id: req.user!.userId },
                      ...(phones.size > 0
                        ? [{
                            AND: [
                              { phone: { in: Array.from(phones) } },
                              { OR: [{ user_id: null }, { user_id: req.user!.userId }] },
                            ],
                          }]
                        : []),
                    ],
                  },
                ],
              },
              include: {
                student_batches: {
                  where: {
                    OR: [{ is_active: true }, { is_active: null }],
                  },
                  select: { batch_id: true },
                },
              },
              orderBy: { created_at: 'desc' },
            });

          let candidates = await loadCandidates(false);
          if (candidates.length === 0) {
            candidates = await loadCandidates(true);
          }

          const ranked = [...candidates].sort((a, b) => {
            const aLinked = a.user_id === req.user!.userId ? 1 : 0;
            const bLinked = b.user_id === req.user!.userId ? 1 : 0;
            if (bLinked != aLinked) return bLinked - aLinked;

            const aBatchCount = a.student_batches?.length || 0;
            const bBatchCount = b.student_batches?.length || 0;
            if (bBatchCount != aBatchCount) return bBatchCount - aBatchCount;

            const aUnlinked = !a.user_id ? 1 : 0;
            const bUnlinked = !b.user_id ? 1 : 0;
            if (bUnlinked != aUnlinked) return bUnlinked - aUnlinked;

            const aCreated = new Date(a.created_at as any).getTime() || 0;
            const bCreated = new Date(b.created_at as any).getTime() || 0;
            return bCreated - aCreated;
          });

          let student = ranked[0] || null;
          if (student && (student.student_batches?.length || 0) === 0) {
            const withBatches = ranked.find((item) => (item.student_batches?.length || 0) > 0);
            if (withBatches) {
              student = withBatches;
            }
          }
          
          if (!student) {
              return sendResponse({ res, data: [] });
          }

          if (!student.user_id) {
              await prisma.student.update({
                  where: { id: student.id },
                  data: { user_id: req.user!.userId },
              });
          }

          const batchIds = student.student_batches.map(sb => sb.batch_id);
          if (batchIds.length === 0) {
            return sendResponse({ res, data: [] });
          }

          const { subject } = req.query;
          try {
            const puzzles = await prisma.quiz.findMany({
                where: {
                    institute_id: req.instituteId!,
                    batch_id: { in: batchIds },
                    is_published: true,
                    OR: [
                      { scheduled_at: null },
                      { scheduled_at: { lte: new Date() } },
                    ],
                    ...(subject
                      ? {
                          subject: {
                            equals: String(subject),
                            mode: 'insensitive',
                          },
                        }
                      : {})
                },
                include: {
                    batch: { select: { name: true } },
                    _count: { select: { questions: true } },
                    attempts: {
                      where: { student_id: student.id },
                      select: { submitted_at: true, obtained_marks: true, total_marks: true },
                    },
                },
                orderBy: { created_at: 'desc' }
            });
            return sendResponse({ res, data: puzzles, message: 'Available quizzes fetched' });
          } catch (error) {
             if (!isLegacyColumnError(error, 'subject')) throw error;
             
             let query = `SELECT q.*, b.name as batch_name 
                          FROM quizzes q 
                          LEFT JOIN batches b ON q.batch_id = b.id 
                          WHERE q.institute_id::text = $1::text 
                            AND q.batch_id::text IN (${batchIds.map((_, i) => `$${i + 2}`).join(',')})
                            AND COALESCE(q.is_published, false) = true
                            AND (q.scheduled_at IS NULL OR q.scheduled_at <= NOW())`;
             const params = [req.instituteId, ...batchIds];

             if (subject) {
               query += ` AND LOWER(COALESCE(q.subject, '')) = LOWER($${params.length + 1}::text)`;
               params.push(String(subject));
             }
             
             query += ` ORDER BY q.created_at DESC`;
             const rawPuzzles = await prisma.$queryRawUnsafe<any[]>(query, ...params);
             
             const puzzles = rawPuzzles.map(p => ({
                 ...p,
                 batch: { name: p.batch_name },
                 _count: { questions: 0 } // Legacy fallback simplification
             }));
             return sendResponse({ res, data: puzzles, message: 'Available quizzes fetched (legacy fallback)' });
          }
      } catch (error) { next(error); }
  };


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
      const quiz = await QuizService.getQuizById(req.params.id, req.instituteId!, req.user!.role, req.user!.userId);
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
      const leaderboard = await QuizService.getLeaderboard(
        req.params.id,
        req.instituteId!,
        req.user!.role,
        req.user!.userId,
      );
      return sendResponse({ res, data: leaderboard });
    } catch (error) {
      next(error);
    }
  }

  static async getReport(req: Request, res: Response, next: NextFunction) {
    try {
      const report = await QuizService.getFullReport(
        req.params.id,
        req.instituteId!,
        req.user!.role,
        req.user!.userId,
      );
      return sendResponse({ res, data: report });
    } catch (error) {
      next(error);
    }
  }
}
