import { Router } from 'express';
import { TimetableController } from './timetable.controller';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const controller = new TimetableController();

router.use(authenticateJWT, tenantMiddleware);

router.get('/batch/:batchId', controller.getByBatch);
router.get('/teacher/:teacherId', controller.getByTeacher);
router.get('/teacher/me', requireRole('teacher'), controller.getMySchedule);

// Scheduling restricted to admin and teacher
// router.post('/schedule', requireRole(['admin', 'teacher'] as any), controller.schedule);
router.post('/teacher/me', requireRole('teacher'), controller.createMySchedule);
router.put('/teacher/me/:lectureId', requireRole('teacher'), controller.updateMySchedule);
router.delete('/teacher/me/past', requireRole('teacher'), controller.clearMyPastSchedules);
router.delete('/teacher/me/:lectureId', requireRole('teacher'), controller.deleteMySchedule);

export default router;
