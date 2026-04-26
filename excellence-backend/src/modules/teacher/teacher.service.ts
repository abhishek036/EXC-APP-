import { TeacherRepository } from './teacher.repository';
import { CreateTeacherInput, UpdateTeacherInput, UpdateTeacherSettingsInput, AddTeacherFeedbackInput } from './teacher.validator';
import { ApiError } from '../../middleware/error.middleware';
import { prisma } from '../../config/prisma';
import { batchHasTeacher } from '../../utils/batch-teacher-assignment';

export class TeacherService {
  private teacherRepository: TeacherRepository;

  constructor() {
    this.teacherRepository = new TeacherRepository();
  }

  private defaultPermissions() {
    return {
      can_edit_attendance: true,
      can_see_fee_data: false,
      can_upload_study_material: true,
      can_create_exams: false,
      can_manage_students: false,
    };
  }

  private async getTeacherMetaMap(instituteId: string): Promise<Record<string, any>> {
    const institute = await prisma.institute.findUnique({
      where: { id: instituteId },
      select: { settings: true },
    });

    const settings = (institute?.settings ?? {}) as Record<string, any>;
    const map = settings['teacher_meta'];
    if (map && typeof map === 'object' && !Array.isArray(map)) return { ...map };
    return {};
  }

  private async updateTeacherMeta(instituteId: string, teacherId: string, updateFn: (prev: any) => any) {
    return prisma.$transaction(async (tx) => {
      const institute = await tx.institute.findUnique({
        where: { id: instituteId },
        select: { settings: true },
      });
      const settings = (institute?.settings ?? {}) as Record<string, any>;
      const map = (settings['teacher_meta'] ?? {}) as Record<string, any>;
      const previous = (map[teacherId] ?? {}) as Record<string, any>;

      const next = updateFn(previous);

      map[teacherId] = {
        ...next,
        updated_at: new Date().toISOString(),
      };

      await tx.institute.update({
        where: { id: instituteId },
        data: {
          settings: {
            ...settings,
            teacher_meta: map,
          },
        },
      });
      return next;
    });
  }

  private async getTeacherMeta(instituteId: string, teacherId: string): Promise<Record<string, any>> {
    const map = await this.getTeacherMetaMap(instituteId);
    const item = map[teacherId];
    if (item && typeof item === 'object' && !Array.isArray(item)) return item;
    return {};
  }

  private toNumber(value: unknown): number | null {
    if (value == null) return null;
    if (typeof value === 'number' && !Number.isNaN(value)) return value;
    const parsed = Number(value);
    return Number.isNaN(parsed) ? null : parsed;
  }

  async listTeachers(instituteId: string, query: { name?: string, phone?: string, page?: number, perPage?: number }) {
    const page = parseInt(query.page as any) || 1;
    const perPage = parseInt(query.perPage as any) || 20;
    const skip = (page - 1) * perPage;

    const { teachers, total } = await this.teacherRepository.listTeachers(instituteId, { name: query.name, phone: query.phone }, { skip, take: perPage });
    const metaMap = await this.getTeacherMetaMap(instituteId);
    
    return {
      data: teachers.map(t => ({
        ...t,
        batches_count: t._count.batches,
        permissions: (metaMap[t.id]?.permissions ?? this.defaultPermissions()),
        compensation: {
          salary: this.toNumber(metaMap[t.id]?.salary),
          revenue_share: this.toNumber(metaMap[t.id]?.revenue_share),
        }
      })),
      meta: {
        page,
        perPage,
        total,
        totalPages: Math.ceil(total / perPage)
      }
    };
  }

