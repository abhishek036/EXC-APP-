import { Request, Response, NextFunction } from 'express';
import { ContentService } from './content.service';
import { sendResponse } from '../../utils/response';
import { prisma } from '../../server';
import { emitBatchSync, emitInstituteDashboardSync } from '../../config/socket';

export class ContentController {
  private service: ContentService;

  constructor() {
    this.service = new ContentService();
  }

  private async resolveTeacherId(instituteId: string, userId: string): Promise<string | null> {
    const teacher = await prisma.teacher.findFirst({
      where: { institute_id: instituteId, user_id: userId },
      select: { id: true },
    });
    return teacher?.id ?? null;
  }

  // NOTES
  createNote = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const teacherId = await this.resolveTeacherId(req.instituteId!, req.user!.userId);
      const data = await this.service.createNote(req.instituteId!, teacherId, req.body);
      return sendResponse({ res, data, message: 'Note uploaded successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  listNotes = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.listNotes(req.instituteId!, req.query.batchId as string);
      return sendResponse({ res, data, message: 'Notes fetched successfully' });
    } catch (e) { next(e); }
  }

  // ASSIGNMENTS
  createAssignment = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const teacherId = await this.resolveTeacherId(req.instituteId!, req.user!.userId);
      const data = await this.service.createAssignment(req.instituteId!, teacherId, req.body);
      emitBatchSync(req.instituteId!, req.body.batch_id, 'assignment_created', {
        assignment_id: (data as any)?.id,
      });
      return sendResponse({ res, data, message: 'Assignment uploaded successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  listAssignments = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const filter = {
        batchId: req.query.batchId as string,
        teacherId: req.query.teacherId as string
      };
      const data = await this.service.listAssignments(req.instituteId!, filter);
      return sendResponse({ res, data, message: 'Assignments fetched successfully' });
    } catch (e) { next(e); }
  }

  submitAssignment = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await prisma.student.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! },
        select: { id: true },
      });
      if (!student) {
        throw new Error('Student profile not found');
      }

      const data = await this.service.submitAssignment(
        req.instituteId!,
        req.params.assignmentId,
        student.id,
        req.body,
      );

      const assignment = await prisma.assignment.findFirst({
        where: { id: req.params.assignmentId, institute_id: req.instituteId! },
        select: { batch_id: true },
      });
      if (assignment?.batch_id) {
        emitBatchSync(req.instituteId!, assignment.batch_id, 'assignment_submitted', {
          assignment_id: req.params.assignmentId,
          student_id: student.id,
        });
      }

      return sendResponse({ res, data, message: 'Assignment submitted successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  listAssignmentSubmissions = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.listAssignmentSubmissions(req.instituteId!, req.params.assignmentId);
      return sendResponse({ res, data, message: 'Assignment submissions fetched successfully' });
    } catch (e) { next(e); }
  }

  reviewAssignmentSubmission = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.reviewAssignmentSubmission(
        req.instituteId!,
        req.params.submissionId,
        req.user!.userId,
        req.body,
      );

      const submission = await prisma.assignmentSubmission.findFirst({
        where: { id: req.params.submissionId, institute_id: req.instituteId! },
        include: { assignment: { select: { id: true, batch_id: true } } },
      });
      if (submission?.assignment?.batch_id) {
        emitBatchSync(req.instituteId!, submission.assignment.batch_id, 'assignment_reviewed', {
          assignment_id: submission.assignment.id,
          submission_id: req.params.submissionId,
        });
      }

      return sendResponse({ res, data, message: 'Assignment submission reviewed successfully' });
    } catch (e) { next(e); }
  }

  // DOUBTS
  askDoubt = async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Typically student_id is req.user.userId, but checking logic depends on the specific user schema implementation
      const data = await this.service.askDoubt(req.instituteId!, req.user!.userId, req.body);
      if (req.body.batch_id) {
        emitBatchSync(req.instituteId!, req.body.batch_id, 'doubt_created', {
          doubt_id: (data as any)?.id,
        });
      } else {
        emitInstituteDashboardSync(req.instituteId!, 'doubt_created');
      }
      return sendResponse({ res, data, message: 'Doubt submitted successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  respondDoubt = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.respondToDoubt(req.params.doubtId, req.instituteId!, req.user!.userId, req.body);
      const doubt = await prisma.doubt.findFirst({
        where: { id: req.params.doubtId, institute_id: req.instituteId! },
        select: { batch_id: true },
      });
      if (doubt?.batch_id) {
        emitBatchSync(req.instituteId!, doubt.batch_id, 'doubt_responded', {
          doubt_id: req.params.doubtId,
        });
      } else {
        emitInstituteDashboardSync(req.instituteId!, 'doubt_responded', { doubt_id: req.params.doubtId });
      }
      return sendResponse({ res, data, message: 'Doubt answer submitted successfully' });
    } catch (e) { next(e); }
  }

  listDoubts = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.listDoubts(req.instituteId!, {
          batchId: req.query.batchId as string,
          studentId: req.query.studentId as string,
          status: req.query.status as string
      });
      return sendResponse({ res, data, message: 'Doubts fetched successfully' });
    } catch (e) { next(e); }
  }
}
