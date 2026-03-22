import { Router } from 'express';
import { TeacherController } from './teacher.controller';
import { validate } from '../../middleware/validate.middleware';
import { createTeacherSchema, updateTeacherSchema } from './teacher.validator';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const teacherController = new TeacherController();

// Applying token validation and tenant isolation universally to these private routes
router.use(authenticateJWT, tenantMiddleware);

// ── Self-service routes (teacher role) ─────────────────────
router.get('/me', requireRole('teacher'), teacherController.getMe);
router.get('/me/dashboard', requireRole('teacher'), teacherController.getDashboard);
router.get('/me/stats/weekly', requireRole('teacher'), teacherController.getWeeklyStats);
router.get('/me/batches', requireRole('teacher'), teacherController.getMyBatches);
router.get('/me/schedule/today', requireRole('teacher'), teacherController.getTodaySchedule);

// ── Admin management routes ────────────────────────────────
router.get('/', requireRole('admin'), teacherController.list);
router.post('/', requireRole('admin'), validate(createTeacherSchema), teacherController.create);
router.get('/:id', requireRole('admin', 'teacher'), teacherController.getById);
router.put('/:id', requireRole('admin'), validate(updateTeacherSchema), teacherController.update);
router.patch('/:id/status', requireRole('admin'), teacherController.toggleStatus);
router.delete('/:id', requireRole('admin'), teacherController.remove);

export default router;