  async getTeacherDetails(teacherId: string, instituteId: string) {
    const teacher = await this.teacherRepository.findTeacherById(teacherId, instituteId);
    if (!teacher) {
        throw new ApiError('Teacher not found', 404, 'NOT_FOUND');
    }

    const meta = await this.getTeacherMeta(instituteId, teacherId);

    return {
      ...teacher,
      permissions: meta.permissions ?? this.defaultPermissions(),
      compensation: {
        salary: this.toNumber(meta.salary),
        revenue_share: this.toNumber(meta.revenue_share),
      },
      feedback_summary: {
        average_rating: this.toNumber(meta.feedback_summary?.average_rating) ?? 0,
        feedback_count: this.toNumber(meta.feedback_summary?.feedback_count) ?? 0,
      },
    };
  }

  async createTeacher(instituteId: string, data: CreateTeacherInput) {
    const createdTeacher = await this.teacherRepository.createTeacherWithUser(instituteId, data);

    const permissions = {
      ...this.defaultPermissions(),
      ...(data.permissions ?? {}),
    };
    const salary = this.toNumber(data.salary);
    const revenueShare = this.toNumber(data.revenue_share);

    await this.updateTeacherMeta(instituteId, createdTeacher.id, () => ({
      permissions,
      salary,
      revenue_share: revenueShare,
      feedbacks: [],
      feedback_summary: {
        average_rating: 0,
        feedback_count: 0,
      },
    }));

    return createdTeacher;
  }

  async updateTeacher(teacherId: string, instituteId: string, data: UpdateTeacherInput) {
    const patch = (data ?? {}) as NonNullable<UpdateTeacherInput>;
    const teacher = await this.teacherRepository.findTeacherById(teacherId, instituteId);
    if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

    const updated = await this.teacherRepository.updateTeacher(teacherId, instituteId, patch);

    const hasSettingsPatch = patch.salary !== undefined || patch.revenue_share !== undefined || patch.permissions !== undefined;
    if (hasSettingsPatch) {
      await this.updateTeacherSettings(teacherId, instituteId, {
        salary: patch.salary,
        revenue_share: patch.revenue_share,
        permissions: patch.permissions,
      });
    }

    return updated;
  }

  async changeStatus(teacherId: string, instituteId: string, isActive: boolean) {
    const teacher = await this.teacherRepository.findTeacherById(teacherId, instituteId);
    if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

    return this.teacherRepository.toggleStatus(teacherId, isActive);
  }

  async removeTeacher(teacherId: string, instituteId: string) {
    const teacher = await this.teacherRepository.findTeacherById(teacherId, instituteId);
    if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

    const removed = await this.teacherRepository.removeTeacher(teacherId, instituteId);

    const institute = await prisma.institute.findUnique({
      where: { id: instituteId },
      select: { settings: true },
    });

    const settings = (institute?.settings ?? {}) as Record<string, any>;
    const teacherMeta = (settings['teacher_meta'] ?? {}) as Record<string, any>;
    if (Object.prototype.hasOwnProperty.call(teacherMeta, teacherId)) {
      delete teacherMeta[teacherId];
      await prisma.institute.update({
        where: { id: instituteId },
        data: {
          settings: {
            ...settings,
            teacher_meta: teacherMeta,
          },
        },
      });
    }

    return removed;
  }

  async updateTeacherSettings(teacherId: string, instituteId: string, data: UpdateTeacherSettingsInput) {
    const teacher = await this.teacherRepository.findTeacherById(teacherId, instituteId);
    if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

    const result = await this.updateTeacherMeta(instituteId, teacherId, (previous) => {
      const nextPermissions = {
        ...this.defaultPermissions(),
        ...(previous.permissions ?? {}),
        ...(data.permissions ?? {}),
      };

      const nextSalary = data.salary !== undefined ? this.toNumber(data.salary) : this.toNumber(previous.salary);
      const nextRevenueShare = data.revenue_share !== undefined ? this.toNumber(data.revenue_share) : this.toNumber(previous.revenue_share);

      return {
        ...previous,
        permissions: nextPermissions,
        salary: nextSalary,
        revenue_share: nextRevenueShare,
        feedbacks: Array.isArray(previous.feedbacks) ? previous.feedbacks : [],
        feedback_summary: previous.feedback_summary ?? { average_rating: 0, feedback_count: 0 },
      };
    });

    return {
      permissions: result.permissions,
      salary: result.salary,
      revenue_share: result.revenue_share,
    };
  }

