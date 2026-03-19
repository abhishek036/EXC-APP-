import { Router } from 'express';
import { PayrollController } from './payroll.controller';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const controller = new PayrollController();

router.use(authenticateJWT, tenantMiddleware, requireRole('admin'));

router.get('/', controller.list);
router.get('/stats', controller.stats);
router.post('/generate', controller.generate);

export default router;
