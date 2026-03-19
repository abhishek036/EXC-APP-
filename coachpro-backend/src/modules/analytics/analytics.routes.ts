import { Router } from 'express';
import { AnalyticsController } from './analytics.controller';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();

router.use(authenticateJWT);
router.use(tenantMiddleware);

router.get('/dashboard', requireRole('admin'), AnalyticsController.getDashboard);
router.get('/student/:id', requireRole('admin', 'teacher', 'parent', 'student'), AnalyticsController.getStudentPerformance);

export default router;