  async getTeacherProfileDashboard(teacherId: string, instituteId: string) {
    const teacher = await this.teacherRepository.findTeacherById(teacherId, instituteId);
    if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

    const meta = await this.getTeacherMeta(instituteId, teacherId);
    const teacherIdentifiers = [teacher.id, teacher.user_id].filter((id): id is string => Boolean(id));
    const institute = await prisma.institute.findUnique({
      where: { id: instituteId },
      select: { settings: true },
    });
    const settings = (institute?.settings ?? {}) as Record<string, any>;
    const batchMetaMap = (settings['batch_meta'] ?? {}) as Record<string, any>;

    const directBatches = await prisma.batch.findMany({
      where: { institute_id: instituteId, teacher_id: teacherId, is_active: true },
      select: { id: true, teacher_id: true },
    });

    const assignedBatchIds = new Set<string>();
    for (const batch of directBatches) {
      const batchMeta = (batchMetaMap[batch.id] ?? {}) as Record<string, unknown>;
      if (batchHasTeacher(batchMeta, batch.teacher_id, teacherIdentifiers)) {
        assignedBatchIds.add(batch.id);
      }
    }

    for (const [batchId, metaValue] of Object.entries(batchMetaMap)) {
      if (assignedBatchIds.has(batchId)) continue;

      const batchMeta = (metaValue ?? {}) as Record<string, unknown>;
      if (batchHasTeacher(batchMeta, null, teacherIdentifiers)) {
        assignedBatchIds.add(batchId);
      }
    }

    const assignedBatches = assignedBatchIds.size > 0
      ? await prisma.batch.findMany({
        where: {
          id: { in: Array.from(assignedBatchIds) },
          institute_id: instituteId,
          is_active: true,
        },
        include: {
          _count: { select: { student_batches: { where: { is_active: true } } } },
        },
      })
      : [];

    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const [
      totalSessions,
      sessionsLast30,
      classesTakenThisWeek,
      pendingDoubts,
      recentAttendanceSessions,
      recentLectures,
      recentQuizzes,
      recentNotes,
      recentAssignments,
    ] = await Promise.all([
      prisma.attendanceSession.count({ where: { institute_id: instituteId, teacher_id: teacherId } }),
      prisma.attendanceSession.count({ where: { institute_id: instituteId, teacher_id: teacherId, session_date: { gte: thirtyDaysAgo } } }),
      prisma.attendanceSession.count({ where: { institute_id: instituteId, teacher_id: teacherId, session_date: { gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) } } }),
      prisma.doubt.count({ where: { institute_id: instituteId, assigned_to_id: teacherId, status: 'pending' } }),
      prisma.attendanceSession.findMany({
        where: { institute_id: instituteId, teacher_id: teacherId },
        orderBy: { submitted_at: 'desc' },
        take: 6,
        include: { batch: { select: { id: true, name: true } } }
      }),
      prisma.lecture.findMany({
        where: { institute_id: instituteId, teacher_id: teacherId },
        select: { id: true, title: true, scheduled_at: true, batch_id: true, batch: { select: { name: true } } },
        orderBy: { created_at: 'desc' },
        take: 6,
      }),
      prisma.quiz.findMany({
        where: { institute_id: instituteId, teacher_id: teacherId },
        select: { id: true, title: true, created_at: true, batch_id: true, batch: { select: { name: true } } },
        orderBy: { created_at: 'desc' },
        take: 6,
      }),
      prisma.note.findMany({
        where: { institute_id: instituteId, teacher_id: teacherId },
        select: { id: true, title: true, created_at: true, batch: { select: { name: true } } },
        orderBy: { created_at: 'desc' },
        take: 6,
      }),
      prisma.assignment.findMany({
        where: { institute_id: instituteId, teacher_id: teacherId },
        select: { id: true, title: true, created_at: true, batch: { select: { name: true } } },
        orderBy: { created_at: 'desc' },
        take: 6,
      }),
    ]);

