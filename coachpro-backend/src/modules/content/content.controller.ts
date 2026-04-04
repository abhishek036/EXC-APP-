import { Request, Response, NextFunction } from 'express';
import { ContentService } from './content.service';
import { sendResponse } from '../../utils/response';
import { prisma } from '../../server';
import { emitBatchSync, emitInstituteDashboardSync } from '../../config/socket';
import { ApiError } from '../../middleware/error.middleware';

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

  private phoneVariants(phone: string | null | undefined): string[] {
    const clean = String(phone ?? '').replace(/[\s\-()]/g, '');
    if (!clean) return [];
    const set = new Set<string>([clean]);
    if (clean.startsWith('+91') && clean.length >= 13) set.add(clean.substring(3));
    if (clean.startsWith('91') && clean.length === 12) {
      const ten = clean.substring(2);
      set.add(ten);
      set.add(`+91${ten}`);
    }
    if (/^\d{10}$/.test(clean)) {
      set.add(`+91${clean}`);
      set.add(`91${clean}`);
    }
    return Array.from(set);
  }

  private async resolveStudentProfile(instituteId: string, userId: string): Promise<{ id: string; name: string | null; batch_ids: string[] } | null> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { phone: true },
    });
    const phones = this.phoneVariants(user?.phone);

    const orFilters: Array<Record<string, any>> = [{ user_id: userId }];
    if (phones.length > 0) {
      orFilters.push({ phone: { in: phones } });
    }

    const candidates = await prisma.student.findMany({
      where: {
        institute_id: instituteId,
        is_active: true,
        OR: orFilters,
      },
      include: {
        student_batches: {
          where: { is_active: true },
          select: { id: true, batch_id: true },
        },
      },
      orderBy: { created_at: 'desc' },
    });

    const ranked = [...candidates].sort((a, b) => {
      const aBatchCount = a.student_batches?.length || 0;
      const bBatchCount = b.student_batches?.length || 0;
      if (bBatchCount != aBatchCount) return bBatchCount - aBatchCount;

      const aLinked = a.user_id === userId ? 1 : 0;
      const bLinked = b.user_id === userId ? 1 : 0;
      if (bLinked != aLinked) return bLinked - aLinked;

      const aHasUser = a.user_id ? 1 : 0;
      const bHasUser = b.user_id ? 1 : 0;
      if (bHasUser != aHasUser) return bHasUser - aHasUser;

      const aCreated = new Date(a.created_at as any).getTime() || 0;
      const bCreated = new Date(b.created_at as any).getTime() || 0;
      return bCreated - aCreated;
    });

    const best = ranked[0] || null;

    if (!best) return null;

    if (!best.user_id) {
      await prisma.student.update({
        where: { id: best.id },
        data: { user_id: userId },
      });
    }

    return {
      id: best.id,
      name: best.name ?? null,
      batch_ids: (best.student_batches ?? []).map((item: any) => String(item.batch_id)).filter(Boolean),
    };
  }

  private assignmentProgressStatus(assignment: any, submission: any, feedback: any): 'not_started' | 'in_progress' | 'submitted' | 'late_submission' | 'evaluated' {
    if (!submission) return 'not_started';
    if (submission.is_draft || submission.status === 'in_progress') return 'in_progress';
    if (feedback || submission.status === 'evaluated') return 'evaluated';
    if (submission.is_late || submission.status === 'late_submission') return 'late_submission';
    return 'submitted';
  }

  private progressLabel(status: 'not_started' | 'in_progress' | 'submitted' | 'late_submission' | 'evaluated'): string {
    const map: Record<string, string> = {
      not_started: 'Not Started',
      in_progress: 'In Progress',
      submitted: 'Submitted',
      late_submission: 'Late Submission',
      evaluated: 'Evaluated',
    };
    return map[status] ?? 'Not Started';
  }

  private async ensureTeacherCanAccessAssignment(instituteId: string, userId: string, assignmentId: string) {
    const teacherId = await this.resolveTeacherId(instituteId, userId);
    if (!teacherId) {
      throw new ApiError('Teacher profile not found', 403, 'FORBIDDEN');
    }

    const assignment = await prisma.assignment.findFirst({
      where: {
        id: assignmentId,
        institute_id: instituteId,
        OR: [
          { teacher_id: teacherId },
          { batch: { teacher_id: teacherId } },
        ],
      },
      select: { id: true, batch_id: true, title: true, teacher_id: true },
    });

    if (!assignment) {
      throw new ApiError('You are not authorized to access this assignment', 403, 'FORBIDDEN');
    }

    return assignment;
  }

  private async ensureStudentCanAccessAssignment(instituteId: string, student: { id: string; batch_ids: string[] }, assignmentId: string) {
    const assignment = await prisma.assignment.findFirst({
      where: { id: assignmentId, institute_id: instituteId },
      select: { id: true, batch_id: true, title: true, teacher_id: true },
    });

    if (!assignment) {
      throw new ApiError('Assignment not found', 404, 'NOT_FOUND');
    }

    if (student.batch_ids.length > 0 && !student.batch_ids.includes(String(assignment.batch_id))) {
      throw new ApiError('You are not authorized to access this assignment', 403, 'FORBIDDEN');
    }

    return assignment;
  }

  // NOTES
  createNote = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const teacherId = await this.resolveTeacherId(req.instituteId!, req.user!.userId);
      const data = await this.service.createNote(req.instituteId!, teacherId, req.body);
      
      // Notify students
      const { NotificationService } = await import('../notification/notification.service');
      const students = await prisma.student.findMany({
        where: { student_batches: { some: { batch_id: req.body.batch_id } }, is_active: true },
        select: { user_id: true }
      });

      for (const student of students) {
        if (student.user_id) {
          await NotificationService.sendNotificationToUser(student.user_id, {
            title: 'New Study Material',
            body: `New study material "${req.body.title}" has been uploaded to your batch.`,
            type: 'material',
            institute_id: req.instituteId!,
            meta: {
              route: '/student/materials',
              note_id: (data as any)?.id
            }
          });
        }
      }

      return sendResponse({ res, data, message: 'Note uploaded successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  listNotes = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.listNotes(req.instituteId!, req.query.batchId as string, req.query.subject as string);
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

      // Notify students
      const { NotificationService } = await import('../notification/notification.service');
      const students = await prisma.student.findMany({
        where: { student_batches: { some: { batch_id: req.body.batch_id } }, is_active: true },
        select: { user_id: true }
      });

      for (const student of students) {
        if (student.user_id) {
          await NotificationService.sendNotificationToUser(student.user_id, {
            title: 'New Assignment',
            body: `You have a new assignment: "${req.body.title}". Check details and submit before deadline.`,
            type: 'material',
            institute_id: req.instituteId!,
            meta: {
              route: '/student/assignments',
              assignment_id: (data as any)?.id
            }
          });
        }
      }

      return sendResponse({ res, data, message: 'Assignment uploaded successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  listAssignments = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const filter = {
        batchId: req.query.batchId as string,
        teacherId: req.query.teacherId as string,
        subject: req.query.subject as string
      };
      const baseAssignments = await this.service.listAssignments(req.instituteId!, filter);

      if (req.user?.role === 'student' && Array.isArray(baseAssignments)) {
        const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
        if (!student) {
          throw new ApiError('Student profile not found', 404, 'NOT_FOUND');
        }

        const studentAssignments = baseAssignments.filter((assignment: any) => {
          if (!assignment?.batch_id) return false;
          if (student.batch_ids.length === 0) return true;
          return student.batch_ids.includes(String(assignment.batch_id));
        });

        const assignmentIds = studentAssignments.map((a: any) => String(a.id)).filter(Boolean);
        if (assignmentIds.length === 0) {
          return sendResponse({ res, data: [], message: 'Assignments fetched successfully' });
        }

        const submissions = await prisma.assignmentSubmission.findMany({
          where: {
            institute_id: req.instituteId!,
            student_id: student.id,
            assignment_id: { in: assignmentIds },
            is_latest: true,
          },
          select: {
            id: true,
            assignment_id: true,
            file_url: true,
            file_name: true,
            file_mime_type: true,
            file_size_kb: true,
            submission_text: true,
            status: true,
            is_draft: true,
            is_late: true,
            attempt_no: true,
            submitted_at: true,
            reviewed_at: true,
            marks_obtained: true,
            remarks: true,
          },
        });

        const submissionIds = submissions.map((item) => item.id);
        const feedbacks = submissionIds.length > 0
          ? await prisma.assignmentFeedback.findMany({
            where: {
              institute_id: req.instituteId!,
              assignment_submission_id: { in: submissionIds },
              is_latest: true,
            },
            orderBy: { revision_no: 'desc' },
          })
          : [];

        const byAssignment = new Map<string, any>();
        for (const item of submissions) byAssignment.set(String(item.assignment_id), item);

        const bySubmission = new Map<string, any>();
        for (const fb of feedbacks) {
          if (!bySubmission.has(String(fb.assignment_submission_id))) {
            bySubmission.set(String(fb.assignment_submission_id), fb);
          }
        }

        const enriched = studentAssignments.map((assignment: any) => {
          const submission = byAssignment.get(String(assignment.id)) ?? null;
          const feedback = submission ? bySubmission.get(String(submission.id)) ?? null : null;
          const progressStatus = this.assignmentProgressStatus(assignment, submission, feedback);
          return {
            ...assignment,
            my_submission: submission,
            my_feedback: feedback,
            progress_status: progressStatus,
            progress_label: this.progressLabel(progressStatus),
          };
        });

        return sendResponse({ res, data: enriched, message: 'Assignments fetched successfully' });
      }

      return sendResponse({ res, data: baseAssignments, message: 'Assignments fetched successfully' });
    } catch (e) { next(e); }
  }

  saveAssignmentDraft = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
      if (!student) {
        throw new ApiError('Student profile not found', 404, 'NOT_FOUND');
      }

      await this.ensureStudentCanAccessAssignment(req.instituteId!, student, req.params.assignmentId);

      const data = await this.service.saveAssignmentDraft(
        req.instituteId!,
        req.params.assignmentId,
        student.id,
        req.body,
      );

      return sendResponse({ res, data, message: 'Assignment draft saved successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  submitAssignment = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
      if (!student) {
        throw new ApiError('Student profile not found', 404, 'NOT_FOUND');
      }

      const assignment = await this.ensureStudentCanAccessAssignment(req.instituteId!, student, req.params.assignmentId);

      const data = await this.service.submitAssignment(
        req.instituteId!,
        req.params.assignmentId,
        student.id,
        req.body,
      );

      if (assignment?.batch_id) {
        emitBatchSync(req.instituteId!, assignment.batch_id, 'assignment_submitted', {
          assignment_id: req.params.assignmentId,
          student_id: student.id,
        });

        // Notify teacher about submission
        try {
          const { NotificationService } = await import('../notification/notification.service');
          if (assignment.teacher_id) {
            const teacher = await prisma.teacher.findUnique({
              where: { id: assignment.teacher_id },
              select: { user_id: true }
            });
            if (teacher?.user_id) {
              await NotificationService.sendNotificationToUser(teacher.user_id, {
                title: 'Assignment Submitted',
                body: `${student.name || 'A student'} submitted "${assignment.title || 'an assignment'}" for review.`,
                type: 'material',
                institute_id: req.instituteId!,
                meta: {
                  route: '/teacher/assignments',
                  assignment_id: req.params.assignmentId,
                  student_id: student.id
                }
              });
            }
          }
        } catch (err) {
          console.error('[ContentController] Failed to send teacher assignment notification:', err);
        }
      }

      return sendResponse({ res, data, message: 'Assignment submitted successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  listMyAssignmentSubmissions = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
      if (!student) {
        throw new ApiError('Student profile not found', 404, 'NOT_FOUND');
      }

      await this.ensureStudentCanAccessAssignment(req.instituteId!, student, req.params.assignmentId);

      const data = await this.service.listMyAssignmentSubmissions(
        req.instituteId!,
        req.params.assignmentId,
        student.id,
      );

      return sendResponse({ res, data, message: 'My assignment submissions fetched successfully' });
    } catch (e) { next(e); }
  }

  listAssignmentSubmissions = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (req.user?.role === 'teacher') {
        await this.ensureTeacherCanAccessAssignment(req.instituteId!, req.user!.userId, req.params.assignmentId);
      }

      const data = await this.service.listAssignmentSubmissions(req.instituteId!, req.params.assignmentId);
      return sendResponse({ res, data, message: 'Assignment submissions fetched successfully' });
    } catch (e) { next(e); }
  }

  getAssignmentSubmissionFeedback = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const submission = await prisma.assignmentSubmission.findFirst({
        where: { id: req.params.submissionId, institute_id: req.instituteId! },
        include: {
          assignment: { select: { id: true, batch_id: true, teacher_id: true } },
        },
      });

      if (!submission) {
        throw new ApiError('Assignment submission not found', 404, 'NOT_FOUND');
      }

      if (req.user?.role === 'student') {
        const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
        if (!student || submission.student_id !== student.id) {
          throw new ApiError('You are not authorized to access this feedback', 403, 'FORBIDDEN');
        }
      }

      if (req.user?.role === 'teacher') {
        await this.ensureTeacherCanAccessAssignment(req.instituteId!, req.user!.userId, submission.assignment_id);
      }

      const data = await this.service.getAssignmentSubmissionFeedback(req.instituteId!, req.params.submissionId);
      return sendResponse({ res, data, message: 'Assignment feedback history fetched successfully' });
    } catch (e) { next(e); }
  }

  reviewAssignmentSubmission = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (req.user?.role === 'teacher') {
        const submission = await prisma.assignmentSubmission.findFirst({
          where: { id: req.params.submissionId, institute_id: req.instituteId! },
          select: { assignment_id: true },
        });

        if (!submission) {
          throw new ApiError('Assignment submission not found', 404, 'NOT_FOUND');
        }

        await this.ensureTeacherCanAccessAssignment(req.instituteId!, req.user!.userId, submission.assignment_id);
      }

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
        
        // Notify student
        const { NotificationService } = await import('../notification/notification.service');
        const student = await prisma.student.findFirst({
           where: { id: submission.student_id },
           select: { user_id: true }
        });
        
        if (student?.user_id) {
           await NotificationService.sendNotificationToUser(student.user_id, {
              title: 'Assignment Reviewed',
              body: `Your submission has been reviewed.`,
              type: 'material',
              institute_id: req.instituteId!,
              meta: {
                 route: '/student/assignments',
                 assignment_id: submission.assignment.id
              }
           });
        }
      }

      return sendResponse({ res, data, message: 'Assignment submission reviewed successfully' });
    } catch (e) { next(e); }
  }

  assignmentAnalytics = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const filter = {
        batchId: req.query.batchId as string,
        teacherId: req.query.teacherId as string,
        subject: req.query.subject as string,
      };

      if (req.user?.role === 'teacher') {
        const teacherId = await this.resolveTeacherId(req.instituteId!, req.user!.userId);
        if (!teacherId) {
          throw new ApiError('Teacher profile not found', 403, 'FORBIDDEN');
        }
        filter.teacherId = teacherId;
      }

      const data = await this.service.getAssignmentAnalytics(req.instituteId!, filter);
      return sendResponse({ res, data, message: 'Assignment analytics fetched successfully' });
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

        // Notify teacher about new doubt
        try {
          const { NotificationService } = await import('../notification/notification.service');
          const batch = await prisma.batch.findUnique({
            where: { id: req.body.batch_id },
            select: { teacher_id: true, name: true, institute: { select: { settings: true } } }
          });
          if (batch) {
            const metaMap = (batch.institute.settings as any)?.batch_meta || {};
            const batchMeta = metaMap[req.body.batch_id] || {};
            const teacherIds = [batch.teacher_id, ...(Array.isArray(batchMeta.teacher_ids) ? batchMeta.teacher_ids : [])].filter(Boolean);

            for (const tId of teacherIds) {
              const teacher = await prisma.teacher.findUnique({
                where: { id: tId },
                select: { user_id: true }
              });
              if (teacher?.user_id) {
                await NotificationService.sendNotificationToUser(teacher.user_id, {
                  title: 'New Doubt from Student',
                  body: `A student has a new doubt in "${batch.name || 'your batch'}": "${((req.body.question_text || 'doubt') as string).substring(0, 50)}..."`,
                  type: 'doubt',
                  institute_id: req.instituteId!,
                  meta: {
                    route: '/teacher/doubts',
                    doubt_id: (data as any)?.id,
                    batch_id: req.body.batch_id
                  }
                });
              }
            }
          }
        } catch (err) {
          console.error('[ContentController] Failed to send doubt notification to teacher:', err);
        }
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

      // Notify student
      const actualDoubt = await prisma.doubt.findUnique({
        where: { id: req.params.doubtId },
        select: { student_id: true }
      });
      
      const { NotificationService } = await import('../notification/notification.service');
      const student = await prisma.student.findFirst({
        where: { id: actualDoubt?.student_id },
        select: { user_id: true }
      });

      if (student?.user_id) {
        await NotificationService.sendNotificationToUser(student.user_id, {
          title: 'Doubt Resolved',
          body: 'Your doubt has been answered. Click to view solution.',
          type: 'doubt',
          institute_id: req.instituteId!,
          meta: {
            route: '/student/doubts/history',
            doubt_id: req.params.doubtId
          }
        });
      }

      return sendResponse({ res, data, message: 'Doubt answer submitted successfully' });
    } catch (e) { next(e); }
  }

  listDoubts = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.listDoubts(req.instituteId!, {
          batchId: req.query.batchId as string,
          studentId: req.query.studentId as string,
          status: req.query.status as string,
          subject: req.query.subject as string
      });
      return sendResponse({ res, data, message: 'Doubts fetched successfully' });
    } catch (e) { next(e); }
  }
}
