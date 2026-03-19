import { Router } from 'express';
import { ContentController } from './content.controller';
import { validate } from '../../middleware/validate.middleware';
import { createNoteSchema, createAssignmentSchema, createDoubtSchema, respondDoubtSchema } from './content.validator';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const controller = new ContentController();

router.use(authenticateJWT, tenantMiddleware);

// Notes / Assignments (Staff creation, Student viewing)
router.post('/notes', requireRole('admin', 'teacher'), validate(createNoteSchema), controller.createNote);
router.get('/notes', requireRole('admin', 'teacher', 'student'), controller.listNotes);

router.post('/assignments', requireRole('admin', 'teacher'), validate(createAssignmentSchema), controller.createAssignment);
router.get('/assignments', requireRole('admin', 'teacher', 'student'), controller.listAssignments);

// Doubts (Student creation, Staff responding)
router.post('/doubts', requireRole('student'), validate(createDoubtSchema), controller.askDoubt);
router.patch('/doubts/:doubtId/respond', requireRole('admin', 'teacher'), validate(respondDoubtSchema), controller.respondDoubt);
router.get('/doubts', requireRole('admin', 'teacher', 'student'), controller.listDoubts);

export default router;