    const activity = [
      ...recentAttendanceSessions.map((item) => ({
        type: 'attendance_marked',
        title: 'Marked attendance',
        batch_name: item.batch?.name ?? 'Batch',
        at: item.submitted_at ?? item.session_date,
      })),
      ...recentLectures.map((item) => ({
        type: 'lecture_taught',
        title: item.title,
        batch_name: item.batch?.name ?? 'Batch',
        at: item.scheduled_at,
      })),
      ...recentQuizzes.map((item) => ({
        type: 'quiz_updated',
        title: item.title,
        batch_name: item.batch?.name ?? 'Batch',
        at: item.created_at,
      })),
      ...recentNotes.map((item) => ({
        type: 'material_uploaded',
        title: item.title,
        batch_name: item.batch?.name ?? 'Batch',
        at: item.created_at,
      })),
      ...recentAssignments.map((item) => ({
        type: 'assignment_posted',
        title: item.title,
        batch_name: item.batch?.name ?? 'Batch',
        at: item.created_at,
      })),
    ].sort((a, b) => {
      const atA = a.at ? new Date(a.at as any).getTime() : 0;
      const atB = b.at ? new Date(b.at as any).getTime() : 0;
      return atB - atA;
    }).slice(0, 20);

    const feedbacks = Array.isArray(meta.feedbacks) ? meta.feedbacks : [];
    const averageRating = feedbacks.length > 0
      ? feedbacks.reduce((sum: number, item: any) => sum + (this.toNumber(item.rating) ?? 0), 0) / feedbacks.length
      : 0;

    return {
      teacher: {
        ...teacher,
        batches: assignedBatches,
      },
      stats: {
        batches_assigned: assignedBatches.length,
        total_sessions_taken: totalSessions,
        sessions_last_30_days: sessionsLast30,
        classes_this_week: classesTakenThisWeek,
        pending_doubts: pendingDoubts,
        average_rating: Number(averageRating.toFixed(2)),
      },
      permissions: {
        ...this.defaultPermissions(),
        ...(meta.permissions ?? {}),
      },
      compensation: {
        salary: this.toNumber(meta.salary),
        revenue_share: this.toNumber(meta.revenue_share),
      },
      feedback_summary: {
        average_rating: Number(averageRating.toFixed(2)),
        feedback_count: feedbacks.length,
        recent_feedbacks: feedbacks.slice(0, 10),
      },
      attendance: {
        total_sessions_taken: totalSessions,
        sessions_last_30_days: sessionsLast30,
      },
      activity_timeline: activity,
    };
  }

  async addTeacherFeedback(teacherId: string, instituteId: string, data: AddTeacherFeedbackInput) {
    const teacher = await this.teacherRepository.findTeacherById(teacherId, instituteId);
    if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

    const result = await this.updateTeacherMeta(instituteId, teacherId, (previous) => {
        const oldFeedbacks = Array.isArray(previous.feedbacks) ? previous.feedbacks : [];
        const feedbackItem = {
          rating: data.rating,
          comment: data.comment ?? null,
          student_name: data.student_name ?? null,
          created_at: new Date().toISOString(),
        };

        const feedbacks = [feedbackItem, ...oldFeedbacks].slice(0, 100);
        const averageRating = feedbacks.reduce((sum, item) => sum + (this.toNumber(item.rating) ?? 0), 0) / (feedbacks.length || 1);

        return {
          ...previous,
          feedbacks,
          feedback_summary: {
            average_rating: Number(averageRating.toFixed(2)),
            feedback_count: feedbacks.length,
          },
        };
    });

    return {
      average_rating: result.feedback_summary.average_rating,
      feedback_count: result.feedback_summary.feedback_count,
      recent_feedbacks: result.feedbacks.slice(0, 10),
    };
  }
}
