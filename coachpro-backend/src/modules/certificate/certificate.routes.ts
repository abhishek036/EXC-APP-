import { Router } from 'express';
import { CertificateController } from './certificate.controller';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const controller = new CertificateController();

// Only admin can mint/list all; Anyone can verify with number
router.get('/verify/:cert_number', controller.verify);

router.use(authenticateJWT, tenantMiddleware, requireRole('admin'));
router.get('/', controller.list);
router.post('/mint', controller.mint);

export default router;
