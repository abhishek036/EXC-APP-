import { Router } from 'express';
import { UsersController } from './users.controller';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';

const router = Router();
const ctrl = new UsersController();

// All routes require admin role
router.use(authenticateJWT, requireRole(['admin']));

router.get('/', ctrl.list);
router.get('/:id', ctrl.getUser);
router.patch('/:id/status', ctrl.updateStatus);
router.patch('/:id/role', ctrl.changeRole);

export default router;
