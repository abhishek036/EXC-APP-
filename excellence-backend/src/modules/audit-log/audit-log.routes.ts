import { Router } from 'express';
import { AuditLogController } from './audit-log.controller';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const controller = new AuditLogController();

// All audit log routes require admin role
router.get('/', authenticateJWT, tenantMiddleware, requireRole('admin'), controller.list);

export default router;
