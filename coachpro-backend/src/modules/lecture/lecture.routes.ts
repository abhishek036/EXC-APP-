import { Router } from 'express';
import { LectureController } from './lecture.controller';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';
import { validate } from '../../middleware/validate.middleware';
import { createLectureSchema, updateLectureSchema } from './lecture.validator';

const router = Router();

router.use(authenticateJWT);
router.use(tenantMiddleware);

router.get('/batch/:batchId', requireRole('admin', 'teacher', 'student', 'parent'), LectureController.listLectures);
router.post('/', requireRole('admin', 'teacher'), validate(createLectureSchema), LectureController.createLecture);
router.put('/:id', requireRole('admin', 'teacher'), validate(updateLectureSchema), LectureController.updateLecture);
router.delete('/:id', requireRole('admin', 'teacher'), LectureController.deleteLecture);

export default router;
