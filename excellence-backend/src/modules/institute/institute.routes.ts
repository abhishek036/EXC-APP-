import { Router } from 'express';
import { InstituteController } from './institute.controller';
import { validate } from '../../middleware/validate.middleware';
import { updateInstituteSchema } from './institute.validator';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const controller = new InstituteController();

// Only admin users managing their specific institute can hit these APIs
router.use(authenticateJWT, requireRole('admin'), tenantMiddleware);

router.get('/config', controller.getProfile);
router.put('/config', validate(updateInstituteSchema), controller.updateProfile);

export default router;
