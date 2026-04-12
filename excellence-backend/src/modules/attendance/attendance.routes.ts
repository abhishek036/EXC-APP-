import { Router } from 'express';
import { AttendanceController } from './attendance.controller';
import { validate } from '../../middleware/validate.middleware';
import { markAttendanceSchema, reportIssueSchema } from './attendance.validator';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const controller = new AttendanceController();

router.use(authenticateJWT, tenantMiddleware);

// Teachers and Admins marking
router.get('/stats', requireRole('admin', 'teacher'), controller.getStats);
router.post('/mark', requireRole('admin', 'teacher'), validate(markAttendanceSchema), controller.mark);
router.get('/batch/:batchId', requireRole('admin', 'teacher'), controller.getBatch);

// Any role checking a specific student
router.get('/student/:studentId', requireRole('admin', 'teacher', 'student', 'parent'), controller.getStudent);
router.post('/student/:studentId/report-issue', requireRole('student', 'parent'), validate(reportIssueSchema), controller.reportIssue);

export default router;
