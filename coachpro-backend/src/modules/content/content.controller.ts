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

  private async resolveStudentProfile(instituteId: string, userId: string): Promise<{ id: string; name: string | null } | null> {
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
          select: { id: true },
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

    return { id: best.id, name: best.name ?? null };
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
      const data = await this.service.listAssignments(req.instituteId!, filter);

      if (req.user?.role === 'student' && Array.isArray(data) && data.length > 0) {
        const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
        if (student) {
          const assignmentIds = data
            .map((a: any) => String(a?.id ?? ''))
            .filter((id: string) => id.length > 0);

          if (assignmentIds.length > 0) {
            const submissions = await prisma.assignmentSubmission.findMany({
              where: {
                institute_id: req.instituteId!,
                student_id: student.id,
                assignment_id: { in: assignmentIds },
              },
              select: {
                id: true,
                assignment_id: true,
                file_url: true,
                submission_text: true,
                status: true,
                submitted_at: true,
                reviewed_at: true,
                marks_obtained: true,
                remarks: true,
              },
            });

            const byAssignment = new Map<string, any>();
            for (const s of submissions) byAssignment.set(s.assignment_id, s);

            const enriched = data.map((a: any) => ({
              ...a,
              my_submission: byAssignment.get(String(a?.id ?? '')) ?? null,
            }));

            return sendResponse({ res, data: enriched, message: 'Assignments fetched successfully' });
          }
        }
      }

      return sendResponse({ res, data, message: 'Assignments fetched successfully' });
    } catch (e) { next(e); }
  }

  submitAssignment = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
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
        select: { batch_id: true, title: true, teacher_id: true },
      });
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
