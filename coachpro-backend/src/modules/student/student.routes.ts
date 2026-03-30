import { Router } from 'express';
import { StudentController } from './student.controller';
import { validate } from '../../middleware/validate.middleware';
import { createStudentSchema, updateStudentSchema } from './student.validator';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

import { excelUpload } from '../../middleware/upload';

const router = Router();
const studentController = new StudentController();

// Applying token validation and tenant isolation
router.use(authenticateJWT, tenantMiddleware);

// ── Self-service routes (student role) ─────────────────────
router.get('/me', requireRole('student'), studentController.getMe);
router.get('/me/dashboard', requireRole('student'), studentController.getDashboard);
router.get('/me/batches', requireRole('student'), studentController.getMyBatches);
router.get('/me/schedule/today', requireRole('student'), studentController.getTodaySchedule);
router.get('/me/attendance', requireRole('student'), studentController.getMyAttendance);
router.get('/me/exams/upcoming', requireRole('student'), studentController.getUpcomingExams);
router.get('/me/performance', requireRole('student'), studentController.getMyPerformance);
router.get('/me/fees', requireRole('student'), studentController.getMyFees);
router.get('/me/fees/history', requireRole('student'), studentController.getFeeHistory);
router.get('/me/results', requireRole('student'), studentController.getMyResults);
router.get('/me/doubts', requireRole('student'), studentController.getMyDoubts);
router.get('/me/notifications', requireRole('student'), studentController.getNotifications);

// ── Admin/Teacher management routes ────────────────────────
router.get('/', requireRole('admin', 'teacher'), studentController.list);
router.post('/', requireRole('admin'), validate(createStudentSchema), studentController.create);
router.post('/import', requireRole('admin'), excelUpload.single('file'), studentController.importStudents);
router.get('/:id', requireRole('admin', 'teacher'), studentController.getById);
router.put('/:id', requireRole('admin'), validate(updateStudentSchema), studentController.update);
router.patch('/:id/status', requireRole('admin'), studentController.toggleStatus);

export default router;
