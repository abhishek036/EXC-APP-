import { ExamRepository } from './exam.repository';
import { CreateExamInput, SaveExamResultInput } from './exam.validator';
import { NotificationService } from '../notification/notification.service';
import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';
import { resolveTeacherScope } from '../../utils/teacher-scope';

export class ExamService {
  private repo: ExamRepository;

  constructor() {
    this.repo = new ExamRepository();
  }

  async list(instituteId: string, status?: string, actor?: { role?: string; userId?: string }) {
    const now = new Date();
    const normalizedRole = (actor?.role ?? '').trim().toLowerCase();

    let exams: any[] = [];
    if (normalizedRole === 'teacher') {
      if (!actor?.userId) {
        throw new ApiError('Unauthorized teacher access', 401, 'UNAUTHORIZED');
      }

      const scope = await resolveTeacherScope(instituteId, actor.userId);
      if (scope.batchIds.length === 0) {
        return [];
      }
      exams = await this.repo.list(instituteId, scope.batchIds);
    } else {
      exams = await this.repo.list(instituteId);
    }

    return exams
      .map((exam) => {
        const computedStatus = exam.exam_date < now ? 'completed' : 'upcoming';
        return {
          id: exam.id,
          name: exam.title,
          subject: exam.subject,
          date: exam.exam_date,
          duration: exam.duration_min,
          totalMarks: exam.total_marks,
          batchId: exam.batches[0]?.batch_id ?? '',
          batchName: exam.batches[0]?.batch?.name ?? 'Batch',
          status: computedStatus,
        };
      })
      .filter((exam) => !status || exam.status === status);
  }

  async create(instituteId: string, userId: string, data: CreateExamInput) {
    return this.repo.create(instituteId, userId, data);
  }

  async setStatus(instituteId: string, examId: string, status: 'upcoming' | 'completed') {
    return this.repo.setStatus(instituteId, examId, status);
  }

  async remove(instituteId: string, examId: string) {
    return this.repo.remove(instituteId, examId);
  }

  async listResults(instituteId: string, actor?: { role?: string; userId?: string }) {
    const normalizedRole = (actor?.role ?? '').trim().toLowerCase();

    let results: any[] = [];
    if (normalizedRole === 'teacher') {
      if (!actor?.userId) {
        throw new ApiError('Unauthorized teacher access', 401, 'UNAUTHORIZED');
      }

      const scope = await resolveTeacherScope(instituteId, actor.userId);
      if (scope.batchIds.length === 0) {
        return [];
      }
      results = await this.repo.listResults(instituteId, scope.batchIds);
    } else {
      results = await this.repo.listResults(instituteId);
    }

    return results.map((result) => {
      const totalMarks = result.exam.total_marks;
      const score = Number(result.marks_obtained ?? 0);
      const grade = result.grade ?? '';
      return {
        id: result.id,
        studentName: result.student.name,
        examName: result.exam.title,
        subject: result.exam.subject,
        score,
        totalMarks,
        grade,
      };
    });
  }

  async saveResult(
    instituteId: string,
    data: SaveExamResultInput,
    actor?: { role?: string; userId?: string },
  ) {
    const normalizedRole = (actor?.role ?? '').trim().toLowerCase();
    if (normalizedRole === 'teacher') {
      if (!actor?.userId) {
        throw new ApiError('Unauthorized teacher access', 401, 'UNAUTHORIZED');
      }

      const scope = await resolveTeacherScope(instituteId, actor.userId);
      if (scope.batchIds.length === 0) {
        throw new ApiError('You are not assigned to any batches', 403, 'FORBIDDEN');
      }

      const examInScope = await prisma.exam.findFirst({
        where: {
          id: data.examId,
          institute_id: instituteId,
          batches: {
            some: {
              batch_id: { in: scope.batchIds },
            },
          },
        },
        select: { id: true },
      });

      if (!examInScope) {
        throw new ApiError('You can only publish results for your assigned batches', 403, 'FORBIDDEN');
      }
    }

    const result = await this.repo.saveResult(instituteId, data);

    const studentProfile = await prisma.student.findFirst({
      where: { id: data.studentId, institute_id: instituteId },
      select: {
        user_id: true,
        parent_students: {
          include: {
            parent: {
              select: { user_id: true },
            },
          },
        },
      },
    });

    const examTitle = result.exam?.title ?? 'Exam';
    const score = Number(result.marks_obtained ?? 0);
    const total = Number(result.exam?.total_marks ?? 0);
    const body = `Result published for ${examTitle}: ${score}/${total}.`;

    if (studentProfile?.user_id) {
      await NotificationService.sendNotificationToUser(studentProfile.user_id, {
        title: 'Result Published',
        body,
        type: 'result',
        role_target: 'student',
        institute_id: instituteId,
        meta: {
          route: '/student/results',
          exam_id: data.examId,
          dedupe_key: `result:student:${data.examId}:${data.studentId}`,
        },
      });
    }

    const parentUserIds = (studentProfile?.parent_students ?? [])
      .map((item) => item.parent.user_id)
      .filter((value): value is string => Boolean(value));

    for (const parentUserId of parentUserIds) {
      await NotificationService.sendNotificationToUser(parentUserId, {
        title: 'Result Published',
        body,
        type: 'result',
        role_target: 'parent',
        institute_id: instituteId,
        meta: {
          route: '/parent/results',
          exam_id: data.examId,
          dedupe_key: `result:parent:${parentUserId}:${data.examId}:${data.studentId}`,
        },
      });
    }

    return result;
  }
}
