import { Router } from 'express';
import { QuizController } from './quiz.controller';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';
import { validate } from '../../middleware/validate.middleware';
import { createQuizSchema, updateQuizSchema, submitQuizSchema } from './quiz.validator';

const router = Router();

router.use(authenticateJWT);
router.use(tenantMiddleware);

// Roles: teacher, admin
router.get('/', requireRole('admin', 'teacher'), QuizController.listQuizzes);
router.post('/', requireRole('admin', 'teacher'), validate(createQuizSchema), QuizController.createQuiz);
router.get('/available', requireRole('student'), QuizController.getAvailableQuizzes);
router.get('/:id', requireRole('admin', 'teacher', 'student'), QuizController.getQuiz);
router.put('/:id', requireRole('admin', 'teacher'), validate(updateQuizSchema), QuizController.updateQuiz);
router.post('/:id/publish', requireRole('admin', 'teacher'), QuizController.publishQuiz);
router.delete('/:id', requireRole('admin', 'teacher'), QuizController.deleteQuiz);

// Student attempt routes
router.post('/:id/attempt/start', requireRole('student'), QuizController.startAttempt);
router.post('/:id/attempt/submit', requireRole('student'), validate(submitQuizSchema), QuizController.submitAttempt);
router.get('/:id/result', requireRole('student'), QuizController.getResult); // student's own result
router.get('/:id/results', requireRole('admin', 'teacher'), QuizController.getLeaderboard); // alias for leaderboard/results for staff

// Reports & Leaderboards
router.get('/:id/leaderboard', requireRole('admin', 'teacher', 'student'), QuizController.getLeaderboard);
router.get('/:id/report', requireRole('admin', 'teacher'), QuizController.getReport);

export default router;
