import { Router } from 'express';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';
import { validate } from '../../middleware/validate.middleware';
import { LeadController } from './lead.controller';
import { createLeadSchema, updateLeadStatusSchema } from './lead.validator';

const router = Router();
const controller = new LeadController();

router.use(authenticateJWT, tenantMiddleware);

router.get('/', requireRole('admin', 'teacher'), controller.list);
router.post('/', requireRole('admin'), validate(createLeadSchema), controller.create);
router.patch('/:id/status', requireRole('admin'), validate(updateLeadStatusSchema), controller.updateStatus);

export default router;
