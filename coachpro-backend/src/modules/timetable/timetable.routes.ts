import { Router } from 'express';
import { TimetableController } from './timetable.controller';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const controller = new TimetableController();

router.use(authenticateJWT, tenantMiddleware);

router.get('/batch/:batchId', controller.getByBatch);
router.get('/teacher/:teacherId', controller.getByTeacher);

// Scheduling restricted to admin and teacher
router.post('/schedule', requireRole(['admin', 'teacher'] as any), controller.schedule);

export default router;
