import { Router } from 'express';
import { ContentController } from './content.controller';
import { validate } from '../../middleware/validate.middleware';
import { createNoteSchema, noteBookmarkSchema, noteFileAccessSchema, createAssignmentSchema, submitAssignmentSchema, reviewAssignmentSubmissionSchema, createDoubtSchema, respondDoubtSchema } from './content.validator';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const controller = new ContentController();

// Token-signed temporary streaming endpoint (no active session required).
router.get('/notes/:noteId/files/:fileId/stream', validate(noteFileAccessSchema), controller.streamNoteFile);

router.use(authenticateJWT, tenantMiddleware);

// Notes / Assignments (Staff creation, Student viewing)
router.post('/notes', requireRole('admin', 'teacher'), validate(createNoteSchema), controller.createNote);
router.get('/notes', requireRole('admin', 'teacher', 'student'), controller.listNotes);
router.get('/notes/analytics', requireRole('admin', 'teacher'), controller.noteAnalytics);
router.get('/notes/bookmarks', requireRole('student'), controller.listBookmarkedNotes);
router.post('/notes/:noteId/bookmark', requireRole('student'), validate(noteBookmarkSchema), controller.bookmarkNote);
router.delete('/notes/:noteId/bookmark', requireRole('student'), validate(noteBookmarkSchema), controller.unbookmarkNote);
router.get('/notes/:noteId/files/:fileId/access', requireRole('admin', 'teacher', 'student'), validate(noteFileAccessSchema), controller.noteFileAccess);
router.delete('/notes/:noteId', requireRole('admin', 'teacher'), validate(noteBookmarkSchema), controller.deleteNote);

router.post('/assignments', requireRole('admin', 'teacher'), validate(createAssignmentSchema), controller.createAssignment);
router.get('/assignments', requireRole('admin', 'teacher', 'student'), controller.listAssignments);
router.get('/assignments/analytics', requireRole('admin', 'teacher'), controller.assignmentAnalytics);
router.post('/assignments/:assignmentId/draft', requireRole('student'), validate(submitAssignmentSchema), controller.saveAssignmentDraft);
router.post('/assignments/:assignmentId/submit', requireRole('student'), validate(submitAssignmentSchema), controller.submitAssignment);
router.get('/assignments/:assignmentId/my-submissions', requireRole('student'), controller.listMyAssignmentSubmissions);
router.get('/assignments/:assignmentId/submissions', requireRole('admin', 'teacher'), controller.listAssignmentSubmissions);
router.get('/assignments/submissions/:submissionId/feedback', requireRole('admin', 'teacher', 'student'), controller.getAssignmentSubmissionFeedback);
router.patch('/assignments/submissions/:submissionId/review', requireRole('admin', 'teacher'), validate(reviewAssignmentSubmissionSchema), controller.reviewAssignmentSubmission);

// Doubts (Student creation, Staff responding)
router.post('/doubts', requireRole('student'), validate(createDoubtSchema), controller.askDoubt);
router.patch('/doubts/:doubtId/respond', requireRole('admin', 'teacher'), validate(respondDoubtSchema), controller.respondDoubt);
router.get('/doubts', requireRole('admin', 'teacher', 'student'), controller.listDoubts);

export default router;
