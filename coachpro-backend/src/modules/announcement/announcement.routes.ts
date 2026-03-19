import { Router } from 'express';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';
import { validate } from '../../middleware/validate.middleware';
import { AnnouncementController } from './announcement.controller';
import { createAnnouncementSchema } from './announcement.validator';

const router = Router();
const controller = new AnnouncementController();

router.use(authenticateJWT, tenantMiddleware);

router.get('/', requireRole('admin', 'teacher'), controller.list);
router.post('/', requireRole('admin'), validate(createAnnouncementSchema), controller.create);
router.delete('/:id', requireRole('admin'), controller.remove);

export default router;
