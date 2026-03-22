import { Router } from 'express';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';
import { validate } from '../../middleware/validate.middleware';
import { AnnouncementController } from './announcement.controller';
import { createAnnouncementSchema, updateAnnouncementSchema } from './announcement.validator';

const router = Router();
const controller = new AnnouncementController();

router.use(authenticateJWT, tenantMiddleware);

router.get('/', requireRole('admin', 'teacher'), controller.list);
router.post('/', requireRole('admin'), validate(createAnnouncementSchema), controller.create);
router.put('/:id', requireRole('admin'), validate(updateAnnouncementSchema), controller.update);
router.delete('/:id', requireRole('admin'), controller.remove);

export default router;
