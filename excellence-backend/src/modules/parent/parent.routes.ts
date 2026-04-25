import { Router } from 'express';
import { ParentController } from './parent.controller';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const ctrl = new ParentController();

// Applying token validation and tenant isolation
router.use(authenticateJWT, tenantMiddleware);

// All routes require parent role
router.use(requireRole(['parent']));

router.get('/me/dashboard', ctrl.getDashboard);
router.get('/me/children', ctrl.getChildren);
router.get('/me/payments', ctrl.getPayments);
router.get('/me/children/doubts', ctrl.getChildrenDoubts);
router.get('/me/children/:childId/report', ctrl.getChildReport);

export default router;
