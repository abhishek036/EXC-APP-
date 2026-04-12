import { Router } from 'express';
import { BatchController } from './batch.controller';
import { validate } from '../../middleware/validate.middleware';
import { createBatchSchema, updateBatchSchema, addStudentsToBatchSchema, updateBatchMetaSchema, migrateBatchStudentsSchema } from './batch.validator';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const batchController = new BatchController();

// Applying token validation and tenant isolation universally to these private routes
router.use(authenticateJWT, tenantMiddleware);

router.get('/', requireRole('admin', 'teacher'), batchController.list);

router.post('/', requireRole('admin'), validate(createBatchSchema), batchController.create);

router.get('/:id', requireRole('admin', 'teacher'), batchController.getById);

router.put('/:id', requireRole('admin'), validate(updateBatchSchema), batchController.update);

router.delete('/:id', requireRole('admin'), batchController.delete);

router.patch('/:id/status', requireRole('admin'), batchController.toggleStatus);

router.get('/:id/meta', requireRole('admin', 'teacher'), batchController.getMeta);

router.put('/:id/meta', requireRole('admin'), validate(updateBatchMetaSchema), batchController.updateMeta);

router.post('/:id/migrate', requireRole('admin'), validate(migrateBatchStudentsSchema), batchController.migrateStudents);

router.get('/:id/students', requireRole('admin', 'teacher'), batchController.getStudents);

router.post('/:id/students', requireRole('admin'), validate(addStudentsToBatchSchema), batchController.addStudents);

router.delete('/:id/students/:studentId', requireRole('admin'), batchController.removeStudent);

export default router;
