import { Router } from 'express';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';
import { validate } from '../../middleware/validate.middleware';
import { ExamController } from './exam.controller';
import { createExamSchema, updateExamStatusSchema } from './exam.validator';

const router = Router();
const controller = new ExamController();

router.use(authenticateJWT, tenantMiddleware);

router.get('/', requireRole('admin', 'teacher'), controller.list);
router.post('/', requireRole('admin'), validate(createExamSchema), controller.create);
router.patch('/:id/status', requireRole('admin'), validate(updateExamStatusSchema), controller.updateStatus);
router.delete('/:id', requireRole('admin'), controller.remove);
router.get('/results/list', requireRole('admin', 'teacher'), controller.results);

export default router;
