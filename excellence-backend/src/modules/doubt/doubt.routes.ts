import { Router } from 'express';
import { DoubtController } from './doubt.controller';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';
import { validate } from '../../middleware/validate.middleware';
import { createDoubtSchema, answerDoubtSchema, followUpDoubtSchema } from './doubt.validator';

const router = Router();

router.use(authenticateJWT);
router.use(tenantMiddleware);

router.get('/', requireRole('admin', 'teacher', 'student'), DoubtController.listDoubts);
router.post('/', requireRole('student'), validate(createDoubtSchema), DoubtController.createDoubt);
router.put('/:id/answer', requireRole('teacher'), validate(answerDoubtSchema), DoubtController.answerDoubt);
router.post('/:id/followup', requireRole('student'), validate(followUpDoubtSchema), DoubtController.followUpDoubt);
router.patch('/:id/resolve', requireRole('admin', 'teacher'), DoubtController.resolveDoubt);

export default router;
